import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class PastLeaderboardsScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const PastLeaderboardsScreen({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<PastLeaderboardsScreen> createState() => _PastLeaderboardsScreenState();
}

class _PastLeaderboardsScreenState extends State<PastLeaderboardsScreen> {
  List<String> weekIds = [];
  String? selectedWeekId;
  bool isLoadingWeeks = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableWeeks();
  }

 Future<void> _loadAvailableWeeks() async {
  try {
    debugPrint('Loading available leaderboards for community: ${widget.communityId}');
    
    final archivesSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('leaderboard_archives') // Changed from weekly_archives
        .orderBy('archivedAt', descending: true)
        .get();

    debugPrint('Found ${archivesSnapshot.docs.length} archive documents');

    if (mounted) {
      setState(() {
        weekIds = archivesSnapshot.docs
            .map((doc) => doc.id)
            .toList();
        selectedWeekId = weekIds.isNotEmpty ? weekIds.first : null;
        isLoadingWeeks = false;
      });
      
      debugPrint('Available leaderboard IDs: $weekIds');
      debugPrint('Selected leaderboard ID: $selectedWeekId');
    }
  } catch (e) {
    debugPrint('Error loading leaderboards: $e');
    if (mounted) {
      setState(() {
        isLoadingWeeks = false;
      });
    }
  }

  }

  Future<List<String>> _getFormattedLeaderboardNames() async {
  final List<String> formattedNames = [];
  
  for (String id in weekIds) {
    final formatted = await _formatLeaderboardId(id);
    formattedNames.add(formatted);
  }
  
  return formattedNames;
}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        
        if (isLoadingWeeks) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFFE91E63),
              strokeWidth: screenWidth < 768 ? 2 : 3,
            ),
          );
        }

        if (weekIds.isEmpty) {
          return _buildEmptyState();
        }

        final padding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 16.0 : (screenWidth < 1024 ? 20.0 : 24.0)));

        return Column(
          children: [
            // Week selector
            Container(
              margin: EdgeInsets.all(padding),
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: padding * 0.6,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF4A1625).withOpacity(0.3),
                    const Color(0xFF2D0F1A).withOpacity(0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF8B2635).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: const Color(0xFFE91E63),
                    size: screenWidth < 600 ? 20 : 24,
                  ),
                  SizedBox(width: padding * 0.5),
                  Expanded(
                  child: FutureBuilder<List<String>>(
  future: _getFormattedLeaderboardNames(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return Text(
        'Loading...',
        style: GoogleFonts.poppins(color: Colors.white70),
      );
    }
    
    return DropdownButton<String>(
      value: selectedWeekId,
      isExpanded: true,
      underline: Container(),
      dropdownColor: const Color(0xFF2D0F1A),
      icon: const Icon(
        Icons.keyboard_arrow_down,
        color: Colors.white70,
      ),
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: screenWidth < 600 ? 14 : 16,
        fontWeight: FontWeight.w500,
      ),
      items: weekIds.asMap().entries.map((entry) {
        final index = entry.key;
        final weekId = entry.value;
        final displayName = snapshot.data![index];
        
        return DropdownMenuItem<String>(
          value: weekId,
          child: Text(displayName),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          selectedWeekId = newValue;
        });
      },
    );
  },
),
                  ),
                ],
              ),
            ),
            
            // Leaderboard for selected week
            Expanded(
              child: selectedWeekId != null
                  ? PastWeekLeaderboard(
                      communityId: widget.communityId,
                      weekId: selectedWeekId!,
                      currentUsername: widget.username,
                    )
                  : Container(),
            ),
          ],
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
                  Icons.history,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: spacing),
              Text(
                'No Archives Yet',
                style: GoogleFonts.poppins(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing * 0.5),
              Text(
                'Past weekly leaderboards will appear here after the first reset!',
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

Future<String> _formatLeaderboardId(String leaderboardId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('leaderboard_archives')
        .doc(leaderboardId)
        .get();
    
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final name = data['name'] as String?;
      final archivedAt = data['archivedAt'] as Timestamp?; // Changed from createdAt
      
      if (name != null) {
        if (archivedAt != null) {
          final date = archivedAt.toDate();
          return '$name (${date.day}/${date.month}/${date.year})';
        }
        return name;
      }
    }
  } catch (e) {
    debugPrint('Error formatting leaderboard name: $e');
  }
  
  return leaderboardId;
}
}

class PastWeekLeaderboard extends StatelessWidget {
  final String communityId;
  final String weekId;
  final String currentUsername;

  const PastWeekLeaderboard({
    Key? key,
    required this.communityId,
    required this.weekId,
    required this.currentUsername,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    debugPrint('Building PastWeekLeaderboard for week: $weekId in community: $communityId');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('leaderboard_archives')
          .doc(weekId)
          .collection('game_scores')
          .orderBy('totalPoints', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint('StreamBuilder state: ${snapshot.connectionState}');
        debugPrint('Has data: ${snapshot.hasData}');
        debugPrint('Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugPrint('Error: ${snapshot.error}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE91E63))
          );
        }

