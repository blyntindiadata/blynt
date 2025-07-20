import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:startup/events/summary_counter_events.dart';

class JoinEventScreen extends StatefulWidget {
  final String uid;
  final String username;
  final String firstName;
  final String lastName;

  const JoinEventScreen({
    super.key,
    required this.uid,
    required this.username,
    required this.firstName,
    required this.lastName,});

  @override
  State<JoinEventScreen> createState() => _JoinEventScreenState();
}

class _JoinEventScreenState extends State<JoinEventScreen> {
  Map<String, List<Map<String, dynamic>>> _groupedEvents = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _events = [];
  bool _sortByAscendingDate = true;
  bool _loading = true;
  String _searchQuery = "";
 


  // Color Palette - Kept intact
  static const Color darkBackground = Color(0xFF000000);
  static const Color cardColor = Color(0xFF1A1A1A);
  static const Color gold = Color(0xFFFFB000);
  static const Color goldLight = Color(0xFFFFD700);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color amber = Color(0xFFFFC107);
  static const Color accentGold = Color(0xFFFFE082);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color primaryGradientStart = Color(0xFFE2B04A);
  static const Color primaryGradientEnd = Color(0xFFCD7F32);
  static const Color highlightColor = Color(0xFFF0E68C);
  static const Color newBadgeColor = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    _loadEvents();
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

Widget _buildCategoryList(String category) {
  final rawEvents = (_groupedEvents[category] ?? []);
  final seen = <String>{};

  final events = rawEvents.where((event) {
    final name = event['name'].toString().toLowerCase();
    final description = event['description'].toString().toLowerCase();
    final location = event['location'].toString().toLowerCase();
    final query = _searchQuery.toLowerCase();

    final key = '${event['name']}_${event['date']}_${event['hostUsername']}';
    if (seen.contains(key)) return false;
    seen.add(key);

    return name.contains(query) || description.contains(query) || location.contains(query);
  }).toList();

  print("🔎 Rendering [$category]: ${events.length} filtered events");

  if (events.isEmpty) {
    return Center(
      child: Text(
        'No $category events found.',
        style: GoogleFonts.poppins(color: Colors.white60, fontSize: 15),
      ),
    );
  }

  return RefreshIndicator(
    onRefresh: _refreshEvents,
    color: accentGold,
    backgroundColor: cardColor,
    child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: events.length,
      itemBuilder: (_, i) {
        final e = events[i];
        final createdAt = DateTime.fromMillisecondsSinceEpoch(e['createdAt']);
        final isNew = DateTime.now().difference(createdAt).inHours < 72;

        return EventCardEnhanced(
           event: e, // 👈 Add this
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
  index: i,
        );
      },
    ),
  );
}


