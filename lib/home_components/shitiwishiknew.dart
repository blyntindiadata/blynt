import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/shit_create_post.dart';
import 'package:startup/home_components/shit_post_responses.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class ShitIWishIKnewPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const ShitIWishIKnewPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  }) : super(key: key);

  @override
  State<ShitIWishIKnewPage> createState() => _ShitIWishIKnewPageState();
}

class _ShitIWishIKnewPageState extends State<ShitIWishIKnewPage> with TickerProviderStateMixin {
  final ValueNotifier<List<Map<String, dynamic>>> _allPostsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> _myPostsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;



  final FocusNode _searchFocusNode = FocusNode();
  
  bool _isSearching = false;
  String _searchQuery = '';
  String _selectedTag = 'all';
  final Map<String, Map<String, dynamic>?> _userCache = {};

  final List<String> _availableTags = [
    'all',
    'social',
    'travel buddy',
    'roommates',
    'seniors advice',
    'suggestions',
    'faculty gossip',
    'college trips',
    'academics',
    'placements',
    'internships',
    'food spots',
    'events',
    'custom'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initAnimations();
    _loadPosts();
    _loadCurrentUserData();
  }
  void _dismissKeyboard() {
  _searchFocusNode.unfocus();
  FocusScope.of(context).unfocus();
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
    _allPostsNotifier.dispose();
    _myPostsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _searchController.dispose();
    _tabController.dispose();
    _fadeController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    await _getUserData(widget.username);
  }

  Future<void> _loadPosts() async {
    try {
      _isLoadingNotifier.value = true;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('shitIWishIKnew')
          .orderBy('createdAt', descending: true)
          .get();

      final allPosts = <Map<String, dynamic>>[];
      final myPosts = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final postData = {
          'id': doc.id,
          ...data,
        };

        allPosts.add(postData);
        
        if (data['authorUsername'] == widget.username) {
          myPosts.add(postData);
        }
      }

      _allPostsNotifier.value = allPosts;
      _myPostsNotifier.value = myPosts;
    } catch (e) {
      print('Error loading posts: $e');
      if (mounted) {
        _showMessage('Error loading posts: $e', isError: true);
      }
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String username) async {
    if (_userCache.containsKey(username)) {
      return _userCache[username];
    }

    try {
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

      _userCache[username] = null;
      return null;
    } catch (e) {
      print('Error fetching user data for $username: $e');
      _userCache[username] = null;
      return null;
    }
  }

  Future<void> _deletePost(String postId, String authorUsername) async {
    final bool isAuthor = authorUsername == widget.username;
    final bool canDelete = isAuthor || ['admin', 'manager', 'moderator'].contains(widget.userRole);
    
    if (!canDelete) {
      _showMessage('You don\'t have permission to delete this post', isError: true);
      return;
    }

    String? reason;
    
    if (!isAuthor) {
      reason = await _showDeleteReasonDialog();
      if (reason == null || reason.trim().isEmpty) return;
    }

    try {
      final postRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('shitIWishIKnew')
          .doc(postId);

      if (!isAuthor && reason != null) {
        await postRef.update({
          'deletedBy': widget.username,
          'deletedByRole': widget.userRole,
          'deletionReason': reason,
          'deletedAt': FieldValue.serverTimestamp(),
          'isDeleted': true,
        });
      } else {
        await postRef.delete();
      }

      _loadPosts();
      _showMessage(isAuthor ? 'Post deleted successfully' : 'Post deleted with reason recorded');
    } catch (e) {
      _showMessage('Error deleting post: $e', isError: true);
    }
  }

