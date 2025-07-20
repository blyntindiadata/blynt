import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:startup/groups.dart/summary_counter.dart';

class ItineraryScreen extends StatefulWidget {
  final String username;
  final String groupId;
  final Map<String, dynamic> coordinates;
  final int numPeople;
  final List<String> groupMembers; // ✅ Members passed from GroupDetailScreen

  const ItineraryScreen({
    super.key,
    required this.username,
    required this.groupId,
    required this.coordinates,
    required this.numPeople,
    required this.groupMembers,
  });

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> with TickerProviderStateMixin {
  final TextEditingController _placesController = TextEditingController();
  Map<int, List<String>> outletMembers = {}; // outletIndex -> members      
  bool _isLoading = false;
  bool _showBreakdown = false;
  List<Map<String, dynamic>> itinerary = [];
  List<bool> replaceFlags = [];
  // int totalCost = 0;
  double totalCost = 0.0;
  int walletAmount=0;
  int perPerson = 0;
  String error = "";
  DateTime selectedDate = DateTime.now();
  Map<String, Map<String, bool>> outletSlotMap = {}; // outletId → slot map
  Map<String, String?> selectedSlotPerOutlet = {};
  // String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
Map<int, List<String>> selectedTimeSlots = {};

Map<int, Map<String, bool>> outletSlotAvailability = {}; // index → slot → bool
Set<int> initializedAvailabilityIndexes = {};

 // outletId → selected slot


  List<String> selectedMembers = [];
  bool selectAll = false;

  late AnimationController shimmerController;

  @override
  void initState() {
    super.initState();
    shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    selectedMembers = List.from(widget.groupMembers);
    selectAll = true;
     print("[ItineraryScreen] Received username: ${widget.username}");
  print("[ItineraryScreen] Group members: ${widget.groupMembers}");
  preloadAllOutletAvailability();
    getWalletAmount();
  }
  void preloadAllOutletAvailability() {
  for (int i = 0; i < itinerary.length; i++) {
    fetchAvailability(i, itinerary[i]);
  }
}

Future<void> fetchAvailability(int index, Map<String, dynamic> place) async {
  final outletId = place["Outlet ID"];
  final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
  final docRef = FirebaseFirestore.instance
      .collection("outlets")
      .doc(outletId)
      .collection("availability")
      .doc(formattedDate);

  try {
    final doc = await docRef.get();

    if (!doc.exists) {
      final defaultSlots = {
        for (var slot in generateTimeSlots()) slot: true,
      };
      await docRef.set(defaultSlots);
      print("✅ Created default slots for $outletId");
      outletSlotAvailability[index] = defaultSlots;
    } else {
      final data = doc.data()!.map((k, v) => MapEntry(k, v as bool));
      print("📥 Loaded ${data.length} slots for $outletId");
      outletSlotAvailability[index] = data;
    }

    if (mounted) setState(() {});
  } catch (e) {
    print("🔥 Error fetching availability: $e");
  }
}
  void toggleSelectAll() {
  setState(() {
    if (selectAll) {
      selectedMembers.clear();
    } else {
      selectedMembers = List.from(widget.groupMembers);
    }
    selectAll = !selectAll;
  });
}

void updateTotalCost() {
  double newTotal = 0;
  for (int i = 0; i < itinerary.length; i++) {
    final members = outletMembers[i] ?? selectedMembers;
    final cost = double.tryParse(itinerary[i]["Cost Per Person"].toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    newTotal += members.length * cost;
  }
  setState(() {
    totalCost = newTotal;
  });
}

Future<void> loadOutletAvailability(String outletId) async {
  final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
  final docRef = FirebaseFirestore.instance
      .collection('outlets')
      .doc(outletId)
      .collection('availability')
      .doc(dateStr);

  final doc = await docRef.get();

  if (!doc.exists) {
    final defaultSlots = {
      for (var slot in generateTimeSlots()) slot: true,
    };
    await docRef.set(defaultSlots);
    outletSlotMap[outletId] = defaultSlots;
  } else {
    outletSlotMap[outletId] =
        doc.data()!.map((k, v) => MapEntry(k, v as bool));
  }

  setState(() {}); // update UI
}

List<String> generateTimeSlots() {
  return List.generate(24, (i) {
    final start = i.toString().padLeft(2, '0');
    final end = ((i + 1) % 24).toString().padLeft(2, '0');
    return '$start:00 - $end:00';
  });
}

Future<void> getWalletAmount() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .get();

    if (doc.exists) {
      final data = doc.data();
      if (data != null && data.containsKey('wallet')) {
        setState(() {
          walletAmount = data['wallet'] ?? 0;
        });
        print("[getWalletAmount] Found wallet: ₹$walletAmount in group ${widget.groupId}");
      } else {
        print("[getWalletAmount] Wallet field not found in group ${widget.groupId}");
      }
    } else {
      print("[getWalletAmount] Group ${widget.groupId} does not exist.");
    }
  } catch (e) {
    print('Error fetching wallet amount for group ${widget.groupId}: $e');
  }
}

Future<void> saveEventToFirestore() async {
  try {
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupId);
    final eventsRef = groupRef.collection('events');

    Map<String, double> costDistribution = {};
    List<Map<String, dynamic>> placeData = [];

    for (int i = 0; i < itinerary.length; i++) {
      final place = itinerary[i];
      final members = outletMembers[i] ?? selectedMembers;
      final costPerPerson = double.tryParse(
        place['Cost Per Person'].toString().replaceAll(RegExp(r'[^\d.]'), ''),
      ) ?? 0.0;
      final total = members.length * costPerPerson;

      for (String member in members) {
        costDistribution[member] = (costDistribution[member] ?? 0.0) + costPerPerson;
      }

      placeData.add({
        "place": place["Place"],
        "location": place["Location"],
        "costPerPerson": costPerPerson,
        "members": members,
        "total": total,
      });
    }

    double finalTotal = costDistribution.values.fold(0.0, (a, b) => a + b);

    await eventsRef.add({
      "timestamp": FieldValue.serverTimestamp(),
      "members": selectedMembers,
      "totalCost": finalTotal.round(),
      "perPerson": perPerson,
      "places": placeData,
      "costDistribution": costDistribution.map((k, v) => MapEntry(k, v.round())),
    });

    print("✅ Event saved to Firestore!");
  } catch (e) {
    print("❌ Failed to save event: $e");
  }
}



  @override
  void dispose() {
    shimmerController.dispose();
    _placesController.dispose();
    super.dispose();
  }

  // void toggleSelectAll() {
  //   setState(() {
  //     selectAll = !selectAll;
  //     selectedMembers = selectAll ? List.from(widget.groupMembers) : [];
  //   });
  // }
