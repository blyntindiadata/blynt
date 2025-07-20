import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:startup/models.dart/outlet_model.dart';
import 'package:startup/helpers/users_utils.dart';
import 'package:startup/outlets/outlet_details.dart';

class ForYouTab extends StatefulWidget {
  const ForYouTab({Key? key}) : super(key: key);

  @override
  State<ForYouTab> createState() => _ForYouTabState();
}

class _ForYouTabState extends State<ForYouTab> {
  Future<List<Outlet>>? _recommendations;

  @override
  void initState() {
    super.initState();
    _loadUsernameAndFetch();
  }

  Future<void> _loadUsernameAndFetch() async {
    final storedUsername = await getOrFetchUsername();
    print("🔍 Stored username: $storedUsername");

    if (storedUsername != null && storedUsername.isNotEmpty) {
      setState(() {
        _recommendations = fetchRecommendations(storedUsername);
      });
    } else {
      setState(() {
        _recommendations = Future.error('❌ Username not found. Please log in again.');
      });
    }
  }

  Future<List<Outlet>> fetchRecommendations(String username) async {
    try {
      print("📤 Sending recommendation request for username: $username");

      final response = await http.post(
        Uri.parse('https://blyntfinal-201410726574.asia-south1.run.app/recommend_firebase'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username}),
      );

      print("✅ Status Code: ${response.statusCode}");
      print("📥 Raw Response: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List matches = data['matches'];

        if (matches.isEmpty) {
          print("⚠️ No matches found.");
          return [];
        }

        print("✅ Matches received: ${matches.length}");
        print("🧪 Sample: ${jsonEncode(matches.first)}");

        return matches.map((item) => Outlet.fromJson(item)).toList();
      } else {
        throw Exception('❌ Failed to load recommendations (${response.statusCode})');
      }
    } catch (e) {
      print("🚨 Error in fetchRecommendations(): $e");
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Outlet>>(
      future: _recommendations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          print("❌ FutureBuilder Error: ${snapshot.error}");
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print("ℹ️ No recommendations available.");
          return const Center(
            child: Text(
              "No recommendations available",
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final outlets = snapshot.data!;
        return ListView.builder(
          itemCount: outlets.length,
          padding: const EdgeInsets.all(12),
          itemBuilder: (context, index) {
            final outlet = outlets[index];
            return GestureDetector(
              onTap: () {
                print("➡️ Navigating to details with outletId: ${outlet.outletId}, name: ${outlet.name}");
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OutletDetailsScreen(outlet: outlet),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1D1C1A), Color(0xFF121212)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.amberAccent.withOpacity(0.8),
                    width: 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: CachedNetworkImage(
                        imageUrl: outlet.image,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(height: 200, color: Colors.grey[900]),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error, color: Colors.redAccent),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  outlet.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    fontFamily: 'Poppins_Regular',
                                  ),
                                ),
                              ),
                              const Icon(Icons.star, color: Colors.amberAccent, size: 18),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.amber.shade700,
                                      Colors.deepOrange.shade400,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      outlet.location,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Poppins_Regular',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.amber,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  "starts from ₹${outlet.price}",
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins_Regular',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
