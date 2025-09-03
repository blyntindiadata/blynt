import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/create_poll.dart';
import 'package:startup/home_components/poll_votes.dart';
import 'dart:math' as math;

import 'package:startup/home_components/user_profile_screen.dart';

class PollsPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const PollsPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  }) : super(key: key);

  @override
  State<PollsPage> createState() => _PollsPageState();
}

class _PollsPageState extends State<PollsPage> with TickerProviderStateMixin {
  final ValueNotifier<List<Map<String, dynamic>>> _adminPollsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> _userPollsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isSearching = false;
  String _searchQuery = '';
  final Map<String, Map<String, dynamic>?> _userCache = {};
  late Stream<QuerySnapshot> _pollsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAnimations();
    _loadCurrentUserData();
    _initRealTimeListener();
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

  void _initRealTimeListener() {
    _pollsStream = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .snapshots();
    
    _pollsStream.listen((snapshot) {
      if (mounted) {
        _processPollsFromSnapshot(snapshot);
      }
    });
  }

  void _processPollsFromSnapshot(QuerySnapshot snapshot) {
    final adminPolls = <Map<String, dynamic>>[];
    final userPolls = <Map<String, dynamic>>[];

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final pollData = {
        'id': doc.id,
        ...data,
      };

      // Check if user can see this poll
      if (!_canUserSeePoll(pollData)) {
        continue;
      }

      // Separate polls based on creator role
      final creatorRole = data['creatorRole'] ?? 'member';
      if (['admin', 'manager', 'moderator'].contains(creatorRole)) {
        adminPolls.add(pollData);
      } else {
        userPolls.add(pollData);
      }
    }

