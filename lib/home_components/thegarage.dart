// / the_garage_page.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

import 'package:url_launcher/url_launcher.dart';

// Models
class Journey {
  final String id;
  final String name;
  final String description;
  final String authorId;
  final String authorUsername;
  final bool isHiring;
  final int followersCount;
  final int postsCount;
  final DateTime createdAt;
  final bool isFollowing;
  final int streak;
  final String status;
  final bool rewardEligible; // Add this
  final bool rewardClaimed; // Add this
  final DateTime? rewardEarnedAt;

  Journey({
    required this.id,
    required this.name,
    required this.description,
    required this.authorId,
    required this.authorUsername,
    required this.isHiring,
    required this.followersCount,
    required this.postsCount,
    required this.createdAt,
    required this.isFollowing,
    required this.streak,
    required this.status,
      this.rewardEligible = false,
    this.rewardClaimed = false,
    this.rewardEarnedAt,
  });

  factory Journey.fromMap(Map<String, dynamic> data) {
    return Journey(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      isHiring: data['isHiring'] ?? false,
      followersCount: data['followersCount'] ?? 0,
      postsCount: data['postsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFollowing: data['isFollowing'] ?? false,
      streak: data['streak'] ?? 0,
      status: data['status'] ?? 'active',
            rewardEligible: data['rewardEligible'] ?? false,
      rewardClaimed: data['rewardClaimed'] ?? false,
      rewardEarnedAt: (data['rewardEarnedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class JourneyPost {
  final String id;
  final String journeyId;
  final String content;
  final String authorId;
  final String authorUsername;
  final DateTime createdAt;
  final int likes;
  final int commentsCount;
  final bool isLiked;

  JourneyPost({
    required this.id,
    required this.journeyId,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    required this.createdAt,
    required this.likes,
    required this.commentsCount,
    required this.isLiked,
  });

  factory JourneyPost.fromMap(Map<String, dynamic> data) {
    return JourneyPost(
      id: data['id'] ?? '',
      journeyId: data['journeyId'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      isLiked: data['isLiked'] ?? false,
    );
  }
}

// Notifiers
class JourneyNotifier extends ChangeNotifier {
  List<Journey> _journeys = [];
  bool _isLoading = false;
  String _selectedFilter = 'recent';
  String? _error;

  List<Journey> get journeys => _journeys;
  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;
  String? get error => _error;

  void setFilter(String filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void updateJourneys(List<Journey> journeys) {
    _journeys = journeys;
    notifyListeners();
  }

  void updateJourney(Journey journey) {
    final index = _journeys.indexWhere((j) => j.id == journey.id);
    if (index != -1) {
      _journeys[index] = journey;
      notifyListeners();
    }
  }

  void addJourney(Journey journey) {
    _journeys.insert(0, journey);
    notifyListeners();
  }

  void removeJourney(String journeyId) {
    _journeys.removeWhere((j) => j.id == journeyId);
    notifyListeners();
  }
}

class JourneyPostNotifier extends ChangeNotifier {
  List<JourneyPost> _posts = [];
  bool _isLoading = false;
  String? _error;

  List<JourneyPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void updatePosts(List<JourneyPost> posts) {
    _posts = posts;
    notifyListeners();
  }

  void addPost(JourneyPost post) {
    _posts.insert(0, post);
    notifyListeners();
  }

  void updatePost(JourneyPost post) {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index != -1) {
      _posts[index] = post;
      notifyListeners();
    }
  }

  void removePost(String postId) {
    _posts.removeWhere((p) => p.id == postId);
    notifyListeners();
  }
}

// Main Page
class TheGaragePage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const TheGaragePage({
    super.key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  });

  @override
  State<TheGaragePage> createState() => _TheGaragePageState();
}

class _TheGaragePageState extends State<TheGaragePage> with TickerProviderStateMixin {
  late TabController _tabController;
  late JourneyNotifier _journeyNotifier;
  late StreamSubscription _journeySubscription;
  Map<String, double> _buttonScale = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSearching = false;

    bool _hasShownRewardPopup = false;

  bool get isStaff => ['admin', 'moderator', 'manager'].contains(widget.userRole);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isStaff ? 4 : 3, vsync: this);
    _tabController.addListener(() {
    setState(() {}); // Rebuild when tab changes
  });
    _journeyNotifier = JourneyNotifier();
    _loadJourneys();

    Future.delayed(const Duration(seconds: 1), () {
      _checkForRewards();
    });
  }

  

  @override
  void dispose() {
    _journeySubscription.cancel();
    _tabController.dispose();
    _journeyNotifier.dispose();
    _searchController.dispose();
    super.dispose();

    
  }

  Future<void> _checkForRewards() async {
    if (_hasShownRewardPopup) return;

    try {
      // Check user's journeys for reward eligibility
      final userJourneys = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .where('authorId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in userJourneys.docs) {
        final data = doc.data();
        final followersCount = data['followersCount'] ?? 0;
        final streak = data['streak'] ?? 0;
        final rewardEligible = data['rewardEligible'] ?? false;
        final rewardClaimed = data['rewardClaimed'] ?? false;
        
        // Check if user has achieved the milestone but hasn't been marked as eligible yet
        if (followersCount >= 1 && streak >= 1 && !rewardEligible) {
  // Mark as reward eligible
  await FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .collection('journeys')
      .doc(doc.id)
      .update({
    'rewardEligible': true,
    'rewardEarnedAt': FieldValue.serverTimestamp(),
  });
          
          // Show reward popup
            if (mounted) {
    _hasShownRewardPopup = true;
    _showRewardAchievedPopup(doc.id, data['name'] ?? 'Your Journey');
  }
  return;
}
        
        // Check if user is eligible but hasn't claimed yet
        if (rewardEligible && !rewardClaimed) {
          if (mounted) {
            _hasShownRewardPopup = true;
            _showRewardAchievedPopup(doc.id, data['name'] ?? 'Your Journey');
          }
          return;
        }
      }
    } catch (e) {
      print('Error checking rewards: $e');
    }
  }

  void _showRewardAchievedPopup(String journeyId, String journeyName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RewardAchievedPopup(
        journeyId: journeyId,
        journeyName: journeyName,
        communityId: widget.communityId,
        userId: widget.userId,
        username: widget.username,
        onClaimReward: () => _navigateToRewardClaim(journeyId, journeyName),
      ),
    );
  }

  void _navigateToRewardClaim(String journeyId, String journeyName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RewardClaimPage(
          journeyId: journeyId,
          journeyName: journeyName,
          communityId: widget.communityId,
          userId: widget.userId,
          username: widget.username,
        ),
      ),
    );
  }

  Future<String?> _getUserProfileImage(String username) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .doc(username)
        .get();
    
    return userDoc.data()?['profileImageUrl'] as String?;
  } catch (e) {
    print('Error fetching profile image for $username: $e');
    return null;
  }
}

  void _loadJourneys() {
  _journeyNotifier.setLoading(true);
  
  _journeySubscription = FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .collection('journeys')
      .where('status', isEqualTo: 'active')
      .snapshots()
      .listen((snapshot) async {
    List<Journey> journeys = [];
    
    // Get all journey IDs first
    List<String> journeyIds = snapshot.docs.map((doc) => doc.id).toList();
    
    // Batch check follow status for all journeys
    Map<String, bool> followStatusMap = await _batchCheckFollowStatus(journeyIds);
    
    // Create journeys with correct follow status
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final isFollowing = followStatusMap[doc.id] ?? false;
      
      final journey = Journey(
        id: data['id'] ?? '',
        name: data['name'] ?? '',
        description: data['description'] ?? '',
        authorId: data['authorId'] ?? '',
        authorUsername: data['authorUsername'] ?? '',
        isHiring: data['isHiring'] ?? false,
        followersCount: data['followersCount'] ?? 0,
        postsCount: data['postsCount'] ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isFollowing: isFollowing,
        streak: data['streak'] ?? 0,
        status: data['status'] ?? 'active',
      );
      
      journeys.add(journey);
    }

    // Apply filter based on selected filter
    if (_journeyNotifier.selectedFilter == 'following') {
      journeys = journeys.where((journey) {
        return journey.isFollowing; // Remove || journey.authorId == widget.userId
      }).toList();
    }

    _sortJourneys(journeys);
    _journeyNotifier.updateJourneys(journeys);
    _journeyNotifier.setLoading(false);
  }, onError: (error) {
    _journeyNotifier.setError(error.toString());
    _journeyNotifier.setLoading(false);
  });
}

