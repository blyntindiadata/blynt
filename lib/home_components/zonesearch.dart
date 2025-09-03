import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/home_components/anonymous_chat_landing.dart';
import 'package:startup/home_components/barter_system_page.dart';
import 'package:startup/home_components/chat_screen.dart';
import 'package:startup/home_components/chat_service.dart';
import 'package:startup/home_components/committee_mainpage.dart';
import 'package:startup/home_components/confessions.dart';
import 'package:startup/home_components/doubt_screen.dart';
import 'package:startup/home_components/games_screen.dart';
import 'package:startup/home_components/lostfoundpage.dart';
import 'package:startup/home_components/no_limits_scree.dart';
import 'package:startup/home_components/polls_screen.dart';
import 'package:startup/home_components/shitiwishiknew.dart';
import 'package:startup/home_components/thegarage.dart';
import 'package:startup/home_components/your_neighbourhood.dart';

class ZoneSearchScreen extends StatefulWidget {
  final String communityId;
  final String userRole;
  final String userId;
  final String username;

  const ZoneSearchScreen({
    super.key,
    required this.communityId,
    required this.userRole,
    required this.userId,
    required this.username,
  });

  @override
  State<ZoneSearchScreen> createState() => _ZoneSearchScreenState();
}

class _ZoneSearchScreenState extends State<ZoneSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Map<String, dynamic>> filteredZones = [];
  bool isSearching = false;

  final List<Map<String, dynamic>> allZones = [
    {'name': 'anonymous chatting', 'desc': 'wait till the identities get revealed🥷', 'icon': Icons.people_sharp, 'colors': [Color(0xFF3B82F6), Color(0xFF2563EB)], 'type': 'chat'},
    {'name': 'gaming arena', 'desc': 'make those long talented fingers work🖖', 'icon': Icons.theater_comedy, 'colors': [const Color(0xFFE91E63), const Color(0xFF8B2635)], 'type': 'shows'},
    {'name': 'the confession vault', 'desc': 'we know you cannot face that baddie💔', 'icon': Icons.lock_outline, 'colors': [Color(0xFF8B5CF6), Color(0xFFA855F7)], 'type': 'confessions'},
    {'name': 'shit i wish i knew', 'desc': 'do not make the mistake that your parents did', 'icon': Icons.lightbulb_outline, 'colors': [Color(0xFFF59E0B), Color(0xFFD97706)], 'type': 'shit_i_wish'},
    {'name': 'no limits', 'desc': 'show your college who is the goat🐐', 'icon': Icons.all_inclusive, 'colors': [Color(0xFFEF4444), Color(0xFFDC2626)], 'type': 'no_limits'},
    {'name': 'lost it', 'desc': 'you might find your lost tiffin but not her🥀', 'icon': Icons.search_off, 'colors': [Color.fromARGB(255, 102, 75, 63), Color.fromARGB(255, 103, 62, 44)], 'type': 'lost'},
    {'name': 'doubts', 'desc': 'we know this is kinda useless', 'icon': Icons.construction, 'colors': [const Color(0xFF4A4A4A), const Color(0xFF2C2C2C)], 'type': 'doubts'},
    {'name': 'barter?\nhell yeah', 'desc': 'trade skills, not drugs', 'icon': Icons.swap_horiz, 'colors': [Color(0xFF10B981), Color(0xFF059669)], 'type': 'barter'},
    {'name': 'the polls', 'desc': 'organize mass bunks🤤', 'icon': Icons.poll_sharp, 'colors': [Color(0xFF1976D2), Color(0xFF64B5F6)], 'type': 'polls'},
    {'name': 'your\nneighbourhood', 'desc': 'places where you go', 'icon': Icons.location_on_outlined, 'colors': [Color(0xFF84CC16), Color(0xFF65A30D)], 'type': 'neighbourhood'},
    {'name': 'committees', 'desc': 'ah shit here we go again', 'icon': Icons.groups_outlined, 'colors': [Color(0xFF0EA5E9), Color(0xFF0284C7)], 'type': 'committees'},
  ];

  @override
  void initState() {
    super.initState();
    filteredZones = List.from(allZones);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _filterZones(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredZones = List.from(allZones);
        isSearching = false;
      } else {
        isSearching = true;
        filteredZones = allZones.where((zone) {
          return zone['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
                 zone['desc'].toString().toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _navigateToZone(Map<String, dynamic> zone) async {
    if (zone['type'] == 'confessions') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ConfessionsPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'no_limits') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NoLimitsPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'barter') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarterSystemPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'polls') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PollsPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'garage') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TheGaragePage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'shit_i_wish') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShitIWishIKnewPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'chat') {
      final chatService = ChatService();
      final activeSession = await chatService.getActiveSession(widget.communityId, widget.userId);
      
      if (activeSession != null) {
        final partnerId = activeSession.getPartnerId(widget.userId);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              communityId: widget.communityId,
              userId: widget.userId,
              username: widget.username,
              sessionId: activeSession.sessionId,
              partnerId: partnerId,
            ),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnonymousChatLanding(
              communityId: widget.communityId,
              userId: widget.userId,
              username: widget.username,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'lost') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LostAndFoundPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'neighbourhood') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => YourNeighbourhoodScreen(
            communityId: widget.communityId,
            userRole: widget.userRole,
          ),
        ),
      );
    } else if (zone['type'] == 'doubts') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoubtsPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'shows') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GamesPage(
            communityId: widget.communityId,
            userId: widget.userId,
            username: widget.username,
          ),
        ),
      );
    } else if (zone['type'] == 'committees') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CommitteesPage(
            communityId: widget.communityId,
            userId: widget.userId,
            userRole: widget.userRole,
            username: widget.username,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coming soon: ${zone['name']}',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildSearchResults() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (filteredZones.isEmpty && isSearching) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 48 : 40),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: isTablet ? 56 : 48,
              color: Colors.white60,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'No zones found',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              'Try searching for confessions, polls, gaming, etc.',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 16 : 14,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredZones.map((zone) {
        return Container(
          margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
          child: GestureDetector(
            onTap: () => _navigateToZone(zone),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (zone['colors'] as List<Color>)[0].withOpacity(0.2),
                    (zone['colors'] as List<Color>)[1].withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (zone['colors'] as List<Color>)[0].withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: zone['colors'] as List<Color>,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      zone['icon'] as IconData,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone['name'] as String,
                          style: GoogleFonts.dmSerifDisplay(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isTablet ? 6 : 4),
                        Text(
                          zone['desc'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 13,
                            color: Colors.white60,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white60,
                    size: isTablet ? 18 : 16,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        height: screenHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2A1810).withOpacity(0.9),
              const Color(0xFF3D2914).withOpacity(0.7),
              const Color(0xFF4A3218).withOpacity(0.5),
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with back button and search bar
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 10 : 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white,
                          size: isTablet ? 20 : 18,
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF7B42C).withOpacity(0.1),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _focusNode,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: isTablet ? 16 : 14,
                          ),
                          cursorColor: const Color(0xFFF7B42C),
                          onChanged: _filterZones,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: const Color(0xFFF7B42C),
                              size: isTablet ? 24 : 20,
                            ),
                            hintText: 'Search zones...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: isTablet ? 16 : 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFF7B42C),
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 16 : 14,
                              vertical: isTablet ? 16 : 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Results
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isSearching) ...[
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: isTablet ? 16 : 12,
                            left: 4,
                          ),
                          child: Text(
                            'Search Results',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: isTablet ? 16 : 12,
                            left: 4,
                          ),
                          child: Text(
                            'All Zones',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 20 : 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                      
                      Expanded(
                        child: SingleChildScrollView(
                          child: _buildSearchResults(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}