Future<void> _loadEvents() async {
  print("🟡 [_loadEvents] Triggered");
  setState(() => _loading = true);

  final prefs = await SharedPreferences.getInstance();

  try {
    final cachedJson = prefs.getString('cachedEvents');
    if (cachedJson != null) {
      print("✅ [_loadEvents] Loaded cached events");
      final List decoded = jsonDecode(cachedJson);
      _events = decoded.cast<Map<String, dynamic>>();
      print("📦 [_loadEvents] _events (from cache): ${_events.length}");

      _groupedEvents.clear(); // ✅ Clear instead of reassignment
      for (var item in _events) {
        final category = (item['mainCategory'] ?? 'Other').toString().trim();
        _groupedEvents.putIfAbsent(category, () => []).add(item);
      }
    } else {
      print("⚠️ [_loadEvents] No cache found");
    }
  } catch (e) {
    print("❌ [_loadEvents] Cache error: $e");
    _events = [];
    _groupedEvents.clear();
  }

  try {
    final snapshot = await FirebaseFirestore.instance.collectionGroup('events').get();
    print("✅ [_loadEvents] Firestore fetched: ${snapshot.docs.length} events");

    final fresh = snapshot.docs.map((doc) {
  final data = doc.data();
  final pathSegments = doc.reference.path.split('/');
  final eventType = pathSegments.length >= 4 ? pathSegments[pathSegments.length - 3] : 'unknown';

  return {
    'id': doc.id,
    'type': eventType, // stand-up-comedy or similar
    'name': data['name'] ?? 'Untitled Event',
    'location': data['location'] ?? 'Not specified',
    'description': data['description'] ?? '',
    'date': data['date'] ?? 'Date not specified',
    'time': _formatTimeSlots(data['timeSlots']),
    'mainCategory': data['mainCategory'] ?? 'Other',
    'createdAt': (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
    'hostUsername': data['hostUsername'] ?? '',
    'hostFirstName': data['hostFirstName'] ?? '',
    'hostLastName': data['hostLastName'] ?? '',
    'selectedCategory': data['selectedCategory'] ?? '',
  };
}).toList();


    // ✅ Remove duplicate events by composite key
    final seen = <String>{};
    final deduped = fresh.where((e) {
      final key = '${e['name']}_${e['date']}_${e['hostUsername']}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();

    deduped.sort((a, b) => _sortByAscendingDate
        ? a['createdAt'].compareTo(b['createdAt'])
        : b['createdAt'].compareTo(a['createdAt']));

    _events = deduped;
    print("📥 [_loadEvents] _events (from Firestore): ${_events.length}");

    _groupedEvents.clear();
    for (var item in _events) {
      final category = (item['mainCategory'] ?? 'Other').toString().trim();
      _groupedEvents.putIfAbsent(category, () => []).add(item);
    }

    await prefs.setString('cachedEvents', jsonEncode(_events));
    print("📝 [_loadEvents] Cache updated");

    setState(() => _loading = false);
  } catch (e) {
    print("❌ [_loadEvents] Firestore error: $e");
    setState(() => _loading = false);
  }
}


  Future<void> _refreshEvents() async {
    print("🔄 [_refreshEvents] Called");
    setState(() {
      _searchController.clear();
      _searchQuery = "";
      _loading = true;
    });
    await _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEvents = _events.where((event) {
      final name = event['name'].toString().toLowerCase();
      final description = event['description'].toString().toLowerCase();
      final location = event['location'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query) || location.contains(query);
    }).toList();

    return DefaultTabController(
      length: 5,
    child:Scaffold(
      backgroundColor: darkBackground,
      body: Stack(
        children: [
          // Ambient background particles
          ...List.generate(8, (index) => Positioned(
            left: (index * 47.3) % MediaQuery.of(context).size.width,
            top: (index * 73.7) % MediaQuery.of(context).size.height,
            child: Container(
              width: 2 + (index % 3).toDouble(),
              height: 2 + (index % 3).toDouble(),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentGold.withOpacity(0.1),
              ),
            ),
          )),
          
          SafeArea(
            child: Column(
              children: [
                // Enhanced Header with glassmorphism
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.12),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                child: Column(
  children: [
    // Header with title and back/sort
    Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  goldLight.withOpacity(0.3),
                  goldLight.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: goldLight.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
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
            'upcoming events',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            setState(() {
              _sortByAscendingDate = !_sortByAscendingDate;
              _events.sort((a, b) {
                final aTime = (a['createdAt'] as int);
                final bTime = (b['createdAt'] as int);
                return _sortByAscendingDate
                    ? aTime.compareTo(bTime)
                    : bTime.compareTo(aTime);
              });
            });
          },
          child: Icon(
            _sortByAscendingDate ? Icons.calendar_month_outlined : Icons.calendar_today_outlined,
            color: goldLight,
            size: 20,
          ),
        ),
      ],
    ),

  // const SizedBox(height: 16),

// Enhanced Gradient TabBar
const SizedBox(height: 16),

// Outer pill background for the scrollable TabBar
Container(
  margin: const EdgeInsets.symmetric(horizontal: 1),
  padding: const EdgeInsets.symmetric(horizontal: 1),
  height: 42,
  decoration: BoxDecoration(
    color: const Color(0xFF121212),
    borderRadius: BorderRadius.circular(30),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.8),
        offset: const Offset(4, 4),
        blurRadius: 8,
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.05),
        offset: const Offset(-2, -2),
        blurRadius: 6,
      ),
    ],
  ),
  child: TabBar(
    isScrollable: true, // 👈 Set to true to allow individual tab padding to dictate width
    indicatorSize: TabBarIndicatorSize.label, // 👈 Indicator wraps text + padding
    indicator: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(
          color: Colors.amberAccent.withOpacity(0.6),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ],
    ),
    dividerColor: Colors.transparent,
    labelColor: Colors.black,
    unselectedLabelColor: Colors.white70,
    labelStyle: GoogleFonts.poppins(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
    ),
    splashFactory: NoSplash.splashFactory,
    overlayColor: MaterialStateProperty.all(Colors.transparent),
    tabs: const [
      Tab(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24), // 👈 Increased horizontal padding
        child: Text("Individual"),
      )),
      Tab(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24), // 👈 Increased horizontal padding
        child: Text("Music"),
      )),
      Tab(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24), // 👈 Increased horizontal padding
        child: Text("College"),
      )),
      Tab(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24), // 👈 Increased horizontal padding
        child: Text("Festival"),
      )),
      Tab(child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24), // 👈 Increased horizontal padding
        child: Text("Workshops"),
      )),
    ],
  ),
),



  ],
),

                ),

                // Premium Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 25,
                          spreadRadius: 0,
                          offset: const Offset(0, 15),
                        ),
                        BoxShadow(
                          color: gold.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: "Search events...",
                        hintStyle: GoogleFonts.poppins(
                          color: textSecondary.withOpacity(0.7),
                          fontSize: 15,
                        ),
                        prefixIcon: Container(
                          padding: const EdgeInsets.all(12),
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [goldLight, amber],
                            ).createShader(bounds),
                            child: const Icon(
                              Icons.search_rounded,
                              size: 24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: textSecondary.withOpacity(0.7),
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = "";
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.transparent,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      ),
                      onChanged: (val) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        _debounce = Timer(const Duration(milliseconds: 400), () {
                          setState(() => _searchQuery = val.trim());
                        });
                      },
                    ),
                  ),
                ),
                 if (_loading)
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accentGold.withOpacity(0.2),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: CircularProgressIndicator(
                          color: accentGold,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  )
                else if (_groupedEvents.entries.every((entry) =>
    entry.value.where((event) {
      final name = event['name'].toString().toLowerCase();
      final description = event['description'].toString().toLowerCase();
      final location = event['location'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || description.contains(query) || location.contains(query);
    }).isEmpty))

                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.02),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    textSecondary.withOpacity(0.2),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.event_busy_rounded,
                                color: textSecondary.withOpacity(0.6),
                                size: 60,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found.\nExpand your search or check back later!',
                              style: GoogleFonts.poppins(
                                color: textSecondary.withOpacity(0.8),
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
  child: TabBarView(
    physics: const BouncingScrollPhysics(),
    children: [
      _buildCategoryList('Individual'),
      _buildCategoryList('Music'),
      _buildCategoryList('College'),
      _buildCategoryList('Festival'),
      _buildCategoryList('Workshops'),
    ],
  ),
),


              ],
            ),
          ),
        ],
      ),
    )
    );
  }
}