    _adminPollsNotifier.value = adminPolls;
    _userPollsNotifier.value = userPolls;
    _isLoadingNotifier.value = false;
  }

  @override
  void dispose() {
    _adminPollsNotifier.dispose();
    _userPollsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _searchController.dispose();
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    await _getUserData(widget.username);
  }

  bool _canUserSeePoll(Map<String, dynamic> poll) {
    final visibility = poll['visibility'] as Map<String, dynamic>?;
    if (visibility == null) return true; // Default to visible
    
    // Admins can always see their own polls regardless of visibility settings
    final creatorUsername = poll['creatorUsername'] as String?;
    final isCurrentUsersPoll = creatorUsername == widget.username;
    final isPrivilegedUser = ['admin', 'manager', 'moderator'].contains(widget.userRole);
    
    if (isCurrentUsersPoll && isPrivilegedUser) {
      return true;
    }
    
    final visibilityType = visibility['type'] as String?;
    if (visibilityType == 'everyone') return true;
    
    final allowedYears = List<String>.from(visibility['allowedYears'] ?? []);
    final allowedBranches = List<String>.from(visibility['allowedBranches'] ?? []);
    
    final currentUserData = _userCache[widget.username];
    final userYear = currentUserData?['year']?.toString();
    final userBranch = currentUserData?['branch']?.toString();
    
    switch (visibilityType) {
      case 'year':
        return allowedYears.isEmpty || allowedYears.contains(userYear);
      case 'branch':
        return allowedBranches.isEmpty || allowedBranches.contains(userBranch);
      case 'branch_year':
        return (allowedYears.isEmpty || allowedYears.contains(userYear)) && 
               (allowedBranches.isEmpty || allowedBranches.contains(userBranch));
      case 'custom':
        final yearMatch = allowedYears.isEmpty || allowedYears.contains(userYear);
        final branchMatch = allowedBranches.isEmpty || allowedBranches.contains(userBranch);
        return yearMatch && branchMatch;
      default:
        return true;
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String username) async {
    // Check cache first
    if (_userCache.containsKey(username)) {
      return _userCache[username];
    }

    try {
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (trioQuery.docs.isNotEmpty) {
        final userData = trioQuery.docs.first.data();
        _userCache[username] = userData;
        return userData;
      }

      // Check members collection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (membersQuery.docs.isNotEmpty) {
        final userData = membersQuery.docs.first.data();
        _userCache[username] = userData;
        return userData;
      }

      // Cache null result
      _userCache[username] = null;
      return null;
    } catch (e) {
      print('Error fetching user data for $username: $e');
      _userCache[username] = null;
      return null;
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1B263B),
              const Color(0xFF0D1B2A),
              const Color(0xFF041426),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(screenWidth, isTablet),
              _buildTabBar(screenWidth, isTablet),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildTabBarView(screenWidth, isTablet),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildCreateFAB(screenWidth, isTablet),
    );
  }

  Widget _buildHeader(double screenWidth, bool isTablet) {
  final isCompact = screenWidth < 350;

  return Container(
    padding: EdgeInsets.fromLTRB(
      isTablet ? 24 : (isCompact ? 16 : 20),
      isTablet ? 24 : (isCompact ? 16 : 20),
      isTablet ? 24 : (isCompact ? 16 : 20),
      isTablet ? 20 : (isCompact ? 12 : 16),
    ),
    // decoration: BoxDecoration(
    //   gradient: LinearGradient(
    //     begin: Alignment.topLeft,
    //     end: Alignment.bottomRight,
    //     colors: [
    //       const Color(0xFF1B263B).withOpacity(0.3),
    //       Colors.transparent,
    //     ],
    //   ),
    // ),
    child: Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(isTablet ? 10 : (isCompact ? 8 : 8)),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                  border: Border.all(
                    color: const Color(0xFF64B5F6).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: isTablet ? 22 : (isCompact ? 18 : 18),
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 15),
              padding: EdgeInsets.all(isTablet ? 16 : (isCompact ? 10 : 12)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF1B263B), const Color(0xFF0D1B2A)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B263B).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.poll,
                color: Colors.white,
                size: isTablet ? 28 : (isCompact ? 20 : 24),
              ),
            ),
            SizedBox(width: isTablet ? 20 : (isCompact ? 12 : 16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
                    ).createShader(bounds),
                    child: Text(
                      'the polls',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: isTablet ? 28 : (isCompact ? 18 : 22),
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    'mass bun- well well well',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : (isCompact ? 10 : 12),
                      color: const Color(0xFF64B5F6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: const Color(0xFF64B5F6),
                size: isTablet ? 28 : (isCompact ? 20 : 24),
              ),
              onPressed: () {
                // Refresh is handled by real-time stream
              },
            ),
          ],
        ),
        SizedBox(height: isTablet ? 20 : (isCompact ? 12 : 16)),
        _buildSearchBar(screenWidth, isTablet),
      ],
    ),
  );
}
  Widget _buildSearchBar(double screenWidth, bool isTablet) {
    final isCompact = screenWidth < 350;

    return Container(
      height: isTablet ? 50 : (isCompact ? 40 : 45),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF1B263B).withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
        ),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'Search polls...',
          hintStyle: GoogleFonts.poppins(color: Colors.white38),
          prefixIcon: Icon(
            Icons.search,
            color: const Color(0xFF64B5F6),
            size: isTablet ? 24 : (isCompact ? 18 : 20),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : (isCompact ? 16 : 20),
            vertical: isTablet ? 12 : (isCompact ? 8 : 10),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
            _isSearching = value.isNotEmpty;
          });
        },
      ),
    );
  }

  Widget _buildTabBar(double screenWidth, bool isTablet) {
    final isCompact = screenWidth < 350;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : (isCompact ? 16 : 20),
        vertical: isTablet ? 12 : (isCompact ? 8 : 10),
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF1B263B).withOpacity(0.3)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Admin'),
          Tab(text: 'Users'),
        ],
      ),
    );
  }

  Widget _buildTabBarView(double screenWidth, bool isTablet) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildPollsList(_adminPollsNotifier, screenWidth, isTablet),
        _buildPollsList(_userPollsNotifier, screenWidth, isTablet),
      ],
    );
  }

  Widget _buildPollsList(ValueNotifier<List<Map<String, dynamic>>> pollsNotifier, double screenWidth, bool isTablet) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF64B5F6),
              strokeWidth: isTablet ? 4 : 3,
            ),
          );
        }

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: pollsNotifier,
          builder: (context, polls, child) {
            var visiblePolls = polls;

            if (_isSearching) {
              visiblePolls = polls.where((poll) {
                final question = (poll['question'] ?? '').toString().toLowerCase();
                final username = (poll['creatorUsername'] ?? '').toString().toLowerCase();
                
                return question.contains(_searchQuery) ||
                       username.contains(_searchQuery);
              }).toList();
            }

            if (visiblePolls.isEmpty) {
              return _buildEmptyState(screenWidth, isTablet);
            }

          return LayoutBuilder(
  builder: (context, constraints) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isCompact = screenWidth < 350;
    final padding = isLandscape 
        ? (isTablet ? 12.0 : (isCompact ? 8.0 : 10.0))
        : (isTablet ? 20.0 : (isCompact ? 12.0 : 16.0));
        
    return ListView.builder(
      padding: EdgeInsets.all(padding),
      itemCount: visiblePolls.length,
      itemBuilder: (context, index) {
        final poll = visiblePolls[index];
        return PollCard(
          poll: poll,
          currentUsername: widget.username,
          currentUserRole: widget.userRole,
          getUserData: _getUserData,
          communityId: widget.communityId,
          screenWidth: screenWidth,
          isTablet: isTablet,
          onViewVotes: (pollId) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PollVotesPage(
                  poll: poll,
                  communityId: widget.communityId,
                  getUserData: _getUserData,
                ),
              ),
            );
          },
        );
      },
    );
  },
);
          },
        );
      },
    );
  }

 Widget _buildEmptyState(double screenWidth, bool isTablet) {
  final isCompact = screenWidth < 350;

  return LayoutBuilder(
    builder: (context, constraints) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      final availableHeight = constraints.maxHeight;
      
      // Adaptive sizing for landscape mode
      final iconSize = isLandscape 
          ? (isTablet ? 48.0 : (isCompact ? 32.0 : 40.0))
          : (isTablet ? 72.0 : (isCompact ? 48.0 : 64.0));
      final spacing = isLandscape 
          ? (isTablet ? 12.0 : (isCompact ? 8.0 : 10.0))
          : (isTablet ? 20.0 : (isCompact ? 12.0 : 16.0));
      final titleSize = isLandscape 
          ? (isTablet ? 16.0 : (isCompact ? 14.0 : 15.0))
          : (isTablet ? 20.0 : (isCompact ? 16.0 : 18.0));
      final subtitleSize = isLandscape 
          ? (isTablet ? 14.0 : (isCompact ? 10.0 : 12.0))
          : (isTablet ? 16.0 : (isCompact ? 12.0 : 14.0));
      
      return Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: availableHeight > 200 ? 150 : availableHeight * 0.8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.poll_outlined,
                  color: const Color(0xFF64B5F6),
                  size: iconSize,
                ),
                SizedBox(height: spacing),
                Text(
                  'No polls available',
                  style: GoogleFonts.poppins(
                    fontSize: titleSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: spacing / 2),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24),
                  child: Text(
                    'Be the first to create a poll!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: subtitleSize,
                      color: Colors.white60,
                    ),
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

  Widget _buildCreateFAB(double screenWidth, bool isTablet) {
    final isCompact = screenWidth < 350;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1976D2).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePollPage(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
                userRole: widget.userRole,
              ),
            ),
          );
          // No need to manually refresh - real-time stream handles updates
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Text(
          'create poll',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: Icon(
          Icons.add,
          color: Colors.white,
          size: isTablet ? 24 : (isCompact ? 18 : 20),
        ),
      ),
    );
  }
}