        if (snapshot.hasError) {
          debugPrint('Firebase error: ${snapshot.error}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading data',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          debugPrint('No data found for week: $weekId');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sentiment_dissatisfied,
                  size: 48,
                  color: Colors.white38,
                ),
                const SizedBox(height: 16),
                Text(
                  'No archived data for this week',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Week: ${_formatWeekId(weekId)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        debugPrint('Found ${docs.length} archived scores for week: $weekId');

        final screenWidth = MediaQuery.of(context).size.width;
        final padding = screenWidth < 360 ? 8.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 16.0 : (screenWidth < 1024 ? 20.0 : 24.0)));

        return ListView.builder(
          padding: EdgeInsets.all(padding),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            debugPrint('User: ${doc.id}, Points: ${data['totalPoints']}, Rank: ${data['rank']}');
            
            return PastLeaderboardItem(
              key: ValueKey('${weekId}_${doc.id}'),
              username: doc.id,
              rank: data['rank'] ?? (index + 1), // Use stored rank or fallback to index
              scoreData: data,
              isCurrentUser: doc.id == currentUsername,
              communityId: communityId,
            );
          },
        );
      },
    );
  }

  String _formatWeekId(String weekId) {
    final parts = weekId.split('-W');
    if (parts.length == 2) {
      return 'Week ${parts[1]}, ${parts[0]}';
    }
    return weekId;
  }
}

class PastLeaderboardItem extends StatefulWidget {
  final String username;
  final int rank;
  final Map<String, dynamic> scoreData;
  final bool isCurrentUser;
  final String communityId;

  const PastLeaderboardItem({
    Key? key,
    required this.username,
    required this.rank,
    required this.scoreData,
    required this.isCurrentUser,
    required this.communityId,
  }) : super(key: key);

  @override
  State<PastLeaderboardItem> createState() => _PastLeaderboardItemState();
}

class _PastLeaderboardItemState extends State<PastLeaderboardItem> {
  Map<String, dynamic>? userDetails;
  bool isLoading = true;

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
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    userDetails = await _getUserDetails();
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
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
      debugPrint('Error getting user details: $e');
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
    if (isLoading || userDetails == null) {
      return Container(
        height: 100,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
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
    final fullName = '${userDetails!['firstName']} ${userDetails!['lastName']}'.trim();
    final currentPoints = widget.scoreData['totalPoints'] ?? 0;

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
          colors: widget.isCurrentUser ? [
            const Color(0xFF8B2635).withOpacity(0.3),
            const Color(0xFF4A1625).withOpacity(0.2),
          ] : [
            const Color(0xFF4A1625).withOpacity(0.2),
            const Color(0xFF2D0F1A).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: widget.isCurrentUser 
              ? const Color(0xFF8B2635).withOpacity(0.5)
              : const Color(0xFF4A1625).withOpacity(0.3),
          width: widget.isCurrentUser ? 2 : 1,
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
                      child: _buildUserInfo(fullName, screenWidth),
                    ),
                    
                    // Total Score
                    _buildScoreBadge(currentPoints, screenWidth),
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

  Widget _buildUserInfo(String fullName, double screenWidth) {
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
            if (widget.isCurrentUser) ...[
              const SizedBox(width: 6),
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

  Widget _buildScoreBadge(int currentPoints, double screenWidth) {
    final scoreFontSize = screenWidth < 360 ? 14.0 : (screenWidth < 600 ? 16.0 : (screenWidth < 768 ? 18.0 : (screenWidth < 1024 ? 20.0 : 22.0)));
    final padding = screenWidth < 360 ? 10.0 : (screenWidth < 600 ? 12.0 : (screenWidth < 768 ? 14.0 : (screenWidth < 1024 ? 16.0 : 18.0)));
    
    return Container(
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
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        currentPoints.toString(),
        style: GoogleFonts.poppins(
          fontSize: scoreFontSize,
          fontWeight: FontWeight.bold,
          color: widget.rank <= 3 ? Colors.black87 : Colors.white,
          height: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
        _buildMiniScoreBadge('Timer', widget.scoreData['timerPoints'] ?? 0, gameColors['timer']!, screenWidth),
        _buildMiniScoreBadge('Puzzle', widget.scoreData['puzzlePoints'] ?? 0, gameColors['puzzle']!, screenWidth),
        _buildMiniScoreBadge('2048', widget.scoreData['2048Points'] ?? 0, gameColors['2048']!, screenWidth),
        _buildMiniScoreBadge('Bird', widget.scoreData['planePoints'] ?? 0, gameColors['plane']!, screenWidth),
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
}