Future<Map<String, bool>> _batchCheckFollowStatus(List<String> journeyIds) async {
  Map<String, bool> followStatus = {};
  
  try {
    final futures = journeyIds.map((journeyId) async {
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(journeyId)
          .collection('followers')
          .doc(widget.userId)
          .get();
      return MapEntry(journeyId, doc.exists);
    });
    
    final results = await Future.wait(futures);
    for (final entry in results) {
      followStatus[entry.key] = entry.value;
    }
  } catch (e) {
    print('Error batch checking follow status: $e');
  }
  
  return followStatus;
}

  void _sortJourneys(List<Journey> journeys) {
    switch (_journeyNotifier.selectedFilter) {
      case 'following':
        journeys.sort((a, b) {
          if (a.isFollowing && !b.isFollowing) return -1;
          if (!a.isFollowing && b.isFollowing) return 1;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
      case 'popular':
        journeys.sort((a, b) => b.followersCount.compareTo(a.followersCount));
        break;
      default: // recent
        journeys.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

 Future<void> _followJourney(String journeyId, bool isCurrentlyFollowing) async {
  try {
    final journeyRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(journeyId);

    final followerRef = journeyRef
        .collection('followers')
        .doc(widget.userId);

    if (isCurrentlyFollowing) {
      // Unfollow
      await followerRef.delete();
      await journeyRef.update({
        'followersCount': FieldValue.increment(-1),
      });
    } else {
      // Follow
      await followerRef.set({
        'userId': widget.userId,
        'username': widget.username,
        'followedAt': FieldValue.serverTimestamp(),
      });
      await journeyRef.update({
        'followersCount': FieldValue.increment(1),
      });
      
      // Check if this follow triggers reward eligibility
      final journeyDoc = await journeyRef.get();
      if (journeyDoc.exists) {
        final data = journeyDoc.data()!;
        final followersCount = data['followersCount'] ?? 0;
        final streak = data['streak'] ?? 0;
        final rewardEligible = data['rewardEligible'] ?? false;
        final authorId = data['authorId'] ?? '';
        
        if (followersCount >= 1 && streak >= 1 && !rewardEligible) {
  await journeyRef.update({
    'rewardEligible': true,
    'rewardEarnedAt': FieldValue.serverTimestamp(),
  });
          
          // If this is the author's journey, show reward popup
          if (authorId == widget.userId && mounted && !_hasShownRewardPopup) {
    _hasShownRewardPopup = true;
    _showRewardAchievedPopup(journeyId, data['name'] ?? 'Your Journey');
  }
}
      }
    }
  } catch (e) {
    _showMessage('Failed to update follow status: $e', isError: true);
  }
}
  Future<void> _reportJourney(String journeyId, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(journeyId)
          .collection('reports')
          .add({
        'reportedBy': widget.userId,
        'reportedByUsername': widget.username,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _showMessage('Journey reported successfully');
    } catch (e) {
      _showMessage('Failed to report journey: $e', isError: true);
    }
  }

  Future<void> _deleteJourney(String journeyId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(journeyId)
          .update({
        'status': 'deleted',
        'deletedBy': widget.username,
        'deletedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Journey deleted successfully');
    } catch (e) {
      _showMessage('Failed to delete journey: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.9),
              const Color(0xFF4F46E5).withOpacity(0.7),
              const Color(0xFF3730A3).withOpacity(0.5),
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              _buildSearchBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildJourneysList(),
                    _buildCreateJourney(),
                    _buildMyJourneysList(),
                    if (isStaff) _buildReportsPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

 Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.05),
          Colors.transparent,
        ],
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white70,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.rocket_launch,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'the garage',
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B5FE8), // More visible purple
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'start your journey, inspire others',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white60,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        // Add refresh button
        GestureDetector(
          onTap: () => _loadJourneys(),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.refresh,
              color: const Color(0xFF6366F1),
              size: 20,
            ),
          ),
        ),
      ],
    ),
  );
}
  Widget _buildSearchBar() {
    if (_tabController.index != 0) {
    return const SizedBox.shrink();
  }
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    height: 45,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
    ),
    child: TextField(
      controller: _searchController,
      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search journeys...',
        hintStyle: GoogleFonts.poppins(color: Colors.white38),
        prefixIcon: Icon(Icons.search, color: const Color(0xFF6366F1), size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

Widget _buildTabBar() {
  return Container(
    margin: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: TabBar(
      controller: _tabController,
      isScrollable: false,
      indicatorPadding: const EdgeInsets.all(4),
      indicator: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
      dividerColor: Colors.transparent,
      tabAlignment: TabAlignment.fill,
      tabs: [
        const Tab(text: 'Journeys'),
        const Tab(text: 'Create'),
        const Tab(text: 'My Journeys'),
        if (isStaff) const Tab(text: 'Reports'),
      ],
    ),
  );
}
  Widget _buildJourneysList() {
  return Column(
    children: [
      _buildFilters(),
      Expanded(
        child: ChangeNotifierBuilder<JourneyNotifier>(
          notifier: _journeyNotifier,
          builder: (context, notifier) {
            if (notifier.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              );
            }

            if (notifier.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading journeys',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                    ),
                    Text(
                      notifier.error!,
                      style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Apply search filter
            var filteredJourneys = notifier.journeys;
            if (_isSearching && _searchQuery.isNotEmpty) {
              filteredJourneys = filteredJourneys.where((journey) {
                final name = journey.name.toLowerCase();
                final description = journey.description.toLowerCase();
                final username = journey.authorUsername.toLowerCase();
                
                return name.contains(_searchQuery) ||
                       description.contains(_searchQuery) ||
                       username.contains(_searchQuery);
              }).toList();
            }

            if (filteredJourneys.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredJourneys.length,
              itemBuilder: (context, index) {
                final journey = filteredJourneys[index];
                return JourneyCard(
                  key: ValueKey(journey.id),
                  journey: journey,
                  currentUserId: widget.userId,
                  currentUsername: widget.username,
                  userRole: widget.userRole,
                  communityId: widget.communityId,
                  onFollow: _followJourney,
                  onReport: _reportJourney,
                  onDelete: isStaff ? _deleteJourney : null,
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

  Widget _buildFilters() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.15),
        width: 1,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFFDB2777)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.filter_list, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 8),
            Text(
              'sort by',
              style: GoogleFonts.dmSerifDisplay(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildFilterChip('recent', 'Recent', Icons.access_time),
            const SizedBox(width: 8),
            _buildFilterChip('popular', 'Popular', Icons.trending_up),
            const SizedBox(width: 8),
            _buildFilterChip('following', 'Following', Icons.favorite),
          ],
        ),
      ],
    ),
  );
}


Widget _buildMyJourneysList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .where('authorId', isEqualTo: widget.userId)
        .where('status', isEqualTo: 'active')
        // .orderBy('createdAt', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        );
      }

      if (snapshot.hasError) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading your journeys',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
              ),
              Text(
                snapshot.error.toString(),
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.rocket_launch, color: Colors.white60, size: 48),
              const SizedBox(height: 16),
              Text(
                'No Journeys Created',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
              ),
              Text(
                'Start your first journey!',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60),
              ),
            ],
          ),
        );
      }

      final myJourneys = snapshot.data!.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Journey.fromMap(data);
      }).toList();

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myJourneys.length,
        itemBuilder: (context, index) {
          final journey = myJourneys[index];
          return MyJourneyCard(
            journey: journey,
            communityId: widget.communityId,
            onToggleHiring: (journeyId, isHiring) => _toggleHiring(journeyId, isHiring),
            onDeleteJourney: (journeyId) => _deleteMyJourney(journeyId),
          );
        },
      );
    },
  );
}
Future<void> _toggleHiring(String journeyId, bool currentHiring) async {
  try {
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(journeyId)
        .update({'isHiring': !currentHiring});
    
    setState(() {}); // Refresh the view
    _showMessage('Hiring status updated successfully!');
  } catch (e) {
    _showMessage('Failed to update hiring status: $e', isError: true);
  }
}

Future<void> _deleteMyJourney(String journeyId) async {
  try {
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(journeyId)
        .update({'status': 'deleted'});
    
    setState(() {}); // Refresh the view
    _showMessage('Journey deleted successfully!');
  } catch (e) {
    _showMessage('Failed to delete journey: $e', isError: true);
  }
}
Widget _buildFilterChip(String value, String label, IconData icon) {
  return ChangeNotifierBuilder<JourneyNotifier>(
    notifier: _journeyNotifier,
    builder: (context, notifier) {
      final isSelected = notifier.selectedFilter == value;
      return GestureDetector(
        onTap: () {
          _journeyNotifier.setFilter(value);
          _loadJourneys();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected 
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  )
                : null,
            color: isSelected ? null : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.15),
            ),
          ),
          child: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 12),
    const SizedBox(width: 4),
    Text(
      label,
      style: GoogleFonts.poppins(
        color: isSelected ? Colors.white : Colors.white70,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 10,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  ],
),
        ),
      );
    },
  );
}

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rocket_launch,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Journeys Yet',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to start a journey and inspire others',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateJourney() {
    return CreateJourneyPage(
      communityId: widget.communityId,
      userId: widget.userId,
      username: widget.username,
      onJourneyCreated: (journey) {
        _journeyNotifier.addJourney(journey);
        _tabController.animateTo(0);
      },
    );
  }
Widget _buildReportsPanel() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .where('status', isEqualTo: 'active')
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, color: Colors.white60, size: 48),
              const SizedBox(height: 16),
              Text(
                'No Reports',
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
              ),
              Text(
                'All clear! No pending reports.',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60),
              ),
            ],
          ),
        );
      }

      // Collect all reports from all journeys
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _collectAllReports(snapshot.data!.docs),
        builder: (context, reportsSnapshot) {
          if (!reportsSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
          }

          final reports = reportsSnapshot.data!;
          
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.security, color: Colors.white60, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No Reports',
                    style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                  ),
                  Text(
                    'All clear! No pending reports.',
                    style: GoogleFonts.poppins(fontSize: 13, color: Colors.white60),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];  // Changed from reportData to report
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Journey: ${report['journeyName'] ?? 'Unknown'}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Reason: ${report['reason'] ?? 'Unknown'}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      'By: ${report['reportedByUsername'] ?? 'Anonymous'}',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => _dismissReport(report['journeyId'], report['reportId']),
                          child: Text('Dismiss', style: GoogleFonts.poppins(color: Colors.white60)),
                        ),
                        ElevatedButton(
                          onPressed: () => _handleReport(report['journeyId'], report['reportId'], report),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: Text('Take Action', style: GoogleFonts.poppins(color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

Future<List<Map<String, dynamic>>> _collectAllReports(List<QueryDocumentSnapshot> journeys) async {
  List<Map<String, dynamic>> allReports = [];
  
  for (var journeyDoc in journeys) {
    final journeyData = journeyDoc.data() as Map<String, dynamic>;
    final reportsSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(journeyDoc.id)
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .get();
    
    for (var reportDoc in reportsSnapshot.docs) {
      final reportData = reportDoc.data();
      allReports.add({
        ...reportData,
        'reportId': reportDoc.id,  // Keep as reportId
        'journeyId': journeyDoc.id,
        'journeyName': journeyData['name'] ?? 'Unknown Journey',
      });
    }
  }
  
  return allReports;
}
Future<void> _handleReport(String journeyId, String reportId, Map<String, dynamic> reportData) async {
  try {
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(journeyId)
        .collection('reports')
        .doc(reportId)
        .update({'status': 'resolved'});
    
    _showMessage('Report handled successfully');
  } catch (e) {
    _showMessage('Error handling report: $e', isError: true);
  }
}

// Future<void> _handleReport(String reportId, Map<String, dynamic> reportData) async {
//   // Add your report handling logic here
//   try {
//     await FirebaseFirestore.instance
//         .collection('communities')
//         .doc(widget.communityId)
//         .collection('reports')
//         .doc(reportId)
//         .update({'status': 'resolved'});
    
//     _showMessage('Report handled successfully');
//   } catch (e) {
//     _showMessage('Error handling report: $e', isError: true);
//   }
// }

Future<void> _dismissReport(String journeyId, String reportId) async {
  try {
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(journeyId)
        .collection('reports')
        .doc(reportId)
        .update({'status': 'dismissed'});
    
    _showMessage('Report dismissed successfully');
  } catch (e) {
    _showMessage('Error dismissing report: $e', isError: true);
  }
}

// Future<void> _handleReport(String reportId, Map<String, dynamic> reportData) async {
//   // Add your report handling logic here
//   try {
//     await FirebaseFirestore.instance
//         .collection('communities')
//         .doc(widget.communityId)
//         .collection('reports')
//         .doc(reportId)
//         .update({'status': 'resolved'});
    
//     _showMessage('Report handled successfully');
//   } catch (e) {
//     _showMessage('Error handling report: $e', isError: true);
//   }
// }
}

// Helper widget for ChangeNotifier
class ChangeNotifierBuilder<T extends ChangeNotifier> extends StatefulWidget {
  final T notifier;
  final Widget Function(BuildContext context, T notifier) builder;

  const ChangeNotifierBuilder({
    super.key,
    required this.notifier,
    required this.builder,
  });

  @override
  State<ChangeNotifierBuilder<T>> createState() => _ChangeNotifierBuilderState<T>();
}

class _ChangeNotifierBuilderState<T extends ChangeNotifier> extends State<ChangeNotifierBuilder<T>> {
  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onNotifierChange);
  }

  @override
  void dispose() {
    widget.notifier.removeListener(_onNotifierChange);
    super.dispose();
  }

  void _onNotifierChange() {
    if (mounted) {
      setState(() {});
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.notifier);
  }
}