class EventCardEnhanced extends StatelessWidget {
  final Map<String, dynamic> event;
  final String title;
  final String description;
  final String location;
  final String dateFormatted;
  final String time;
  final bool isNew;
  final int index;
  final String subCategory;
final String hostFirstName;
final String hostLastName;
final String hostUsername;


 const EventCardEnhanced({
    super.key,
  required this.event,
  required this.title,
  required this.description,
  required this.location,
  required this.dateFormatted,
  required this.time,
  required this.subCategory,
  required this.hostFirstName,
  required this.hostLastName,
  required this.hostUsername,
  required this.isNew,
  required this.index,
});

  static const Color cardColor = Color(0xFF1A1A1A);
  static const Color gold = Color(0xFFFFB000);
  static const Color goldLight = Color(0xFFFFD700);
  static const Color bronze = Color(0xFFCD7F32);
  static const Color amber = Color(0xFFFFC107);
  static const Color accentGold = Color(0xFFFFE082);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color primaryGradientStart = Color(0xFFE2B04A);
  static const Color primaryGradientEnd = Color(0xFFCD7F32);
  static const Color newBadgeColor = Color.fromARGB(255, 255, 160, 8);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.12),
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(0, 25),
            blurRadius: 60,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: accentGold.withOpacity(0.08),
            offset: const Offset(0, 0),
            blurRadius: 40,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Opening details for '$title'...",
                  style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                ),
                backgroundColor: amber,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          colors: [accentGold, goldLight, gold],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),

      const SizedBox(height: 12),

      // Host name golden glowing tile
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFFFD700), Color(0xFFFFB000)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          "~by ${hostFirstName.trim()} ${hostLastName.trim()} (@$hostUsername)",
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),

      const SizedBox(height: 12),

      // Sub-category glowing chip
      if (subCategory.isNotEmpty)
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              subCategory,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
        ),
    ],
  ),
),

                    if (isNew)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [newBadgeColor, newBadgeColor.withOpacity(0.8)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: newBadgeColor.withOpacity(0.6),
                              blurRadius: 15,
                              spreadRadius: 0,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          'NEW',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Enhanced Description
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.03),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Text(
                    description.isNotEmpty
                        ? description
                        : 'No description available for this event. Stay tuned for updates!',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: textSecondary.withOpacity(0.95),
                      fontStyle: description.isEmpty ? FontStyle.italic : FontStyle.normal,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 24),

                // Enhanced Info Tiles
                _buildInfoTile(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  value: location,
                  iconColor: bronze,
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: dateFormatted,
                  iconColor: amber,
                ),
                const SizedBox(height: 12),
                _buildInfoTile(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: time,
                  iconColor: goldLight,
                ),
                const SizedBox(height: 12),

// _buildInfoTile(
//   icon: Icons.star_outline_rounded,
//   label: 'Sub-category',
//   value: subCategory.isNotEmpty ? subCategory : 'Not specified',
//   iconColor: Colors.amber,
// ),

// const SizedBox(height: 12),

// _buildInfoTile(
//   icon: Icons.person_outline_rounded,
//   label: 'Host',
//   value: "${hostFirstName.trim()} ${hostLastName.trim()} (@$hostUsername)",
//   iconColor: Colors.tealAccent,
// ),


                // Premium Join Button
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [goldLight, primaryGradientEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: goldLight.withOpacity(0.4),
                          blurRadius: 25,
                          spreadRadius: 0,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: amber.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 0,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                       onTap: () {
  final enrichedEvent = {
    ...event,
    'id': event['id'],
    'selectedCategory': event['selectedCategory'],
    'mainCategory': event['mainCategory'],
  };

  print('🟢 Pushing enriched event with id=${enrichedEvent['id']}, type=${enrichedEvent['selectedCategory']}, mainCategory=${enrichedEvent['mainCategory']}');

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EventDetailSummaryScreen(event: enrichedEvent),
    ),
  );
},

                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Join Event',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.black,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  iconColor.withOpacity(0.3),
                  iconColor.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: iconColor.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: textSecondary.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}