import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventDetailSummaryScreen extends StatefulWidget {
  final Map<String, dynamic> event;
 
  const EventDetailSummaryScreen({super.key, required this.event});

  @override
  State<EventDetailSummaryScreen> createState() => _EventDetailSummaryScreenState();
}

class _EventDetailSummaryScreenState extends State<EventDetailSummaryScreen> with SingleTickerProviderStateMixin {
  bool isDarkMode = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _controller.forward();
  }

  void switchView() {
    setState(() => isDarkMode = !isDarkMode);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
      final String eventId = widget.event['id'] ?? 'unknown';
final String eventType = widget.event['selectedCategory'] ?? 'unknown';
final String category = widget.event['mainCategory'] ?? 'Other';
final String fullPath = 'hostedEvents/$category/events/$eventType/events/$eventId';
    final event = widget.event;
    final backgroundGradient = isDarkMode
        ? const LinearGradient(colors: [Color(0xFF1E1E1E), Color(0xFF2A1F1F)])
        : const LinearGradient(colors: [Color(0xFFFDF3D0), Color(0xFFF9E8B5)]);

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final headingColor = isDarkMode ? Colors.amber.shade200 : Colors.brown.shade900;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.brown.shade600;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: Text(
            'event summary',
            style: GoogleFonts.poppins(fontSize: 22, letterSpacing: 1.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              "you're about to join this event 🎉",
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: switchView,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFC107), Color(0xFFFFA000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(color: Colors.amberAccent.withOpacity(0.7), blurRadius: 12, offset: const Offset(0, 1)),
                    BoxShadow(color: Colors.orangeAccent.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 0)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                      size: 16,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDarkMode ? "VIEW IN CLASSICAL MODE" : "BACK TO NIGHT VIEW",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: 1 - (_controller.value * 0.3),
                  child: Transform.scale(
                    scale: 1 - (_controller.value * 0.02),
                    child: Container(
  constraints: const BoxConstraints(maxWidth: 500),
  padding: const EdgeInsets.all(8),
  child: Stack(
    clipBehavior: Clip.none,
    children: [
      // Background Watermark: "blynt"
      Positioned.fill(
                                            child: IgnorePointer(
                                              child: Center(
                                                child: Opacity(
                                                  opacity: 0.04,
                                                  child: Text(
                                                    'blynt',
                                                    style: GoogleFonts.dmSerifDisplay(
                                                      fontSize: 90,
                                                      color: headingColor,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 2,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

      // Ticket Card
      Card(
        elevation: 14,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ClipPath(
          clipper: DiagonalTicketClipper(),
          child: Container(
            decoration: BoxDecoration(gradient: backgroundGradient),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    '🎫 one step away',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 24,
                      color: headingColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: headingColor.withOpacity(0.8)),
                const SizedBox(height: 8),
                Text("📌 ${event['name'] ?? 'Untitled Event'}",
                    style: GoogleFonts.dmSerifDisplay(fontSize: 20, color: headingColor)),
                const SizedBox(height: 6),
                Text("📍 ${event['location'] ?? 'Unknown'}",
                    style: GoogleFonts.poppins(fontSize: 13, color: subTextColor)),
                const SizedBox(height: 6),
                Text("🧑 Host: ${event['hostFirstName'] ?? ''} ${event['hostLastName'] ?? ''}",
                    style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                const SizedBox(height: 6),
                Text("📅 Date: ${event['date'] ?? 'N/A'}",
                    style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                const SizedBox(height: 6),
                Text("⏰ Time: ${event['time'] ?? 'N/A'}",
                    style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                const SizedBox(height: 6),
                Text("📂 Category: ${event['mainCategory'] ?? 'Other'}",
                    style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
              ],
            ),
          ),
        ),
      ),

      // Punch Holes
      const Positioned(left: -6, top: 40, child: _PunchHole()),
      const Positioned(left: -6, bottom: 40, child: _PunchHole()),
      const Positioned(right: -6, top: 40, child: _PunchHole()),
      const Positioned(right: -6, bottom: 40, child: _PunchHole()),
      const Positioned(top: -6, left: 80, child: _PunchHole()),
      const Positioned(top: -6, right: 80, child: _PunchHole()),
      const Positioned(bottom: -6, left: 80, child: _PunchHole()),
      const Positioned(bottom: -6, right: 80, child: _PunchHole()),
    ],
  ),
),

                  ),
                );
              },
            ),
            const SizedBox(height: 30),
            GestureDetector(
           onTap: () async {
  final user = FirebaseAuth.instance.currentUser;
  final event = widget.event;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Please log in first"), backgroundColor: Colors.red),
    );
    return;
  }

  final userId = user.uid;
  final eventId = event['id'];
  final eventCategory = event['mainCategory']; // e.g., "individual"
  final eventType = event['selectedCategory'];           // e.g., "stand-up-comedy"

  print('🟡 UID: $userId');
  print('🟡 eventId: $eventId');
  print('🟡 eventCategory: $eventCategory');
  print('🟡 eventType: $eventType');

  final eventPath = FirebaseFirestore.instance
      .collection('hostedEvents')
      .doc(eventCategory)
      .collection('events')
      .doc(eventType)
      .collection('events')
      .doc(eventId);

  print('🟡 Full Firestore Path: hostedEvents/$eventCategory/events/$eventType/events/$eventId');

  try {
    // Optional: Check if the event document exists
    final docSnapshot = await eventPath.get();
    if (!docSnapshot.exists) {
      print('🔴 Event document does NOT exist!');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event not found. Please try again later."), backgroundColor: Colors.red),
      );
      return;
    } else {
      print('🟢 Event document found.');
    }

    // 1. Add user to joinedEvents in the event document
    await eventPath.collection('joinedEvents').doc(userId).set({
      'uid': userId,
      'joinedAt': Timestamp.now(),
    });
    print('✅ Added to event\'s joinedEvents.');

    // 2. Add event to user's joinedEvents
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('joinedEvents')
        .doc(eventId)
        .set({
      'eventId': eventId,
      'name': event['name'],
      'location': event['location'],
      'date': event['date'],
      'time': event['time'],
      'mainCategory': eventCategory,
      'type': eventType,
      'joinedAt': Timestamp.now(),
    });
    print('✅ Added to user\'s joinedEvents.');

    // 3. Increment joinedCount field in event document
    await eventPath.update({
      'joinedCount': FieldValue.increment(1),
    });
    print('✅ joinedCount incremented.');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Event joined successfully!"), backgroundColor: Colors.green),
    );
  } catch (e) {
    print('❌ Firestore write error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
    );
  }
},


              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFC107), Color(0xFFFFA000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.6),
                      blurRadius: 18,
                      spreadRadius: 2,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  "PROCEED",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class DiagonalTicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const double slice = 16;
    final path = Path();
    path.moveTo(0, slice);
    path.lineTo(slice, 0);
    path.lineTo(size.width - slice, 0);
    path.lineTo(size.width, slice);
    path.lineTo(size.width, size.height - slice);
    path.lineTo(size.width - slice, size.height);
    path.lineTo(slice, size.height);
    path.lineTo(0, size.height - slice);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _PunchHole extends StatelessWidget {
  const _PunchHole();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
    );
  }
}
