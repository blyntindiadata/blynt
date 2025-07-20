import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HostEventFormScreen extends StatefulWidget {
  final String category;
  final String uid;
  final String username;
  final String firstName;
  final String lastName;

  const HostEventFormScreen({
    super.key,
    required this.category,
    required this.uid,
    required this.username,
    required this.firstName,
    required this.lastName,
  });

  @override
  State<HostEventFormScreen> createState() => _HostEventFormScreenState();
}


class _HostEventFormScreenState extends State<HostEventFormScreen> with TickerProviderStateMixin {
  final nameController = TextEditingController();
  final locationController = TextEditingController();
  final descriptionController = TextEditingController();

  int audienceLimit = 10;
  String selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final Set<String> selectedSlots = {};
  
  // Category selection variables
  List<String> availableCategories = [];
  String? selectedCategory;
  bool isLoadingCategories = true;

  late AnimationController _formAnimationController;
  late Animation<double> _formAnimation;

  final gradient = const LinearGradient(
    colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  final timeSlots = List.generate(24, (i) {
    final start = i.toString().padLeft(2, '0');
    final end = ((i + 1) % 24).toString().padLeft(2, '0');
    return '$start:00 - $end:00';
  });

  @override
  void initState() {
    super.initState();
    _formAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _formAnimation = CurvedAnimation(
      parent: _formAnimationController,
      curve: Curves.easeOut,
    );

    _formAnimationController.forward();
    _loadCategories();
  }

  @override
  void dispose() {
    _formAnimationController.dispose();
    super.dispose();
  }

Future<void> _loadCategories() async {
  try {
    setState(() {
      isLoadingCategories = true;
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('hostedEvents')
        .doc(widget.category)
        .collection('categories')
        .get();

    final List<String> categories = snapshot.docs
        .map((doc) => doc.data()['name'] as String?)
        .where((name) => name != null && name.trim().isNotEmpty)
        .cast<String>()
        .toList();

    setState(() {
      availableCategories = categories;
      selectedCategory = categories.isNotEmpty ? categories.first : null;
      isLoadingCategories = false;
    });
  } catch (e) {
    setState(() {
      isLoadingCategories = false;
    });

    debugPrint('🔥 Error loading sub-categories: $e');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Failed to load sub-categories: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}




  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.08),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white12, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }

  Widget glassyTitle(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 6),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget buildCategorySelector() {
    if (isLoadingCategories) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (availableCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "No categories available",
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

   return Container(
  margin: const EdgeInsets.symmetric(vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.06),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.1)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  // Remove SizedBox(height: 60) – it restricts dropdown
  child: DropdownButtonFormField<String>(
    isExpanded: true, // ✅ Important to avoid overflow
    value: selectedCategory,
    decoration: InputDecoration(
      labelText: "Select Category",
      labelStyle: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
      prefixIcon: const Icon(Icons.category, color: Colors.amber),
      filled: true,
      fillColor: Colors.transparent,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.amber, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
    style: GoogleFonts.poppins(color: Colors.white),
    dropdownColor: const Color(0xFF1A1A1A),
    icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
    items: availableCategories.map((category) {
      return DropdownMenuItem<String>(
        value: category,
        child: Text(
          category,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }).toList(),
    onChanged: (value) {
      setState(() {
        selectedCategory = value;
      });
    },
  ),
);


    
  }

  Widget buildDateSelector() {
    return Container(
      height: 78,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final label = DateFormat('EEE\ndd').format(date);
          final formatted = DateFormat('yyyy-MM-dd').format(date);
          final isSelected = selectedDate == formatted;

          return GestureDetector(
            onTap: () => setState(() => selectedDate = formatted),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? gradient
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.04)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? Colors.amber.withOpacity(0.6) : Colors.white12,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildTimeChips(String title, List<String> slots) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: slots.map((slot) {
                  final selected = selectedSlots.contains(slot);
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selected ? selectedSlots.remove(slot) : selectedSlots.add(slot);
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? gradient
                              : LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.08),
                                    Colors.white.withOpacity(0.04)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? Colors.amber.withOpacity(0.6) : Colors.white24,
                            width: selected ? 1.3 : 1,
                          ),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  )
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              slot,
                              style: GoogleFonts.poppins(
                                color: selected ? Colors.black : Colors.white70,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.black,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAudienceLimitCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Audience Limit",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  "$audienceLimit people",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.05),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                activeTrackColor: Colors.amber,
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                thumbColor: Colors.amber,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                overlayColor: Colors.amber.withOpacity(0.2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
                activeTickMarkColor: Colors.transparent,
                inactiveTickMarkColor: Colors.transparent,
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: audienceLimit.toDouble(),
                min: 1,
                max: 500,
                divisions: 499,
                onChanged: (value) => setState(() => audienceLimit = value.round()),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "1",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
              Text(
                "500",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
Future<void> saveHostedEvent() async {
  final firestore = FirebaseFirestore.instance;

  try {
    // Step 1: Generate global unique event ID
    final eventDocRef = firestore.collection('events').doc();
    final eventId = eventDocRef.id;

    final eventData = {
      'name': nameController.text.trim(),
      'location': locationController.text.trim(),
      'audienceLimit': audienceLimit,
      'description': descriptionController.text.trim(),
      'date': selectedDate,
      'timeSlots': selectedSlots.toList(),
      'mainCategory': widget.category,
      'selectedCategory': selectedCategory,
      'createdAt': FieldValue.serverTimestamp(),
      'hostUid': widget.uid,
      'hostUsername': widget.username,
      'hostFirstName': widget.firstName,
      'hostLastName': widget.lastName,
      'eventId': eventId, // Include the ID here for consistency
    };

    // Step 2: Save to flat global collection
    await eventDocRef.set(eventData);

    // Step 3: Save to nested hostedEvents collection using same ID
    await firestore
        .collection('hostedEvents')
        .doc(widget.category)
        .collection('events')
        .doc(selectedCategory)
        .collection('events')
        .doc(eventId)
        .set(eventData);

    // Step 4: Save to user's hostedEvents
    await firestore
        .collection('users')
        .doc(widget.uid)
        .collection('hostedEvents')
        .doc(eventId)
        .set(eventData);

    print('✅ Event successfully saved in all paths with ID: $eventId');
  } catch (e) {
    print('❌ Error saving event: $e');
  }
}

  bool get isFormValid {
    return nameController.text.trim().isNotEmpty &&
        locationController.text.trim().isNotEmpty &&
        descriptionController.text.trim().isNotEmpty &&
        selectedSlots.isNotEmpty &&
        selectedCategory != null &&
        selectedCategory!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final morning = timeSlots.sublist(6, 12);
    final afternoon = timeSlots.sublist(12, 18);
    final evening = timeSlots.sublist(18, 24);
    final night = timeSlots.sublist(0, 6);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => gradient.createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'host event',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.amber),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _formAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 30 * (1 - _formAnimation.value)),
              child: Opacity(
                opacity: _formAnimation.value,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Main Category Tag
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(40),
                            gradient: gradient,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, size: 20, color: Colors.black),
                              const SizedBox(width: 8),
                              Text(
                                "Main Category: ${widget.category}",
                                style: GoogleFonts.poppins(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Event Category Selection
                      buildSectionTitle("🏷️ Event Category"),
                      glassyTitle("Choose the specific category for your event."),
                      buildCategorySelector(),

                      buildSectionTitle("📋 Event Details"),
                      glassyTitle("Give your event a short and clear name, and its location."),
                      
                      TextField(
                        controller: nameController,
                        decoration: inputDecoration("Event Name"),
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: locationController,
                        decoration: inputDecoration("Location"),
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),

                      buildSectionTitle("👥 Audience Limit"),
                      glassyTitle("How many people do you want to allow for this event?"),
                      buildAudienceLimitCard(),

                      buildSectionTitle("📝 Description"),
                      glassyTitle("Briefly describe your event (max 100 characters)."),
                      TextField(
                        controller: descriptionController,
                        maxLength: 100,
                        maxLines: 3,
                        decoration: inputDecoration("Description"),
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),

                      buildSectionTitle("📅 Select Date"),
                      glassyTitle("Choose a day that best suits your audience."),
                      buildDateSelector(),

                      buildSectionTitle("⏰ Pick Time Slots"),
                      glassyTitle("Select preferred times when users can attend."),
                      buildTimeChips("🌅 Morning (6AM – 12PM)", morning),
                      buildTimeChips("🌞 Afternoon (12PM – 6PM)", afternoon),
                      buildTimeChips("🌇 Evening (6PM – 12AM)", evening),
                      buildTimeChips("🌙 Night (12AM – 6AM)", night),

                      const SizedBox(height: 30),
                      
                      // Submit Button
                      GestureDetector(
                        onTap: isFormValid
                            ? () async {
                                // await saveEventToFirestore();
                                await saveHostedEvent();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("🎉 Event hosted successfully!"),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                setState(() {
                                  nameController.clear();
                                  locationController.clear();
                                  descriptionController.clear();
                                  selectedSlots.clear();
                                  selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
                                  audienceLimit = 10;
                                  selectedCategory = null;
                                });
                              }
                            : null,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: isFormValid ? gradient : null,
                            color: isFormValid ? null : Colors.white12,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: isFormValid
                                ? [
                                    BoxShadow(
                                      color: Colors.amber.withOpacity(0.6),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              "🚀 HOST EVENT",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: isFormValid ? Colors.black : Colors.white38,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}