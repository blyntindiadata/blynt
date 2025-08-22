import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class PostCommentsPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final String communityId;
  final String currentUsername;
  final String currentUserRole;
  final Future<Map<String, dynamic>?> Function(String) getUserData;

  const PostCommentsPage({
    Key? key,
    required this.post,
    required this.communityId,
    required this.currentUsername,
    required this.currentUserRole,
    required this.getUserData,
  }) : super(key: key);

  @override
  State<PostCommentsPage> createState() => _PostCommentsPageState();
}

class _PostCommentsPageState extends State<PostCommentsPage> with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _commentFocusNode = FocusNode();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Static data - no rebuilds after initial load
  List<Map<String, dynamic>> _comments = [];
  final Map<String, Map<String, dynamic>?> _userCache = {};
  final Map<String, GlobalKey> _commentKeys = {};
  
  // Only for initial loading state
  bool _isInitialLoading = true;
  
  // UI state - minimal updates
  bool _isPosting = false;
  String? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadCommentsOnce(); // Only load once
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

  void _dismissKeyboard() {
    _commentFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  // LOAD COMMENTS ONLY ONCE - NO RELOADING
Future<void> _loadCommentsOnce() async {
  try {
    final commentsSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('shitIWishIKnew')
        .doc(widget.post['id'])
        .collection('comments')
        .orderBy('createdAt', descending: true) // CHANGED: true for most recent first
        .get();

    final comments = <Map<String, dynamic>>[];
    
    for (var doc in commentsSnapshot.docs) {
      final data = doc.data();
      final commentData = {
        'id': doc.id,
        ...data,
      };
      
      // Load replies for each comment
      final repliesSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('shitIWishIKnew')
          .doc(widget.post['id'])
          .collection('comments')
          .doc(doc.id)
          .collection('replies')
          .orderBy('createdAt', descending: true) // CHANGED: true for most recent first
          .get();
      
      final replies = repliesSnapshot.docs.map((replyDoc) => {
        'id': replyDoc.id,
        ...replyDoc.data(),
      }).toList();
      
      commentData['replies'] = replies;
      comments.add(commentData);
    }
    
    // Set data once and never reload
    if (mounted) {
      setState(() {
        _comments = comments;
        _isInitialLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Error loading comments: $e');
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }
}

  // POST COMMENT - ADD TO LIST WITHOUT RELOADING
  Future<void> _postComment() async {
    final content = _commentController.text.trim();
    
    if (content.isEmpty) {
      _showMessage('Please enter a comment', isError: true);
      return;
    }

    _dismissKeyboard();

    try {
      setState(() => _isPosting = true);

      if (_replyingToCommentId != null) {
        // Post as reply - add to existing comment without reload
        final replyRef = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('shitIWishIKnew')
            .doc(widget.post['id'])
            .collection('comments')
            .doc(_replyingToCommentId)
            .collection('replies')
            .add({
          'content': content,
          'authorUsername': widget.currentUsername,
          'authorRole': widget.currentUserRole,
          'replyingTo': _replyingToUsername,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Add reply to existing comment in memory
        _addReplyToComment(_replyingToCommentId!, replyRef.id, content);
        // _scrollToComment(_replyingToCommentId!);
      } else {
        // Post as comment - add to list without reload
        final commentRef = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('shitIWishIKnew')
            .doc(widget.post['id'])
            .collection('comments')
            .add({
          'content': content,
          'authorUsername': widget.currentUsername,
          'authorRole': widget.currentUserRole,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Add comment to list in memory
        _addCommentToList(commentRef.id, content);
        // _scrollToComment(commentRef.id);
      }

      _commentController.clear();
      _cancelReply();
    } catch (e) {
      _showMessage('Error posting comment: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  // ADD COMMENT TO MEMORY - NO RELOAD
void _addCommentToList(String commentId, String content) {
  final newComment = {
    'id': commentId,
    'content': content,
    'authorUsername': widget.currentUsername,
    'authorRole': widget.currentUserRole,
    'createdAt': Timestamp.now(),
    'replies': <Map<String, dynamic>>[],
  };

  setState(() {
    _comments.insert(0, newComment); // CHANGED: insert(0, ...) for most recent first
    // Generate key for the new comment
    _commentKeys[commentId] = GlobalKey();
  });
}
  // ADD REPLY TO EXISTING COMMENT - NO RELOAD
void _addReplyToComment(String commentId, String replyId, String content) {
  final newReply = {
    'id': replyId,
    'content': content,
    'authorUsername': widget.currentUsername,
    'authorRole': widget.currentUserRole,
    'replyingTo': _replyingToUsername,
    'createdAt': Timestamp.now(),
  };

  setState(() {
    final commentIndex = _comments.indexWhere((comment) => comment['id'] == commentId);
    if (commentIndex != -1) {
      final replies = List<Map<String, dynamic>>.from(_comments[commentIndex]['replies'] ?? []);
      replies.insert(0, newReply); // CHANGED: insert(0, ...) for most recent first
      _comments[commentIndex]['replies'] = replies;
    }
  });
}

  void _scrollToComment(String commentId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        final key = _commentKeys[commentId];
        if (key?.currentContext != null && mounted) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    });
  }

  void _replyToComment(String commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        FocusScope.of(context).requestFocus(_commentFocusNode);
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
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

  void _navigateToUserProfile(String? username) {
  if (username != null) {
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

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _commentFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildPostSummary(),
                  Expanded(
                    child: _buildCommentsList(),
                  ),
                  _buildCommentInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        ScreenUtil.responsiveWidth(context, 0.05),
        MediaQuery.of(context).padding.top + 8,
        ScreenUtil.responsiveWidth(context, 0.05),
        16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B263B).withOpacity(0.3),
            Colors.transparent,
          ],
        ),
      ),
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
            margin: const EdgeInsets.only(left: 20),
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
              Icons.comment, 
              color: Colors.white, 
              size: ScreenUtil.isTablet(context) ? 24 : 20,
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
                    'comments',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: ResponsiveFonts.title(context),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                Text(
                  'join the discussion',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveFonts.caption(context),
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostSummary() {
    final content = widget.post['content'] ?? '';
    final displayContent = content.length > 150 
        ? '${content.substring(0, 150)}...' 
        : content;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: ScreenUtil.responsiveWidth(context, 0.05)
      ),
      padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 16 : 12),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: const Color(0xFFF59E0B),
                size: ScreenUtil.isTablet(context) ? 18 : 16,
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
              Text(
                'Original Post',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveFonts.body(context),
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          SizedBox(height: ScreenUtil.isTablet(context) ? 8 : 6),
          Text(
            displayContent,
            style: GoogleFonts.poppins(
              fontSize: ResponsiveFonts.caption(context),
              color: Colors.white70,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildCommentsList() {
  // ONLY show shimmer during initial load
  if (_isInitialLoading) {
    return _buildCommentsShimmer();
  }

  // NO REBUILDS after initial load
  if (_comments.isEmpty) {
    return _buildEmptyComments();
  }

  // Generate keys only once when comments are first loaded
  for (var comment in _comments) {
    if (!_commentKeys.containsKey(comment['id'])) {
      _commentKeys[comment['id']] = GlobalKey();
    }
  }

  return ListView.builder(
    controller: _scrollController,
    padding: EdgeInsets.all(ScreenUtil.responsiveWidth(context, 0.04)),
    itemCount: _comments.length,
    cacheExtent: 2000,
    addAutomaticKeepAlives: true,
    addRepaintBoundaries: true,
    physics: const BouncingScrollPhysics(),
    itemBuilder: (context, index) {
      final comment = _comments[index];
      final commentKey = _commentKeys[comment['id']]!; // Use existing key
      
      return Container(
        key: commentKey,
        child: CommentCard(
          key: ValueKey('comment_${comment['id']}'),
          comment: comment,
          currentUsername: widget.currentUsername,
          currentUserRole: widget.currentUserRole,
          getUserData: widget.getUserData,
          communityId: widget.communityId,
          onReply: () => _replyToComment(comment['id'], comment['authorUsername']),
        ),
      );
    },
  );
}
  Widget _buildCommentsShimmer() {
    return ListView.builder(
      padding: EdgeInsets.all(ScreenUtil.responsiveWidth(context, 0.04)),
      itemCount: 5,
      itemBuilder: (context, index) {
        return _buildCommentShimmerItem();
      },
    );
  }

  Widget _buildCommentShimmerItem() {
    return Container(
      margin: EdgeInsets.only(bottom: ScreenUtil.isTablet(context) ? 16 : 12),
      padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 16 : 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: ScreenUtil.isTablet(context) ? 36 : 28,
                  height: ScreenUtil.isTablet(context) ? 36 : 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: ScreenUtil.isTablet(context) ? 12 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: ScreenUtil.isTablet(context) ? 12 : 8),
            Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 16,
              width: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyComments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.comment_outlined, 
            color: const Color(0xFFF59E0B), 
            size: ScreenUtil.isTablet(context) ? 64 : 48,
          ),
          SizedBox(height: ScreenUtil.isTablet(context) ? 16 : 12),
          Text(
            'No comments yet',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveFonts.title(context) - 4,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Be the first to comment!',
            style: GoogleFonts.poppins(
              fontSize: ResponsiveFonts.body(context), 
              color: Colors.white60
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.all(ScreenUtil.responsiveWidth(context, 0.04)),
      decoration: BoxDecoration(
        color: const Color(0xFF1B263B).withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Reply indicator
          if (_replyingToCommentId != null) ...[
            Container(
              padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 10 : 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    color: const Color(0xFFF59E0B),
                    size: ScreenUtil.isTablet(context) ? 18 : 16,
                  ),
                  SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
                  Expanded(
                    child: Text(
                      'Replying to @$_replyingToUsername',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveFonts.caption(context),
                        color: const Color(0xFFF59E0B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _cancelReply,
                    icon: Icon(
                      Icons.close,
                      color: const Color(0xFFF59E0B),
                      size: ScreenUtil.isTablet(context) ? 18 : 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: ScreenUtil.isTablet(context) ? 10 : 8),
          ],
          
          // Comment input
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: ScreenUtil.isTablet(context) ? 120 : 100,
                    minHeight: ScreenUtil.isTablet(context) ? 50 : 45,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xFF1B263B).withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: ResponsiveFonts.body(context),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _replyingToCommentId != null 
                          ? 'Write a reply...' 
                          : 'Write a comment...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: ScreenUtil.isTablet(context) ? 20 : 16,
                        vertical: ScreenUtil.isTablet(context) ? 12 : 10,
                      ),
                    ),
                    onTapOutside: (event) {
                      _commentFocusNode.unfocus();
                    },
                  ),
                ),
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 12 : 8),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: IconButton(
                  onPressed: _isPosting ? null : _postComment,
                  icon: _isPosting
                      ? SizedBox(
                          width: ScreenUtil.isTablet(context) ? 20 : 18,
                          height: ScreenUtil.isTablet(context) ? 20 : 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: Colors.white,
                          size: ScreenUtil.isTablet(context) ? 20 : 18,
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

class CommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String currentUsername;
  final String currentUserRole;
  final Future<Map<String, dynamic>?> Function(String) getUserData;
  final String communityId;
  final VoidCallback onReply;

  const CommentCard({
    Key? key,
    required this.comment,
    required this.currentUsername,
    required this.currentUserRole,
    required this.getUserData,
    required this.communityId,
    required this.onReply,
  }) : super(key: key);

@override
Widget build(BuildContext context) {
  final createdAt = comment['createdAt'] as Timestamp?;
  final replies = List<Map<String, dynamic>>.from(comment['replies'] ?? []);

  // Define navigation method inside build context
  void navigateToUserProfile(String? username) {
    if (username != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            username: username,
            communityId: communityId,
          ),
        ),
      );
    }
  }

  return Container(
    margin: EdgeInsets.only(bottom: ScreenUtil.isTablet(context) ? 16 : 12),
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
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 16 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header
          _buildUserInfo(context, navigateToUserProfile),
          SizedBox(height: ScreenUtil.isTablet(context) ? 12 : 8),

          // Comment content with proper padding
          Padding(
            padding: EdgeInsets.only(
              left: ScreenUtil.isTablet(context) ? 42 : 30, // Align with user info
              right: 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment text
                Text(
                  comment['content'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveFonts.body(context) - 1,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
                
                SizedBox(height: ScreenUtil.isTablet(context) ? 12 : 8),

                // Reply button aligned with content
                Row(
                  children: [
                    GestureDetector(
                      onTap: onReply,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ScreenUtil.isTablet(context) ? 12 : 8,
                          vertical: ScreenUtil.isTablet(context) ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reply,
                              color: const Color(0xFFF59E0B),
                              size: ScreenUtil.isTablet(context) ? 16 : 12,
                            ),
                            SizedBox(width: ScreenUtil.isTablet(context) ? 6 : 4),
                            Text(
                              'Reply',
                              style: GoogleFonts.poppins(
                                fontSize: ResponsiveFonts.caption(context),
                                color: const Color(0xFFF59E0B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(), // Push timestamp to the right if needed
                    if (createdAt != null)
                      Text(
                        _formatTimestamp(createdAt),
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: ResponsiveFonts.caption(context) - 3,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Replies
          if (replies.isNotEmpty) ...[
            SizedBox(height: ScreenUtil.isTablet(context) ? 16 : 12),
            Container(
              margin: EdgeInsets.only(left: ScreenUtil.isTablet(context) ? 42 : 30),
              padding: EdgeInsets.only(left: ScreenUtil.isTablet(context) ? 12 : 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: const Color(0xFFF59E0B).withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: replies.map((reply) => ReplyCard(
                  key: ValueKey('reply_${reply['id']}'),
                  reply: reply,
                  currentUsername: currentUsername,
                  currentUserRole: currentUserRole,
                  getUserData: getUserData,
                  communityId: communityId,
                )).toList(),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildUserInfo(BuildContext context, Function(String?) navigateToUserProfile) {
  return FutureBuilder<Map<String, dynamic>?>(
    future: getUserData(comment['authorUsername'] ?? ''),
    builder: (context, snapshot) {
      final userData = snapshot.data;
      final firstName = userData?['firstName'] ?? '';
      final lastName = userData?['lastName'] ?? '';
      final branch = userData?['branch'] ?? '';
      final year = userData?['year'] ?? '';
      final profileImageUrl = userData?['profileImageUrl'];
      
      return Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => navigateToUserProfile(comment['authorUsername']),
                child: CircleAvatar(
                  radius: ScreenUtil.isTablet(context) ? 18 : 14,
                  backgroundImage: profileImageUrl != null 
                      ? NetworkImage(profileImageUrl) 
                      : null,
                  backgroundColor: const Color(0xFFF59E0B),
                  child: profileImageUrl == null
                      ? Text(
                          (comment['authorUsername'] ?? 'U').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: ScreenUtil.isTablet(context) ? 14 : 10,
                          ),
                        )
                      : null,
                ),
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 12 : 8),
             Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (firstName.isNotEmpty || lastName.isNotEmpty)
        Text(
          '$firstName $lastName'.trim(),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
            fontSize: ResponsiveFonts.body(context),
          ),
        ),
      GestureDetector(
        onTap: () => navigateToUserProfile(comment['authorUsername']),
        child: Text(
          '@${comment['authorUsername'] ?? 'Unknown'}',
          style: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: ResponsiveFonts.caption(context) - 2,
          ),
        ),
      ),
    ],
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
              fontSize: 8,
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
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
    ],
  ),
            ],
          ),
          
          // Branch and Year tags
          // if (branch.isNotEmpty || year.isNotEmpty) ...[
          //   SizedBox(height: ScreenUtil.isTablet(context) ? 6 : 4),
          //   Row(
          //     children: [
          //       SizedBox(width: ScreenUtil.isTablet(context) ? 42 : 30),
          //       Expanded(
          //         child: Wrap(
          //           spacing: 4,
          //           runSpacing: 4,
          //           children: [
          //             if (branch.isNotEmpty)
          //               Container(
          //                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          //                 decoration: BoxDecoration(
          //                   gradient: LinearGradient(
          //                     colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          //                   ),
          //                   borderRadius: BorderRadius.circular(6),
          //                 ),
          //                 child: Text(
          //                   branch,
          //                   style: GoogleFonts.poppins(
          //                     fontSize: 8,
          //                     fontWeight: FontWeight.w600,
          //                     color: Colors.white,
          //                   ),
          //                 ),
          //               ),
          //             if (year.isNotEmpty)
          //               Container(
          //                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          //                 decoration: BoxDecoration(
          //                   gradient: LinearGradient(
          //                     colors: [const Color(0xFFD97706), const Color(0xFFB45309)],
          //                   ),
          //                   borderRadius: BorderRadius.circular(6),
          //                 ),
          //                 child: Text(
          //                   year,
          //                   style: GoogleFonts.poppins(
          //                     fontSize: 8,
          //                     fontWeight: FontWeight.w600,
          //                     color: Colors.white,
          //                   ),
          //                 ),
          //               ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ],
        ],
      );
    },
  );
}

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

class ReplyCard extends StatelessWidget {
  final Map<String, dynamic> reply;
  final String currentUsername;
  final String currentUserRole;
  final Future<Map<String, dynamic>?> Function(String) getUserData;
  final String communityId; // Add this

  const ReplyCard({
    Key? key,
    required this.reply,
    required this.currentUsername,
    required this.currentUserRole,
    required this.getUserData,
    required this.communityId, // Add this
  }) : super(key: key);

@override
Widget build(BuildContext context) {
  final createdAt = reply['createdAt'] as Timestamp?;
  final replyingTo = reply['replyingTo'];

  // Define navigation method inside build context
  void navigateToUserProfile(String? username) {
    if (username != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            username: username,
            communityId: communityId,
          ),
        ),
      );
    }
  }

  return Container(
    margin: EdgeInsets.only(bottom: ScreenUtil.isTablet(context) ? 12 : 8),
    padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 12 : 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.white.withOpacity(0.05),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reply header with FutureBuilder
        _buildReplyUserInfo(context, navigateToUserProfile),
        
        SizedBox(height: ScreenUtil.isTablet(context) ? 8 : 6),

        // Replying to indicator
        if (replyingTo != null) ...[
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ScreenUtil.isTablet(context) ? 8 : 6,
              vertical: ScreenUtil.isTablet(context) ? 4 : 2,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Replying to @$replyingTo',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveFonts.caption(context) - 2,
                color: const Color(0xFFF59E0B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(height: ScreenUtil.isTablet(context) ? 6 : 4),
        ],

        // Reply content
        Text(
          reply['content'] ?? '',
          style: GoogleFonts.poppins(
            fontSize: ResponsiveFonts.caption(context),
            color: Colors.white,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

Widget _buildReplyUserInfo(BuildContext context, Function(String?) navigateToUserProfile) {
  final createdAt = reply['createdAt'] as Timestamp?;
  
  return FutureBuilder<Map<String, dynamic>?>(
    future: getUserData(reply['authorUsername'] ?? ''),
    builder: (context, snapshot) {
      final userData = snapshot.data;
      final firstName = userData?['firstName'] ?? '';
      final lastName = userData?['lastName'] ?? '';
      final branch = userData?['branch'] ?? '';
      final year = userData?['year'] ?? '';
      final profileImageUrl = userData?['profileImageUrl'];
      
      return Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => navigateToUserProfile(reply['authorUsername']),
                child: CircleAvatar(
                  radius: ScreenUtil.isTablet(context) ? 14 : 10,
                  backgroundImage: profileImageUrl != null 
                      ? NetworkImage(profileImageUrl) 
                      : null,
                  backgroundColor: const Color(0xFFD97706),
                  child: profileImageUrl == null
                      ? Text(
                          (reply['authorUsername'] ?? 'U').substring(0, 1).toUpperCase(),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: ScreenUtil.isTablet(context) ? 10 : 8,
                          ),
                        )
                      : null,
                ),
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
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
                : reply['authorUsername'] ?? 'Unknown',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: ResponsiveFonts.caption(context),
              ),
            ),
          ),
          if (createdAt != null)
            Text(
              _formatTimestamp(createdAt),
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: ResponsiveFonts.caption(context) - 4,
              ),
            ),
        ],
      ),
      GestureDetector(
        onTap: () => navigateToUserProfile(reply['authorUsername']),
        child: Text(
          '@${reply['authorUsername'] ?? 'Unknown'}',
          style: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: ResponsiveFonts.caption(context) - 3,
          ),
        ),
      ),
    ],
  ),
),
// Branch and Year tags on the right for replies
if (branch.isNotEmpty || year.isNotEmpty)
  Wrap(
    spacing: 3,
    runSpacing: 3,
    children: [
      if (branch.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            branch,
            style: GoogleFonts.poppins(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      if (year.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFD97706), const Color(0xFFB45309)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            year,
            style: GoogleFonts.poppins(
              fontSize: 7,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
    ],
  ),
            ],
          ),
          
          // Branch and Year tags for replies
          // if (branch.isNotEmpty || year.isNotEmpty) ...[
          //   SizedBox(height: ScreenUtil.isTablet(context) ? 4 : 2),
          //   Row(
          //     children: [
          //       SizedBox(width: ScreenUtil.isTablet(context) ? 36 : 24),
          //       Expanded(
          //         child: Wrap(
          //           spacing: 3,
          //           runSpacing: 3,
          //           children: [
          //             if (branch.isNotEmpty)
          //               Container(
          //                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          //                 decoration: BoxDecoration(
          //                   gradient: LinearGradient(
          //                     colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
          //                   ),
          //                   borderRadius: BorderRadius.circular(4),
          //                 ),
          //                 child: Text(
          //                   branch,
          //                   style: GoogleFonts.poppins(
          //                     fontSize: 7,
          //                     fontWeight: FontWeight.w600,
          //                     color: Colors.white,
          //                   ),
          //                 ),
          //               ),
          //             if (year.isNotEmpty)
          //               Container(
          //                 padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          //                 decoration: BoxDecoration(
          //                   gradient: LinearGradient(
          //                     colors: [const Color(0xFFD97706), const Color(0xFFB45309)],
          //                   ),
          //                   borderRadius: BorderRadius.circular(4),
          //                 ),
          //                 child: Text(
          //                   year,
          //                   style: GoogleFonts.poppins(
          //                     fontSize: 7,
          //                     fontWeight: FontWeight.w600,
          //                     color: Colors.white,
          //                   ),
          //                 ),
          //               ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ],
        ],
      );
    },
  );
}
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

// Responsive utility classes
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