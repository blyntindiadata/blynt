import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:startup/events/joineventscreen.dart';

// import 'event_card_enhanced.dart';

class PastEventScreen extends StatefulWidget {
  final String uid;
  final String username;

  const PastEventScreen({
    super.key,
    required this.uid,
    required this.username,
  });

  @override
  State<PastEventScreen> createState() => _PastEventScreenState();
}

class _PastEventScreenState extends State<PastEventScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _createdEvents = [];
  bool _loading = true;

  static const Color darkBackground = Color(0xFF000000);
  static const Color gold = Color(0xFFFFD700);
  static const Color accentGold = Color(0xFFFFE082);
  static const Color amber = Color(0xFFFFC107);
  static const Color textSecondary = Color(0xFFAAAAAA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCreatedEvents();
  }

  Future<void> _loadCreatedEvents() async {
    setState(() {
      _loading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
  .collection('users')
  .doc(widget.uid)
  .collection('hostedEvents')
  .get();

// final events = hostedEventsSnapshot.docs.map((doc) => doc.data()).toList();


      final events = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'name': data['name'] ?? '',
          'description': data['description'] ?? '',
          'location': data['location'] ?? '',
          'date': data['date'] ?? '',
          'time': _formatTimeSlots(data['timeSlots']),
          'mainCategory': data['mainCategory'] ?? '',
          'selectedCategory': data['selectedCategory'] ?? '',
          'createdAt': (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
          'hostUsername': data['hostUsername'] ?? '',
          'hostFirstName': data['hostFirstName'] ?? '',
          'hostLastName': data['hostLastName'] ?? '',
        };
      }).toList();

      events.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));

      setState(() {
        _createdEvents = events;
        _loading = false;
      });
    } catch (e) {
      print("❌ Failed to load created events: $e");
      setState(() => _loading = false);
    }
  }

  String _formatTimeSlots(List<dynamic>? timeSlots) {
    if (timeSlots == null || timeSlots.isEmpty) return 'Time not specified';
    final first = timeSlots.first.toString().split('-')[0];
    final last = timeSlots.last.toString().split('-').last;

    try {
      final start = DateFormat('HH:mm').parse(first);
      final end = DateFormat('HH:mm').parse(last);
      return '${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}';
    } catch (e) {
      return timeSlots.join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [gold.withOpacity(0.3), gold.withOpacity(0.1)],
                  ),
                  border: Border.all(
                    color: gold.withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            const Spacer(),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                'Past Events',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            const SizedBox(width: 36),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(32),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                ),
                borderRadius: BorderRadius.circular(32),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: "Joined Events"),
                Tab(text: "Created Events"),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          // Joined Events (placeholder)
          const Center(
            child: Text(
              "Joined events will appear here.",
              style: TextStyle(color: Colors.white54),
            ),
          ),

          // Created Events
          _loading
              ? const Center(
                  child: CircularProgressIndicator(color: accentGold),
                )
              : _createdEvents.isEmpty
                  ? Center(
                      child: Text(
                        "No created events found.",
                        style: GoogleFonts.poppins(color: Colors.white60),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      itemCount: _createdEvents.length,
                      itemBuilder: (_, i) {
                        final e = _createdEvents[i];
                        final createdAt = DateTime.fromMillisecondsSinceEpoch(e['createdAt']);
                        final isNew = DateTime.now().difference(createdAt).inHours < 72;

                        return EventCardEnhanced(
                          title: e['name'],
                          description: e['description'],
                          location: e['location'],
                          dateFormatted: e['date'],
                          time: e['time'],
                          subCategory: e['selectedCategory'] ?? '',
                          hostFirstName: e['hostFirstName'] ?? '',
                          hostLastName: e['hostLastName'] ?? '',
                          hostUsername: e['hostUsername'] ?? '',
                          isNew: isNew,
                          index: i, event: {}, 
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
