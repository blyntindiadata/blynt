import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/scheduler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup/home_components/2048.dart';
import 'package:startup/home_components/bird.dart';
import 'package:startup/home_components/past_leaderboard.dart';
import 'package:startup/home_components/puzzle.dart';
import 'package:startup/home_components/timer_game.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class GamesPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const GamesPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends State<GamesPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initAnimations();
  }

  // Add this method to check if there's an active leaderboard
Future<Map<String, dynamic>?> _getCurrentLeaderboard() async {
  try {
    print('Checking leaderboard for community: ${widget.communityId}'); // Debug line
    final doc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('meta')
        .doc('current_leaderboard')
        .get();
    
    print('Document exists: ${doc.exists}'); // Debug line
    if (doc.exists) {
      print('Document data: ${doc.data()}'); // Debug line
      return doc.data() as Map<String, dynamic>;
    }
  } catch (e) {
    print('Error getting current leaderboard: $e');
  }
  return null;
}

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
    body: Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF4A1625),
        Color(0xFF2D0F1A),
        Color(0xFF1A0B11),
        Colors.black,
      ],
    ),
  ),
  child: SafeArea(
    child: Column(
      children: [
        _buildHeader(),
        _buildTabBar(),
        _buildCurrentLeaderboardDisplay(MediaQuery.of(context).size.width),
        // Add reset button for admins
       FutureBuilder<bool>(
  future: _checkIfAdmin(),
  builder: (context, snapshot) {
    if (snapshot.data == true) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _buildLeaderboardButton(MediaQuery.of(context).size.width), // Changed method name
      );
    }
    return const SizedBox.shrink();
  },
),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildTabBarView(),
          ),
        ),
      ],
    ),
  ),
),
    );
    
  }

  Widget _buildLeaderboardButton(double screenWidth) {
  return FutureBuilder<Map<String, dynamic>?>(
    future: _getCurrentLeaderboard(),
    builder: (context, snapshot) {
      final hasActiveLeaderboard = snapshot.data != null;
      final leaderboardName = snapshot.data?['name'] ?? '';
      
      if (hasActiveLeaderboard) {
        // Show Archive button
        return Container(
          margin: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 12 : 16),
          child: Column(
            children: [
              // Current leaderboard info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A1625).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8B2635).withOpacity(0.5)),
                ),
                child: Text(
                  'Active: $leaderboardName',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE91E63),
                    fontSize: screenWidth < 600 ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Archive button
              ElevatedButton.icon(
                onPressed: () => _showArchiveConfirmation(leaderboardName),
                icon: const Icon(Icons.archive, color: Colors.white),
                label: Text(
                  'Archive Leaderboard',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B2635),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Show Create button
        return Container(
          margin: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 12 : 16),
          child: ElevatedButton.icon(
            onPressed: _showCreateLeaderboardDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Create Leaderboard',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B2635),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      }
    },
  );
}

Widget _buildCurrentLeaderboardDisplay(double screenWidth) {
  return FutureBuilder<Map<String, dynamic>?>(
    future: _getCurrentLeaderboard(),
    builder: (context, snapshot) {
      if (snapshot.data != null) {
        final leaderboardName = snapshot.data!['name'] ?? '';
        final createdAt = snapshot.data!['createdAt'] as Timestamp?;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 12 : 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF4A1625).withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF8B2635).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events,
                color: const Color(0xFFE91E63),
                size: screenWidth < 600 ? 16 : 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Current: $leaderboardName',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE91E63),
                    fontSize: screenWidth < 600 ? 12 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    },
  );
}

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        // More granular breakpoints
        final isVerySmall = screenWidth < 360; // Very small phones
        final isSmall = screenWidth < 600; // Small phones
        final isMedium = screenWidth >= 600 && screenWidth < 768; // Large phones/small tablets
        final isTablet = screenWidth >= 768 && screenWidth < 1024; // Tablets
        final isLarge = screenWidth >= 1024; // Large tablets/small desktops
        
        // Responsive sizing
        double horizontalPadding = isVerySmall ? 12 : (isSmall ? 16 : (isMedium ? 20 : (isTablet ? 24 : 32)));
        double verticalPadding = isVerySmall ? 12 : (isSmall ? 16 : (isMedium ? 18 : (isTablet ? 20 : 24)));
        double iconSize = isVerySmall ? 20 : (isSmall ? 24 : (isMedium ? 26 : (isTablet ? 28 : 32)));
        double gameIconSize = isVerySmall ? 16 : (isSmall ? 20 : (isMedium ? 22 : (isTablet ? 24 : 28)));
        double spacing = isVerySmall ? 8 : (isSmall ? 12 : (isMedium ? 14 : (isTablet ? 16 : 20)));
        double titleFontSize = isVerySmall ? 16 : (isSmall ? 20 : (isMedium ? 22 : (isTablet ? 24 : 32)));
        double subtitleFontSize = isVerySmall ? 8 : (isSmall ? 10 : (isMedium ? 11 : (isTablet ? 12 : 16)));
        
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            verticalPadding * 0.75,
          ),
          // decoration: BoxDecoration(
          //   gradient: LinearGradient(
          //     begin: Alignment.topLeft,
          //     end: Alignment.bottomRight,
          //     colors: [
          //       const Color(0xFF4A1625).withOpacity(0.3),
          //       Colors.transparent,
          //     ],
          //   ),
          // ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back button
             // Back button
GestureDetector(
  onTap: () => Navigator.pop(context),
  child: Container(
    padding: EdgeInsets.all(isVerySmall ? 8 : (isSmall ? 10 : (isMedium ? 11 : (isTablet ? 12 : 16)))),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(isVerySmall ? 12 : (isSmall ? 14 : (isMedium ? 15 : (isTablet ? 16 : 18)))),
      border: Border.all(
        color: const Color(0xFF8B2635).withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Icon(
      Icons.arrow_back_ios_new,
      color: Colors.white,
      size: iconSize,
    ),
  ),
),
              
              SizedBox(width: spacing * 0.5),
              
              // Games icon
              Container(
                padding: EdgeInsets.all(isVerySmall ? 8 : (isSmall ? 10 : (isMedium ? 11 : (isTablet ? 12 : 16)))),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B2635), Color(0xFF4A1625)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B2635).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.games,
                  color: Colors.white,
                  size: gameIconSize,
                ),
              ),
              
              SizedBox(width: spacing),
              
              // Title section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
  'gamer\'s garage',
  style: GoogleFonts.dmSerifDisplay(
    fontSize: titleFontSize,
    fontWeight: FontWeight.bold,
    foreground: Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
      ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
    letterSpacing: 0.5,
    height: 1.1,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
                    if (subtitleFontSize > 0)
                      Text(
                        'not so fancy games - but you\'ll like \'em',
                        style: GoogleFonts.poppins(
                          fontSize: subtitleFontSize,
                          color: const Color(0xFFE91E63),
                          height: 1.2,
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
      },
    );
  }

  Widget _buildTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        final isVerySmall = screenWidth < 360;
        final isSmall = screenWidth < 600;
        final isMedium = screenWidth >= 600 && screenWidth < 768;
        final isTablet = screenWidth >= 768 && screenWidth < 1024;
        final isLarge = screenWidth >= 1024;
        
        double horizontalMargin = isVerySmall ? 12 : (isSmall ? 16 : (isMedium ? 20 : (isTablet ? 24 : 32)));
        double verticalMargin = isVerySmall ? 6 : (isSmall ? 8 : (isMedium ? 9 : (isTablet ? 10 : 12)));
        double fontSize = isVerySmall ? 10 : (isSmall ? 11 : (isMedium ? 12 : (isTablet ? 13 : 17)));
        
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: verticalMargin,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF4A1625).withOpacity(0.3)),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B2635), Color(0xFFE91E63)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Games'),
              Tab(text: 'Leaderboard'),
              Tab(text: 'Archives'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        GamesListView(
          communityId: widget.communityId,
          userId: widget.userId,
          username: widget.username,
        ),
        LeaderboardView(
          communityId: widget.communityId,
          userId: widget.userId,
          username: widget.username,
        ),
         PastLeaderboardsScreen(
    communityId: widget.communityId,
    userId: widget.userId,
    username: widget.username,
  ),
      ],
    );
  }