Widget _buildGlowingButton({
  required String label,
  required IconData icon,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 1.0, end: isSelected ? 1.05 : 1.0),
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    builder: (context, scale, child) {
      return GestureDetector(
        onTap: onTap,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFB87333)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isSelected
                    ? Colors.amber.withOpacity(0.85)
                    : Colors.white.withOpacity(0.06),
                width: isSelected ? 1.4 : 1.1,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10)]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.black : const Color(0xFF5AC8FA),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

 Widget buildFancyPlaceField() {
  final bool isFocused = FocusScope.of(context).hasFocus;

  return TextField(
    controller: _placesController,
    style: GoogleFonts.poppins(color: Colors.white),
    keyboardType: TextInputType.number,
    cursorColor: const Color(0xFFFFD700), // amber
    decoration: InputDecoration(
      filled: true,
      fillColor: Colors.grey[900],
      labelText: "how many places?",
      labelStyle: GoogleFonts.poppins(color: Colors.grey),
      prefixIcon: const Icon(Icons.place_outlined, color: Colors.grey),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.grey),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
    ),
  );
}


Future<void> fetchItinerary({bool replace = false}) async {
  if (_placesController.text.isEmpty) return;
  final numPlaces = int.tryParse(_placesController.text);
  if (numPlaces == null || numPlaces <= 0) return;

  setState(() {
    _isLoading = true;
    error = "";
  });

  final url = Uri.parse("https://blyntfinal-201410726574.asia-south1.run.app/generate_itinerary");

  final body = {
    "username": widget.username,
    "num_places": numPlaces,
    "num_people": selectedMembers.length,
    "coordinates": {
      "latitude": widget.coordinates['latitude'],
      "longitude": widget.coordinates['longitude'],
    },
  };

  if (replace) {
    final indices = List.generate(replaceFlags.length, (i) => i + 1)
        .where((i) => replaceFlags[i - 1])
        .toList();
    body["current_places"] = itinerary.map((e) => e["Place"]).toList();
    body["replace_indices"] = indices;
  }

  try {
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      setState(() {
        itinerary = List<Map<String, dynamic>>.from(data["itinerary"]);
        replaceFlags = List.generate(itinerary.length, (_) => false);

        totalCost = 0;
        for (int i = 0; i < itinerary.length; i++) {
          final costPerPerson = double.tryParse(
                itinerary[i]['Cost Per Person'].toString().replaceAll(RegExp(r'[^\d.]'), ''),
              ) ??
              0.0;
          final members = outletMembers[i] ?? selectedMembers;
          

          totalCost += members.length * costPerPerson;
        }

        perPerson = (totalCost / (selectedMembers.length > 0 ? selectedMembers.length : 1)).round();
      });
    } else {
      setState(() {
        error = data["error"] ?? "Something went wrong.";
      });
    }
  } catch (e) {
    setState(() {
      error = "Error fetching itinerary.";
    });
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

Widget _buildSlotSection({
  required String title,
  required List<String> slotRange,
  required Map<String, bool> castedAvailability,
  required int index,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: slotRange.map((slot) {
            final isAvailable = castedAvailability[slot] ?? false;
            final isSelected = selectedTimeSlots[index]!.contains(slot);

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: GestureDetector(
                onTap: () {
                  if (!isAvailable) return;
                  setState(() {
                    isSelected
                        ? selectedTimeSlots[index]!.remove(slot)
                        : selectedTimeSlots[index]!.add(slot);
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: !isAvailable
                        ? const LinearGradient(
                            colors: [Colors.redAccent, Colors.deepOrange],
                          )
                        : isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFB87333)],
                              )
                            : null,
                    color: isSelected || !isAvailable
                        ? null
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.amber.withOpacity(0.85)
                          : Colors.white.withOpacity(0.06),
                      width: isSelected ? 1.4 : 1.1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 10)
                          ]
                        : [],
                  ),
                  child: Text(
                    slot,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.black
                          : isAvailable
                              ? Colors.white
                              : Colors.white54,
                      decoration: isAvailable
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ],
  );
}

Widget buildBreakdownCard(double totalPrice, int numPeople) {
  double platformFee = 10;
  double gst = platformFee * 0.18;
  double finalPrice = totalPrice + platformFee + gst;
  double discounted = finalPrice * 0.9;
  double roundedFinal = discounted.roundToDouble();
  double perPersonAmount = roundedFinal / (numPeople > 0 ? numPeople : 1);
  bool walletSufficient = walletAmount >= roundedFinal;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFFFFC107), Color(0xFFFF8008)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          "💰 Price Summary",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2A2A2A), Color(0xFF111111)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: Colors.amber.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Total + Toggle
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.amberAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("Final Price (after GST & Fee)",
                      style: GoogleFonts.poppins(color: Colors.white60)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showBreakdown = !_showBreakdown),
                  child: Row(
                    children: [
                      Text("₹${finalPrice.toStringAsFixed(2)}",
                          style: GoogleFonts.poppins(color: Colors.amberAccent, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Icon(_showBreakdown ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white54, size: 20),
                    ],
                  ),
                )
              ],
            ),

            /// Breakdown Slide Down
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    buildBreakdownLine("Base Cost", totalPrice, icon: Icons.layers, color: Colors.white70),
                    buildBreakdownLine("Platform Fee", platformFee,
                        icon: Icons.miscellaneous_services, color: Colors.orange),
                    buildBreakdownLine("GST (18%)", gst,
                        icon: Icons.percent_rounded, color: Colors.cyanAccent),
                    const Divider(color: Colors.white12),
                  ],
                ),
              ),
              crossFadeState: _showBreakdown ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            ),

            const SizedBox(height: 10),

            /// Discount
            Row(
              children: [
                const Icon(Icons.discount_rounded, color: Colors.greenAccent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "10% discount (availed via Event Planner)",
                    style: GoogleFonts.poppins(color: Colors.greenAccent),
                  ),
                ),
                Text(
                  "- ₹${(finalPrice - discounted).toStringAsFixed(2)}",
                  style: GoogleFonts.poppins(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 8),

            /// Final Price After Discount
            buildBreakdownLine("Final Price After Discount", discounted,
                icon: Icons.monetization_on_outlined, color: Colors.amberAccent),

            /// Round Off
            buildBreakdownLine("Cash Round Off", roundedFinal,
                icon: Icons.calculate_rounded, color: Colors.orangeAccent),

            const SizedBox(height: 10),

            /// Per Person
            Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.group, size: 18, color: Colors.white54),
          const SizedBox(width: 6),
          Text("Per Head Split",
              style: GoogleFonts.poppins(
                  color: Colors.white54, fontSize: 13)),
        ],
      ),
    ),
    const SizedBox(height: 6),
    ...selectedMembers.map((member) {
      final cost = (totalCost / selectedMembers.length);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(Icons.person_2_rounded, size: 16, color: Colors.white30),
            const SizedBox(width: 6),
            Expanded(
                child: Text(member,
                    style: GoogleFonts.poppins(
                        color: Colors.white60, fontSize: 13))),
            Text(
              "₹${cost.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 13),
            ),
          ],
        ),
      );
    }).toList(),
  ],
),


            const SizedBox(height: 16),

            /// Wallet
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: walletSufficient
                      ? [Colors.green.withOpacity(0.3), Colors.greenAccent.withOpacity(0.15)]
                      : [Colors.red.withOpacity(0.3), Colors.redAccent.withOpacity(0.15)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    walletSufficient ? Icons.check_circle : Icons.warning_amber_rounded,
                    color: walletSufficient ? Colors.greenAccent : Colors.redAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      walletSufficient
                          ? "Blynt Wallet Balance ₹$walletAmount — you're good to go! 🎉"
                          : "Wallet has ₹$walletAmount. Add funds or use another method.",
                      style: GoogleFonts.poppins(
                          color: walletSufficient ? Colors.greenAccent : Colors.redAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );
}





