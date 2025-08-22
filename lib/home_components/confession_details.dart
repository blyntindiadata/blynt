import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_screen.dart';

class ConfessionDetailsPage extends StatefulWidget {
  final Map<String, dynamic> confession;
  final String currentUsername;
  final String currentUserRole;
  final String communityId;
  final Future<Map<String, dynamic>?> Function(String) getUserData;

  const ConfessionDetailsPage({
    Key? key,
    required this.confession,
    required this.currentUsername,
    required this.currentUserRole,
    required this.communityId,
    required this.getUserData,
  }) : super(key: key);

  @override
  State<ConfessionDetailsPage> createState() => _ConfessionDetailsPageState();
}

class _ConfessionDetailsPageState extends State<ConfessionDetailsPage> with TickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ValueNotifier<List<Map<String, dynamic>>> _commentsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<bool> _isPostingNotifier = ValueNotifier(false);
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  String? _replyingToCommentId;
  String? _replyingToUsername;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadComments();
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
    _commentController.dispose();
    _commentsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _isPostingNotifier.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      _isLoadingNotifier.value = true;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(widget.confession['id'])
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .get();

      final comments = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      _commentsNotifier.value = comments;
    } catch (e) {
      print('Error loading comments: $e');
      _showMessage('Error loading comments: $e', isError: true);
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) {
      _showMessage('Please write a comment', isError: true);
      return;
    }

    _isPostingNotifier.value = true;

    try {
      final commentRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(widget.confession['id'])
          .collection('comments')
          .doc();

      await commentRef.set({
        'content': _commentController.text.trim(),
        'authorUsername': widget.currentUsername,
        'createdAt': FieldValue.serverTimestamp(),
        'parentCommentId': _replyingToCommentId,
        'replyingTo': _replyingToUsername,
        'likes': [],
        'likesCount': 0,
      });

      _commentController.clear();
      _replyingToCommentId = null;
      _replyingToUsername = null;
      _loadComments();
      
      _showMessage('Comment posted successfully');
    } catch (e) {
      _showMessage('Error posting comment: $e', isError: true);
    } finally {
      _isPostingNotifier.value = false;
    }
  }

  Future<void> _likeComment(String commentId) async {
    try {
      final commentRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(widget.confession['id'])
          .collection('comments')
          .doc(commentId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        
        if (!commentDoc.exists) {
          throw Exception('Comment not found');
        }

        final commentData = commentDoc.data()!;
        final likes = List<String>.from(commentData['likes'] ?? []);

        if (likes.contains(widget.currentUsername)) {
          likes.remove(widget.currentUsername);
        } else {
          likes.add(widget.currentUsername);
        }

        transaction.update(commentRef, {
          'likes': likes,
          'likesCount': likes.length,
        });
      });

      _loadComments();
    } catch (e) {
      _showMessage('Error updating like: $e', isError: true);
    }
  }

  Future<void> _deleteComment(String commentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(widget.confession['id'])
          .collection('comments')
          .doc(commentId)
          .delete();

      _loadComments();
      _showMessage('Comment deleted successfully');
    } catch (e) {
      _showMessage('Error deleting comment: $e', isError: true);
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

  void _startReply(String commentId, String username) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUsername = username;
    });
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUsername = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8B5CF6).withOpacity(0.1),
              const Color(0xFFA855F7).withOpacity(0.05),
              const Color(0xFF0D1B2A),
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
                Expanded(
                  child: Column(
                    children: [
                      _buildConfessionCard(),
                      const SizedBox(height: 16),
                      Expanded(child: _buildCommentsList()),
                    ],
                  ),
                ),
                _buildCommentInput(),
              ],
            ),
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
            const Color(0xFF8B5CF6).withOpacity(0.2),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Confession Comments',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfessionCard() {
    final content = widget.confession['content'] ?? '';
    final createdAt = widget.confession['createdAt'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.15),
            const Color(0xFFA855F7).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info
          Row(
            children: [
              if (!widget.confession['isAnonymous']) ...[
                FutureBuilder<Map<String, dynamic>?>(
                  future: widget.getUserData(widget.confession['authorUsername']),
                  builder: (context, snapshot) {
                    final userData = snapshot.data;
                    final profileImageUrl = userData?['profileImageUrl'];
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              username: widget.confession['authorUsername'],
                              communityId: widget.communityId,
                            ),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: profileImageUrl != null 
                            ? NetworkImage(profileImageUrl) 
                            : null,
                        backgroundColor: const Color(0xFF8B5CF6),
                        child: profileImageUrl == null
                            ? Text(
                                (userData?['firstName'] ?? 'A').substring(0, 1).toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ] else ...[
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF8B5CF6),
                  child: const Icon(Icons.person, color: Colors.white, size: 20),
                ),
              ],
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.confession['isAnonymous']) ...[
                      FutureBuilder<Map<String, dynamic>?>(
                        future: widget.getUserData(widget.confession['authorUsername']),
                        builder: (context, snapshot) {
                          final userData = snapshot.data;
                          final firstName = userData?['firstName'] ?? '';
                          final lastName = userData?['lastName'] ?? '';
                          
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(
                                    username: widget.confession['authorUsername'],
                                    communityId: widget.communityId,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              '$firstName $lastName'.trim(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      Text(
                        'Anonymous',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Content
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          
          if (createdAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Posted ${_formatTimestamp(createdAt)}',
              style: GoogleFonts.poppins(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
          );
        }

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _commentsNotifier,
          builder: (context, comments, child) {
            if (comments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      color: const Color(0xFF8B5CF6),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No comments yet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Be the first to comment!',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              );
            }

            // Organize comments with replies
            final topLevelComments = comments.where((c) => c['parentCommentId'] == null).toList();
            final replies = comments.where((c) => c['parentCommentId'] != null).toList();

            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: topLevelComments.length,
              itemBuilder: (context, index) {
                final comment = topLevelComments[index];
                final commentReplies = replies.where((r) => r['parentCommentId'] == comment['id']).toList();
                
                return Column(
                  children: [
                    _buildCommentCard(comment, false),
                    if (commentReplies.isNotEmpty) ...[
                      ...commentReplies.map((reply) => Padding(
                        padding: const EdgeInsets.only(left: 40),
                        child: _buildCommentCard(reply, true),
                      )),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommentCard(Map<String, dynamic> comment, bool isReply) {
    final content = comment['content'] ?? '';
    final authorUsername = comment['authorUsername'] ?? '';
    final createdAt = comment['createdAt'] as Timestamp?;
    final likes = List<String>.from(comment['likes'] ?? []);
    final likesCount = comment['likesCount'] ?? 0;
    final hasLiked = likes.contains(widget.currentUsername);
    final replyingTo = comment['replyingTo'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(isReply ? 0.05 : 0.08),
            Colors.white.withOpacity(isReply ? 0.02 : 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isReply 
              ? Colors.white.withOpacity(0.1)
              : const Color(0xFF8B5CF6).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author info
          FutureBuilder<Map<String, dynamic>?>(
            future: widget.getUserData(authorUsername),
            builder: (context, snapshot) {
              final userData = snapshot.data;
              final firstName = userData?['firstName'] ?? '';
              final lastName = userData?['lastName'] ?? '';
              final profileImageUrl = userData?['profileImageUrl'];
              final branch = userData?['branch'] ?? '';
              final year = userData?['year'] ?? '';

              return Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            username: authorUsername,
                            communityId: widget.communityId,
                          ),
                        ),
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: profileImageUrl != null 
                          ? NetworkImage(profileImageUrl) 
                          : null,
                      backgroundColor: const Color(0xFF8B5CF6),
                      child: profileImageUrl == null
                          ? Text(
                              (firstName.isNotEmpty ? firstName : 'U').substring(0, 1).toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => UserProfileScreen(
                                      username: authorUsername,
                                      communityId: widget.communityId,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                '$firstName $lastName'.trim(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (replyingTo != null) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.reply, color: Colors.white54, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '@$replyingTo',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF8B5CF6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (branch.isNotEmpty || year.isNotEmpty)
                          Row(
                            children: [
                              if (branch.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFA855F7).withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(4),
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
                  ),
                  if (authorUsername == widget.currentUsername ||
                      ['admin', 'manager', 'moderator'].contains(widget.currentUserRole))
                    GestureDetector(
                      onTap: () => _deleteComment(comment['id']),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // Content
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          // Actions
          Row(
            children: [
              // Like button
              GestureDetector(
                onTap: () => _likeComment(comment['id']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasLiked 
                        ? Colors.green.withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasLiked ? Colors.green : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.thumb_up,
                        size: 12,
                        color: hasLiked ? Colors.green : Colors.white70,
                      ),
                      if (likesCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '$likesCount',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: hasLiked ? Colors.green : Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Reply button
              if (!isReply)
                GestureDetector(
                  onTap: () => _startReply(comment['id'], authorUsername),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.reply,
                          size: 12,
                          color: Color(0xFF8B5CF6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reply',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: const Color(0xFF8B5CF6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const Spacer(),

              // Timestamp
              if (createdAt != null)
                Text(
                  _formatTimestamp(createdAt),
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.1),
            const Color(0xFF0D1B2A),
          ],
        ),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          if (_replyingToUsername != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    color: const Color(0xFF8B5CF6),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to @$_replyingToUsername',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 16,
                    ),
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
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    ),
                  ),
                  child: TextField(
                    controller: _commentController,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: _replyingToUsername != null 
                          ? 'Reply to @$_replyingToUsername...'
                          : 'Write a comment...',
                      hintStyle: GoogleFonts.poppins(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<bool>(
                valueListenable: _isPostingNotifier,
                builder: (context, isPosting, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: IconButton(
                      onPressed: isPosting ? null : _postComment,
                      icon: isPosting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
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