  Future<String?> _showDeleteReasonDialog() async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        title: Text(
          'Delete Post',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Please provide a reason for deleting this post:',
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: GoogleFonts.poppins(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter deletion reason...',
                hintStyle: GoogleFonts.poppins(color: Colors.white38),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
            ),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : const Color(0xFFF59E0B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF0D1B2A),
    body: GestureDetector(
      onTap: _dismissKeyboard,
      child: Container(
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
              _buildHeader(),
              _buildSearchAndFilter(),
              _buildTabBar(),
              Expanded(
                child: GestureDetector(
                  onTap: _dismissKeyboard, // Add this extra layer
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildTabBarView(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    floatingActionButton: _buildCreateFAB(),
  );
}
  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.fromLTRB(
      ScreenUtil.responsiveWidth(context, 0.05), // 5% of screen width
      MediaQuery.of(context).padding.top + 16,
      ScreenUtil.responsiveWidth(context, 0.05),
      16,
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
          child: Row(
            children: [
              GestureDetector(
            onTap: () {
              _dismissKeyboard();
              Navigator.pop(context);
            },
            child: Container(
              padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 10 : 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ScreenUtil.isTablet(context) ? 14 : 12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: ScreenUtil.isTablet(context) ? 22 : 18,
              ),
            ),
          ),
              Container(
                margin: EdgeInsets.only(left:15),
                padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lightbulb, 
                  color: Colors.white, 
                  size: isCompact ? 20 : 24
                ),
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                      ).createShader(bounds),
                      child: Text(
                        'sh*t i wish i knew',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: isCompact ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                    Text(
                      'the space to exchange thoughts & have meaningful conversations',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 10 : 12,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh, 
                  color: const Color(0xFFF59E0B),
                  size: ScreenUtil.isTablet(context) ? 24 : 20,
                ),
                onPressed: _loadPosts,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchAndFilter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.symmetric(
      horizontal: ScreenUtil.responsiveWidth(context, 0.05)
    ),
          child: Column(
            children: [
              // Search Bar
              Container(
                height: ScreenUtil.isTablet(context) ? 50 : 45,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFF1B263B).withOpacity(0.3)),
          ),
                child: TextField(
  controller: _searchController,
  focusNode: _searchFocusNode,
  style: GoogleFonts.poppins(
    color: Colors.white, 
    fontSize: ResponsiveFonts.body(context)
  ),
  textAlignVertical: TextAlignVertical.center,
  decoration: InputDecoration(
    hintText: 'search...',
    hintStyle: GoogleFonts.poppins(color: Colors.white38), 
    prefixIcon: Icon(
      Icons.search, 
      color: const Color(0xFFF59E0B), 
      size: ScreenUtil.isTablet(context) ? 20 : 18
    ),
    suffixIcon: _isSearching ? GestureDetector(
      onTap: () {
        _searchController.clear();
        _searchFocusNode.unfocus();
        setState(() {
          _searchQuery = '';
          _isSearching = false;
        });
      },
      child: Icon(
        Icons.clear,
        color: const Color(0xFFF59E0B),
        size: ScreenUtil.isTablet(context) ? 20 : 18,
      ),
    ) : null,
    border: InputBorder.none,
    contentPadding: EdgeInsets.symmetric(
      horizontal: ScreenUtil.isTablet(context) ? 20 : 16, 
      vertical: ScreenUtil.isTablet(context) ? 12 : 6
    ),
  ),
  onChanged: (value) {
    setState(() {
      _searchQuery = value.toLowerCase();
      _isSearching = value.isNotEmpty;
    });
  },
  onTapOutside: (event) {
    _searchFocusNode.unfocus();
  },
),
              ),
              
              SizedBox(height: ScreenUtil.isTablet(context) ? 12 : 8),
              
              // Tag Filter
              Container(
                 height: ScreenUtil.isTablet(context) ? 45 : 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableTags.length,
                  itemBuilder: (context, index) {
                    final tag = _availableTags[index];
                    final isSelected = _selectedTag == tag;
                    
                    return Container(
                      margin: EdgeInsets.only(right: isCompact ? 6 : 8),
                      child: FilterChip(
                        label: Text(
                          tag == 'all' ? 'All' : tag,
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 10 : 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedTag = tag;
                          });
                        },
                        backgroundColor: Colors.grey[900],
                        selectedColor: const Color(0xFFF59E0B),
                        checkmarkColor: Colors.white,
                        side: BorderSide(
                          color: isSelected 
                              ? const Color(0xFFF59E0B) 
                              : const Color.fromARGB(255, 88, 88, 87).withOpacity(0.3),
                        ),
                      ),
                    );
                  },
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
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 20, 
            vertical: isCompact ? 8 : 10
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
                colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 12 : 14
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? 12 : 14
            ),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Feed'),
              Tab(text: 'My Posts'),
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
        _buildPostsList(_allPostsNotifier),
        _buildPostsList(_myPostsNotifier),
      ],
    );
  }