Widget buildBreakdownLine(String label, double amount, {IconData? icon, Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        if (icon != null) Icon(icon, size: 18, color: color ?? Colors.white38),
        if (icon != null) const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: GoogleFonts.poppins(color: Colors.white60)),
        ),
        Text("₹${amount.toStringAsFixed(2)}",
            style: GoogleFonts.poppins(
              color: color ?? Colors.white70,
              fontWeight: FontWeight.w500,
            )),
      ],
    ),
  );
}


Widget buildTimelineCard(int index, Map<String, dynamic> place) {
  outletMembers[index] ??= List.from(selectedMembers);
  selectedTimeSlots[index] ??= [];

  final members = outletMembers[index]!;
  final costPerPerson = double.tryParse(
        place["Cost Per Person"].toString().replaceAll(RegExp(r'[^\d.]'), ''),
      ) ??
      0.0;
  final calculatedTotal = members.length * costPerPerson;

  final outletId = place["Outlet ID"];
  final formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate);
  final docRef = FirebaseFirestore.instance
      .collection("outlets")
      .doc(outletId)
      .collection("availability")
      .doc(formattedDate);

  return StreamBuilder<DocumentSnapshot>(
    stream: docRef.snapshots(),
    builder: (context, snapshot) {
      Map<String, bool> availability = {};

      if (snapshot.hasData && snapshot.data!.exists) {
        availability = (snapshot.data!.data() as Map<String, dynamic>)
            .map((key, value) => MapEntry(key, value as bool));
      } else {
        final newSlots = {
          for (var slot in generateTimeSlots()) slot: true,
        };
        docRef.set(newSlots);
        availability = newSlots;
      }

      final sortedSlots = availability.keys.toList()
        ..sort((a, b) => _timeStringToDateTime(a).compareTo(_timeStringToDateTime(b)));

      outletSlotAvailability[index] = availability;

      List<String> daySlots = [], eveningSlots = [], nightSlots = [];
      for (var slot in sortedSlots) {
        final hour = int.tryParse(slot.split(":")[0]) ?? 0;
        if (hour >= 3 && hour < 16) {
          daySlots.add(slot);
        } else if (hour >= 16 && hour < 20) {
          eveningSlots.add(slot);
        } else {
          nightSlots.add(slot);
        }
      }

      Widget slotScroller(String label, List<String> slotList) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                  color: Colors.amberAccent,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                )),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: slotList.map((slot) {
                  final isAvailable = availability[slot] ?? false;
                  final isSelected = selectedTimeSlots[index]!.contains(slot);

                  return GestureDetector(
                    onTap: () {
                      if (!isAvailable) return;
                      setState(() {
                        if (isSelected) {
                          selectedTimeSlots[index]!.remove(slot);
                        } else {
                          selectedTimeSlots[index]!.add(slot);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isAvailable
                            ? isSelected
                                ? const LinearGradient(
                                    colors: [Color(0xFFFFD700), Color(0xFFB87333)])
                                : null
                            : const LinearGradient(
                                colors: [Colors.red, Colors.redAccent]),
                        color: isSelected
                            ? null
                            : Colors.grey.shade800.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: isSelected
                                ? Colors.amber
                                : Colors.white.withOpacity(0.08),
                            width: isSelected ? 1.3 : 1),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Text(
                        slot,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: isAvailable
                              ? (isSelected ? Colors.black : Colors.white)
                              : Colors.white54,
                          decoration: isAvailable
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],
        );
      }

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step Circle
            Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8008)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.amber, blurRadius: 6),
                    ],
                  ),
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (index < itinerary.length - 1)
                  Container(
                    width: 2,
                    height: 50,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orangeAccent, Colors.deepOrange],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Main Card
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A1A1A), Color(0xFF0F0F0F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(color: Colors.amber.withOpacity(0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      children: [
                        Checkbox(
                          value: replaceFlags[index],
                          onChanged: (val) {
                            setState(() => replaceFlags[index] = val ?? false);
                          },
                          activeColor: const Color(0xFFFFD700),
                          checkColor: Colors.black,
                        ),
                        Expanded(
                          child: Text(
                            place["Place"] ?? "Unknown",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 18, color: Colors.white24),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text("📍 ${place["Location"] ?? ""}",
                        style: GoogleFonts.poppins(color: Colors.white70)),
                    const SizedBox(height: 12),

                    if (selectedTimeSlots[index]!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.amber.withOpacity(0.2)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedTimeSlots[index]!.map((slot) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFB87333)
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                slot,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                    // Time Slot Sections
                    slotScroller("🌞 Day (3 AM – 4 PM)", daySlots),
                    slotScroller("🌆 Evening (4 PM – 8 PM)", eveningSlots),
                    slotScroller("🌙 Night (8 PM – 3 AM)", nightSlots),

                    const SizedBox(height: 12),

                    // Member Selector
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: widget.groupMembers.map((member) {
                        final isSelected = members.contains(member);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              isSelected
                                  ? members.remove(member)
                                  : members.add(member);
                              outletMembers[index] = members;
                            });
                            updateTotalCost();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(colors: [
                                      Color(0xFFFFD700),
                                      Color(0xFFB87333)
                                    ])
                                  : null,
                              color:
                                  isSelected ? null : const Color(0xFF1C1C1C),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: isSelected
                                      ? Colors.amber.withOpacity(0.85)
                                      : Colors.white.withOpacity(0.06),
                                  width: isSelected ? 1.4 : 1.1),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                          color: Colors.amber.withOpacity(0.3),
                                          blurRadius: 10)
                                    ]
                                  : [],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_outline,
                                    size: 16,
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white),
                                const SizedBox(width: 6),
                                Text(member,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: isSelected
                                          ? Colors.black
                                          : Colors.white,
                                    )),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 22, color: Colors.redAccent),
                        onPressed: () {
                          setState(() {
                            itinerary.removeAt(index);
                            outletMembers.remove(index);
                            replaceFlags.removeAt(index);
                            selectedTimeSlots.remove(index);
                            outletSlotAvailability.remove(index);
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Cost: ₹${costPerPerson.toStringAsFixed(2)} × ${members.length} = ₹${calculatedTotal.toStringAsFixed(2)}",
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}




// Helper to convert time string to DateTime
DateTime _timeStringToDateTime(String timeStr) {
  final parts = timeStr.split('-').first.split(':');
  return DateTime(0, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
}




  @override
  Widget build(BuildContext context) {
    totalCost = itinerary.fold<double>(0.0, (sum, item) {
  final total = item['Total Cost'];
  return sum +
      (total is num
          ? total.toDouble()
          : double.tryParse(total.toString().replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0);
});

final int numPeople = widget.groupMembers.length > 0 ? widget.groupMembers.length : 1;

// final int numPeople = widget.groupMembers.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFD700)),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'your itinerary',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 22),
          ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildFancyPlaceField(),
                  Row(
  children: [
    const Icon(Icons.calendar_today, size: 18, color: Colors.amber),
    const SizedBox(width: 8),
    Text("Selected Date:",
        style: GoogleFonts.poppins(color: Colors.white70)),
    const SizedBox(width: 12),
    GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 30)),
          builder: (context, child) {
            return Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Color(0xFFFFD700),
                  onPrimary: Colors.black,
                  surface: Colors.black,
                  onSurface: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) setState(() => selectedDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.6)),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(selectedDate),
          style: GoogleFonts.poppins(color: Colors.white),
        ),
      ),
    ),
  ],
),
const SizedBox(height: 16),

                  GestureDetector(
                        onTap: _isLoading ? null : () => fetchItinerary(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Center(
  child: Align(
    alignment: Alignment(0, 5), // x=0 (center), y=0.3 (slightly down)
    child: Text(
      _placesController.text.isEmpty ? "GENERATE" : "CONFIRM",
      style: GoogleFonts.poppins(
        color: Colors.black,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    ),
  ),
),

                        ),
                      ),
                  const SizedBox(height: 16),
                  // if (widget.groupMembers.isNotEmpty) buildMemberSelector(),
                  if (error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(error, style: GoogleFonts.poppins(color: Colors.redAccent)),
                    ),
                  if (_isLoading)
                    const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: CircularProgressIndicator(color: Color(0xFFFFD700))))
                  else if (itinerary.isNotEmpty) ...[
  ...List.generate(itinerary.length, (index) => buildTimelineCard(index, itinerary[index])),
  Align(
  alignment: Alignment.centerRight,
  child: GestureDetector(
    onTap: _isLoading ? null : () => fetchItinerary(replace: true),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 206, 53, 53), Color.fromARGB(255, 158, 37, 0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.refresh, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            "Replace Selected",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    ),
  ),
),


  const SizedBox(height: 12),
  buildBreakdownCard(totalCost, numPeople),

  const SizedBox(height: 10),

Align(
  alignment: Alignment.center,
  child: GestureDetector(
    onTap: () {
      // TODO: navigate to billing or show success
      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SummaryCounter(
      itinerary: itinerary,
      selectedTimeSlots: selectedTimeSlots,
      outletMembers: outletMembers,
    ),
  ),
);

    },
    child: Container(
      margin: const EdgeInsets.only(top: 30, bottom: 60),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFF8008)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(
        child: Text(
          "🧾 PROCEED TO BILLING COUNTER",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            fontSize: 14.5,
          ),
        ),
      ),
    ),
  ),
),


],

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Bottom Confirm + Replace Buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
