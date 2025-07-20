import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup/home_components/home.dart';
import 'package:startup/home_tabs/for_you.dart';

class LocationMapPage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String uid;

  const LocationMapPage({
    super.key,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.uid,
  });

  @override
  State<LocationMapPage> createState() => _LocationMapPageState();
}

class _LocationMapPageState extends State<LocationMapPage> {
  LatLng? currentLatLng;
  String? currentAddress;
  GoogleMapController? mapController;
  Stream<Position>? positionStream;
  DateTime lastUpdated = DateTime.fromMillisecondsSinceEpoch(0);

  final String darkMapStyle = '''[{"elementType":"geometry","stylers":[{"color":"#212121"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#757575"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#212121"}]},
  {"featureType":"administrative","elementType":"geometry","stylers":[{"color":"#757575"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#181818"}]},
  {"featureType":"road","elementType":"geometry.fill","stylers":[{"color":"#2c2c2c"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#1a1a1a"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#111111"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#000000"}]}]''';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _requestPermissionPopup);
  }

  Future<void> _requestPermissionPopup() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Location Access", style: TextStyle(color: Colors.white)),
        content: const Text("Allow blynt to access your location for better experience?",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Deny", style: TextStyle(color: Colors.redAccent))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Allow", style: TextStyle(color: Colors.greenAccent))),
        ],
      ),
    );

    if (result == true) {
      _startLiveLocationListener();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location permission required.")));
    }
  }

  Future<void> _startLiveLocationListener() async {
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      _showPreciseLocationInfo();
      return;
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 100),
    );

    positionStream!.listen((Position position) async {
      if (position.latitude == 0.0 && position.longitude == 0.0) return;
      if (DateTime.now().difference(lastUpdated).inSeconds < 30) return;
      lastUpdated = DateTime.now();

      currentLatLng = LatLng(position.latitude, position.longitude);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      double? cachedLat = prefs.getDouble('lat');
      double? cachedLng = prefs.getDouble('lng');
      String? cachedAddress = prefs.getString('address');

      if (cachedLat != null &&
          cachedLng != null &&
          Geolocator.distanceBetween(cachedLat, cachedLng, currentLatLng!.latitude, currentLatLng!.longitude) < 100 &&
          cachedAddress != null) {
        currentAddress = cachedAddress;
      } else {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
              currentLatLng!.latitude, currentLatLng!.longitude);
          Placemark place = placemarks.first;

          currentAddress = [
            place.street,
            place.subLocality,
            place.locality,
            place.postalCode,
            place.administrativeArea,
            place.country
          ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

          await prefs.setDouble('lat', currentLatLng!.latitude);
          await prefs.setDouble('lng', currentLatLng!.longitude);
          await prefs.setString('address', currentAddress!);
        } catch (e) {
          currentAddress = "Unknown location";
        }
      }

      setState(() {});
    });
  }

  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return false;

    // Check for accurate location
    final position = await Geolocator.getCurrentPosition();
    if (position.accuracy > 100) {
      return false;
    }

    return true;
  }

  void _showPreciseLocationInfo() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Precise Location Needed", style: TextStyle(color: Colors.white)),
        content: const Text("Please enable Precise Location in your phone settings for accurate recommendations.",
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Geolocator.openAppSettings();
            },
            child: const Text("Open Settings", style: TextStyle(color: Colors.greenAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    controller.setMapStyle(darkMapStyle);
    if (currentLatLng != null) {
      controller.animateCamera(CameraUpdate.newLatLng(currentLatLng!));
    }
  }

  Future<void> _onConfirm() async {
  if (currentLatLng == null || currentAddress == null) return;

  final userDoc = FirebaseFirestore.instance.collection("users").doc(widget.uid);
  final docSnapshot = await userDoc.get();

  final existingAddress = docSnapshot.data()?['address'];
  final existingCoords = docSnapshot.data()?['coordinates'];
  final existingLat = (existingCoords?['latitude'] as num?)?.toDouble();
  final existingLng = (existingCoords?['longitude'] as num?)?.toDouble();

  final distance = existingLat != null && existingLng != null
      ? Geolocator.distanceBetween(existingLat, existingLng, currentLatLng!.latitude, currentLatLng!.longitude)
      : double.infinity;

  if (existingAddress != currentAddress || distance > 100) {
    await userDoc.set({
      'address': currentAddress,
      'coordinates': {
        'latitude': currentLatLng!.latitude,
        'longitude': currentLatLng!.longitude,
      },
      'timestamp': DateTime.now(),
    }, SetOptions(merge: true));
  }

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => Home(
        firstName: widget.firstName,
        lastName: widget.lastName,
        username: widget.username,
        uid: widget.uid,
      ),
    ),
  );
  Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ForYouTab(),
  ),
);

}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: currentLatLng == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: currentLatLng!, zoom: 16),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          currentAddress ?? "Fetching location...",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurpleAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Confirm", style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                )
              ],
            ),
    );
  }
}