class PollCard extends StatefulWidget {
  final Map<String, dynamic> poll;
  final String currentUsername;
  final String currentUserRole;
  final Future<Map<String, dynamic>?> Function(String) getUserData;
  final String communityId;
  final double screenWidth;
  final bool isTablet;
  final Function(String) onViewVotes;

  const PollCard({
    Key? key,
    required this.poll,
    required this.currentUsername,
    required this.currentUserRole,
    required this.getUserData,
    required this.communityId,
    required this.screenWidth,
    required this.isTablet,
    required this.onViewVotes,
  }) : super(key: key);

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _hoverAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  bool get _hasVoted {
    final votes = widget.poll['votes'] as Map<String, dynamic>? ?? {};
    for (var voters in votes.values) {
      if (voters is List && voters.contains(widget.currentUsername)) {
        return true;
      }
    }
    return false;
  }

  int? get _userVotedOption {
    final votes = widget.poll['votes'] as Map<String, dynamic>? ?? {};
    for (String optionKey in votes.keys) {
      if (votes[optionKey] is List && 
          (votes[optionKey] as List).contains(widget.currentUsername)) {
        return int.tryParse(optionKey.split('_').last);
      }
    }
    return null;
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

  bool get _canChangeVote {
    final voteTimestamps = widget.poll['voteTimestamps'] as Map<String, dynamic>? ?? {};
    final userTimestamp = voteTimestamps[widget.currentUsername] as Timestamp?;
    
    if (userTimestamp == null) return true;
    
    final votedAt = userTimestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(votedAt);
    
    return difference.inHours < 24;
  }

  // Check if there are duplicate options
  bool _hasDuplicateOptions(List<String> options) {
    final optionCounts = <String, int>{};
    for (String option in options) {
      optionCounts[option] = (optionCounts[option] ?? 0) + 1;
    }
    return optionCounts.values.any((count) => count > 1);
  }

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(widget.poll['options'] ?? []);
    final optionCounts = List<int>.from(widget.poll['optionCounts'] ?? []);
    final totalVotes = widget.poll['totalVotes'] ?? 0;
    final createdAt = widget.poll['createdAt'] as Timestamp?;
    final isCompact = widget.screenWidth < 350;
    final hasDuplicates = _hasDuplicateOptions(options);

    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _hoverAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _hoverAnimation.value,
            child: Container(
              margin: EdgeInsets.only(
                bottom: widget.isTablet ? 20 : (isCompact ? 12 : 16),
              ),
              padding: EdgeInsets.all(widget.isTablet ? 24 : (isCompact ? 16 : 20)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1B263B).withOpacity(0.2),
                    const Color(0xFF0D1B2A).withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(widget.isTablet ? 20 : 16),
                border: Border.all(
                  color: _isHovered 
                      ? const Color(0xFF64B5F6).withOpacity(0.3)
                      : const Color(0xFF1B263B).withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: widget.isTablet ? 12 : (isCompact ? 6 : 8),
                    offset: const Offset(0, 4),
                  ),
                  if (_isHovered)
                    BoxShadow(
                      color: const Color(0xFF64B5F6).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with user info
                  FutureBuilder<Map<String, dynamic>?>(
                    future: widget.getUserData(widget.poll['creatorUsername'] ?? ''),
                    builder: (context, snapshot) {
                      final userData = snapshot.data;
                      final firstName = userData?['firstName'] ?? '';
                      final lastName = userData?['lastName'] ?? '';
                      final branch = userData?['branch'] ?? '';
                      final year = userData?['year'] ?? '';
                      final profileImageUrl = userData?['profileImageUrl'];

                      return _buildUserHeader(firstName, lastName, branch, year, profileImageUrl, isCompact);
                    },
                  ),

                  SizedBox(height: widget.isTablet ? 20 : (isCompact ? 12 : 16)),

                  // Question
                  Text(
                    widget.poll['question'] ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: widget.isTablet ? 18 : (isCompact ? 14 : 16),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),

                  SizedBox(height: widget.isTablet ? 20 : (isCompact ? 12 : 16)),

                  // Options with improved duplicate handling
                  ...options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final count = index < optionCounts.length ? optionCounts[index] : 0;
                    final percentage = totalVotes > 0 ? (count / totalVotes * 100) : 0.0;
                    final isSelected = _userVotedOption == index;

                    return _buildOptionTile(context, index, option, count, percentage, isSelected, isCompact, hasDuplicates);
                  }).toList(),

                  SizedBox(height: widget.isTablet ? 20 : (isCompact ? 12 : 16)),

                  // Footer
                  _buildFooter(totalVotes, createdAt, isCompact),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserHeader(String firstName, String lastName, String branch, String year, String? profileImageUrl, bool isCompact) {
    return Column(
      children: [
        Row(
          children: [
          GestureDetector(
  onTap: () => _openUserProfile(widget.poll['creatorUsername'] ?? ''),
  child: CircleAvatar(
    radius: widget.isTablet ? 24 : (isCompact ? 16 : 20),
    backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
        ? NetworkImage(profileImageUrl)
        : null,
    backgroundColor: const Color(0xFF1976D2),
    child: profileImageUrl == null || profileImageUrl.isEmpty
        ? Text(
            (widget.poll['creatorUsername'] ?? 'U').substring(0, 1).toUpperCase(),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontSize: widget.isTablet ? 16 : (isCompact ? 12 : 14),
            ),
          )
        : null,
  ),
),
            SizedBox(width: widget.isTablet ? 16 : (isCompact ? 8 : 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
  children: [
    Flexible(
      child: GestureDetector(
        onTap: () => _openUserProfile(widget.poll['creatorUsername'] ?? ''),
        child: Text(
          '$firstName $lastName'.trim().isNotEmpty 
              ? '$firstName $lastName'.trim()
              : '@${widget.poll['creatorUsername'] ?? 'Unknown'}',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: widget.isTablet ? 18 : (isCompact ? 14 : 16),
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
                      if (widget.poll['creatorRole'] != 'member') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isTablet ? 8 : (isCompact ? 4 : 6),
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: widget.poll['creatorRole'] == 'admin'
                                  ? [Colors.amber, Colors.orange]
                                  : [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            (widget.poll['creatorRole'] ?? 'member').toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: widget.isTablet ? 10 : (isCompact ? 7 : 8),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                 if (firstName.isNotEmpty && lastName.isNotEmpty)
  GestureDetector(
    onTap: () => _openUserProfile(widget.poll['creatorUsername'] ?? ''),
    child: Text(
      '@${widget.poll['creatorUsername'] ?? 'Unknown'}',
      style: GoogleFonts.poppins(
        color: Colors.white60,
        fontSize: widget.isTablet ? 14 : (isCompact ? 10 : 12),
      ),
    ),
  ),
                ],
              ),
            ),
          ],
        ),
        if (branch.isNotEmpty || year.isNotEmpty) ...[
          SizedBox(height: widget.isTablet ? 12 : (isCompact ? 6 : 8)),
          Row(
            children: [
              SizedBox(width: widget.isTablet ? 56 : (isCompact ? 40 : 44)), // Avatar width + spacing
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (branch.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isTablet ? 8 : 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          branch,
                          style: GoogleFonts.poppins(
                            fontSize: widget.isTablet ? 11 : (isCompact ? 8 : 9),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (year.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isTablet ? 8 : 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          year,
                          style: GoogleFonts.poppins(
                            fontSize: widget.isTablet ? 11 : (isCompact ? 8 : 9),
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildOptionTile(BuildContext context, int index, String option, int count, double percentage, bool isSelected, bool isCompact, bool hasDuplicates) {
    return Container(
      margin: EdgeInsets.only(bottom: widget.isTablet ? 12 : 8),
      child: InkWell(
        onTap: () async {
          // Handle voting with proper error handling and smooth animations
          try {
            final pollRef = FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('polls')
                .doc(widget.poll['id']);

            await FirebaseFirestore.instance.runTransaction((transaction) async {
              final pollDoc = await transaction.get(pollRef);
              
              if (!pollDoc.exists) {
                throw Exception('Poll not found');
              }

              final pollData = pollDoc.data()!;
              final votes = Map<String, dynamic>.from(pollData['votes'] ?? {});
              final optionCounts = List<int>.from(pollData['optionCounts'] ?? []);
              final voteTimestamps = Map<String, dynamic>.from(pollData['voteTimestamps'] ?? {});
              
              // Ensure optionCounts has enough elements
              while (optionCounts.length <= index) {
                optionCounts.add(0);
              }
              
              // Remove previous vote if exists - always use index-based keys
              String? previousOption;
              for (int i = 0; i < optionCounts.length; i++) {
                final optionKey = 'option_$i';
                final votersList = votes[optionKey];
                if (votersList is List) {
                  final voters = List<String>.from(votersList);
                  if (voters.contains(widget.currentUsername)) {
                    previousOption = optionKey;
                    voters.remove(widget.currentUsername);
                    votes[optionKey] = voters;
                    optionCounts[i] = math.max(0, optionCounts[i] - 1);
                    break;
                  }
                }
              }

              final currentOptionKey = 'option_$index';
              if (previousOption != currentOptionKey) {
                // Add new vote
                if (votes[currentOptionKey] == null) {
                  votes[currentOptionKey] = <String>[];
                }
                final votersList = votes[currentOptionKey];
                final voters = votersList is List ? List<String>.from(votersList) : <String>[];
                voters.add(widget.currentUsername);
                votes[currentOptionKey] = voters;
                
                optionCounts[index] = optionCounts[index] + 1;
                voteTimestamps[widget.currentUsername] = FieldValue.serverTimestamp();
              } else {
                // Toggle off - remove vote timestamp
                voteTimestamps.remove(widget.currentUsername);
              }

              final totalVotes = optionCounts.fold<int>(0, (sum, count) => sum + count);

              transaction.update(pollRef, {
                'votes': votes,
                'optionCounts': optionCounts,
                'voteTimestamps': voteTimestamps,
                'totalVotes': totalVotes,
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            });
          } catch (e) {
            print('Error voting: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to vote: $e'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(widget.isTablet ? 16 : 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(widget.isTablet ? 16 : (isCompact ? 10 : 12)),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.05),
                    ],
                  ),
            borderRadius: BorderRadius.circular(widget.isTablet ? 16 : 12),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFF1976D2)
                  : const Color(0xFF1B263B).withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.isTablet ? 32 : (isCompact ? 24 : 28),
                height: widget.isTablet ? 32 : (isCompact ? 24 : 28),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.2)
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            key: const ValueKey('check'),
                            color: Colors.white,
                            size: widget.isTablet ? 18 : (isCompact ? 14 : 16),
                          )
                        : Text(
                            '${index + 1}',
                            key: const ValueKey('number'),
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: widget.isTablet ? 14 : (isCompact ? 10 : 12),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              SizedBox(width: widget.isTablet ? 16 : (isCompact ? 8 : 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: widget.isTablet ? 16 : (isCompact ? 12 : 14),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      child: Text(option),
                    ),
                    // Show option number for duplicates
                    if (hasDuplicates) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Option ${index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: widget.isTablet ? 10 : (isCompact ? 8 : 9),
                          color: Colors.white.withOpacity(0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isTablet ? 12 : (isCompact ? 6 : 8),
                  vertical: widget.isTablet ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count (${percentage.toStringAsFixed(1)}%)',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: widget.isTablet ? 14 : (isCompact ? 10 : 12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(int totalVotes, Timestamp? createdAt, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isTablet ? 12 : (isCompact ? 8 : 12),
                vertical: widget.isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Total votes: $totalVotes',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: widget.isTablet ? 14 : (isCompact ? 10 : 12),
                ),
              ),
            ),
            if (_hasVoted && !_canChangeVote)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isTablet ? 12 : (isCompact ? 8 : 12),
                  vertical: widget.isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_clock,
                      color: Colors.orange,
                      size: widget.isTablet ? 16 : (isCompact ? 12 : 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Vote locked',
                      style: GoogleFonts.poppins(
                        color: Colors.orange,
                        fontSize: widget.isTablet ? 14 : (isCompact ? 10 : 12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (_hasVoted && _canChangeVote)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.isTablet ? 12 : (isCompact ? 8 : 12),
                  vertical: widget.isTablet ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit,
                      color: Colors.green,
                      size: widget.isTablet ? 16 : (isCompact ? 12 : 14),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Can change vote',
                      style: GoogleFonts.poppins(
                        color: Colors.green,
                        fontSize: widget.isTablet ? 14 : (isCompact ? 10 : 12),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            if (totalVotes > 0)
              GestureDetector(
                onTap: () => widget.onViewVotes(widget.poll['id'] ?? ''),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isTablet ? 12 : (isCompact ? 8 : 12),
                    vertical: widget.isTablet ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility,
                        color: Colors.white,
                        size: widget.isTablet ? 16 : (isCompact ? 12 : 14),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View Votes',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: widget.isTablet ? 14 : (isCompact ? 10 : 12),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        
        if (createdAt != null) ...[
          SizedBox(height: widget.isTablet ? 12 : (isCompact ? 6 : 8)),
          Text(
            'Created ${_formatTimestamp(createdAt)}',
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: widget.isTablet ? 13 : (isCompact ? 9 : 11),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}