// Journey Card Widget
class JourneyCard extends StatefulWidget {
  final Journey journey;
  final String currentUserId;
  final String currentUsername;
  final String userRole;
  final String communityId;
  final Function(String, bool) onFollow;
  final Function(String, String) onReport;
  final Function(String)? onDelete;

  const JourneyCard({
    super.key,
    required this.journey,
    required this.currentUserId,
    required this.currentUsername,
    required this.userRole,
    required this.communityId,
    required this.onFollow,
    required this.onReport,
    this.onDelete,
  });

  @override
  State<JourneyCard> createState() => _JourneyCardState();
}

class _JourneyCardState extends State<JourneyCard> {
  bool isExpanded = false;
  Map<String, double> _buttonScale = {};

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<String?> _getUserProfileImage(String username, String communityId) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(username)
        .get();
    
    return userDoc.data()?['profileImageUrl'] as String?;
  } catch (e) {
    print('Error fetching profile image for $username: $e');
    return null;
  }
}

  void _showReportDialog() {
    final List<String> reportReasons = [
      'Inappropriate Content',
      'Spam',
      'Misleading Information',
      'Harassment',
      'Copyright Violation',
      'Other',
    ];
    
    String? selectedReason;
    final TextEditingController customReasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A1810),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.report, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Journey',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...reportReasons.map((reason) => GestureDetector(
                  onTap: () => setDialogState(() => selectedReason = reason),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedReason == reason
                          ? Colors.red.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedReason == reason
                            ? Colors.red
                            : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selectedReason == reason
                              ? Colors.red
                              : Colors.white60,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.poppins(
                              color: selectedReason == reason
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customReasonController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Please specify...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () {
                      final finalReason = selectedReason == 'Other'
                          ? customReasonController.text.trim()
                          : selectedReason!;
                      if (finalReason.isNotEmpty) {
                        Navigator.pop(context);
                        widget.onReport(widget.journey.id, finalReason);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Report', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserData(String username) async {
  try {
    // First check members collection
    final memberDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .doc(username)
        .get();
    
    if (memberDoc.exists) {
      return memberDoc.data();
    }
    
    // If not found in members, check trio collection
    final trioDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .doc(username)
        .get();
    
    if (trioDoc.exists) {
      return trioDoc.data();
    }
    
    return null;
  } catch (e) {
    print('Error fetching user data for $username: $e');
    return null;
  }
}

@override
Widget build(BuildContext context) {
  final journey = widget.journey;
  final displayDescription = journey.description.length > 150 && !isExpanded 
      ? '${journey.description.substring(0, 150)}...' 
      : journey.description;
  final isAuthor = journey.authorId == widget.currentUserId;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF6366F1).withOpacity(0.08),
          const Color(0xFF4F46E5).withOpacity(0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFF6366F1).withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF6366F1).withOpacity(0.1),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              FutureBuilder<String?>(
                future: _getUserProfileImage(journey.authorUsername, widget.communityId),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(snapshot.data!),
                      backgroundColor: Color(int.parse('FF${journey.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Handle image load error - will show fallback
                      },
                    );
                  } else {
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(int.parse('FF${journey.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                            const Color(0xFF6366F1),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          journey.authorUsername[0].toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '@${journey.authorUsername}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (isAuthor) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF7B42C), Color(0xFFFF8C00)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'You',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        if (journey.isHiring) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'HIRING',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<DocumentSnapshot>(
  future: FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .collection('members')
      .doc(journey.authorUsername)
      .get(),
  builder: (context, snapshot) {
    if (snapshot.hasData && snapshot.data!.exists) {
      final userData = snapshot.data!.data() as Map<String, dynamic>;
      final firstName = userData['firstName'] ?? userData['userFirstName'] ?? '';
      final lastName = userData['lastName'] ?? userData['userLastName'] ?? '';
      final fullName = '$firstName $lastName'.trim();
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fullName.isNotEmpty && fullName != ' ') ...[
            Text(
              fullName,
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              if (userData['branch']?.toString().isNotEmpty == true)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.school, color: Colors.white, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        userData['branch'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              if (userData['year']?.toString().isNotEmpty == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF6366F1).withOpacity(0.8), const Color(0xFF4F46E5).withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        '${userData['year']}',
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  },
),
                    Row(
                      children: [
                        Text(
                          _formatTimestamp(journey.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                        if (journey.streak > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B6B), Color(0xFFFF5722)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${journey.streak}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Journey Title
          Text(
            journey.name,
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Text(
            displayDescription,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white,
              height: 1.6,
              letterSpacing: 0.2,
            ),
          ),

          if (journey.description.length > 150)
            GestureDetector(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Text(
                      isExpanded ? 'Show less' : 'Read more',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF6366F1),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF6366F1),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Stats Row
          Row(
            children: [
              _buildStatChip(
                icon: Icons.people,
                count: journey.followersCount,
                label: 'followers',
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                icon: Icons.article,
                count: journey.postsCount,
                label: 'posts',
              ),
              const Spacer(),
              Text(
                _formatTimestamp(journey.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white60,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons
          // Action Buttons
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    // Follow Button
    if (!isAuthor)
      GestureDetector(
        onTapDown: (_) => setState(() => _buttonScale['follow'] = 0.95),
        onTapUp: (_) => setState(() => _buttonScale['follow'] = 1.0),
        onTapCancel: () => setState(() => _buttonScale['follow'] = 1.0),
        onTap: () => widget.onFollow(journey.id, journey.isFollowing),
        child: AnimatedScale(
          scale: _buttonScale['follow'] ?? 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: journey.isFollowing
                  ? LinearGradient(
                      colors: [
                        Colors.grey.withOpacity(0.8),
                        Colors.grey.withOpacity(0.6),
                      ],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (journey.isFollowing ? Colors.grey : const Color(0xFF6366F1)).withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  journey.isFollowing ? Icons.check : Icons.add,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  journey.isFollowing ? 'Following' : 'Follow',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

    // Contact Info Button (only for hiring journeys)
    if (journey.isHiring)
      GestureDetector(
        onTapDown: (_) => setState(() => _buttonScale['contact'] = 0.95),
        onTapUp: (_) => setState(() => _buttonScale['contact'] = 1.0),
        onTapCancel: () => setState(() => _buttonScale['contact'] = 1.0),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactJourneyPage(
                journey: journey,
                communityId: widget.communityId,
              ),
            ),
          );
        },
        child: AnimatedScale(
          scale: _buttonScale['contact'] ?? 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withOpacity(0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.contact_phone,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  'Contact',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

    // View Journey Button
    GestureDetector(
      onTapDown: (_) => setState(() => _buttonScale['view'] = 0.95),
      onTapUp: (_) => setState(() => _buttonScale['view'] = 1.0),
      onTapCancel: () => setState(() => _buttonScale['view'] = 1.0),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JourneyDetailPage(
              journey: journey,
              communityId: widget.communityId,
              userId: widget.currentUserId,
              username: widget.currentUsername,
              userRole: widget.userRole,
            ),
          ),
        );
      },
      child: AnimatedScale(
        scale: _buttonScale['view'] ?? 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility,
                color: Colors.white70,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'View',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]
            ),
          ),
        ),
      ),
  ]
    ),

    // Report Button (right aligned)
    if (!isAuthor)
      GestureDetector(
        onTap: _showReportDialog,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.flag_outlined,
            color: Colors.white60,
            size: 14,
          ),
        ),
      ),

    // Delete Button (for staff)
    if (widget.onDelete != null && !isAuthor)
      GestureDetector(
        onTap: () => widget.onDelete!(journey.id),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.red,
            size: 14,
          ),
        ),
      ),
  ],
),
    )
    ); 
}

  Widget _buildStatChip({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFF6366F1),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
      
  

  Widget _buildStatChip({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFF6366F1),
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }


class MyJourneyCard extends StatelessWidget {
  final Journey journey;
  final String communityId;
  final Function(String, bool) onToggleHiring;
  final Function(String) onDeleteJourney;

  const MyJourneyCard({
    super.key,
    required this.journey,
    required this.communityId,
    required this.onToggleHiring,
    required this.onDeleteJourney,
  });

  Future<String?> _getUserProfileImage(String username) async {
  try {
    final userDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(username)
        .get();
    
    return userDoc.data()?['profileImageUrl'] as String?;
  } catch (e) {
    print('Error fetching profile image for $username: $e');
    return null;
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6366F1).withOpacity(0.08),
            const Color(0xFF4F46E5).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
         Row(
  children: [
    FutureBuilder<String?>(
      future: _getUserProfileImage(journey.authorUsername),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(snapshot.data!),
            backgroundColor: Color(int.parse('FF${journey.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
          );
        } else {
          return Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(int.parse('FF${journey.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                  const Color(0xFF6366F1),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                journey.authorUsername[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }
      },
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Text(
        journey.name,
        style: GoogleFonts.dmSerifDisplay(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white60),
                  color: const Color(0xFF2A1810),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(context);
                    } else if (value == 'view') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JourneyDetailPage(
                            journey: journey,
                            communityId: communityId,
                            userId: journey.authorId,
                            username: journey.authorUsername,
                            userRole: 'user',
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          const Icon(Icons.visibility, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Text('View Details', style: GoogleFonts.poppins(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, color: const Color(0xFF6366F1), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${journey.followersCount} followers',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.article, color: const Color(0xFF6366F1), size: 16),
                const SizedBox(width: 4),
                Text(
                  '${journey.postsCount} posts',
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.work, color: const Color(0xFF6366F1), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Looking to Hire',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: journey.isHiring,
                  onChanged: (value) => onToggleHiring(journey.id, journey.isHiring),
                  activeColor: const Color(0xFF6366F1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A1810),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Journey', style: GoogleFonts.poppins(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete this journey? This action cannot be undone.',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDeleteJourney(journey.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// Create Journey Page
class CreateJourneyPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final Function(Journey) onJourneyCreated;

  const CreateJourneyPage({
    super.key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.onJourneyCreated,
  });

  @override
  State<CreateJourneyPage> createState() => _CreateJourneyPageState();
}

class _CreateJourneyPageState extends State<CreateJourneyPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isHiring = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createJourney() async {
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    if (name.isEmpty) {
      _showMessage('Please enter a journey name', isError: true);
      return;
    }

    if (description.isEmpty) {
      _showMessage('Please enter a journey description', isError: true);
      return;
    }

    if (name.length < 3) {
      _showMessage('Journey name must be at least 3 characters', isError: true);
      return;
    }

    if (description.length < 10) {
      _showMessage('Journey description must be at least 10 characters', isError: true);
      return;
    }

    setState(() => _isCreating = true);

    try {
      final journeyRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc();

      final journey = Journey(
        id: journeyRef.id,
        name: name,
        description: description,
        authorId: widget.userId,
        authorUsername: widget.username,
        isHiring: _isHiring,
        followersCount: 0,
        postsCount: 0,
        createdAt: DateTime.now(),
        isFollowing: false,
        streak: 0,
        status: 'active',
      );

      await journeyRef.set({
        'id': journey.id,
        'name': journey.name,
        'description': journey.description,
        'authorId': journey.authorId,
        'authorUsername': journey.authorUsername,
        'isHiring': journey.isHiring,
        'followersCount': journey.followersCount,
        'postsCount': journey.postsCount,
        'createdAt': FieldValue.serverTimestamp(),
        'streak': journey.streak,
        'status': journey.status,
        'lastPostAt': null,
      });

      // Create engagement stats
      await journeyRef.collection('stats').doc('engagement').set({
        'totalViews': 0,
        'uniqueViewers': [],
        'peakEngagement': 0,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      widget.onJourneyCreated(journey);
      _nameController.clear();
      _descriptionController.clear();
      setState(() => _isHiring = false);
      _showMessage('Journey created successfully!');
      
    } catch (e) {
      _showMessage('Failed to create journey: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'start your journey',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'share your goals, inspire others, and build something amazing',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 20),

          // Journey Name
          Text(
            'Journey Name',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _nameController,
              maxLength: 50,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g., "Building My First App"',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Journey Description
          Text(
            'Description',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 150),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _descriptionController,
              maxLines: null,
              maxLength: 500,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Describe your journey, goals, and what you hope to achieve...',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Hiring Toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Icon(
                  _isHiring ? Icons.work : Icons.work_outline,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Looking to Hire',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _isHiring 
                            ? 'Others will see you\'re hiring for this journey' 
                            : 'Toggle if you\'re looking for collaborators',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isHiring,
                  onChanged: (value) => setState(() => _isHiring = value),
                  activeColor: const Color(0xFF6366F1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Reward Information
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF7B42C).withOpacity(0.15),
                  const Color(0xFFFF8C00).withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF7B42C).withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Color(0xFFF7B42C), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Journey Rewards',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFF7B42C),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '🎯 Reach 1000 followers + Complete 100-day streak = Special Reward!\n'
                  '🔥 Daily posts help maintain your streak\n'
                  '⭐ Consistent progress leads to community recognition',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Create Button
          Row(
            children: [
              const Spacer(),
              GestureDetector(
                onTap: _isCreating ? null : _createJourney,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.6),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'START JOURNEY',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          _buildCreationGuidelines(),
        ],
      ),
    );
  }

  Widget _buildCreationGuidelines() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Text(
                'Journey Guidelines',
                style: GoogleFonts.poppins(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Journey name: 3-50 characters\n'
            '• Description: 10-500 characters\n'
            '• Post daily to maintain streak\n'
            '• Each post: 50-100 characters\n'
            '• Be authentic and inspiring',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// Journey Detail Page
class JourneyDetailPage extends StatefulWidget {
  final Journey journey;
  final String communityId;
  final String userId;
  final String username;
  final String userRole;

  const JourneyDetailPage({
    super.key,
    required this.journey,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
  });

  @override
  State<JourneyDetailPage> createState() => _JourneyDetailPageState();
}

class _JourneyDetailPageState extends State<JourneyDetailPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late JourneyPostNotifier _postNotifier;
  late StreamSubscription _postSubscription;
  final TextEditingController _postController = TextEditingController();
  bool _isPosting = false;

  bool _hasShownRewardPopup = false;

  bool get isStaff => ['admin', 'moderator', 'manager'].contains(widget.userRole);
  bool get isAuthor => widget.journey.authorId == widget.userId;

@override
void initState() {
  super.initState();
  _tabController = TabController(length: (widget.journey.authorId == widget.userId) ? 2 : 1, vsync: this);
  _postNotifier = JourneyPostNotifier();
  _loadPosts();
}

  @override
  void dispose() {
    _postSubscription.cancel();
    _tabController.dispose();
    _postNotifier.dispose();
    _postController.dispose();
    super.dispose();
  }

  void _showRewardAchievedPopup(String journeyId, String journeyName) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => RewardAchievedPopup(
      journeyId: journeyId,
      journeyName: journeyName,
      communityId: widget.communityId,
      userId: widget.userId,
      username: widget.username,
      onClaimReward: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RewardClaimPage(
              journeyId: journeyId,
              journeyName: journeyName,
              communityId: widget.communityId,
              userId: widget.userId,
              username: widget.username,
            ),
          ),
        );
      },
    ),
  );
}

  void _loadPosts() {
    _postNotifier.setLoading(true);
    
    _postSubscription = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(widget.journey.id)
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final posts = snapshot.docs.map((doc) {
        final data = doc.data();
        return JourneyPost.fromMap(data);
      }).toList();

      _postNotifier.updatePosts(posts);
      _postNotifier.setLoading(false);
    }, onError: (error) {
      _postNotifier.setError(error.toString());
      _postNotifier.setLoading(false);
    });
  }

  Future<void> _createPost() async {
    final content = _postController.text.trim();
    
    if (content.isEmpty) {
      _showMessage('Please write something for your post', isError: true);
      return;
    }

    if (content.length < 50) {
      _showMessage('Post must be at least 50 characters long', isError: true);
      return;
    }

    if (content.length > 100) {
      _showMessage('Post must be 100 characters or less', isError: true);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final postRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journey.id)
          .collection('posts')
          .doc();

      await postRef.set({
        'id': postRef.id,
        'journeyId': widget.journey.id,
        'content': content,
        'authorId': widget.userId,
        'authorUsername': widget.username,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'commentsCount': 0,
      });

      // Update journey stats
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journey.id)
          .update({
        'postsCount': FieldValue.increment(1),
        'lastPostAt': FieldValue.serverTimestamp(),
      });

      // Update streak if it's the author posting
      if (isAuthor) {
        await _updateStreak();
      }

      _postController.clear();
      _showMessage('Post created successfully!');
      
    } catch (e) {
      _showMessage('Failed to create post: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _updateStreak() async {
  try {
    final journeyRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(widget.journey.id);

    final journeyDoc = await journeyRef.get();
    if (!journeyDoc.exists) return;

    final data = journeyDoc.data()!;
    final lastPostAt = data['lastPostAt'] as Timestamp?;
    final currentStreak = data['streak'] ?? 0;
    final followersCount = data['followersCount'] ?? 0;
    final rewardEligible = data['rewardEligible'] ?? false;

    if (lastPostAt == null) {
      // First post
      await journeyRef.update({'streak': 1});
      
      // Check for reward eligibility after first post
      if (followersCount >= 1 && !rewardEligible) {
        await journeyRef.update({
          'rewardEligible': true,
          'rewardEarnedAt': FieldValue.serverTimestamp(),
        });
        
        // Show reward popup if not shown
        if (mounted && !_hasShownRewardPopup) {
          setState(() => _hasShownRewardPopup = true);
          Navigator.of(context).pop(); // Close current page
          _showRewardAchievedPopup(widget.journey.id, widget.journey.name);
        }
      }
    } else {
      final lastPostDate = lastPostAt.toDate();
      final today = DateTime.now();
      final daysDifference = today.difference(DateTime(lastPostDate.year, lastPostDate.month, lastPostDate.day)).inDays;

      int newStreak = currentStreak;
      if (daysDifference == 1) {
        // Posted yesterday, continue streak
        newStreak = currentStreak + 1;
        await journeyRef.update({'streak': newStreak});
      } else if (daysDifference > 1) {
        // Streak broken, reset to 1
        newStreak = 1;
        await journeyRef.update({'streak': newStreak});
      }
      
      // Check for reward eligibility after updating streak
      if (newStreak >= 1 && followersCount >= 1 && !rewardEligible) {
  await journeyRef.update({
    'rewardEligible': true,
    'rewardEarnedAt': FieldValue.serverTimestamp(),
  });
        
        // Show reward popup if not shown
         if (mounted && !_hasShownRewardPopup) {
    setState(() => _hasShownRewardPopup = true);
    // Don't close the current page, just show popup
    _showRewardAchievedPopup(widget.journey.id, widget.journey.name);
  }
}
    }
  } catch (e) {
    print('Error updating streak: $e');
  }
}
  Future<void> _likePost(String postId, bool isCurrentlyLiked) async {
    try {
      final postRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journey.id)
          .collection('posts')
          .doc(postId);

      final userLikeRef = postRef.collection('likes').doc(widget.userId);
      
      if (isCurrentlyLiked) {
        // Unlike
        await userLikeRef.delete();
        await postRef.update({'likes': FieldValue.increment(-1)});
      } else {
        // Like
        await userLikeRef.set({'timestamp': FieldValue.serverTimestamp()});
        await postRef.update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      _showMessage('Failed to update like: $e', isError: true);
    }
  }

  Future<void> _reportPost(String postId, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journey.id)
          .collection('posts')
          .doc(postId)
          .collection('reports')
          .add({
        'reportedBy': widget.userId,
        'reportedByUsername': widget.username,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _showMessage('Post reported successfully');
    } catch (e) {
      _showMessage('Failed to report post: $e', isError: true);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journey.id)
          .collection('posts')
          .doc(postId)
          .delete();

      // Update journey stats
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journey.id)
          .update({
        'postsCount': FieldValue.increment(-1),
      });

      _showMessage('Post deleted successfully');
    } catch (e) {
      _showMessage('Failed to delete post: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.9),
              const Color(0xFF4F46E5).withOpacity(0.7),
              const Color(0xFF3730A3).withOpacity(0.5),
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildDetailHeader(),
              _buildJourneyInfo(),
              _buildTabBar(),
              Expanded(
  child: TabBarView(
    controller: _tabController,
    children: [
      _buildPostsList(),
      if (widget.journey.authorId == widget.userId) _buildCreatePost(),
    ],
  ),
),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.journey.name,
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'by @${widget.journey.authorUsername}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(int.parse('FF${widget.journey.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                      const Color(0xFF6366F1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    widget.journey.authorUsername[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '@${widget.journey.authorUsername}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (widget.journey.isHiring) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'HIRING',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (widget.journey.streak > 0)
                      Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.journey.streak} day streak',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.journey.description,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                icon: Icons.people,
                count: widget.journey.followersCount,
                label: 'followers',
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                icon: Icons.article,
                count: widget.journey.postsCount,
                label: 'posts',
              ),
              const SizedBox(width: 12),
              _buildInfoChip(
                icon: Icons.calendar_today,
                count: DateTime.now().difference(widget.journey.createdAt).inDays + 1,
                label: 'days',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required int count,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: const Color(0xFF6366F1),
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 9,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildTabBar() {
  return Container(
    margin: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: TabBar(
      controller: _tabController,
      isScrollable: false,
      indicatorPadding: const EdgeInsets.all(4),
      indicator: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
      dividerColor: Colors.transparent,
      tabAlignment: TabAlignment.fill,
      tabs: [
        const Tab(text: 'Posts'),
        if (widget.journey.authorId == widget.userId) const Tab(text: 'Add Post'),
      ],
    ),
  );
}
  Widget _buildPostsList() {
    return ChangeNotifierBuilder<JourneyPostNotifier>(
      notifier: _postNotifier,
      builder: (context, notifier) {
        if (notifier.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6366F1)),
          );
        }

        if (notifier.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading posts',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
          );
        }

        if (notifier.posts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.article_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No Posts Yet',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isAuthor 
                        ? 'Share your first update to start your journey'
                        : 'This journey is just getting started',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white60,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: notifier.posts.length,
          itemBuilder: (context, index) {
            final post = notifier.posts[index];
            return JourneyPostCard(
              key: ValueKey(post.id),
              post: post,
              currentUserId: widget.userId,
              currentUsername: widget.username,
              userRole: widget.userRole,
              communityId: widget.communityId,
              journeyId: widget.journey.id,
              onLike: _likePost,
              onReport: _reportPost,
              onDelete: (isStaff || post.authorId == widget.userId) ? _deletePost : null,
            );
          },
        );
      },
    );
  }

Widget _buildCreatePost() {
  if (!isAuthor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              color: Colors.white60,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Only the Journey Owner Can Post',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow this journey to see updates from @${widget.journey.authorUsername}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'share an update',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'keep your followers updated on your progress',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 20),

          // Post Input
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _postController,
              maxLines: null,
              maxLength: 100,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Share your progress, thoughts, or what you learned today...',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Character Count Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Posts must be between 50-100 characters to maintain quality and readability.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Post Button
          Row(
            children: [
              const Spacer(),
              GestureDetector(
                onTap: _isPosting ? null : _createPost,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(0.6),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _isPosting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'SHARE UPDATE',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Streak Info
          if (widget.journey.streak > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.15),
                    Colors.red.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Streak: ${widget.journey.streak} days',
                          style: GoogleFonts.poppins(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Keep posting daily to maintain your streak!',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// Journey Post Card
class JourneyPostCard extends StatefulWidget {
  final JourneyPost post;
  final String currentUserId;
  final String currentUsername;
  final String userRole;
  final String communityId;
  final String journeyId;
  final Function(String, bool) onLike;
  final Function(String, String) onReport;
  final Function(String)? onDelete;

  const JourneyPostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.currentUsername,
    required this.userRole,
    required this.communityId,
    required this.journeyId,
    required this.onLike,
    required this.onReport,
    this.onDelete,
  });

  @override
  State<JourneyPostCard> createState() => _JourneyPostCardState();
}

class _JourneyPostCardState extends State<JourneyPostCard> {
  bool isLiked = false;
  Map<String, double> _buttonScale = {};

  @override
  void initState() {
    super.initState();
    _loadUserLike();
  }

  @override
void didUpdateWidget(JourneyPostCard oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (oldWidget.post.id != widget.post.id) {
    _loadUserLike();
  }
}

  Future<void> _loadUserLike() async {
  try {
    final likeDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(widget.journeyId)
        .collection('posts')
        .doc(widget.post.id)
        .collection('likes')
        .doc(widget.currentUserId)
        .get();
    
    if (mounted) {
      setState(() => isLiked = likeDoc.exists);
    }
  } catch (e) {
    print('Error loading user like: $e');
  }
}

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JourneyPostCommentsPage(
        postId: widget.post.id,
        journeyId: widget.journeyId,
        communityId: widget.communityId,
        userId: widget.currentUserId,
        username: widget.currentUsername,
      ),
    );
  }

@override
Widget build(BuildContext context) {
  final post = widget.post;
  final isAuthor = post.authorId == widget.currentUserId;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF6366F1).withOpacity(0.05),
          const Color(0xFF4F46E5).withOpacity(0.02),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(int.parse('FF${post.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                      const Color(0xFF6366F1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    post.authorUsername[0].toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '@${post.authorUsername}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        if (isAuthor) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF7B42C), Color(0xFFFF8C00)],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'You',
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatTimestamp(post.createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
             PopupMenuButton<String>(
  icon: const Icon(Icons.more_vert, color: Colors.white60, size: 16),
  color: const Color(0xFF2A1810),
  onSelected: (value) {
    if (value == 'delete') {
      widget.onDelete!(post.id);
    } else if (value == 'report') {
      _showReportDialog();
    }
  },
  itemBuilder: (context) => [
    if (!isAuthor)
      PopupMenuItem(
        value: 'report',
        child: Row(
          children: [
            const Icon(Icons.flag, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Text('Report', style: GoogleFonts.poppins(color: Colors.white)),
          ],
        ),
      ),
    if (widget.onDelete != null && (isAuthor || ['admin', 'moderator', 'manager'].contains(widget.userRole)))
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            const Icon(Icons.delete, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ],
        ),
      ),
  ],
),
            ],
          ),

          const SizedBox(height: 12),

          // Post Content
          Text(
            post.content,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              // Like Button
              GestureDetector(
                onTapDown: (_) => setState(() => _buttonScale['like'] = 0.95),
                onTapUp: (_) => setState(() => _buttonScale['like'] = 1.0),
                onTapCancel: () => setState(() => _buttonScale['like'] = 1.0),
                onTap: () async {
  // Optimistic update
  final wasLiked = isLiked;
  setState(() => isLiked = !isLiked);
  
  try {
    await widget.onLike(post.id, wasLiked);
  } catch (e) {
    // Revert on error
    if (mounted) {
      setState(() => isLiked = wasLiked);
    }
  }
},
                child: AnimatedScale(
                  scale: _buttonScale['like'] ?? 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isLiked 
                          ? Colors.red.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLiked 
                            ? Colors.red.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.red : Colors.white60,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          post.likes.toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: isLiked ? Colors.red : Colors.white60,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Comments Button
              GestureDetector(
                onTap: _showCommentsModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.comment_outlined,
                        color: Colors.white60,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.commentsCount.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.white60,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              Text(
                _formatTimestamp(post.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  void _showReportDialog() {
    final List<String> reportReasons = [
      'Inappropriate Content',
      'Spam',
      'Misleading Information',
      'Harassment',
      'Copyright Violation',
      'Other',
    ];
    
    String? selectedReason;
    final TextEditingController customReasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A1810),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.report, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Report Post',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...reportReasons.map((reason) => GestureDetector(
                  onTap: () => setDialogState(() => selectedReason = reason),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selectedReason == reason
                          ? Colors.red.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedReason == reason
                            ? Colors.red
                            : Colors.white.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedReason == reason
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: selectedReason == reason
                              ? Colors.red
                              : Colors.white60,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            reason,
                            style: GoogleFonts.poppins(
                              color: selectedReason == reason
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
                if (selectedReason == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customReasonController,
                    maxLines: 3,
                    style: GoogleFonts.poppins(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Please specify...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: selectedReason != null
                  ? () {
                      final finalReason = selectedReason == 'Other'
                          ? customReasonController.text.trim()
                          : selectedReason!;
                      if (finalReason.isNotEmpty) {
                        Navigator.pop(context);
                        widget.onReport(widget.post.id, finalReason);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Report', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
// Reports Panel Widget
class ReportsPanel extends StatefulWidget {
  final String communityId;
  final String currentUsername;
  final Function(String) onDeleteJourney;

  const ReportsPanel({
    super.key,
    required this.communityId,
    required this.currentUsername,
    required this.onDeleteJourney,
  });

  @override
  State<ReportsPanel> createState() => _ReportsPanelState();
}

class _ReportsPanelState extends State<ReportsPanel> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.security,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Reports Panel',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Review and manage community reports',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Journey Post Comments Page
class JourneyPostCommentsPage extends StatefulWidget {
  final String postId;
  final String journeyId;
  final String communityId;
  final String userId;
  final String username;

  const JourneyPostCommentsPage({
    super.key,
    required this.postId,
    required this.journeyId,
    required this.communityId,
    required this.userId,
    required this.username,
  });

  @override
  State<JourneyPostCommentsPage> createState() => _JourneyPostCommentsPageState();
}

class _JourneyPostCommentsPageState extends State<JourneyPostCommentsPage> {
  late JourneyCommentNotifier _commentNotifier;
  late StreamSubscription _commentSubscription;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  bool _isCommenting = false;
  String? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    _commentNotifier = JourneyCommentNotifier();
    _loadComments();
  }

  @override
  void dispose() {
    _commentSubscription?.cancel();
    _commentNotifier.dispose();
    _commentController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _loadComments() {
    _commentNotifier.setLoading(true);
    
    _commentSubscription = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('journeys')
        .doc(widget.journeyId)
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) {
      List<JourneyComment> comments = [];
      List<JourneyComment> replies = [];
      
      for (var doc in snapshot.docs) {
        final comment = JourneyComment.fromMap(doc.data());
        if (comment.parentCommentId == null) {
          comments.add(comment);
        } else {
          replies.add(comment);
        }
      }

      _commentNotifier.updateComments(comments);
      _commentNotifier.updateReplies(replies);
      _commentNotifier.setLoading(false);
    }, onError: (error) {
      _commentNotifier.setError(error.toString());
      _commentNotifier.setLoading(false);
    });
  }

  Future<void> _createComment({String? parentCommentId}) async {
    final controller = parentCommentId == null ? _commentController : _replyController;
    final content = controller.text.trim();
    
    if (content.isEmpty) {
      _showMessage('Please write something', isError: true);
      return;
    }

    if (content.length < 3) {
      _showMessage('Comment must be at least 3 characters long', isError: true);
      return;
    }

    setState(() => _isCommenting = true);

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journeyId)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc();

      await commentRef.set({
        'id': commentRef.id,
        'postId': widget.postId,
        'content': content,
        'authorId': widget.userId,
        'authorUsername': widget.username,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'repliesCount': 0,
        'parentCommentId': parentCommentId,
      });

      // Update post comment count
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journeyId)
          .collection('posts')
          .doc(widget.postId)
          .update({
        'commentsCount': FieldValue.increment(1),
      });

      // Update parent comment replies count if this is a reply
      if (parentCommentId != null) {
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('journeys')
            .doc(widget.journeyId)
            .collection('posts')
            .doc(widget.postId)
            .collection('comments')
            .doc(parentCommentId)
            .update({
          'repliesCount': FieldValue.increment(1),
        });
      }

      controller.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUsername = null;
      });
      _showMessage('Comment added successfully!');
      
    } catch (e) {
      _showMessage('Failed to add comment: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCommenting = false);
    }
  }

  Future<void> _likeComment(String commentId, bool isCurrentlyLiked) async {
    try {
      final commentRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journeyId)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId);

      final userLikeRef = commentRef.collection('likes').doc(widget.userId);
      
      if (isCurrentlyLiked) {
        // Unlike
        await userLikeRef.delete();
        await commentRef.update({'likes': FieldValue.increment(-1)});
      } else {
        // Like
        await userLikeRef.set({'timestamp': FieldValue.serverTimestamp()});
        await commentRef.update({'likes': FieldValue.increment(1)});
      }
    } catch (e) {
      _showMessage('Failed to update like: $e', isError: true);
    }
  }

  Future<void> _reportComment(String commentId, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journeyId)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .collection('reports')
          .add({
        'reportedBy': widget.userId,
        'reportedByUsername': widget.username,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      _showMessage('Comment reported successfully');
    } catch (e) {
      _showMessage('Failed to report comment: $e', isError: true);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journeyId)
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Update post comment count
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journeyId)
          .collection('posts')
          .doc(widget.postId)
          .update({
        'commentsCount': FieldValue.increment(-1),
      });

      _showMessage('Comment deleted successfully');
    } catch (e) {
      _showMessage('Failed to delete comment: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
  duration: const Duration(milliseconds: 300),
  tween: Tween(begin: 0.0, end: 1.0),
  curve: Curves.easeOutCubic,
  builder: (context, value, child) {
    return Transform.translate(
      offset: Offset(0, 50 * (1 - value)),
      child: Opacity(
        opacity: value,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A1A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: child,
        ),
      ),
    );
  },
  child: Column(
    children: [
      Container(
        margin: const EdgeInsets.only(top: 8),
        height: 4,
        width: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Text(
              'Comments',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, color: Colors.white60),
            ),
          ],
        ),
      ),
      Expanded(
        child: ChangeNotifierBuilder<JourneyCommentNotifier>(
          notifier: _commentNotifier,
          builder: (context, notifier) {
            if (notifier.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              );
            }

            if (notifier.error != null) {
              return Center(
                child: Text(
                  'Error loading comments',
                  style: GoogleFonts.poppins(color: Colors.white60),
                ),
              );
            }

            if (notifier.comments.isEmpty) {
              return Center(
                child: Text(
                  'No comments yet. Be the first to comment!',
                  style: GoogleFonts.poppins(color: Colors.white60),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: notifier.comments.length,
              itemBuilder: (context, index) {
                final comment = notifier.comments[index];
                final replies = notifier.replies
                    .where((r) => r.parentCommentId == comment.id)
                    .toList();
                
                return TweenAnimationBuilder<double>(
                  duration: Duration(milliseconds: 300 + (index * 50)),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(30 * (1 - value), 0),
                      child: Opacity(
                        opacity: value,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      CommentCard(
                        comment: comment,
                        replies: replies,
                        currentUserId: widget.userId,
                        currentUsername: widget.username,
                        onLike: _likeComment,
                        onReport: _reportComment,
                        onDelete: _deleteComment,
                        onReply: (commentId, username) {
                          setState(() {
                            _replyingToCommentId = commentId;
                            _replyingToUsername = username;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      _buildCommentInput(),
    ],
  ),
          
)
        ]
      )
      );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Column(
        children: [
          if (_replyingToCommentId != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    'Replying to @$_replyingToUsername',
                    style: GoogleFonts.poppins(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyingToCommentId = null;
                        _replyingToUsername = null;
                        _replyController.clear();
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.blue, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _replyingToCommentId == null ? _commentController : _replyController,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _replyingToCommentId == null 
                          ? 'Add a comment...' 
                          : 'Write a reply...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    maxLength: 200,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isCommenting ? null : () => _createComment(parentCommentId: _replyingToCommentId),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: _isCommenting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 16,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Comment Card Widget
class CommentCard extends StatefulWidget {
  final JourneyComment comment;
  final List<JourneyComment> replies;
  final String currentUserId;
  final String currentUsername;
  final Function(String, bool) onLike;
  final Function(String, String) onReport;
  final Function(String) onDelete;
  final Function(String, String) onReply;

  const CommentCard({
    super.key,
    required this.comment,
    required this.replies,
    required this.currentUserId,
    required this.currentUsername,
    required this.onLike,
    required this.onReport,
    required this.onDelete,
    required this.onReply,
  });

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  bool isLiked = false;
  Map<String, bool> replyLikes = {};
  bool showReplies = false;

  @override
  void initState() {
    super.initState();
    _loadLikeStatus();
  }

  Future<void> _loadLikeStatus() async {
    try {
      // Load comment like status
      final commentLikeDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc('community_id') // You'll need to pass this
          .collection('journeys')
          .doc('journey_id') // You'll need to pass this
          .collection('posts')
          .doc(widget.comment.postId)
          .collection('comments')
          .doc(widget.comment.id)
          .collection('likes')
          .doc(widget.currentUserId)
          .get();
      
      if (mounted) {
        setState(() => isLiked = commentLikeDoc.exists);
      }

      // Load reply like statuses
      for (var reply in widget.replies) {
        final replyLikeDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc('community_id') // You'll need to pass this
            .collection('journeys')
            .doc('journey_id') // You'll need to pass this
            .collection('posts')
            .doc(widget.comment.postId)
            .collection('comments')
            .doc(reply.id)
            .collection('likes')
            .doc(widget.currentUserId)
            .get();
        
        if (mounted) {
          setState(() => replyLikes[reply.id] = replyLikeDoc.exists);
        }
      }
    } catch (e) {
      print('Error loading like status: $e');
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthor = widget.comment.authorId == widget.currentUserId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(int.parse('FF${widget.comment.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                      const Color(0xFF6366F1),
                   ],
                 ),
                 shape: BoxShape.circle,
               ),
               child: Center(
                 child: Text(
                   widget.comment.authorUsername[0].toUpperCase(),
                   style: GoogleFonts.poppins(
                     fontSize: 12,
                     fontWeight: FontWeight.w700,
                     color: Colors.white,
                   ),
                 ),
               ),
             ),
             const SizedBox(width: 10),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Text(
                         '@${widget.comment.authorUsername}',
                         style: GoogleFonts.poppins(
                           fontSize: 12,
                           fontWeight: FontWeight.w600,
                           color: Colors.white,
                         ),
                       ),
                       if (isAuthor) ...[
                         const SizedBox(width: 6),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                           decoration: BoxDecoration(
                             gradient: const LinearGradient(
                               colors: [Color(0xFFF7B42C), Color(0xFFFF8C00)],
                             ),
                             borderRadius: BorderRadius.circular(6),
                           ),
                           child: Text(
                             'You',
                             style: GoogleFonts.poppins(
                               fontSize: 8,
                               fontWeight: FontWeight.w600,
                               color: Colors.white,
                             ),
                           ),
                         ),
                       ],
                     ],
                   ),
                   Text(
                     _formatTimestamp(widget.comment.createdAt),
                     style: GoogleFonts.poppins(
                       fontSize: 10,
                       color: Colors.white60,
                     ),
                   ),
                 ],
               ),
             ),
             PopupMenuButton<String>(
               icon: const Icon(Icons.more_vert, color: Colors.white60, size: 16),
               color: const Color(0xFF2A1810),
               onSelected: (value) {
                 if (value == 'delete') {
                   widget.onDelete(widget.comment.id);
                 } else if (value == 'report') {
                   _showReportDialog(widget.comment.id);
                 }
               },
               itemBuilder: (context) => [
                 if (!isAuthor)
                   PopupMenuItem(
                     value: 'report',
                     child: Row(
                       children: [
                         const Icon(Icons.flag, color: Colors.red, size: 16),
                         const SizedBox(width: 8),
                         Text('Report', style: GoogleFonts.poppins(color: Colors.white)),
                       ],
                     ),
                   ),
                 if (isAuthor)
                   PopupMenuItem(
                     value: 'delete',
                     child: Row(
                       children: [
                         const Icon(Icons.delete, color: Colors.red, size: 16),
                         const SizedBox(width: 8),
                         Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
                       ],
                     ),
                   ),
               ],
             ),
           ],
         ),

         const SizedBox(height: 12),

         // Comment Content
         Text(
           widget.comment.content,
           style: GoogleFonts.poppins(
             fontSize: 13,
             color: Colors.white,
             height: 1.4,
           ),
         ),

         const SizedBox(height: 12),

         // Comment Actions
         Row(
           children: [
             // Like Button
            GestureDetector(
  onTap: () {
    final currentLikeStatus = isLiked;
    setState(() => isLiked = !currentLikeStatus);
    widget.onLike(widget.comment.id, currentLikeStatus);
  },
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: isLiked 
                       ? Colors.red.withOpacity(0.2)
                       : Colors.white.withOpacity(0.05),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(
                     color: isLiked 
                         ? Colors.red.withOpacity(0.5)
                         : Colors.white.withOpacity(0.1),
                   ),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(
                       isLiked ? Icons.favorite : Icons.favorite_border,
                       color: isLiked ? Colors.red : Colors.white60,
                       size: 12,
                     ),
                     const SizedBox(width: 4),
                     Text(
                       widget.comment.likes.toString(),
                       style: GoogleFonts.poppins(
                         fontSize: 10,
                         color: isLiked ? Colors.red : Colors.white60,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ],
                 ),
               ),
             ),

             const SizedBox(width: 12),

             // Reply Button
             GestureDetector(
               onTap: () => widget.onReply(widget.comment.id, widget.comment.authorUsername),
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                 decoration: BoxDecoration(
                   color: Colors.white.withOpacity(0.05),
                   borderRadius: BorderRadius.circular(8),
                   border: Border.all(
                     color: Colors.white.withOpacity(0.1),
                   ),
                 ),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     const Icon(
                       Icons.reply,
                       color: Colors.white60,
                       size: 12,
                     ),
                     const SizedBox(width: 4),
                     Text(
                       'Reply',
                       style: GoogleFonts.poppins(
                         fontSize: 10,
                         color: Colors.white60,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ],
                 ),
               ),
             ),

             const Spacer(),

             // Show Replies Button
             if (widget.replies.isNotEmpty)
               GestureDetector(
                 onTap: () => setState(() => showReplies = !showReplies),
                 child: Text(
                   showReplies ? 'Hide replies' : '${widget.replies.length} replies',
                   style: GoogleFonts.poppins(
                     fontSize: 10,
                     color: const Color(0xFF6366F1),
                     fontWeight: FontWeight.w600,
                   ),
                 ),
               ),
           ],
         ),

         // Replies Section
         if (showReplies && widget.replies.isNotEmpty) ...[
           const SizedBox(height: 16),
           Container(
             margin: const EdgeInsets.only(left: 20),
             padding: const EdgeInsets.only(left: 12),
             decoration: BoxDecoration(
               border: Border(
                 left: BorderSide(
                   color: Colors.white.withOpacity(0.2),
                   width: 2,
                 ),
               ),
             ),
             child: Column(
               children: widget.replies.map((reply) {
                 final isReplyAuthor = reply.authorId == widget.currentUserId;
                 final isReplyLiked = replyLikes[reply.id] ?? false;

                 return Container(
                   margin: const EdgeInsets.only(bottom: 12),
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: Colors.white.withOpacity(0.03),
                     borderRadius: BorderRadius.circular(8),
                     border: Border.all(color: Colors.white.withOpacity(0.05)),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Reply Header
                       Row(
                         children: [
                           Container(
                             width: 24,
                             height: 24,
                             decoration: BoxDecoration(
                               gradient: LinearGradient(
                                 colors: [
                                   Color(int.parse('FF${reply.authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                                   const Color(0xFF6366F1),
                                 ],
                               ),
                               shape: BoxShape.circle,
                             ),
                             child: Center(
                               child: Text(
                                 reply.authorUsername[0].toUpperCase(),
                                 style: GoogleFonts.poppins(
                                   fontSize: 10,
                                   fontWeight: FontWeight.w700,
                                   color: Colors.white,
                                 ),
                               ),
                             ),
                           ),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Row(
                                   children: [
                                     Text(
                                       '@${reply.authorUsername}',
                                       style: GoogleFonts.poppins(
                                         fontSize: 11,
                                         fontWeight: FontWeight.w600,
                                         color: Colors.white,
                                       ),
                                     ),
                                     if (isReplyAuthor) ...[
                                       const SizedBox(width: 4),
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                         decoration: BoxDecoration(
                                           gradient: const LinearGradient(
                                             colors: [Color(0xFFF7B42C), Color(0xFFFF8C00)],
                                           ),
                                           borderRadius: BorderRadius.circular(4),
                                         ),
                                         child: Text(
                                           'You',
                                           style: GoogleFonts.poppins(
                                             fontSize: 7,
                                             fontWeight: FontWeight.w600,
                                             color: Colors.white,
                                           ),
                                         ),
                                       ),
                                     ],
                                   ],
                                 ),
                                 Text(
                                   _formatTimestamp(reply.createdAt),
                                   style: GoogleFonts.poppins(
                                     fontSize: 9,
                                     color: Colors.white60,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                           PopupMenuButton<String>(
                             icon: const Icon(Icons.more_vert, color: Colors.white60, size: 14),
                             color: const Color(0xFF2A1810),
                             onSelected: (value) {
                               if (value == 'delete') {
                                 widget.onDelete(reply.id);
                               } else if (value == 'report') {
                                 _showReportDialog(reply.id);
                               }
                             },
                             itemBuilder: (context) => [
                               if (!isReplyAuthor)
                                 PopupMenuItem(
                                   value: 'report',
                                   child: Row(
                                     children: [
                                       const Icon(Icons.flag, color: Colors.red, size: 14),
                                       const SizedBox(width: 6),
                                       Text('Report', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                                     ],
                                   ),
                                 ),
                               if (isReplyAuthor)
                                 PopupMenuItem(
                                   value: 'delete',
                                   child: Row(
                                     children: [
                                       const Icon(Icons.delete, color: Colors.red, size: 14),
                                       const SizedBox(width: 6),
                                       Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12)),
                                     ],
                                   ),
                                 ),
                             ],
                           ),
                         ],
                       ),

                       const SizedBox(height: 8),

                       // Reply Content
                       Text(
                         reply.content,
                         style: GoogleFonts.poppins(
                           fontSize: 12,
                           color: Colors.white,
                           height: 1.4,
                         ),
                       ),

                       const SizedBox(height: 8),

                       // Reply Actions
                       Row(
                         children: [
                           // Like Button for Reply
                           // Like Button for Reply
GestureDetector(
  onTap: () {
    final currentLikeStatus = replyLikes[reply.id] ?? false;
    setState(() => replyLikes[reply.id] = !currentLikeStatus);
    widget.onLike(reply.id, currentLikeStatus); // Pass current status, not negated
  },
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: isReplyLiked 
          ? Colors.red.withOpacity(0.2)
          : Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: isReplyLiked 
            ? Colors.red.withOpacity(0.5)
            : Colors.white.withOpacity(0.1),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isReplyLiked ? Icons.favorite : Icons.favorite_border,
          color: isReplyLiked ? Colors.red : Colors.white60,
          size: 10,
        ),
        const SizedBox(width: 3),
        Text(
          reply.likes.toString(),
          style: GoogleFonts.poppins(
            fontSize: 9,
            color: isReplyLiked ? Colors.red : Colors.white60,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ),
),

                           const SizedBox(width: 8),

                           // Reply to Reply Button
                           GestureDetector(
                             onTap: () => widget.onReply(widget.comment.id, reply.authorUsername),
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                               decoration: BoxDecoration(
                                 color: Colors.white.withOpacity(0.05),
                                 borderRadius: BorderRadius.circular(6),
                                 border: Border.all(
                                   color: Colors.white.withOpacity(0.1),
                                 ),
                               ),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   const Icon(
                                     Icons.reply,
                                     color: Colors.white60,
                                     size: 10,
                                   ),
                                   const SizedBox(width: 3),
                                   Text(
                                     'Reply',
                                     style: GoogleFonts.poppins(
                                       fontSize: 9,
                                       color: Colors.white60,
                                       fontWeight: FontWeight.w600,
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ),
                         ],
                       ),
                     ],
                   ),
                 );
               }).toList(),
             ),
           ),
         ],
       ],
     ),
   );
 }

 void _showReportDialog(String commentId) {
   final List<String> reportReasons = [
     'Inappropriate Content',
     'Spam',
     'Misleading Information',
     'Harassment',
     'Copyright Violation',
     'Other',
   ];
   
   String? selectedReason;
   final TextEditingController customReasonController = TextEditingController();
   
   showDialog(
     context: context,
     builder: (context) => StatefulBuilder(
       builder: (context, setDialogState) => AlertDialog(
         backgroundColor: const Color(0xFF2A1810),
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
         title: Row(
           children: [
             Container(
               padding: const EdgeInsets.all(8),
               decoration: BoxDecoration(
                 color: Colors.red.withOpacity(0.2),
                 borderRadius: BorderRadius.circular(10),
               ),
               child: const Icon(Icons.report, color: Colors.red, size: 20),
             ),
             const SizedBox(width: 12),
             Text(
               'Report Comment',
               style: GoogleFonts.poppins(
                 color: Colors.white,
                 fontWeight: FontWeight.w600,
                 fontSize: 18,
               ),
             ),
           ],
         ),
         content: SizedBox(
           width: double.maxFinite,
           child: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               ...reportReasons.map((reason) => GestureDetector(
                 onTap: () => setDialogState(() => selectedReason = reason),
                 child: Container(
                   margin: const EdgeInsets.only(bottom: 8),
                   padding: const EdgeInsets.all(12),
                   decoration: BoxDecoration(
                     color: selectedReason == reason
                         ? Colors.red.withOpacity(0.2)
                         : Colors.white.withOpacity(0.05),
                     borderRadius: BorderRadius.circular(10),
                     border: Border.all(
                       color: selectedReason == reason
                           ? Colors.red
                           : Colors.white.withOpacity(0.2),
                     ),
                   ),
                   child: Row(
                     children: [
                       Icon(
                         selectedReason == reason
                             ? Icons.radio_button_checked
                             : Icons.radio_button_unchecked,
                         color: selectedReason == reason
                             ? Colors.red
                             : Colors.white60,
                         size: 18,
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Text(
                           reason,
                           style: GoogleFonts.poppins(
                             color: selectedReason == reason
                                 ? Colors.white
                                 : Colors.white70,
                             fontSize: 13,
                           ),
                         ),
                       ),
                     ],
                   ),
                 ),
               )).toList(),
               if (selectedReason == 'Other') ...[
                 const SizedBox(height: 12),
                 TextField(
                   controller: customReasonController,
                   maxLines: 3,
                   style: GoogleFonts.poppins(color: Colors.white),
                   decoration: InputDecoration(
                     hintText: 'Please specify...',
                     hintStyle: GoogleFonts.poppins(color: Colors.white38),
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(8),
                       borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                     ),
                   ),
                 ),
               ],
             ],
           ),
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(context),
             child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white60)),
           ),
           ElevatedButton(
             onPressed: selectedReason != null
                 ? () {
                     final finalReason = selectedReason == 'Other'
                         ? customReasonController.text.trim()
                         : selectedReason!;
                     if (finalReason.isNotEmpty) {
                       Navigator.pop(context);
                       widget.onReport(commentId, finalReason);
                     }
                   }
                 : null,
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
             child: Text('Report', style: GoogleFonts.poppins(color: Colors.white)),
           ),
         ],
       ),
     ),
   );
 }
}
  // Comment Models
class JourneyComment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorUsername;
  final DateTime createdAt;
  final int likes;
  final bool isLiked;
  final int repliesCount;
  final String? parentCommentId;

  JourneyComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    required this.createdAt,
    required this.likes,
    required this.isLiked,
    required this.repliesCount,
    this.parentCommentId,
  });

  factory JourneyComment.fromMap(Map<String, dynamic> data) {
    return JourneyComment(
      id: data['id'] ?? '',
      postId: data['postId'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      isLiked: data['isLiked'] ?? false,
      repliesCount: data['repliesCount'] ?? 0,
      parentCommentId: data['parentCommentId'],
    );
  }
}

class JourneyCommentNotifier extends ChangeNotifier {
  List<JourneyComment> _comments = [];
  List<JourneyComment> _replies = [];
  bool _isLoading = false;
  String? _error;

  List<JourneyComment> get comments => _comments;
  List<JourneyComment> get replies => _replies;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void updateComments(List<JourneyComment> comments) {
    _comments = comments;
    notifyListeners();
  }

  void updateReplies(List<JourneyComment> replies) {
    _replies = replies;
    notifyListeners();
  }

  void addComment(JourneyComment comment) {
    if (comment.parentCommentId == null) {
      _comments.insert(0, comment);
    } else {
      _replies.insert(0, comment);
    }
    notifyListeners();
  }

  void updateComment(JourneyComment comment) {
    if (comment.parentCommentId == null) {
      final index = _comments.indexWhere((c) => c.id == comment.id);
      if (index != -1) {
        _comments[index] = comment;
        notifyListeners();
      }
    } else {
      final index = _replies.indexWhere((r) => r.id == comment.id);
      if (index != -1) {
        _replies[index] = comment;
        notifyListeners();
      }
    }
  }

  void removeComment(String commentId) {
    _comments.removeWhere((c) => c.id == commentId);
    _replies.removeWhere((r) => r.id == commentId);
    notifyListeners();
  }
}

class RewardAchievedPopup extends StatefulWidget {
  final String journeyId;
  final String journeyName;
  final String communityId;
  final String userId;
  final String username;
  final VoidCallback onClaimReward;

  const RewardAchievedPopup({
    super.key,
    required this.journeyId,
    required this.journeyName,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.onClaimReward,
  });

  @override
  State<RewardAchievedPopup> createState() => _RewardAchievedPopupState();
}

class _RewardAchievedPopupState extends State<RewardAchievedPopup>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _rotateAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6366F1),
              Color(0xFF4F46E5),
              Color(0xFFEC4899),
              Color(0xFFF59E0B),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Trophy
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotateAnimation.value * 0.1,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.6),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Congratulations Text
            Text(
              '🎉 CONGRATULATIONS! 🎉',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'You\'ve achieved an incredible milestone!',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            // Achievement Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '"${widget.journeyName}"',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.people, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1000+',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Followers',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.local_fire_department, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '100+',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Day Streak',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            Text(
              'You\'ve earned a special reward!',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 20),
            
            // Claim Button
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                widget.onClaimReward();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.white, Color(0xFFF8F9FA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.card_giftcard,
                      color: Color(0xFF6366F1),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CLAIM REWARD',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Close Button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Later',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RewardClaimPage extends StatefulWidget {
  final String journeyId;
  final String journeyName;
  final String communityId;
  final String userId;
  final String username;

  const RewardClaimPage({
    super.key,
    required this.journeyId,
    required this.journeyName,
    required this.communityId,
    required this.userId,
    required this.username,
  });

  @override
  State<RewardClaimPage> createState() => _RewardClaimPageState();
}

class _RewardClaimPageState extends State<RewardClaimPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submitRewardClaim() async {
    // Validation
    if (_fullNameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _zipController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty) {
      _showMessage('Please fill in all fields', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Save reward claim to Firestore
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('rewards')
          .add({
        'journeyId': widget.journeyId,
        'journeyName': widget.journeyName,
        'userId': widget.userId,
        'username': widget.username,
        'fullName': _fullNameController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'zipCode': _zipController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'claimedAt': FieldValue.serverTimestamp(),
        'status': 'pending_shipment',
      });

      // Update journey to mark reward as claimed
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('journeys')
          .doc(widget.journeyId)
          .update({
        'rewardClaimed': true,
        'rewardClaimedAt': FieldValue.serverTimestamp(),
      });

      _showSuccessDialog();
    } catch (e) {
      _showMessage('Failed to submit reward claim: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A1810),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Success!',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Your reward claim has been submitted successfully! We\'ll process your request and ship your reward within 7-10 business days.',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to main page
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
            child: Text('Got it!', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.9),
              const Color(0xFF4F46E5).withOpacity(0.7),
              const Color(0xFF3730A3).withOpacity(0.5),
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Claim Your Reward',
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Fill in your details for delivery',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reward Info Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 30),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Journey Master Achievement',
                                        style: GoogleFonts.dmSerifDisplay(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '"${widget.journeyName}"',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '🎁 Exclusive merchandise package including a premium hoodie, stickers, and a personalized certificate!',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Form Fields
                      _buildInputField(
                        'Full Name',
                        _fullNameController,
                        'Enter your full name',
                        Icons.person,
                      ),
                      
                      _buildInputField(
                        'Address',
                        _addressController,
                        'Enter your street address',
                        Icons.home,
                        maxLines: 2,
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildInputField(
                              'City',
                              _cityController,
                              'City',
                              Icons.location_city,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInputField(
                              'State',
                              _stateController,
                              'State',
                              Icons.map,
                            ),
                          ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildInputField(
                              'ZIP Code',
                              _zipController,
                              'ZIP Code',
                              Icons.markunread_mailbox,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _buildInputField(
                              'Phone Number',
                              _phoneController,
                              'Phone Number',
                              Icons.phone,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Privacy Notice
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.privacy_tip, color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Your information will only be used for reward delivery and will not be shared with third parties.',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _isSubmitting ? null : _submitRewardClaim,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: _isSubmitting
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'CLAIM REWARD',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                          ),
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

  Widget _buildInputField(
    String label,
    TextEditingController controller,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: controller,
             maxLines: maxLines,
             style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
             decoration: InputDecoration(
               hintText: hint,
               hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
               prefixIcon: Icon(icon, color: const Color(0xFF6366F1), size: 20),
               border: InputBorder.none,
               contentPadding: const EdgeInsets.all(16),
             ),
           ),
         ),
       ],
     ),
   );
 }
}
class ContactJourneyPage extends StatefulWidget {
  final Journey journey;
  final String communityId;

  const ContactJourneyPage({
    super.key,
    required this.journey,
    required this.communityId,
  });

  @override
  State<ContactJourneyPage> createState() => _ContactJourneyPageState();
}

class _ContactJourneyPageState extends State<ContactJourneyPage> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Map<String, dynamic>? _userDetails;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserDetails();
  }

  void _initAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));
    _slideController.forward();
  }

  Future<void> _sendWhatsAppMessage() async {
  if (_userDetails == null) return;
  
  final phone = _userDetails!['userPhone']?.toString() ?? '';
  if (phone.isEmpty) {
    _showMessage('Phone number not available', isError: true);
    return;
  }

  String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (cleanPhone.startsWith('0')) {
    cleanPhone = '91${cleanPhone.substring(1)}';
  } else if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
    cleanPhone = '91$cleanPhone';
  }

  final message = Uri.encodeComponent(
    'Hi ${widget.journey.authorUsername},\n\n'
    'I saw your journey "${widget.journey.name}" and I\'m interested in collaborating!\n\n'
    'Let\'s discuss further. Thanks!'
  );

  final whatsappUrls = [
    'https://wa.me/$cleanPhone?text=$message',
    'https://api.whatsapp.com/send?phone=$cleanPhone&text=$message',
    'whatsapp://send?phone=$cleanPhone&text=$message',
  ];

  bool launched = false;
  for (String urlString in whatsappUrls) {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        launched = true;
        break;
      }
    } catch (e) {
      print('Failed to launch $urlString: $e');
    }
  }

  if (!launched) {
    _showMessage('Could not open WhatsApp. Please make sure WhatsApp is installed.', isError: true);
  }
}