Widget _buildReaderboardButton(double screenWidth) {
  return FutureBuilder<Map<String, dynamic>?>(
    future: _getCurrentLeaderboard(),
    builder: (context, snapshot) {
      final hasActiveLeaderboard = snapshot.data != null;
      final leaderboardName = snapshot.data?['name'] ?? '';
      
      if (hasActiveLeaderboard) {
        // Show Archive button
        return Container(
          margin: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 12 : 16),
          child: Column(
            children: [
              // Current leaderboard info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A1625).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF8B2635).withOpacity(0.5)),
                ),
                child: Text(
                  'Active: $leaderboardName',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFFE91E63),
                    fontSize: screenWidth < 600 ? 12 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Archive button
              ElevatedButton.icon(
                onPressed: () => _showArchiveConfirmation(leaderboardName),
                icon: const Icon(Icons.archive, color: Colors.white),
                label: Text(
                  'Archive Leaderboard',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B2635),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        // Show Create button
        return Container(
          margin: EdgeInsets.symmetric(horizontal: screenWidth < 360 ? 12 : 16),
          child: ElevatedButton.icon(
            onPressed: _showCreateLeaderboardDialog,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text(
              'Create Leaderboard',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B2635),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      }
    },
  );
}

Future<void> _showCreateLeaderboardDialog() async {
  final TextEditingController nameController = TextEditingController();
  
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2D0F1A),
      title: Text(
        'Create New Leaderboard',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Creating a new leaderboard will archive the current scores and reset all points to 0.',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Text(
            'Leaderboard Name:',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: nameController,
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'e.g., "Winter Championship 2024"',
              hintStyle: GoogleFonts.poppins(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF4A1625).withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF8B2635).withOpacity(0.5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: const Color(0xFF8B2635).withOpacity(0.5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE91E63)),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            final name = nameController.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop({
                'confirmed': true,
                'name': name,
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter a leaderboard name'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B2635)),
          child: Text('Create', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    ),
  );

 if (result != null && result['confirmed'] == true && result['name'] != null) {
  await _createNewLeaderboard(result['name'] as String);
}
}

Future<void> _createNewLeaderboard(String leaderboardName) async {
  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      ),
    );

    // Create current leaderboard document
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('meta')
        .doc('current_leaderboard')
        .set({
      'name': leaderboardName,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': widget.username,
      'isActive': true,
    });

    // Hide loading and show success
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Leaderboard "$leaderboardName" created! Players can now start scoring.',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF8B2635),
      ),
    );
    
    // Refresh the current view
    setState(() {});
  } catch (e) {
    Navigator.of(context).pop(); // Hide loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error creating leaderboard: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
Future<void> _showArchiveConfirmation(String currentLeaderboardName) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2D0F1A),
      title: Text(
        'Archive Leaderboard',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      content: Text(
        'This will archive "$currentLeaderboardName" with the current top 10 scores and reset all scores to 0. You can then create a new leaderboard.',
        style: GoogleFonts.poppins(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B2635)),
          child: Text('Archive', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _archiveCurrentLeaderboard(currentLeaderboardName);
  }
}
Future<void> _archiveCurrentLeaderboard(String leaderboardName) async {
  try {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFE91E63)),
      ),
    );

    // Get current top 10 scores
    final currentScores = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('game_scores')
        .orderBy('totalPoints', descending: true)
        .limit(10)
        .get();

    if (currentScores.docs.isNotEmpty) {
      // Generate unique archive ID
      final now = DateTime.now();
      final archiveId = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.millisecondsSinceEpoch}';

      final batch = FirebaseFirestore.instance.batch();
      
      // Create the archive document with metadata
      final archiveDocRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('leaderboard_archives')
          .doc(archiveId);
      
      batch.set(archiveDocRef, {
        'name': leaderboardName,
        'archivedAt': FieldValue.serverTimestamp(),
        'totalUsers': currentScores.docs.length,
        'archivedBy': widget.username,
        'leaderboardId': archiveId,
      });
      
      // Archive top 10 with their ranks
      for (int i = 0; i < currentScores.docs.length; i++) {
        final doc = currentScores.docs[i];
        final data = doc.data();
        data['rank'] = i + 1;
        data['archivedAt'] = FieldValue.serverTimestamp();
        data['leaderboardName'] = leaderboardName;
        
        final archiveRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('leaderboard_archives')
            .doc(archiveId)
            .collection('game_scores')
            .doc(doc.id);
        
        batch.set(archiveRef, data);
      }

      // Reset all current scores to 0
      final allScores = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_scores')
          .get();

      for (final doc in allScores.docs) {
        final resetRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('game_scores')
            .doc(doc.id);
        
        batch.update(resetRef, {
          'totalPoints': 0,
          'timerPoints': 0,
          'puzzlePoints': 0,
          '2048Points': 0,
          'planePoints': 0,
          'lastResetAt': FieldValue.serverTimestamp(),
        });
      }

      // Remove current leaderboard document
      final currentLeaderboardRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('meta')
          .doc('current_leaderboard');
      
      batch.delete(currentLeaderboardRef);

      await batch.commit();
      
      // Hide loading and show success
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leaderboard "$leaderboardName" archived successfully! Archived ${currentScores.docs.length} users.',
           style:GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF8B2635),
        ),
      );
      
      // Refresh the current view
      setState(() {});
    }
  } catch (e) {
    Navigator.of(context).pop(); // Hide loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error archiving leaderboard: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
// Add method to check if user is admin
Future<bool> _checkIfAdmin() async {
  try {
    // Check if user is admin/manager/moderator
    final memberDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .where('username', isEqualTo: widget.username)
        .limit(1)
        .get();
    
    if (memberDoc.docs.isNotEmpty) {
      final role = memberDoc.docs.first.data()['role'] as String?;
      return role == 'admin' || role == 'manager' || role == 'moderator';
    }
    
    // Also check trio collection
    final trioDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .where('username', isEqualTo: widget.username)
        .limit(1)
        .get();
    
    if (trioDoc.docs.isNotEmpty) {
      final role = trioDoc.docs.first.data()['role'] as String?;
      return role == 'admin' || role == 'manager' || role == 'moderator';
    }
    
    return false;
  } catch (e) {
    return false;
  }
}

}



