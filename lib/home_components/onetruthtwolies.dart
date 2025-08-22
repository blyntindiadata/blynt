import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:startup/home_components/uploadottl.dart';
import 'dart:async';

class OneTruthTwoLiesPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const OneTruthTwoLiesPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  }) : super(key: key);

  @override
  State<OneTruthTwoLiesPage> createState() => _OneTruthTwoLiesPageState();
}

class _OneTruthTwoLiesPageState extends State<OneTruthTwoLiesPage> with TickerProviderStateMixin {
  final ValueNotifier<List<Map<String, dynamic>>> _postsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<Set<String>> _votedPostsNotifier = ValueNotifier({});
  final Map<String, ConfettiController> _confettiControllers = {};
  final Map<String, Timer> _countdownTimers = {};
  final Map<String, ValueNotifier<Duration>> _countdownNotifiers = {};
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadPosts();
    _loadUserVotes();
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
    _postsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _votedPostsNotifier.dispose();
    _fadeController.dispose();
    _confettiControllers.forEach((_, controller) => controller.dispose());
    _countdownTimers.forEach((_, timer) => timer.cancel());
    _countdownNotifiers.forEach((_, notifier) => notifier.dispose());
    super.dispose();
  }

  Future<void> _loadPosts() async {
    try {
      _isLoadingNotifier.value = true;
      
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('truth_lies_posts')
          .orderBy('createdAt', descending: true)
          .get();

      final posts = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final postData = {
          'id': doc.id,
          ...data,
        };

        // Check if truth should be revealed
        if (data['revealTime'] != null && !data['truthRevealed']) {
          final revealTime = (data['revealTime'] as Timestamp).toDate();
          if (revealTime.isBefore(now)) {
            // Auto-reveal the truth
            await _revealTruth(doc.id, data['truthIndex']);
            postData['truthRevealed'] = true;
          } else {
            // Set up countdown
            _setupCountdown(doc.id, revealTime);
          }
        }

        // Set up confetti controller
        _confettiControllers[doc.id] = ConfettiController(duration: const Duration(seconds: 3));

        posts.add(postData);
      }

      _postsNotifier.value = posts;
    } catch (e) {
      print('Error loading posts: $e');
      _showMessage('Error loading posts: $e', isError: true);
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  void _setupCountdown(String postId, DateTime revealTime) {
    if (_countdownTimers.containsKey(postId)) {
      _countdownTimers[postId]?.cancel();
    }

    final initialDuration = revealTime.difference(DateTime.now());
    if (initialDuration.isNegative) return;

    _countdownNotifiers[postId] = ValueNotifier(initialDuration);

    _countdownTimers[postId] = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = revealTime.difference(DateTime.now());
      if (remaining.isNegative) {
        timer.cancel();
        _countdownNotifiers[postId]?.dispose();
        _countdownNotifiers.remove(postId);
        _loadPosts(); // Reload to reveal truth
      } else {
        _countdownNotifiers[postId]?.value = remaining;
      }
    });
  }

  Future<void> _revealTruth(String postId, int truthIndex) async {
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('truth_lies_posts')
        .doc(postId)
        .update({'truthRevealed': true});
  }

  Future<void> _loadUserVotes() async {
    try {
      final votesSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('truth_lies_votes')
          .where('userId', isEqualTo: widget.userId)
          .get();

      final votedPosts = <String>{};
      for (var doc in votesSnapshot.docs) {
        votedPosts.add(doc.data()['postId']);
      }

      _votedPostsNotifier.value = votedPosts;
    } catch (e) {
      print('Error loading user votes: $e');
    }
  }

  Future<void> _vote(String postId, int selectedIndex, int truthIndex) async {
    try {
      // Check if already voted
      if (_votedPostsNotifier.value.contains(postId)) return;

      // Record the vote
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('truth_lies_votes')
          .add({
        'postId': postId,
        'userId': widget.userId,
        'username': widget.username,
        'selectedIndex': selectedIndex,
        'votedAt': FieldValue.serverTimestamp(),
      });

      // Update vote count
      final postRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('truth_lies_posts')
          .doc(postId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final postDoc = await transaction.get(postRef);
        final votes = List<int>.from(postDoc.data()?['votes'] ?? [0, 0, 0]);
        if (votes.length < 3) votes.addAll(List.filled(3 - votes.length, 0));
        votes[selectedIndex]++;
        transaction.update(postRef, {'votes': votes});
      });

      // Update local state - both voted posts and post data
      final updatedVotedPosts = Set<String>.from(_votedPostsNotifier.value);
      updatedVotedPosts.add(postId);
      _votedPostsNotifier.value = updatedVotedPosts;

      // Update local post data to prevent rebuild
      final updatedPosts = _postsNotifier.value.map((p) {
        if (p['id'] == postId) {
          final updatedVotes = List<int>.from(p['votes'] ?? [0, 0, 0]);
          if (updatedVotes.length < 3) updatedVotes.addAll(List.filled(3 - updatedVotes.length, 0));
          updatedVotes[selectedIndex]++;
          return {...p, 'votes': updatedVotes};
        }
        return p;
      }).toList();
      _postsNotifier.value = updatedPosts;

      // Check if correct guess - trigger confetti immediately after voting
      if (selectedIndex == truthIndex) {
        _confettiControllers[postId]?.play();
        
        // Check if truth is already revealed
        final post = _postsNotifier.value.firstWhere((p) => p['id'] == postId);
        if (post['truthRevealed'] == true) {
          _showMessage('🎉 Congratulations! You guessed the truth correctly!');
        } else {
          _showMessage('🎉 Great guess! Wait for the reveal to confirm!');
        }
      } else {
        _showMessage('Vote recorded! Let\'s see if you guessed correctly...');
      }

    } catch (e) {
      _showMessage('Error voting: $e', isError: true);
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      // Delete the post
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('truth_lies_posts')
          .doc(postId)
          .delete();

      // Delete all votes for this post
      final votesSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('truth_lies_votes')
          .where('postId', isEqualTo: postId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in votesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Clean up controllers and timers
      _confettiControllers[postId]?.dispose();
      _confettiControllers.remove(postId);
      _countdownTimers[postId]?.cancel();
      _countdownTimers.remove(postId);
      _countdownNotifiers[postId]?.dispose();
      _countdownNotifiers.remove(postId);

      _loadPosts();
      _showMessage('Post deleted successfully');
    } catch (e) {
      _showMessage('Error deleting post: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF134E4A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F766E),
              Color(0xFF134E4A),
              Color(0xFF0F172A),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildPostsList(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildCreateFAB(),
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
            const Color(0xFF0D9488).withOpacity(0.3),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                  ).createShader(bounds),
                  child: Text(
                    'one truth, two lies',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'can you spot the truth?',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF14B8A6).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF14B8A6)),
            onPressed: _loadPosts,
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF14B8A6)),
          );
        }

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _postsNotifier,
          builder: (context, posts, child) {
            if (posts.isEmpty) {
              return _buildEmptyState();
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return TruthLiesCard(
                  post: post,
                  currentUserId: widget.userId,
                  currentUserRole: widget.userRole,
                  communityId: widget.communityId,
                  votedPostsNotifier: _votedPostsNotifier,
                  onVote: _vote,
                  onDelete: _deletePost,
                  confettiController: _confettiControllers[post['id']]!,
                  countdownNotifier: _countdownNotifiers[post['id']],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology, color: Color(0xFF14B8A6), size: 64),
          const SizedBox(height: 16),
          Text(
            'No mysteries yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Be the first to share your truth and lies!',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.4),
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
              builder: (context) => CreateTruthLiesPage(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
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
          'create mystery',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class TruthLiesCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String currentUserId;
  final String currentUserRole;
  final String communityId;
  final ValueNotifier<Set<String>> votedPostsNotifier;
  final Function(String, int, int) onVote;
  final Function(String) onDelete;
  final ConfettiController confettiController;
  final ValueNotifier<Duration>? countdownNotifier;

  const TruthLiesCard({
    Key? key,
    required this.post,
    required this.currentUserId,
    required this.currentUserRole,
    required this.communityId,
    required this.votedPostsNotifier,
    required this.onVote,
    required this.onDelete,
    required this.confettiController,
    this.countdownNotifier,
  }) : super(key: key);

  bool get _canDelete {
    return post['userId'] == currentUserId || 
           ['admin', 'manager', 'moderator'].contains(currentUserRole);
  }

  Future<DocumentSnapshot?> _getUserDocument() async {
    try {
      // First try to get from members collection using username as document ID
      var doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(post['username'])
          .get();
      
      if (doc.exists) {
        print('Found user in members collection: ${post['username']}');
        return doc;
      }
      
      // If not found in members, try trio collection by querying username field
      var trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('trio')
          .where('username', isEqualTo: post['username'])
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        print('Found user in trio collection with username: ${post['username']}');
        return trioQuery.docs.first;
      }
      
      print('User not found in either members or trio with username: ${post['username']}');
      return null;
    } catch (e) {
      print('Error fetching user document: $e');
      return null;
    }
  }

  void _showVoteConfirmation(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D9488),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Confirm Vote', 
            style: GoogleFonts.poppins(
              color: Colors.white, 
              fontWeight: FontWeight.w600
            )
          ),
          content: Text(
            'Are you sure you want to vote for statement ${index + 1}?', 
            style: GoogleFonts.poppins(color: Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel', 
                style: GoogleFonts.poppins(color: Colors.white60)
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onVote(post['id'], index, post['truthIndex']);
                },
                child: Text(
                  'Vote', 
                  style: GoogleFonts.poppins(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600
                  )
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAnonymous = post['isAnonymous'] == true;
    final truthRevealed = post['truthRevealed'] ?? false;
    final truthIndex = post['truthIndex'] ?? 0;
    final statements = List<String>.from(post['statements'] ?? []);
    final votes = List<int>.from(post['votes'] ?? [0, 0, 0]);
    if (votes.length < statements.length) {
      votes.addAll(List.filled(statements.length - votes.length, 0));
    }
    final totalVotes = votes.fold(0, (sum, vote) => sum + vote);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Stack(
        children: [
          // Enhanced Confetti overlay
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiWidget(
                confettiController: confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Color(0xFF14B8A6), 
                  Color(0xFF0D9488),
                  Colors.amber, 
                  Colors.blue, 
                  Colors.red,
                  Colors.purple,
                  Colors.orange,
                ],
                numberOfParticles: 50,
                gravity: 0.3,
                emissionFrequency: 0.3,
                maxBlastForce: 20,
                minBlastForce: 5,
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0D9488).withOpacity(0.2),
                  const Color(0xFF134E4A).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF14B8A6).withOpacity(0.3),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: isAnonymous
                          ? _buildAnonymousHeader()
                          : _buildUserHeader(),
                    ),
                    if (_canDelete)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white60),
                        color: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _showDeleteConfirmation(context);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(Icons.delete, color: Colors.red, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete', 
                                  style: GoogleFonts.poppins(color: Colors.white)
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                const SizedBox(height: 20),

                // Enhanced Countdown or reveal status
                if (!truthRevealed && post['revealTime'] != null)
                  _buildEnhancedCountdown()
                else if (truthRevealed)
                  _buildRevealedBadge(),

                const SizedBox(height: 16),

                // Statements
                ...statements.asMap().entries.map((entry) {
                  final index = entry.key;
                  final statement = entry.value;
                  return _buildStatementItem(
                    context,
                    index,
                    statement,
                    votes.length > index ? votes[index] : 0,
                    totalVotes,
                    truthRevealed && index == truthIndex,
                  );
                }),

                const SizedBox(height: 16),

                // Posted time and vote count
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getTimeAgo(post['createdAt']),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white38,
                      ),
                    ),
                    if (totalVotes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF14B8A6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF14B8A6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0D9488),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Delete Post', 
            style: GoogleFonts.poppins(
              color: Colors.white, 
              fontWeight: FontWeight.w600
            )
          ),
          content: Text(
            'Are you sure you want to delete this mystery? This action cannot be undone.', 
            style: GoogleFonts.poppins(color: Colors.white70)
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel', 
                style: GoogleFonts.poppins(color: Colors.white60)
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onDelete(post['id']);
                },
                child: Text(
                  'Delete', 
                  style: GoogleFonts.poppins(
                    color: Colors.white, 
                    fontWeight: FontWeight.w600
                  )
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnonymousHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.grey.shade700,
          child: const Icon(Icons.person_off, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anonymous',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            Text(
              'Mystery person',
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserHeader() {
    return FutureBuilder<DocumentSnapshot?>(
      future: _getUserDocument(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Color(0xFF14B8A6),
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Text('Loading...', style: GoogleFonts.poppins(color: Colors.white60, fontSize: 14)),
            ],
          );
        }

        if (snapshot.hasError) {
          print('Error fetching user data: ${snapshot.error}');
          return _buildAnonymousHeader();
        }
        
        if (!snapshot.hasData || snapshot.data == null || !snapshot.data!.exists) {
          print('User document does not exist for username: ${post['username']} in either members or trio');
          return _buildAnonymousHeader();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>?;
        if (userData == null) {
          print('User data is null');
          return _buildAnonymousHeader();
        }

        return Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundImage: userData['profileImageUrl'] != null
                  ? NetworkImage(userData['profileImageUrl'])
                  : null,
              backgroundColor: const Color(0xFF14B8A6),
              child: userData['profileImageUrl'] == null
                  ? Text(
                      (post['username']?.toString().isNotEmpty == true) 
                        ? post['username'].toString().substring(0, 1).toUpperCase()
                        : '?',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post['username'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (userData['branch']?.toString().isNotEmpty == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text(
                            userData['branch'].toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (userData['year']?.toString().isNotEmpty == true)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                            ),
                            borderRadius: BorderRadius.all(Radius.circular(6)),
                          ),
                          child: Text(
                            userData['year'].toString(),
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEnhancedCountdown() {
    if (countdownNotifier == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Duration>(
      valueListenable: countdownNotifier!,
      builder: (context, duration, child) {
        final days = duration.inDays;
        final hours = duration.inHours % 24;
        final minutes = duration.inMinutes % 60;
        final seconds = duration.inSeconds % 60;

        // Determine urgency color
        Color primaryColor;
        Color secondaryColor;
        IconData icon;
        
        if (duration.inHours < 1) {
          // Less than 1 hour - red (urgent)
          primaryColor = Colors.red.shade600;
          secondaryColor = Colors.red.shade800;
          icon = Icons.timer;
        } else if (duration.inHours < 24) {
          // Less than 1 day - orange (soon)
          primaryColor = Colors.orange.shade600;
          secondaryColor = Colors.orange.shade800;
          icon = Icons.schedule;
        } else {
          // More than 1 day - teal (normal)
          primaryColor = const Color(0xFF14B8A6);
          secondaryColor = const Color(0xFF0D9488);
          icon = Icons.access_time;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Truth reveals in:',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    days > 0
                        ? '${days}d ${hours}h ${minutes}m'
                        : hours > 0
                            ? '${hours}h ${minutes}m ${seconds}s'
                            : '${minutes}m ${seconds}s',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              if (duration.inMinutes < 5) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRevealedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF14B8A6).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(
            'Truth Revealed!',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              color: Color(0xFF14B8A6),
              size: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementItem(
    BuildContext context,
    int index,
    String statement,
    int voteCount,
    int totalVotes,
    bool isTruth,
  ) {
    final percentage = totalVotes > 0 ? (voteCount / totalVotes * 100) : 0.0;

    return ValueListenableBuilder<Set<String>>(
      valueListenable: votedPostsNotifier,
      builder: (context, votedPosts, child) {
        final hasVoted = votedPosts.contains(post['id']);

        return GestureDetector(
          onTap: hasVoted ? null : () => _showVoteConfirmation(context, index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isTruth && (post['truthRevealed'] ?? false)
                      ? const Color(0xFF14B8A6).withOpacity(0.4)
                      : hasVoted 
                          ? Colors.white.withOpacity(0.12)
                          : Colors.white.withOpacity(0.08),
                  isTruth && (post['truthRevealed'] ?? false)
                      ? const Color(0xFF0D9488).withOpacity(0.3)
                      : hasVoted
                          ? Colors.white.withOpacity(0.08)
                          : Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTruth && (post['truthRevealed'] ?? false)
                    ? const Color(0xFF14B8A6)
                    : hasVoted
                        ? const Color(0xFF14B8A6).withOpacity(0.5)
                        : const Color(0xFF14B8A6).withOpacity(0.3),
                width: isTruth && (post['truthRevealed'] ?? false) ? 2 : 1,
              ),
              boxShadow: isTruth && (post['truthRevealed'] ?? false) ? [
                BoxShadow(
                  color: const Color(0xFF14B8A6).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isTruth && (post['truthRevealed'] ?? false)
                              ? [const Color(0xFF14B8A6), const Color(0xFF0D9488)]
                              : [const Color(0xFF14B8A6).withOpacity(0.8), const Color(0xFF0D9488).withOpacity(0.8)],
                        ),
                        boxShadow: isTruth && (post['truthRevealed'] ?? false) ? [
                          BoxShadow(
                            color: const Color(0xFF14B8A6).withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        statement,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: isTruth && (post['truthRevealed'] ?? false) 
                              ? FontWeight.w600 
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (isTruth && (post['truthRevealed'] ?? false))
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
                if (hasVoted || (post['truthRevealed'] ?? false)) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: Colors.white.withOpacity(0.1),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: percentage / 100,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isTruth && (post['truthRevealed'] ?? false)
                                    ? const Color(0xFF14B8A6)
                                    : Colors.amber.shade400,
                              ),
                              minHeight: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isTruth && (post['truthRevealed'] ?? false))
                              ? const Color(0xFF14B8A6).withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${voteCount} (${percentage.toStringAsFixed(0)}%)',
                          style: GoogleFonts.poppins(
                            color: (isTruth && (post['truthRevealed'] ?? false))
                                ? const Color(0xFF14B8A6)
                                : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _getTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

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
}