  Widget _buildPostsList(ValueNotifier<List<Map<String, dynamic>>> postsNotifier) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(color: const Color(0xFFF59E0B)),
          );
        }

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: postsNotifier,
          builder: (context, posts, child) {
            var visiblePosts = posts.where((post) => post['isDeleted'] != true).toList();

            // Apply search filter
            if (_isSearching) {
              visiblePosts = visiblePosts.where((post) {
                final content = (post['content'] ?? '').toString().toLowerCase();
                final username = (post['authorUsername'] ?? '').toString().toLowerCase();
                final tags = List<String>.from(post['tags'] ?? []).join(' ').toLowerCase();
                
                return content.contains(_searchQuery) ||
                       username.contains(_searchQuery) ||
                       tags.contains(_searchQuery);
              }).toList();
            }

            // Apply tag filter
            if (_selectedTag != 'all') {
              visiblePosts = visiblePosts.where((post) {
                final tags = List<String>.from(post['tags'] ?? []);
                return tags.contains(_selectedTag);
              }).toList();
            }

            if (visiblePosts.isEmpty) {
              return _buildEmptyState();
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                return FadeTransition(
  opacity: _fadeAnimation,
  child: LayoutBuilder(
    builder: (context, constraints) {
      return ListView.builder(
        padding: EdgeInsets.all(constraints.maxWidth < 400 ? 12 : 16),
        itemCount: visiblePosts.length,
        itemBuilder: (context, index) {
          final post = visiblePosts[index];
          return PostCard(
            post: post,
            currentUsername: widget.username,
            currentUserRole: widget.userRole,
            onDelete: () => _deletePost(post['id'], post['authorUsername']),
            getUserData: _getUserData,
            communityId: widget.communityId,
          );
        },
      );
    },
  ),
);
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
      final isCompact = constraints.maxWidth < 400;
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      final availableHeight = constraints.maxHeight;
      
      // Adaptive spacing based on available height
      final iconSize = isLandscape 
          ? (isCompact ? 32.0 : 40.0) 
          : (isCompact ? 48.0 : 64.0);
      final spacing = isLandscape 
          ? (isCompact ? 8.0 : 12.0) 
          : (isCompact ? 12.0 : 16.0);
      final titleSize = isLandscape 
          ? (isCompact ? 14.0 : 16.0) 
          : (isCompact ? 16.0 : 18.0);
      final subtitleSize = isLandscape 
          ? (isCompact ? 10.0 : 12.0) 
          : (isCompact ? 12.0 : 14.0);
      
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
                  Icons.lightbulb_outline, 
                  color: const Color(0xFFF59E0B), 
                  size: iconSize,
                ),
                SizedBox(height: spacing),
                Text(
                  'No posts available',
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
                    'Share something you wish you knew earlier!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: subtitleSize, 
                      color: Colors.white60
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

  Widget _buildCreateFAB() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = MediaQuery.of(context).size.width < 400;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () async {
              _dismissKeyboard(); 
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CreatePostPage(
                    communityId: widget.communityId,
                    userId: widget.userId,
                    username: widget.username,
                    userRole: widget.userRole,
                  ),
                ),
              );
              if (result == true) {
                _loadPosts();
              }
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            label: Text(
              'create post',
              style: GoogleFonts.poppins(
                fontSize: isCompact ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            icon: Icon(
              Icons.add,
              color: Colors.white,
              size: isCompact ? 18 : 20,
            ),
          ),
        );
      },
    );
  }
}

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final String currentUsername;
  final String currentUserRole;
  final VoidCallback onDelete;
  final Future<Map<String, dynamic>?> Function(String) getUserData;
  final String communityId;

  const PostCard({
    Key? key,
    required this.post,
    required this.currentUsername,
    required this.currentUserRole,
    required this.onDelete,
    required this.getUserData,
    required this.communityId,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showFullContent = false;
  final ValueNotifier<int> _commentsCountNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _loadCommentsCount();
  }

  Future<void> _loadCommentsCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('shitIWishIKnew')
          .doc(widget.post['id'])
          .collection('comments')
          .get();
      
      _commentsCountNotifier.value = snapshot.docs.length;
    } catch (e) {
      print('Error loading comments count: $e');
    }
  }

  bool get _canDelete {
    final isAuthor = widget.post['authorUsername'] == widget.currentUsername;
    final isAdmin = ['admin', 'manager', 'moderator'].contains(widget.currentUserRole);
    return isAuthor || isAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.post['content'] ?? '';
    final tags = List<String>.from(widget.post['tags'] ?? []);
    final createdAt = widget.post['createdAt'] as Timestamp?;
    final shouldTruncate = content.length > 300;
    final displayContent = _showFullContent || !shouldTruncate 
        ? content 
        : '${content.substring(0, 300)}...';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.only(bottom: isCompact ? 12 : 16),
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1B263B).withOpacity(0.2),
                const Color(0xFF0D1B2A).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1B263B).withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: isCompact ? 6 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with user info and delete button
              FutureBuilder<Map<String, dynamic>?>(
                future: widget.getUserData(widget.post['authorUsername'] ?? ''),
                builder: (context, snapshot) {
                  final userData = snapshot.data;
                  final firstName = userData?['firstName'] ?? '';
                  final lastName = userData?['lastName'] ?? '';
                  final branch = userData?['branch'] ?? '';
                  final year = userData?['year'] ?? '';
                  final profileImageUrl = userData?['profileImageUrl'];
                  final role = userData?['role'] ?? 'member';

                  return Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: isCompact ? 16 : 20,
                            backgroundImage: profileImageUrl != null 
                                ? NetworkImage(profileImageUrl) 
                                : null,
                            backgroundColor: const Color(0xFFF59E0B),
                            child: profileImageUrl == null
                                ? Text(
                                    (widget.post['authorUsername'] ?? 'U').substring(0, 1).toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      fontSize: isCompact ? 12 : 14,
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(width: isCompact ? 8 : 12),
                          Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              firstName.isNotEmpty || lastName.isNotEmpty 
                ? '$firstName $lastName'.trim() 
                : widget.post['authorUsername'] ?? 'Unknown',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: isCompact ? 14 : 16,
              ),
            ),
          ),
          // Branch and Year tags on the right
          if (branch.isNotEmpty || year.isNotEmpty)
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (branch.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      branch,
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 8 : 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                if (year.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFFD97706), const Color(0xFFB45309)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      year,
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 8 : 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                username: widget.post['authorUsername'] ?? 'Unknown',
                communityId: widget.communityId,
              ),
            ),
          );
        },
        child: Text(
          '@${widget.post['authorUsername'] ?? 'Unknown'}',
          style: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: isCompact ? 10 : 12,
          ),
        ),
      ),
    ],
  ),
),
                          if (_canDelete)
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: Colors.red.shade400,
                                size: isCompact ? 18 : 20,
                              ),
                              onPressed: widget.onDelete,
                            ),
                        ],
                      ),

                      // Branch and Year tags
                      if (branch.isNotEmpty || year.isNotEmpty) ...[
                        SizedBox(height: isCompact ? 6 : 8),
                        Row(
                          children: [
                            SizedBox(width: isCompact ? 40 : 44),
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  if (branch.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        branch,
                                        style: GoogleFonts.poppins(
                                          fontSize: isCompact ? 8 : 9,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (year.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [const Color(0xFFD97706), const Color(0xFFB45309)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        year,
                                        style: GoogleFonts.poppins(
                                          fontSize: isCompact ? 8 : 9,
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
                },
              ),

              SizedBox(height: isCompact ? 12 : 16),

              // Content
              Text(
                displayContent,
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 13 : 15,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),

              if (shouldTruncate) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFullContent = !_showFullContent;
                    });
                  },
                  child: Text(
                    _showFullContent ? 'Show less' : 'Read more',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 12 : 13,
                      color: const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              SizedBox(height: isCompact ? 12 : 16),

              // Tags
              if (tags.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags.map((tag) => Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 6 : 8, 
                      vertical: 4
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF59E0B).withOpacity(0.2),
                          const Color(0xFFD97706).withOpacity(0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 10 : 11,
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                ),

              SizedBox(height: isCompact ? 12 : 16),

              // Footer with comments and timestamp
              Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      FocusScope.of(context).unfocus();
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostCommentsPage(
                            post: widget.post,
                            communityId: widget.communityId,
                            currentUsername: widget.currentUsername,
                            currentUserRole: widget.currentUserRole,
                            getUserData: widget.getUserData,
                            currentUserId: widget.currentUsername,
                          ),
                        ),
                      );
                      _loadCommentsCount();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 8 : 12, 
                        vertical: 6
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.comment_outlined, 
                            color: Colors.white, 
                            size: isCompact ? 12 : 14
                          ),
                          const SizedBox(width: 4),
                          ValueListenableBuilder<int>(
                            valueListenable: _commentsCountNotifier,
                            builder: (context, count, child) {
                              return Text(
                                'Comments ($count)',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: isCompact ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (createdAt != null)
                    Text(
                      _formatTimestamp(createdAt),
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: isCompact ? 9 : 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
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

  @override
  void dispose() {
    _commentsCountNotifier.dispose();
    super.dispose();
  }
}
class ScreenUtil {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
  
  static bool isTablet(BuildContext context) => screenWidth(context) > 600;
  static bool isDesktop(BuildContext context) => screenWidth(context) > 1200;
  
  static double responsiveWidth(BuildContext context, double fraction) {
    return screenWidth(context) * fraction;
  }
}

class ResponsiveFonts {
  static double title(BuildContext context) {
    if (ScreenUtil.isTablet(context)) return 28;
    return 24;
  }
  
  static double body(BuildContext context) {
    if (ScreenUtil.isTablet(context)) return 16;
    return 14;
  }
  
  static double caption(BuildContext context) {
    if (ScreenUtil.isTablet(context)) return 14;
    return 12;
  }
}