// Number counter widget for scrolling effect
class NumberCounterWidget extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? textStyle;

  const NumberCounterWidget({
    Key? key,
    required this.value,
    this.duration = const Duration(milliseconds: 1000),
    this.textStyle,
  }) : super(key: key);

  @override
  State<NumberCounterWidget> createState() => _NumberCounterWidgetState();
}

class _NumberCounterWidgetState extends State<NumberCounterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _previousValue = widget.value;
  }

  @override
  void didUpdateWidget(NumberCounterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentValue = (_previousValue + 
            (_animation.value * (widget.value - _previousValue))).round();
        return Text(
          currentValue.toString(),
          style: widget.textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

class GamesListView extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const GamesListView({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<GamesListView> createState() => _GamesListViewState();
}

class _GamesListViewState extends State<GamesListView> {
  Map<String, dynamic> userScores = {};
  bool isLoadingScores = true;
  int? userRank;

  // Consistent game colors
  final Map<String, Color> gameColors = {
    'timer': const Color(0xFF8B2635),
    'puzzle': const Color(0xFF8B2635),
    '2048': const Color(0xFF8B2635),
    'plane': const Color(0xFF8B2635),
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await Future.wait([
      _loadUserScores(),
      _loadUserRank(),
    ]);
  }

  Future<void> _loadUserScores() async {
    try {
      final scoreDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_scores')
          .doc(widget.username)
          .get();

      if (scoreDoc.exists) {
        setState(() {
          userScores = scoreDoc.data() ?? {};
        });
      } else {
        setState(() {
          userScores = {
            'timerPoints': 0,
            'puzzlePoints': 0,
            '2048Points': 0,
            'planePoints': 0,
            'totalPoints': 0,
          };
        });
      }
    } catch (e) {
      print('Error loading user scores: $e');
    }
  }

  Future<void> _loadUserRank() async {
    try {
      final scoresQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('game_scores')
          .orderBy('totalPoints', descending: true)
          .get();

      int rank = 1;
      for (var doc in scoresQuery.docs) {
        if (doc.id == widget.username) {
          setState(() {
            userRank = rank;
            isLoadingScores = false;
          });
          return;
        }
        rank++;
      }
      
      setState(() {
        userRank = null;
        isLoadingScores = false;
      });
    } catch (e) {
      print('Error loading user rank: $e');
      setState(() {
        isLoadingScores = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        return SingleChildScrollView(
          child: Padding(
            padding: _getResponsivePadding(screenWidth),
            child: Column(
              children: [
                // Total Score Card
                _buildTotalScoreCard(screenWidth, screenHeight),
                SizedBox(height: _getResponsiveSpacing(screenWidth)),
                
                // Games Grid
                _buildGamesGrid(screenWidth, screenHeight),
              ],
            ),
          ),
        );
      },
    );
  }

  EdgeInsets _getResponsivePadding(double screenWidth) {
    if (screenWidth < 360) return const EdgeInsets.all(8);
    if (screenWidth < 600) return const EdgeInsets.all(12);
    if (screenWidth < 768) return const EdgeInsets.all(16);
    if (screenWidth < 1024) return const EdgeInsets.all(20);
    return const EdgeInsets.all(24);
  }

  double _getResponsiveSpacing(double screenWidth) {
    if (screenWidth < 360) return 12;
    if (screenWidth < 600) return 16;
    if (screenWidth < 768) return 18;
    if (screenWidth < 1024) return 20;
    return 24;
  }

  Widget _buildGamesGrid(double screenWidth, double screenHeight) {
    int crossAxisCount;
    double childAspectRatio;
    double spacing;
    
    if (screenWidth < 360) {
      // Very small phones
      crossAxisCount = 1;
      childAspectRatio = 2.8;
      spacing = 12;
    } else if (screenWidth < 600) {
      // Small phones
      crossAxisCount = 1;
      childAspectRatio = 2.5;
      spacing = 14;
    } else if (screenWidth < 768) {
      // Large phones/small tablets
      crossAxisCount = 2;
      childAspectRatio = 1.2;
      spacing = 16;
    } else if (screenWidth < 1024) {
      // Tablets
      crossAxisCount = 2;
      childAspectRatio = 1.0;
      spacing = 20;
    } else if (screenWidth < 1200) {
      // Large tablets
      crossAxisCount = 3;
      childAspectRatio = 0.9;
      spacing = 24;
    } else {
      // Desktop/large screens
      crossAxisCount = 4;
      childAspectRatio = 0.85;
      spacing = 28;
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      childAspectRatio: childAspectRatio,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      children: [
        _buildGameCard(
          context,
          'lord of the ticks',
          'the only chance to hit on a 10 in life',
          Icons.timer,
          gameColors['timer']!,
          userScores['timerPoints'] ?? 0,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PerfectTimerGame(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          ).then((_) => _loadUserData()),
          screenWidth,
        ),
             _buildGameCard(
          context,
          'swipe & merge',
          'build numbers not your gpa',
          Icons.grid_4x4,
          gameColors['2048']!,
          userScores['2048Points'] ?? 0,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Ruby2048Game(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          ).then((_) => _loadUserData()),
          screenWidth,
        ),
        _buildGameCard(
          context,
          'mayday!',
          'avoid buildings the way she avoided you',
          Icons.flight,
          gameColors['plane']!,
          userScores['planePoints'] ?? 0,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RubyPlaneGame(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          ).then((_) => _loadUserData()),
          screenWidth,
        ),
        _buildGameCard(
          context,
          'letters of fury',
          'your assignments wish they were this fun',
          Icons.extension,
          gameColors['puzzle']!,
          userScores['puzzlePoints'] ?? 0,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LogicStackGame(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          ).then((_) => _loadUserData()),
          screenWidth,
        ),
   
      ],
    );
  }

  Widget _buildTotalScoreCard(double screenWidth, double screenHeight) {
    final cardPadding = screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 16.0 : (screenWidth < 768 ? 18.0 : (screenWidth < 1024 ? 20.0 : 24.0)));
    final borderRadius = screenWidth < 768 ? 16.0 : (screenWidth < 1024 ? 20.0 : 24.0);
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE91E63).withOpacity(0.3),
            const Color(0xFF8B2635).withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: isLoadingScores
          ? Container(
              height: screenWidth < 600 ? 100 : (screenWidth < 1024 ? 120 : 140),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: const Color(0xFFE91E63),
                  strokeWidth: screenWidth < 768 ? 2 : 3,
                ),
              ),
            )
          : _buildScoreCardContent(screenWidth),
    );
  }

  Widget _buildScoreCardContent(double screenWidth) {
    final iconSize = screenWidth < 360 ? 20.0 : (screenWidth < 600 ? 24.0 : (screenWidth < 768 ? 28.0 : (screenWidth < 1024 ? 32.0 : 36.0)));
    final iconPadding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 12.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
    final spacing = screenWidth < 600 ? 12.0 : (screenWidth < 1024 ? 16.0 : 20.0);
    
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(iconPadding),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE91E63).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.emoji_events,
                size: iconSize,
                color: Colors.white,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _buildUserInfo(screenWidth),
            ),
            _buildTotalScoreBadge(screenWidth),
          ],
        ),
        SizedBox(height: spacing),
        _buildScoreBadges(screenWidth),
      ],
    );
  }

  Widget _buildUserInfo(double screenWidth) {
    final titleFontSize = screenWidth < 360 ? 14.0 : (screenWidth < 600 ? 16.0 : (screenWidth < 768 ? 18.0 : (screenWidth < 1024 ? 20.0 : 22.0)));
    final subtitleFontSize = screenWidth < 360 ? 10.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 13.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
    final rankFontSize = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 11.0 : (screenWidth < 1024 ? 12.0 : 14.0)));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Your Total Score',
          style: GoogleFonts.poppins(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '@${widget.username}',
          style: GoogleFonts.poppins(
            fontSize: subtitleFontSize,
            color: Colors.white70,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (userRank != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth < 600 ? 6 : 8,
              vertical: screenWidth < 600 ? 2 : 4,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getRankColors(userRank!),
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Rank #$userRank',
              style: GoogleFonts.poppins(
                fontSize: rankFontSize,
                fontWeight: FontWeight.w600,
                color: userRank! <= 3 ? Colors.black87 : Colors.white,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTotalScoreBadge(double screenWidth) {
    final scoreFontSize = screenWidth < 360 ? 16.0 : (screenWidth < 600 ? 18.0 : (screenWidth < 768 ? 20.0 : (screenWidth < 1024 ? 22.0 : 24.0)));
    final padding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 12.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
  (userScores['totalPoints'] ?? 0).toString(),
  style: GoogleFonts.poppins(
    fontSize: scoreFontSize,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
    height: 1.0,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
    );
  }

  Widget _buildScoreBadges(double screenWidth) {
    final spacing = screenWidth < 600 ? 6.0 : (screenWidth < 1024 ? 8.0 : 10.0);
    
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: [
        _buildScoreBadge('LOTT', userScores['timerPoints'] ?? 0, gameColors['timer']!, screenWidth),
        _buildScoreBadge('Swipe&Merge', userScores['2048Points'] ?? 0, gameColors['2048']!, screenWidth),
        _buildScoreBadge('Mayday!', userScores['planePoints'] ?? 0, gameColors['plane']!, screenWidth),
        _buildScoreBadge('LOF', userScores['puzzlePoints'] ?? 0, gameColors['puzzle']!, screenWidth),
      ],
    );
  }

  List<Color> _getRankColors(int rank) {
    switch (rank) {
      case 1:
        return [const Color(0xFFFFD700), const Color(0xFFFFA000)]; // Gold
      case 2:
        return [const Color(0xFFC0C0C0), const Color(0xFF999999)]; // Silver
      case 3:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
      default:
        return [const Color(0xFF8B2635), const Color(0xFF4A1625)]; // Default
    }
  }

  Widget _buildScoreBadge(String game, int points, Color color, double screenWidth) {
    final fontSize = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 11.0 : (screenWidth < 1024 ? 12.0 : 14.0)));
    final pointsFontSize = screenWidth < 360 ? 10.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 13.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
    final padding = screenWidth < 360 ? 6.0 : (screenWidth < 600 ? 8.0 : (screenWidth < 768 ? 9.0 : (screenWidth < 1024 ? 10.0 : 12.0)));
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            game,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.2,
            ),
            maxLines: 1,
          ),
        Text(
  points.toString(),
  style: GoogleFonts.poppins(
    fontSize: pointsFontSize,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    height: 1.0,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, String title, String subtitle, 
      IconData icon, Color color, int userScore, VoidCallback onTap, double screenWidth) {
    
    final cardPadding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0)));
    final borderRadius = screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0);
    final iconSize = screenWidth < 360 ? 16.0 : (screenWidth < 600 ? 20.0 : (screenWidth < 768 ? 24.0 : (screenWidth < 1024 ? 28.0 : 32.0)));
    final iconPadding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 12.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
    final titleFontSize = screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 14.0 : (screenWidth < 768 ? 15.0 : (screenWidth < 1024 ? 16.0 : 18.0)));
    final subtitleFontSize = screenWidth < 360 ? 9.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 11.0 : (screenWidth < 1024 ? 12.0 : 14.0)));
    final scoreFontSize = screenWidth < 360 ? 10.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 13.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
    final starIconSize = screenWidth < 360 ? 10.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 13.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(cardPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Score badge at top
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: cardPadding * 0.6, 
                  vertical: cardPadding * 0.3
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: starIconSize,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                  Text(
  userScore.toString(),
  style: GoogleFonts.poppins(
    fontSize: scoreFontSize,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    height: 1.0,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
                  ],
                ),
              ),
              
              // Icon
              Container(
                padding: EdgeInsets.all(iconPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
              
              // Text content
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: subtitleFontSize,
                        color: Colors.white70,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaderboardView extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const LeaderboardView({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  Map<String, int> previousScores = {};
  List<String> userOrder = [];
  bool isLoading = true;
  StreamSubscription? mainSubscription;

  // Consistent game colors
  final Map<String, Color> gameColors = const {
    'timer': Color(0xFF8B2635),
    'puzzle': Color(0xFF8B2635),
    '2048': Color(0xFF8B2635),
    'plane': Color(0xFF8B2635),
  };

  @override
  void initState() {
    super.initState();
    _initializeLeaderboard();
  }

  @override
  void dispose() {
    mainSubscription?.cancel();
    super.dispose();
  }

  void _initializeLeaderboard() {
    mainSubscription = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('game_scores')
        .orderBy('totalPoints', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        setState(() {
          isLoading = false;
          userOrder = [];
        });
        return;
      }

      final newUserOrder = snapshot.docs.map((doc) => doc.data()['username'] as String? ?? '').toList();

      setState(() {
        userOrder = newUserOrder;
        isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFE91E63),
              strokeWidth: screenWidth < 768 ? 2 : 3,
            ),
          );
        }

        if (userOrder.isEmpty) {
          return _buildEmptyState();
        }

        final padding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 16.0 : (screenWidth < 1024 ? 20.0 : 24.0)));

        return ListView.builder(
          padding: EdgeInsets.all(padding),
          itemCount: userOrder.length,
          itemBuilder: (context, index) {
            final username = userOrder[index];
            
            return IsolatedLeaderboardItem(
              key: ValueKey(username), // Important for widget identity
              username: username,
              rank: index + 1,
              communityId: widget.communityId,
              currentUsername: widget.username,
              previousScores: previousScores,
              gameColors: gameColors,
              onScoreUpdate: (username, newScore) {
                previousScores[username] = newScore;
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final iconSize = screenWidth < 600 ? 40.0 : (screenWidth < 1024 ? 48.0 : 56.0);
        final titleFontSize = screenWidth < 600 ? 20.0 : (screenWidth < 1024 ? 24.0 : 28.0);
        final subtitleFontSize = screenWidth < 600 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0);
        final spacing = screenWidth < 600 ? 16.0 : (screenWidth < 1024 ? 20.0 : 24.0);
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(spacing),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.leaderboard,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: spacing),
              Text(
                'No Scores Yet',
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing * 0.5),
              Text(
                'Be the first to play and set a score!',
                style: GoogleFonts.poppins(
                  fontSize: subtitleFontSize,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  void _openUserProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          username: username,
          communityId: widget.communityId,
        ),
      ),
    );
  }
}

