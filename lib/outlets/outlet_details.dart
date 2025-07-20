import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:startup/groups.dart/final_outlet_counter.dart';
import 'package:startup/models.dart/outlet_model.dart';

class OutletDetailsScreen extends StatefulWidget {
  final Outlet outlet;
  const OutletDetailsScreen({required this.outlet, super.key});

  @override
  State<OutletDetailsScreen> createState() => _OutletDetailsScreenState();
}

class _OutletDetailsScreenState extends State<OutletDetailsScreen> {
  Map<String, dynamic> availability = {};
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  bool showOnlyAvailable = true;
  final Set<String> selectedSlots = {};

  @override
  void initState() {
    super.initState();
    setupRealtimeListener();
  }

  void setupRealtimeListener() {
    final docRef = FirebaseFirestore.instance
        .collection('outlets')
        .doc(widget.outlet.outletId)
        .collection('availability')
        .doc(selectedDate);

    docRef.snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        setState(() {
          availability = data.map((k, v) => MapEntry(k, v as bool));
          // Remove selected slots that are no longer available
          selectedSlots.removeWhere((slot) => !(availability[slot] ?? true));
        });
      } else {
        loadAvailability();
      }
    });
  }

  Future<void> loadAvailability() async {
    final docRef = FirebaseFirestore.instance
        .collection('outlets')
        .doc(widget.outlet.outletId)
        .collection('availability')
        .doc(selectedDate);

    try {
      final doc = await docRef.get();
      if (!doc.exists) {
        final defaultSlots = {
          for (var slot in generateTimeSlots()) slot: true,
        };
        await docRef.set(defaultSlots);
        availability = defaultSlots;
      } else {
        availability = doc.data()!.map((k, v) => MapEntry(k, v as bool));
      }
      selectedSlots.clear();
      setState(() {});
    } catch (e) {
      debugPrint("🔥 Error loading availability: $e");
    }
  }

  List<String> generateTimeSlots() {
    return List.generate(24, (i) {
      final start = i.toString().padLeft(2, '0');
      final end = ((i + 1) % 24).toString().padLeft(2, '0');
      return '$start:00 - $end:00';
    });
  }

  void toggleSlotSelection(String slot) {
    if (!(availability[slot] ?? true)) return;
    setState(() {
      selectedSlots.contains(slot)
          ? selectedSlots.remove(slot)
          : selectedSlots.add(slot);
    });
  }

  Widget buildSelectedSlotsSummary() {
    if (selectedSlots.isEmpty) return const SizedBox();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.schedule, color: Colors.black, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${selectedSlots.length} Time Slot${selectedSlots.length > 1 ? 's' : ''} Selected",
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFFFD700),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  selectedSlots.join(', '),
                  style: GoogleFonts.poppins(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGradientChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget buildAmenitiesChips() {
    final amenities = ['🏏 Bat', '🏐 Ball', '👟 Shoes', '📊 Scoreboard'];
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: amenities.map((amenity) => buildGradientChip(amenity)).toList(),
    );
  }

  Widget buildTimeCategory(String label, List<String> slots) {
    final filtered = slots
        .where((s) => !showOnlyAvailable || (availability[s] ?? true))
        .toList();
    if (filtered.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade800),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: const Color(0xFFFFD700),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: filtered.map((slot) {
              final isAvailable = availability[slot] ?? true;
              final isSelected = selectedSlots.contains(slot);
              return GestureDetector(
                onTap: () => toggleSlotSelection(slot),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)])
                        : isAvailable
                            ? LinearGradient(
                                colors: [Colors.grey.shade700, Colors.grey.shade800])
                            : const LinearGradient(colors: [Color(0xFFDC143C), Color(0xFF8B0000)]),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : [],
                  ),
                  child: Stack(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            slot,
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.check_circle, size: 14, color: Colors.black),
                          ],
                          if (!isAvailable && !isSelected) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.lock, size: 14, color: Colors.white70),
                          ],
                        ],
                      ),
                      if (!isAvailable && !isSelected)
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget buildDateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(DateTime.parse(selectedDate)),
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey.shade400,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 75,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 14,
            itemBuilder: (context, index) {
              final date = DateTime.now().add(Duration(days: index));
              final dayName = DateFormat('EEE').format(date);
              final dayNumber = DateFormat('dd').format(date);
              final formatted = DateFormat('yyyy-MM-dd').format(date);
              final isSelected = selectedDate == formatted;
              final isToday = index == 0;

              return GestureDetector(
                onTap: () {
                  selectedDate = formatted;
                  setupRealtimeListener(); // Setup new listener for the selected date
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)])
                        : LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade900]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFFFD700) : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayName,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isSelected ? Colors.black : Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dayNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : Colors.white,
                        ),
                      ),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          height: 3,
                          width: 20,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.black : const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildToggleSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Show Available Only",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Hide booked time slots",
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          Switch(
            value: showOnlyAvailable,
            onChanged: (val) => setState(() => showOnlyAvailable = val),
            activeColor: const Color(0xFFFFD700),
            activeTrackColor: const Color(0xFFB8860B),
            inactiveThumbColor: Colors.grey.shade600,
            inactiveTrackColor: Colors.grey.shade800,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slots = generateTimeSlots();
    final morning = slots.sublist(6, 12);
    final afternoon = slots.sublist(12, 18);
    final evening = slots.sublist(18, 24);
    final night = slots.sublist(0, 6);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.outlet.name,
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFD700),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.black, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    "4.5",
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: GestureDetector(
          onTap: () {
  if (selectedSlots.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please select at least one time slot"), backgroundColor: Colors.red),
    );
    return;
  }

  final bookingDetails = {
    'placeName': widget.outlet.name,
    'timeSlot': selectedSlots.join(', '),
    'price': widget.outlet.price,
  };

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => BookingDetailSummaryScreen(bookingDetails: bookingDetails),
    ),
  );
},

          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    "₹${widget.outlet.price}/hr",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Text(
                    "BOOK NOW",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CachedNetworkImage(
                imageUrl: widget.outlet.image,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFB8860B)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.location_on, size: 14, color: Colors.black),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.outlet.location,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              "Available Amenities",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFFFD700),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            buildAmenitiesChips(),
            const SizedBox(height: 24),
            Text(
              "Select Date",
              style: GoogleFonts.poppins(
                color: const Color(0xFFFFD700),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            buildDateSelector(),
            const SizedBox(height: 20),
            buildToggleSwitch(),
            buildSelectedSlotsSummary(),
            const SizedBox(height: 12),
            buildTimeCategory('🌅 Morning (6 AM - 12 PM)', morning),
            buildTimeCategory('🌞 Afternoon (12 PM - 6 PM)', afternoon),
            buildTimeCategory('🌆 Evening (6 PM - 12 AM)', evening),
            buildTimeCategory('🌙 Night (12 AM - 6 AM)', night),
          ],
        ),
      ),
    );
  }
}