Future<void> _launchEmail() async {
  if (_userDetails == null) return;
  
  final email = _userDetails!['userEmail']?.toString() ?? '';
  if (email.isEmpty) {
    _showMessage('Email not available', isError: true);
    return;
  }

  final subject = 'Regarding your journey: ${widget.journey.name}';
  final body = 'Hi ${widget.journey.authorUsername},\n\n'
      'I saw your journey "${widget.journey.name}" and I\'m interested in collaborating!\n\n'
      'Let\'s discuss further.\n\n'
      'Best regards';

  final emailUrls = [
    'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    'mailto:$email',
  ];

  bool launched = false;
  for (String urlString in emailUrls) {
    try {
      final uri = Uri.parse(urlString);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        launched = true;
        break;
      }
    } catch (e) {
      print('Failed to launch $urlString: $e');
    }
  }

  if (!launched) {
    _showMessage('Could not open email app. Please check if an email app is installed.', isError: true);
  }
}

void _showMessage(String message, {bool isError = false}) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

  Future<void> _loadUserDetails() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .doc(widget.journey.authorUsername)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _userDetails = {
            ...userDoc.data()!,
            'branch': userDoc.data()!['branch'] ?? '',
            'year': userDoc.data()!['year'] ?? '',
          };
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      print('Error loading user details: $e');
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A4A00),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2D5A00),
              const Color(0xFF1A4A00),
              const Color(0xFF0D2A00),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserInfoCard(),
                        const SizedBox(height: 24),
                        _buildContactInfoCard(),
                        const SizedBox(height: 24),
                        _buildJourneyDetailsCard(),
                        const SizedBox(height: 20),
                        _buildInfoNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade900.withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.green.shade700.withOpacity(0.3),
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.green.shade300,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade700, Colors.green.shade900],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade700.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.contact_phone, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade700],
                  ).createShader(bounds),
                  child: Text(
                    'contact details',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'reach out & collaborate',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.green.shade200,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.3),
            Colors.green.shade800.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade600.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _userDetails?['profileImageUrl'] != null
                ? CircleAvatar(
                    radius: 35,
                    backgroundImage: NetworkImage(_userDetails!['profileImageUrl']),
                    backgroundColor: Colors.transparent,
                  )
                : Center(
                    child: Text(
                      widget.journey.authorUsername.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 22,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.journey.authorUsername,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                if (_userDetails != null) ...[
                  Text(
                    '${_userDetails!['firstName'] ?? ''} ${_userDetails!['lastName'] ?? ''}'.trim(),
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_userDetails != null)
            Column(
              children: [
                if (_userDetails!['branch']?.toString().isNotEmpty == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade800],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          _userDetails!['branch'].toString(),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_userDetails!['year']?.toString().isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade700],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${_userDetails!['year']}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.3),
            Colors.green.shade800.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade600.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.contact_mail, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                'Contact Information',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildContactRow(
            Icons.email,
            'Email',
            _userDetails?['email'] ?? _userDetails?['userEmail'] ?? 'Not provided',
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            Icons.phone,
            'Phone',
            _userDetails?['phoneNumber'] ?? _userDetails?['userPhone'] ?? 'Not provided',
          ),
        ],
      ),
      
    );
  }

  Widget _buildJourneyDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.3),
            Colors.green.shade800.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade800],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade600.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.rocket_launch, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                'Journey Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildDetailSection(
            'Journey Name:',
            widget.journey.name,
            Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          _buildDetailSection(
            'Description:',
            widget.journey.description,
            Colors.amber.shade400,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.2),
            Colors.green.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.info_outline, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Connect with ${widget.journey.authorUsername} about their journey "${widget.journey.name}".',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}