// COMPLETELY ISOLATED LEADERBOARD ITEM
class IsolatedLeaderboardItem extends StatefulWidget {
  final String username;
  final int rank;
  final String communityId;
  final String currentUsername;
  final Map<String, int> previousScores;
  final Map<String, Color> gameColors;
  final Function(String, int) onScoreUpdate;

  const IsolatedLeaderboardItem({
    Key? key,
    required this.username,
    required this.rank,
    required this.communityId,
    required this.currentUsername,
    required this.previousScores,
    required this.gameColors,
    required this.onScoreUpdate,
  }) : super(key: key);

  @override
  State<IsolatedLeaderboardItem> createState() => _IsolatedLeaderboardItemState();
}

class _IsolatedLeaderboardItemState extends State<IsolatedLeaderboardItem> {
  Map<String, dynamic>? scoreData;
  Map<String, dynamic>? userDetails;
  StreamSubscription? scoreSubscription;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    scoreSubscription?.cancel();
    super.dispose();
  }

  void _loadData() async {
    // Load user details (only once)
    userDetails = await _getUserDetails();
    
    // Start listening to score changes (this is isolated per user)
    scoreSubscription = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('game_scores')
        .doc(widget.username)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final newScoreData = doc.data() as Map<String, dynamic>;
        final newScore = newScoreData['totalPoints'] ?? 0;
        
        setState(() {
          scoreData = newScoreData;
          isLoading = false;
        });
        
        // Update parent's previousScores tracking
        widget.onScoreUpdate(widget.username, newScore);
      }
    });
  }

  Future<Map<String, dynamic>> _getUserDetails() async {
    try {
      // First check trio collection
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        final memberData = trioQuery.docs.first.data();
        
        // Get user details from users collection
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: widget.username)
            .limit(1)
            .get();
        
        if (userQuery.docs.isNotEmpty) {
          final userData = userQuery.docs.first.data();
          return {
            'firstName': userData['firstName'] ?? '',
            'lastName': userData['lastName'] ?? '',
            'profileImageUrl': userData['profileImageUrl'] ?? memberData['profileImageUrl'],
            'branch': memberData['branch'] ?? '',
            'year': memberData['year'] ?? '',
          };
        }
      } else {
        // Check members collection
        final membersQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .where('username', isEqualTo: widget.username)
            .limit(1)
            .get();
        
        if (membersQuery.docs.isNotEmpty) {
          final memberData = membersQuery.docs.first.data();
          
          // Get user details from users collection
          final userQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: widget.username)
              .limit(1)
              .get();
          
          if (userQuery.docs.isNotEmpty) {
            final userData = userQuery.docs.first.data();
            return {
              'firstName': userData['firstName'] ?? '',
              'lastName': userData['lastName'] ?? '',
              'profileImageUrl': userData['profileImageUrl'] ?? memberData['profileImageUrl'],
              'branch': memberData['branch'] ?? '',
              'year': memberData['year'] ?? '',
            };
          }
        }
      }
    } catch (e) {
      print('Error getting user details: $e');
    }
    
    return {
      'firstName': 'Unknown',
      'lastName': 'User',
      'profileImageUrl': null,
      'branch': '',
      'year': '',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || scoreData == null || userDetails == null) {
      return Container(
        height: 100,
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFE91E63),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        return _buildLeaderboardItem(screenWidth);
      },
    );
  }

  Widget _buildLeaderboardItem(double screenWidth) {
    final isCurrentUser = widget.username == widget.currentUsername;
    final fullName = '${userDetails!['firstName']} ${userDetails!['lastName']}'.trim();
    final currentPoints = scoreData!['totalPoints'] ?? 0;
    final prevPoints = widget.previousScores[widget.username];
    final hasScoreIncreased = prevPoints != null && currentPoints > prevPoints;

    // Responsive sizing
    final marginBottom = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0)));
    final borderRadius = screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0);
    final avatarSize = screenWidth < 360 ? 50.0 : (screenWidth < 600 ? 60.0 : (screenWidth < 768 ? 65.0 : (screenWidth < 1024 ? 70.0 : 80.0)));
    final rankFontSize = screenWidth < 360 ? 40.0 : (screenWidth < 600 ? 60.0 : (screenWidth < 768 ? 70.0 : (screenWidth < 1024 ? 80.0 : 100.0)));
    final leftPadding = screenWidth < 360 ? 25.0 : (screenWidth < 600 ? 35.0 : (screenWidth < 768 ? 45.0 : (screenWidth < 1024 ? 55.0 : 65.0)));
    final cardPadding = screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 16.0 : (screenWidth < 768 ? 18.0 : (screenWidth < 1024 ? 20.0 : 24.0)));
    final spacing = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0)));
    
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrentUser ? [
            const Color(0xFF8B2635).withOpacity(0.3),
            const Color(0xFF4A1625).withOpacity(0.2),
          ] : [
            const Color(0xFF4A1625).withOpacity(0.2),
            const Color(0xFF2D0F1A).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isCurrentUser 
              ? const Color(0xFF8B2635).withOpacity(0.5)
              : const Color(0xFF4A1625).withOpacity(0.3),
          width: isCurrentUser ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Netflix-style huge rank watermark
          Positioned(
            left: 5,
            top: screenWidth < 600 ? 45 : (screenWidth < 1024 ? 70 : 85),
            child: Text(
              widget.rank.toString(),
              style: GoogleFonts.poppins(
                fontSize: rankFontSize,
                fontWeight: FontWeight.w900,
                color: _getRankWatermarkColor(widget.rank),
                height: 1.0,
              ),
            ),
          ),
          
          // Main content
          Padding(
            padding: EdgeInsets.fromLTRB(
              leftPadding,
              cardPadding,
              cardPadding,
              cardPadding,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Profile Image
                    GestureDetector(
                      onTap: () => _openUserProfile(),
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _getRankBorderColor(widget.rank),
                            width: screenWidth < 768 ? 2 : 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: userDetails!['profileImageUrl'] != null
                              ? Image.network(
                                  userDetails!['profileImageUrl'],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildAvatarFallback(fullName, screenWidth),
                                )
                              : _buildAvatarFallback(fullName, screenWidth),
                        ),
                      ),
                    ),
                    
                    SizedBox(width: spacing),
                    
                    // User info
                    Expanded(
                      child: _buildUserInfo(fullName, isCurrentUser, screenWidth),
                    ),
                    
                    // Total Score with animation only when increased
                    _buildScoreBadge(currentPoints, hasScoreIncreased, screenWidth),
                  ],
                ),
                
                SizedBox(height: spacing),
                
                // Individual game scores
                _buildGameScores(screenWidth),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openUserProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          username: widget.username,
          communityId: widget.communityId,
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String fullName, double screenWidth) {
    final initials = fullName.isNotEmpty
        ? fullName.split(' ')
            .where((name) => name.isNotEmpty)
            .take(2)
            .map((name) => name[0].toUpperCase())
            .join()
        : 'U';
    
    final fontSize = screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 16.0 : (screenWidth < 768 ? 18.0 : (screenWidth < 1024 ? 20.0 : 22.0)));
    
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildUserInfo(String fullName, bool isCurrentUser, double screenWidth) {
    final nameFontSize = screenWidth < 360 ? 13.0 : (screenWidth < 600 ? 15.0 : (screenWidth < 768 ? 16.0 : (screenWidth < 1024 ? 17.0 : 19.0)));
    final usernameFontSize = screenWidth < 360 ? 11.0 : (screenWidth < 600 ? 13.0 : (screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 15.0 : 16.0)));
    final tagFontSize = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 11.0 : (screenWidth < 1024 ? 12.0 : 13.0)));
    final youBadgeFontSize = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 11.0 : (screenWidth < 1024 ? 12.0 : 13.0)));
    final tagSpacing = screenWidth < 600 ? 4.0 : 6.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openUserProfile(),
                child: Text(
                  fullName.isNotEmpty ? fullName : 'Unknown User',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: nameFontSize,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (isCurrentUser) ...[
              SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 600 ? 6 : 8, 
                  vertical: screenWidth < 600 ? 2 : 3
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'YOU',
                  style: GoogleFonts.poppins(
                    fontSize: youBadgeFontSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () => _openUserProfile(),
          child: Text(
            '@${widget.username}',
            style: GoogleFonts.poppins(
              fontSize: usernameFontSize,
              color: Colors.white60,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(height: screenWidth < 600 ? 6 : 8),
        // Branch and Year as styled tabs
        Wrap(
          spacing: tagSpacing,
          runSpacing: tagSpacing,
          children: [
            if (userDetails!['branch']?.isNotEmpty == true)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 600 ? 6 : 8, 
                  vertical: screenWidth < 600 ? 2 : 3
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B2635).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF8B2635).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  userDetails!['branch'],
                  style: GoogleFonts.poppins(
                    fontSize: tagFontSize,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFE91E63),
                    height: 1.0,
                  ),
                  maxLines: 1,
                ),
              ),
            if (userDetails!['year']?.isNotEmpty == true)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth < 600 ? 6 : 8, 
                  vertical: screenWidth < 600 ? 2 : 3
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A1625).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF4A1625).withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  userDetails!['year'],
                  style: GoogleFonts.poppins(
                    fontSize: tagFontSize,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                    height: 1.0,
                  ),
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ],
    );
  }

 Widget _buildScoreBadge(int currentPoints, bool hasScoreIncreased, double screenWidth) {
  final scoreFontSize = screenWidth < 360 ? 14.0 : (screenWidth < 600 ? 16.0 : (screenWidth < 768 ? 18.0 : (screenWidth < 1024 ? 20.0 : 22.0)));
  final padding = screenWidth < 360 ? 10.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0)));
  
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    padding: EdgeInsets.symmetric(
      horizontal: padding,
      vertical: padding * 0.7,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _getRankScoreColors(widget.rank),
      ),
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: _getRankScoreColors(widget.rank)[0].withOpacity(0.4),
          blurRadius: hasScoreIncreased ? 15 : 4,
          offset: const Offset(0, 2),
          spreadRadius: hasScoreIncreased ? 3 : 0,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Always use casino widget, but it will only animate when value changes
        CasinoCounterWidget(
          key: ValueKey('score_${widget.username}'), // Unique key per user
          value: currentPoints,
          duration: const Duration(milliseconds: 2500),
          textStyle: GoogleFonts.poppins(
            fontSize: scoreFontSize,
            fontWeight: FontWeight.bold,
            color: widget.rank <= 3 ? Colors.black87 : Colors.white,
            height: 1.0,
          ),
        ),
        // Add sparkle effect when score increases
        if (hasScoreIncreased) ...[
          SizedBox(width: 6),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            tween: Tween(begin: 0.0, end: 4 * 3.14159),
            builder: (context, value, child) {
              return Transform.rotate(
                angle: value,
                child: Icon(
                  Icons.auto_awesome,
                  size: scoreFontSize * 0.6,
                  color: Colors.amber,
                ),
              );
            },
          ),
        ],
      ],
    ),
  );
}

  Widget _buildGameScores(double screenWidth) {
    final spacing = screenWidth < 600 ? 6.0 : (screenWidth < 1024 ? 8.0 : 10.0);
    
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: [
        _buildMiniScoreBadge('Timer', scoreData!['timerPoints'] ?? 0, widget.gameColors['timer']!, screenWidth),
        _buildMiniScoreBadge('Puzzle', scoreData!['puzzlePoints'] ?? 0, widget.gameColors['puzzle']!, screenWidth),
        _buildMiniScoreBadge('2048', scoreData!['2048Points'] ?? 0, widget.gameColors['2048']!, screenWidth),
        _buildMiniScoreBadge('Bird', scoreData!['planePoints'] ?? 0, widget.gameColors['plane']!, screenWidth),
      ],
    );
  }

  Color _getRankWatermarkColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700).withOpacity(0.15); // Gold
      case 2:
        return const Color(0xFFC0C0C0).withOpacity(0.15); // Silver
      case 3:
        return const Color(0xFFCD7F32).withOpacity(0.15); // Bronze
      default:
        return Colors.white.withOpacity(0.05); // Very subtle for others
    }
  }

  Color _getRankBorderColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFFE91E63); // Default pink
    }
  }

  List<Color> _getRankScoreColors(int rank) {
    switch (rank) {
      case 1:
        return [const Color(0xFFFFD700), const Color(0xFFFFA000)]; // Gold
      case 2:
        return [const Color(0xFFC0C0C0), const Color(0xFF999999)]; // Silver
      case 3:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
      default:
        return [const Color(0xFF8B2635), const Color(0xFF4A1625)]; // Default
    }
  }

Widget _buildMiniScoreBadge(String label, int points, Color color, double screenWidth) {
  final labelFontSize = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 11.0 : (screenWidth < 1024 ? 12.0 : 13.0)));
  final pointsFontSize = screenWidth < 360 ? 12.0 : (screenWidth < 600 ? 14.0 : (screenWidth < 768 ? 15.0 : (screenWidth < 1024 ? 16.0 : 17.0)));
  final padding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 10.0 : (screenWidth < 768 ? 12.0 : (screenWidth < 1024 ? 14.0 : 16.0)));
  
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: padding,
      vertical: padding * 0.6,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.5), width: 1),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.1,
          ),
          maxLines: 1,
        ),
        const SizedBox(height: 1),
        // Keep it simple for mini badges - just use regular text
        Text(
          points.toString(),
          style: GoogleFonts.poppins(
            fontSize: pointsFontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.0,
          ),
          maxLines: 1,
        ),
      ],
    ),
  );
}
}

class CasinoCounterWidget extends StatefulWidget {
  final int value;
  final Duration duration;
  final TextStyle? textStyle;

  const CasinoCounterWidget({
    Key? key,
    required this.value,
    this.duration = const Duration(milliseconds: 1500),
    this.textStyle,
  }) : super(key: key);

  @override
  State<CasinoCounterWidget> createState() => _CasinoCounterWidgetState();
}

class _CasinoCounterWidgetState extends State<CasinoCounterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousValue = 0;
  int _currentValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _currentValue = widget.value;
    
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(CasinoCounterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      setState(() {
        _previousValue = _currentValue;
        _currentValue = widget.value;
      });
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Simple interpolation between previous and current value
        final displayValue = (_previousValue + (_animation.value * (_currentValue - _previousValue))).round();
        
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween(begin: 1.0, end: _controller.isAnimating ? 1.1 : 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Text(
                displayValue.toString(),
                style: widget.textStyle,
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            );
          },
        );
      },
    );
  }
}

