import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
// import 'package:flutter_sound/public/flutter_sound_recorder.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ConfessionsPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const ConfessionsPage({
    super.key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  });

  @override
  State<ConfessionsPage> createState() => _ConfessionsPageState();
}

class _ConfessionsPageState extends State<ConfessionsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _confessionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Map<String, Map<String, bool>> userReactions = {};
  Map<String, double> _buttonScale = {};
  
  bool _isPosting = false;
  String _selectedFilter = 'recent';
  String _selectedYear = 'all';
  String _selectedBranch = 'all';
  bool _isAnonymous = true;
  String _visibility = 'everyone'; // everyone, branch, year, branch_year
  // int _revealThreshold = 0;
  // bool _enableRevealThreshold = false;
  
  DateTime? _lastSeenTimestamp;

  Map<String, dynamic>? _userProfile;
  List<String> _availableYears = ['all'];
  List<String> _availableBranches = ['all'];

  bool get isStaff => ['admin', 'moderator', 'manager'].contains(widget.userRole);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isStaff ? 4 : 2, vsync: this);
    _loadUserProfile();
    _loadFilterOptions();
    _preloadUserReactions();
    _loadLastSeenTimestamp();
  }

  


  Future<void> _loadLastSeenTimestamp() async {
  // Load from SharedPreferences or Firestore user preferences
  // For now, using a simple in-memory approach
  setState(() {
    _lastSeenTimestamp = DateTime.now().subtract(const Duration(hours: 1));
  });
}

Future<void> _updateLastSeenTimestamp() async {
  setState(() {
    _lastSeenTimestamp = DateTime.now();
  });
  // Save to SharedPreferences or Firestore
}
@override
  void dispose() {
     _buttonScale.clear();
    _updateLastSeenTimestamp();
    _tabController.dispose();
    _confessionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _preloadUserReactions() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .collection('confessions')
      .where('status', isEqualTo: 'approved')
      .get();
      
  final Map<String, Map<String, bool>> reactions = {};
  
  for (var doc in snapshot.docs) {
    final interactionDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(doc.id)
        .collection('interactions')
        .doc(widget.userId)
        .get();
        
    if (interactionDoc.exists) {
      final type = interactionDoc.data()?['type'];
      reactions[doc.id] = {
        'liked': type == 'like',
        'disliked': type == 'dislike',
      };
    }
  }
  
  if (mounted) {
    setState(() {
      userReactions = reactions;
    });
  }
}
  Future<void> _logActivity(String confessionId, String activityType, Map<String, dynamic> data) async {
  try {
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(confessionId)
        .collection('activities')
        .add({
      'type': activityType,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': widget.userId,
      'username': widget.username,
    });
  } catch (e) {
    print('Error logging activity: $e');
  }
}



  Future<void> _loadUserProfile() async {
  try {
    var doc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .doc(widget.username)
        .get();

        if (!doc.exists) {
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        doc = trioQuery.docs.first;
      }
    }
    
    if (doc.exists && mounted) {
      final data = doc.data()!;
      // Ensure year and branch are strings
      final profile = Map<String, dynamic>.from(data);
      if (profile['year'] != null) {
        profile['year'] = profile['year'].toString();
      }
      if (profile['branch'] != null) {
        profile['branch'] = profile['branch'].toString();
      }
      
      setState(() {
        _userProfile = profile;
      });
    }
  } catch (e) {
    print('Error loading user profile: $e');
  }
}

 Future<void> _loadFilterOptions() async {
  try {
    // Load from community document instead of members collection
    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();

    if (communityDoc.exists) {
      final data = communityDoc.data()!;
      final years = List<String>.from(data['years'] ?? []);
      final branches = List<String>.from(data['branches'] ?? []);

      if (mounted) {
        setState(() {
          _availableYears = ['all', ...years];
          _availableBranches = ['all', ...branches];
        });
      }
    }
  } catch (e) {
    print('Error loading filter options: $e');
    // Fallback to loading from members if community doesn't have the arrays
    _loadFilterOptionsFromMembers();
  }
}

// Keep the old method as fallback
Future<void> _loadFilterOptionsFromMembers() async {
  try {
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .get();

    final years = <String>{'all'};
    final branches = <String>{'all'};

    for (var doc in membersSnapshot.docs) {
      final data = doc.data();
      if (data['year'] != null) years.add(data['year'].toString());
      if (data['branch'] != null) branches.add(data['branch'].toString());
    }

    if (mounted) {
      setState(() {
        _availableYears = years.toList()..sort();
        _availableBranches = branches.toList()..sort();
      });
    }
  } catch (e) {
    print('Error loading filter options from members: $e');
  }
}

  Future<void> _postConfession() async {
    final text = _confessionController.text.trim();
    if (text.isEmpty) {
      _showMessage('Please write your confession', isError: true);
      return;
    }

    if (text.length > 1000) {
      _showMessage('Confession must be 1000 characters or less', isError: true);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final confessionRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc();

      // Determine visibility settings
      Map<String, dynamic> visibilitySettings = {
        'type': _visibility,
        'allowedYears': _visibility == 'everyone' ? [] : 
                      _visibility.contains('year') ? [_userProfile?['year']] : [],
        'allowedBranches': _visibility == 'everyone' ? [] : 
                         _visibility.contains('branch') ? [_userProfile?['branch']] : [],
      };

      await confessionRef.set({
  'id': confessionRef.id,
  'content': text,
  'authorId': widget.userId,
  'authorUsername': widget.username,
  'authorYear': _userProfile?['year'],
  'authorBranch': _userProfile?['branch'],
  'isAnonymous': _isAnonymous,
  'visibility': visibilitySettings,
  'status': 'pending',
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  'approvedAt': null,
  'approvedBy': null,
  'editedBy': null,
  'editHistory': [],
  'likes': 0,
  'dislikes': 0,
  'commentsCount': 0,
  'reportCount': 0,
  'isUnderReview': false,
  'reviewReason': null,
  'tags': _extractTags(text),
  'identityRequests': [],
});
      // Create engagement stats
      await confessionRef.collection('stats').doc('engagement').set({
        'totalViews': 0,
        'uniqueViewers': [],
        'peakEngagement': 0,
        'lastActivity': FieldValue.serverTimestamp(),
      });

      _confessionController.clear();
      _showMessage('Confession submitted for review!');
      
    } catch (e) {
      _showMessage('Failed to post confession: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  List<String> _extractTags(String content) {
    final RegExp hashtagRegex = RegExp(r'#\w+');
    return hashtagRegex.allMatches(content.toLowerCase())
        .map((match) => match.group(0)!)
        .toList();
  }

  Future<void> _approveConfession(String confessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(confessionId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': widget.username,
        'isUnderReview': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await _logActivity(confessionId, 'confession_approved', {
      'approvedBy': widget.username,
    });
    
  
      _showMessage('Confession approved successfully!');
    } catch (e) {
      _showMessage('Failed to approve confession: $e', isError: true);
    }
  }

  Future<void> _rejectConfession(String confessionId, String reason) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(confessionId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': widget.username,
        'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _showMessage('Confession rejected');
    } catch (e) {
      _showMessage('Failed to reject confession: $e', isError: true);
    }
  }

  Future<void> _editConfession(String confessionId, String newContent) async {
  try {
    final confessionRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(confessionId);

    // Get current confession for history
    final currentDoc = await confessionRef.get();
    if (!currentDoc.exists) {
      _showMessage('Confession not found', isError: true);
      return;
    }
    
    final currentData = currentDoc.data()!;
    final editHistory = List<Map<String, dynamic>>.from(currentData['editHistory'] ?? []);
    
    // Add current content to history
    editHistory.add({
      'previousContent': currentData['content'],
      'editedBy': widget.username,
      'editedAt': Timestamp.now(), // Changed from FieldValue.serverTimestamp()
    });
    
    // Update the document
    await confessionRef.update({
      'content': newContent,
      'editedBy': widget.username,
      'editHistory': editHistory,
      'tags': _extractTags(newContent),
      'updatedAt': Timestamp.now(), // Changed from FieldValue.serverTimestamp()
    });
    
    _showMessage('Confession updated successfully!');
  } catch (e) {
    _showMessage('Failed to update confession: $e', isError: true);
  }
}

// In the _ConfessionCardState class, modify the _toggleLike method:

// Replace your _toggleLike and _toggleDislike methods with these simpler versions:

  Future<void> _toggleLike(String confessionId, bool currentHasLiked, bool currentHasDisliked) async {
    if (_isProcessingInteraction(confessionId)) return;
    _setProcessingInteraction(confessionId, true);

    final bool newLiked = !currentHasLiked;
    final bool newDisliked = false; // Liking always removes dislike

    userReactions[confessionId] = {
      'liked': newLiked,
      'disliked': newDisliked,
    };

    try {
      int likeChange = 0;
      int dislikeChange = 0;

      // 💡 Compute the change based on full transition
      if (currentHasLiked && !newLiked) likeChange = -1;
      if (!currentHasLiked && newLiked) likeChange = 1;

      if (currentHasDisliked && !newDisliked) dislikeChange = -1;
      if (!currentHasDisliked && newDisliked) dislikeChange = 1;

      print('[LIKE] Transition: liked $currentHasLiked → $newLiked, disliked $currentHasDisliked → $newDisliked');
      print('[LIKE] likeChange=$likeChange, dislikeChange=$dislikeChange');

      await _updateInteractionDirectly(
        confessionId,
        newLiked ? 'like' : null,
        likeChange,
        dislikeChange,
      );

      await _checkRevealThreshold(confessionId);
    } catch (e) {
      print('[LIKE][ERROR] $e');
      userReactions[confessionId] = {
        'liked': currentHasLiked,
        'disliked': currentHasDisliked,
      };
      _showMessage('Failed to update reaction', isError: true);
    } finally {
      _setProcessingInteraction(confessionId, false);
    }
  }

  Future<void> _toggleDislike(String confessionId, bool currentHasLiked, bool currentHasDisliked) async {
    if (_isProcessingInteraction(confessionId)) return;
    _setProcessingInteraction(confessionId, true);

    final bool newDisliked = !currentHasDisliked;
    final bool newLiked = false; // Disliking always removes like

    userReactions[confessionId] = {
      'liked': newLiked,
      'disliked': newDisliked,
    };

    try {
      int likeChange = 0;
      int dislikeChange = 0;

      // 💡 Compute the change based on full transition
      if (currentHasLiked && !newLiked) likeChange = -1;
      if (!currentHasLiked && newLiked) likeChange = 1;

      if (currentHasDisliked && !newDisliked) dislikeChange = -1;
      if (!currentHasDisliked && newDisliked) dislikeChange = 1;

      print('[DISLIKE] Transition: liked $currentHasLiked → $newLiked, disliked $currentHasDisliked → $newDisliked');
      print('[DISLIKE] likeChange=$likeChange, dislikeChange=$dislikeChange');

      await _updateInteractionDirectly(
        confessionId,
        newDisliked ? 'dislike' : null,
        likeChange,
        dislikeChange,
      );
    } catch (e) {
      print('[DISLIKE][ERROR] $e');
      userReactions[confessionId] = {
        'liked': currentHasLiked,
        'disliked': currentHasDisliked,
      };
      _showMessage('Failed to update reaction', isError: true);
    } finally {
      _setProcessingInteraction(confessionId, false);
    }
  }


// Add this new simpler database update method:
Future<void> _updateInteractionDirectly(
  String confessionId,
  String? newType, // 'like', 'dislike', or null
  int likeChange,
  int dislikeChange,
) async {
  final firestore = FirebaseFirestore.instance;

  final confessionRef = firestore
      .collection('communities')
      .doc(widget.communityId)
      .collection('confessions')
      .doc(confessionId);

  final userInteractionRef = confessionRef
      .collection('interactions')
      .doc(widget.userId);

  final batch = firestore.batch();

  // 👤 User interaction update
  if (newType == null) {
    batch.delete(userInteractionRef);
    print('[UPDATE] Deleting user interaction');
  } else {
    batch.set(userInteractionRef, {
      'userId': widget.userId,
      'type': newType,
      'timestamp': FieldValue.serverTimestamp(),
    });
    print('[UPDATE] Setting user interaction: $newType');
  }

  // 👍👎 Count update
  final updates = <String, dynamic>{};

  if (likeChange != 0) {
    updates['likes'] = FieldValue.increment(likeChange);
  }
  if (dislikeChange != 0) {
    updates['dislikes'] = FieldValue.increment(dislikeChange);
  }

  if (updates.isNotEmpty) {
    batch.update(confessionRef, updates);
    print('[UPDATE] Updating confession counts: $updates');
  } else {
    print('[UPDATE] No confession count changes');
  }

  await batch.commit();
  print('[UPDATE] Firestore batch committed');
}


final Map<String, bool> _processingInteractions = {};

bool _isProcessingInteraction(String confessionId) {
  return _processingInteractions[confessionId] == true;
}

void _setProcessingInteraction(String confessionId, bool processing) {
  _processingInteractions[confessionId] = processing;
}

// Replace your existing _updateInteractionInDatabase method with this:

Future<void> _updateInteractionInDatabase(String confessionId, String? newType, bool wasLiked, bool wasDisliked) async {
  final batch = FirebaseFirestore.instance.batch();
  final confessionRef = FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .collection('confessions')
      .doc(confessionId);

  final userInteractionRef = confessionRef
      .collection('interactions')
      .doc(widget.userId);

  // Calculate the count changes
  int likeChange = 0;
  int dislikeChange = 0;

  if (newType == null) {
    // Removing interaction completely (going to neutral)
    if (wasLiked) likeChange = -1;
    if (wasDisliked) dislikeChange = -1;
    batch.delete(userInteractionRef);
  } else if (newType == 'like') {
    // Setting to like
    if (!wasLiked) {
      likeChange = 1; // Add like
    }
    if (wasDisliked) {
      dislikeChange = -1; // Remove dislike
    }
    batch.set(userInteractionRef, {
      'userId': widget.userId,
      'type': 'like',
      'timestamp': FieldValue.serverTimestamp(),
    });
  } else if (newType == 'dislike') {
    // Setting to dislike
    if (wasLiked) {
      likeChange = -1; // Remove like
    }
    if (!wasDisliked) {
      dislikeChange = 1; // Add dislike
    }
    batch.set(userInteractionRef, {
      'userId': widget.userId,
      'type': 'dislike',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Update counts only if there are changes
  Map<String, dynamic> updates = {};
  if (likeChange != 0) {
    updates['likes'] = FieldValue.increment(likeChange);
  }
  if (dislikeChange != 0) {
    updates['dislikes'] = FieldValue.increment(dislikeChange);
  }

  if (updates.isNotEmpty) {
    batch.update(confessionRef, updates);
  }

  await batch.commit();
  print("🔥 Updated confession $confessionId: likeChange=$likeChange, dislikeChange=$dislikeChange, newType=$newType");
}
Future _checkRevealThreshold(String confessionId) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(confessionId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final revealSettings = data['revealSettings'] as Map?;

      if (revealSettings?['enabled'] == true &&
          (revealSettings?['revealed'] != true) &&
          data['likes'] >= (revealSettings?['threshold'] ?? 0)) {
        await doc.reference.update({
          'revealSettings.revealed': true,
        });
      }
    }
  } catch (e) {
    print('Error checking reveal threshold: $e');
  }
}

Future<void> _reportConfession(String confessionId, String reason) async {
  try {
    final confessionRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(confessionId);

    await confessionRef.collection('reports').add({
      'reportedBy': widget.userId,
      'reportedByUsername': widget.username,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await confessionRef.update({
      'reportCount': FieldValue.increment(1),
      'status': 'reported',
      'isUnderReview': true,
      'reviewReason': 'Reported: $reason',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    _showMessage('Report submitted successfully');
  } catch (e) {
    _showMessage('Failed to submit report: $e', isError: true);
  }
}


  Future<void> _requestIdentityReveal(String confessionId) async {
  try {
    final confessionRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(confessionId);

    // Check if already requested
    final doc = await confessionRef.get();
    if (!doc.exists) {
      _showMessage('Confession not found', isError: true);
      return;
    }
    
    final data = doc.data()!;
    final identityRequests = List<Map<String, dynamic>>.from(
      data['identityRequests'] ?? []
    );

    final alreadyRequested = identityRequests.any(
      (req) => req['requesterId'] == widget.userId
    );

    if (alreadyRequested) {
      _showMessage('You have already requested identity reveal');
      return;
    }

    // Check if user is the author
    if (data['authorId'] == widget.userId) {
      _showMessage('You cannot request to reveal your own identity');
      return;
    }

    // Create new request object
    final newRequest = {
      'requesterId': widget.userId,
      'requesterUsername': widget.username,
      'timestamp': Timestamp.now(),
      'status': 'pending',
    };

    // Add to existing requests
    identityRequests.add(newRequest);

    await confessionRef.update({
      'identityRequests': identityRequests,
    });
    
    _showMessage('Identity reveal request sent');
    
    
  } catch (e) {
    _showMessage('Failed to request identity reveal: $e', isError: true);
  }
}

  Future<void> _handleIdentityRequest(String confessionId, String requesterId, bool accept) async {
    try {
      final confessionRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(confessionId);

      if (accept) {
        await confessionRef.update({
          'revealSettings.revealedTo': FieldValue.arrayUnion([requesterId]),
        });
      }

      // Update request status
      final doc = await confessionRef.get();
      final identityRequests = List<Map<String, dynamic>>.from(
        doc.data()?['identityRequests'] ?? []
      );

      final updatedRequests = identityRequests.map((req) {
        if (req['requesterId'] == requesterId) {
          return {...req, 'status': accept ? 'accepted' : 'rejected'};
        }
        return req;
      }).toList();

      await confessionRef.update({
        'identityRequests': updatedRequests,
      });
      await _logActivity(confessionId, 'identity_reveal_${accept ? 'accepted' : 'rejected'}', {
    'requesterId': requesterId,
    'authorId': widget.userId,
    'authorUsername': widget.username,
  });
      _showMessage(accept ? 'Identity revealed' : 'Request rejected');
    } catch (e) {
      _showMessage('Failed to handle request: $e', isError: true);
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
              const Color.fromARGB(255, 75, 7, 106).withOpacity(0.9),
              Color.fromARGB(255, 65, 4, 122).withOpacity(0.7),
              const Color.fromARGB(255, 64, 0, 94).withOpacity(0.5),
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
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildConfessionsList(),
                    _buildCreateConfession(),
                    if (isStaff) _buildReviewPanel(),
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
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.lock_outline,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  'confession vault',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'share anonymously, connect authentically',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white60,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        // Search button (keeping this)
        GestureDetector(
          onTapDown: (_) => setState(() => _buttonScale['search_button'] = 0.95),
          onTapUp: (_) => setState(() => _buttonScale['search_button'] = 1.0),
          onTapCancel: () => setState(() => _buttonScale['search_button'] = 1.0),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchPage(
                  communityId: widget.communityId,
                  userId: widget.userId,
                  username: widget.username, 
                  userRole: widget.userRole, 
                  onLike: _toggleLike,
                  onDislike: _toggleDislike,
                  onReport: _reportConfession,
                  onRequestIdentity: _requestIdentityReveal,
                  onHandleIdentityRequest: _handleIdentityRequest,
                  userReactions: userReactions,
                  lastSeenTimestamp: _lastSeenTimestamp,
                ),
              ),
            );
          },
          child: AnimatedScale(
            scale: _buttonScale['search_button'] ?? 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                ),
              ),
              child: const Icon(
                Icons.search,
                color: Colors.white70,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

 Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: false, // Changed to false for equal spacing
        indicatorPadding: const EdgeInsets.all(4), // Add padding
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 12),
        dividerColor: Colors.transparent,
        tabAlignment: TabAlignment.fill, // Ensure equal spacing
        tabs: [
          const Tab(text: 'Confessions'),
          const Tab(text: 'Create'),
          if (isStaff) const Tab(text: 'Review'),
          if (isStaff) const Tab(text: 'Reports'),
        ],
      ),
    );
  }

  Widget _buildConfessionsList() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
  stream: _getConfessionsStream().distinct(),
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
    }

    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return _buildEmptyState();
    }

    // Filter and sort in memory
    // Filter and sort in memory
var docs = snapshot.data!.docs.where((doc) {
  final data = doc.data() as Map<String, dynamic>;
  final visibility = data['visibility'] as Map<String, dynamic>?;
  
  if (visibility != null) {
    final visibilityType = visibility['type'] as String?;
    final allowedYears = List<String>.from(visibility['allowedYears'] ?? []);
    final allowedBranches = List<String>.from(visibility['allowedBranches'] ?? []);
    
    // Check if user meets visibility criteria
    if (visibilityType != 'everyone') {
      final userYear = _userProfile?['year']?.toString();
      final userBranch = _userProfile?['branch']?.toString();
      
      if (visibilityType == 'year' && !allowedYears.contains(userYear)) {
        return false;
      }
      if (visibilityType == 'branch' && !allowedBranches.contains(userBranch)) {
        return false;
      }
      if (visibilityType == 'branch_year' && 
          (!allowedYears.contains(userYear) || !allowedBranches.contains(userBranch))) {
        return false;
      }
    }
  }
  
  // Apply user-selected filters
  if (_selectedYear != 'all') {
    final allowedYears = List<String>.from(data['visibility']?['allowedYears'] ?? []);
    if (allowedYears.isNotEmpty && !allowedYears.contains(_selectedYear)) {
      return false;
    }
  }
  
  if (_selectedBranch != 'all') {
    final allowedBranches = List<String>.from(data['visibility']?['allowedBranches'] ?? []);
    if (allowedBranches.isNotEmpty && !allowedBranches.contains(_selectedBranch)) {
      return false;
    }
  }
  
  return true;
}).toList();
    
    // Sort based on selected filter
    docs.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      
      switch (_selectedFilter) {
        case 'popular':
          final aLikes = aData['likes'] ?? 0;
          final bLikes = bData['likes'] ?? 0;
          return bLikes.compareTo(aLikes);
          
        case 'controversial':
          final aComments = aData['commentsCount'] ?? 0;
          final bComments = bData['commentsCount'] ?? 0;
          return bComments.compareTo(aComments);
          
        default: // 'recent'
          final aTime = aData['approvedAt'] as Timestamp?;
          final bTime = bData['approvedAt'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime);
      }
    });

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
       return ConfessionCard(
        key: ValueKey(doc.id), 
  confession: doc.data() as Map<String, dynamic>,
  confessionId: doc.id,
  currentUserId: widget.userId,
  currentUsername: widget.username,
  userRole: widget.userRole,
  communityId: widget.communityId,
  onLike: _toggleLike,
  onDislike: _toggleDislike,
  onReport: _reportConfession,
  onRequestIdentity: _requestIdentityReveal,
  onHandleIdentityRequest: _handleIdentityRequest,
  userReactions: userReactions, // Add this line
);
      },
    );
  },
)
        ),
      ],
    );
  }

Widget _buildFilters() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced margins
    padding: const EdgeInsets.all(12), // Reduced padding
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(16), // Reduced border radius
      border: Border.all(
        color: Colors.white.withOpacity(0.15),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8B5CF6).withOpacity(0.1),
          blurRadius: 8, // Reduced blur
          spreadRadius: 0,
          offset: const Offset(0, 2), // Reduced offset
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4), // Further reduced
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(6), // Smaller radius
              ),
              child: const Icon(Icons.filter_list, color: Colors.white, size: 12), // Smaller icon
            ),
            const SizedBox(width: 8),
            Text(
              'filters',
              style: GoogleFonts.dmSerifDisplay(
                color: Colors.white,
                fontSize: 18, // Smaller text
                fontWeight: FontWeight.w600,
                // letterSpacing: 1.2
              ),
            ),
          ],
        ),
        const SizedBox(height: 8), // Reduced spacing
        
        // First row - Dropdowns only
        // First row - Dropdowns with labels
Row(
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Year',
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _buildCompactFilterDropdown('Year', _selectedYear, _availableYears, (value) {
            setState(() => _selectedYear = value!);
          }),
        ],
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Branch',
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          _buildCompactFilterDropdown('Branch', _selectedBranch, _availableBranches, (value) {
            setState(() => _selectedBranch = value!);
          }),
        ],
      ),
    ),
  ],
),
        
        const SizedBox(height: 8), // Spacing between rows
        
        // Second row - Filter chips
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildCompactFilterChip('recent', 'Recent', Icons.access_time),
            _buildCompactFilterChip('popular', 'Popular', Icons.favorite),
            _buildCompactFilterChip('controversial', 'Hot', Icons.chat_bubble),
          ],
        ),
      ],
    ),
  );
}
Widget _buildCompactFilterDropdown(
  String label,
  String selectedValue,
  List<String> options,
  ValueChanged<String?> onChanged,
) {
  return Container(
    height: 32, // Reduced height for shorter dropdown
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.white.withOpacity(0.05),
        ],
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedValue,
        items: options.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 10, // Smaller font size
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        icon: Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white.withOpacity(0.7),
          size: 16, // Smaller icon
        ),
        dropdownColor: const Color(0xFF1A1A2E),
        isDense: true, // Makes dropdown more compact
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
  );
}

Widget _buildCompactFilterChip(String value, String label, IconData icon) {
  final isSelected = _selectedFilter == value;
  return GestureDetector(
    onTap: () => setState(() => _selectedFilter = value),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected 
            ? const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.10),
                  Colors.white.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? Colors.white.withOpacity(0.3)
              : Colors.white.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  blurRadius: 6,
                  spreadRadius: 0,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? Colors.white : Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.white70,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

Stream<QuerySnapshot> _getConfessionsStream() {
  Query query = FirebaseFirestore.instance
      .collection('communities')
      .doc(widget.communityId)
      .collection('confessions')
      .where('status', isEqualTo: 'approved');

  return query.snapshots();
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
                  colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Confessions Found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to share something or adjust your filters',
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

  Widget _buildCreateConfession() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'share your confession',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'the admin, manager & moderator will review your confession. god knows what y\'all will put - we play safe🥷',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 20),
          
          // Confession input
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _confessionController,
              maxLines: null,
              maxLength: 1000,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'go beserk my dogs and cats',
                hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
                counterStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Visibility Settings
          _buildVisibilitySettings(),
          const SizedBox(height: 20),

          // Anonymous Setting
          _buildAnonymousSettings(),
          const SizedBox(height: 20),

          // Identity Reveal Settings
          // _buildIdentityRevealSettings(),
          const SizedBox(height: 24),

          // Post Button
          Row(
  children: [
    const Spacer(),
    GestureDetector(
      onTap: _isPosting ? null : _postConfession,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Color(0xFFA855F7).withOpacity(0.6),
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
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'SHARE CONFESSION',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 1.5,
                ),
              ),
      ),
    ),
  ],
),

          const SizedBox(height: 24),
          _buildPostingGuidelines(),
        ],
      ),
    );
  }

  Widget _buildVisibilitySettings() {
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
          Text(
            'Who can see this confession?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _buildVisibilityOption('everyone', 'Everyone in the community', Icons.public),
              _buildVisibilityOption('year', 'Only my year (${_userProfile?['year'] ?? 'Unknown'})', Icons.school),
              _buildVisibilityOption('branch', 'Only my branch (${_userProfile?['branch'] ?? 'Unknown'})', Icons.category),
              _buildVisibilityOption('branch_year', 'My year and branch only', Icons.group),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption(String value, String label, IconData icon) {
  // Update the label to handle potential null values better
  String getDisplayLabel() {
    switch (value) {
      case 'year':
        final year = _userProfile?['year']?.toString() ?? 'Unknown';
        return 'Only my year ($year)';
      case 'branch':
        final branch = _userProfile?['branch']?.toString() ?? 'Unknown';
        return 'Only my branch ($branch)';
      case 'branch_year':
        final year = _userProfile?['year']?.toString() ?? 'Unknown';
        final branch = _userProfile?['branch']?.toString() ?? 'Unknown';
        return 'My year and branch ($year - $branch)';
      default:
        return label;
    }
  }

  return GestureDetector(
    onTap: () => setState(() => _visibility = value),
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _visibility == value 
            ? const Color(0xFF8B5CF6).withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _visibility == value 
              ? const Color(0xFF8B5CF6) 
              : Colors.white.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _visibility == value ? const Color(0xFF8B5CF6) : Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              getDisplayLabel(),
              style: GoogleFonts.poppins(
                color: _visibility == value ? Colors.white : Colors.white70,
                fontSize: 13,
                fontWeight: _visibility == value ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (_visibility == value)
            const Icon(
              Icons.check_circle,
              color: Color(0xFF8B5CF6),
              size: 18,
            ),
        ],
      ),
    ),
  );
}

  Widget _buildAnonymousSettings() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            _isAnonymous ? Icons.visibility_off : Icons.visibility,
            color: const Color(0xFF8B5CF6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Anonymous Posting',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _isAnonymous 
                      ? 'well obviously' 
                      : 'really?',
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (value) => setState(() => _isAnonymous = value),
            activeColor: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildPostingGuidelines() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              Text(
                'Posting Guidelines',
                style: GoogleFonts.poppins(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Maximum 1000 characters\n'
            '• Be respectful and considerate\n',
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

  Widget _buildReviewPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.pending_actions, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pending Reviews',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('confessions')
                .where('status', isEqualTo: 'pending')
                // .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyReviewState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                 final confession = doc.data() as Map<String, dynamic>;
final isOwnConfession = confession['authorId'] == widget.userId;

return ReviewCard(
  confession: confession,
  confessionId: doc.id,
  currentUsername: widget.username,
  isOwnConfession: isOwnConfession,
  onApprove: _approveConfession,
  onReject: _rejectConfession,
  onEdit: _editConfession,
);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReportsPanel() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.report, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text(
                'Reported Confessions',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('confessions')
                .where('status', isEqualTo: 'reported')
                // .orderBy('updatedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyReportsState();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  return ReportedConfessionCard(
                    confession: doc.data() as Map<String, dynamic>,
                    confessionId: doc.id,
                    communityId: widget.communityId,
                    currentUsername: widget.username,
                    onDelete: _deleteConfession,
                    onDismissReports: _dismissReports,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyReviewState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'All Caught Up!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              'No confessions pending review',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyReportsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.thumb_up,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No Reports!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              'All confessions are clean',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteConfession(String confessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(confessionId)
          .delete();
        await _logActivity(confessionId, 'confession_deleted', {
      'deletedBy': widget.username,
      'reason': 'Reported content',
    });
      _showMessage('Confession deleted successfully');
    } catch (e) {
      _showMessage('Failed to delete confession: $e', isError: true);
    }
  }

  Future<void> _dismissReports(String confessionId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(confessionId)
          .update({
        'status': 'approved',
        'isUnderReview': false,
        'reviewReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      _showMessage('Reports dismissed');
    } catch (e) {
      _showMessage('Failed to dismiss reports: $e', isError: true);
    }
  }
}

// Confession Card Widget
class ConfessionCard extends StatefulWidget {
  final Map<String, dynamic> confession;
  final String confessionId;
  final String currentUserId;
  final String currentUsername;
  final String userRole;
  final String communityId;
  final Function(String, bool, bool) onLike;
  final Function(String, bool, bool) onDislike;
  final Function(String, String) onReport;
  final Function(String) onRequestIdentity;
  final Function(String, String, bool) onHandleIdentityRequest;
  final Map<String, Map<String, bool>>? userReactions;
  final DateTime? lastSeenTimestamp;

  const ConfessionCard({
    super.key,
    required this.confession,
    required this.confessionId,
    required this.currentUserId,
    required this.currentUsername,
    required this.userRole,
    required this.communityId,
    required this.onLike,
    required this.onDislike,
    required this.onReport,
    required this.onRequestIdentity,
    required this.onHandleIdentityRequest,
    this.userReactions,
    this.lastSeenTimestamp,
  });

  @override
  State<ConfessionCard> createState() => _ConfessionCardState();
}

class _ConfessionCardState extends State<ConfessionCard> {
 bool hasLiked = false;
bool hasDisliked = false;

  bool isExpanded = false;
  bool showIdentity = false;
  String? userReaction; // Stores user's emoji reaction
  Map<String, int> reactionCounts = {}; // Stores count of each reaction
  Map<String, double> _buttonScale = {};

 @override
void initState() {
  super.initState();
    // final reactions = widget.userReactions?[widget.confessionId];
    // hasLiked = reactions?['liked'] ?? false;
    // hasDisliked = reactions?['disliked'] ?? false;
  // _loadUserInteraction();
  _checkIdentityVisibility();
  _loadReactions(); // Add this line
}
void _handleLike() {
  final reactions = widget.userReactions?[widget.confessionId];
  final currentHasLiked = reactions?['liked'] ?? false;
  final currentHasDisliked = reactions?['disliked'] ?? false;
  
  widget.onLike(widget.confessionId, currentHasLiked, currentHasDisliked);
}

void _handleDislike() {
  final reactions = widget.userReactions?[widget.confessionId];
  final currentHasLiked = reactions?['liked'] ?? false;
  final currentHasDisliked = reactions?['disliked'] ?? false;
  
  widget.onDislike(widget.confessionId, currentHasLiked, currentHasDisliked);
}
  void _showReactionPicker() {
  final List<String> reactions = ['😂', '😍', '😢', '😠', '❤️', '🔥', '💯', '🤔', '🐐', '🤤'];
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      height: 400,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2D1B69),
            Color(0xFF1A0D2E),
            Color(0xFF0F0419),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_emotions,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'react to confession',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'choose an emoji to express your feelings',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: reactions.length,
                itemBuilder: (context, index) {
                  final reaction = reactions[index];
                  final isSelected = userReaction == reaction;
                  
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _addReaction(reaction);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.08),
                                  Colors.white.withOpacity(0.04),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white.withOpacity(0.4)
                              : Colors.white.withOpacity(0.15),
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: AnimatedScale(
                          scale: isSelected ? 1.2 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            reaction,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

Future<void> _addReaction(String emoji) async {
  try {
    final reactionRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('reactions')
        .doc(widget.currentUserId);

    // Check if user already has a reaction
    final existingReaction = await reactionRef.get();
    
    if (existingReaction.exists && existingReaction.data()?['reaction'] == emoji) {
      // Remove reaction if same emoji
      await reactionRef.delete();
      setState(() => userReaction = null);
    } else {
      // Add or update reaction
      await reactionRef.set({
        'userId': widget.currentUserId,
        'reaction': emoji,
        'timestamp': FieldValue.serverTimestamp(),
      });
      setState(() => userReaction = emoji);
    }
    
    _loadReactions();
  } catch (e) {
    print('Error adding reaction: $e');
  }
}

Future<void> _loadReactions() async {
  try {
    final reactionsSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('reactions')
        .get();

    final userReactionDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('reactions')
        .doc(widget.currentUserId)
        .get();

    if (mounted) {
      setState(() {
        // Fix the null safety issue
        if (userReactionDoc.exists && userReactionDoc.data() != null) {
          userReaction = userReactionDoc.data()!['reaction'] as String?;
        } else {
          userReaction = null;
        }
        
        reactionCounts.clear();
        for (var doc in reactionsSnapshot.docs) {
          final data = doc.data();
          final reaction = data['reaction'] as String?;
          if (reaction != null) {
            reactionCounts[reaction] = (reactionCounts[reaction] ?? 0) + 1;
          }
        }
      });
    }
  } catch (e) {
    print('Error loading reactions: $e');
  }
}
 
  void _showCommentsModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CommentsPage(
      confessionId: widget.confessionId,
      communityId: widget.communityId,
      userId: widget.currentUserId,
      username: widget.currentUsername,
    ),
  );
}

void _shareConfession() {
  // TODO: Implement share functionality
  // You can use the share_plus package
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Share functionality coming soon!',
        style: GoogleFonts.poppins(color: Colors.white),
      ),
      backgroundColor: Colors.blue.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

  void _checkIdentityVisibility() {
  final confession = widget.confession;
  final revealSettings = confession['revealSettings'] as Map<String, dynamic>?;
  final isAuthor = confession['authorId'] == widget.currentUserId;
  
  if (isAuthor) {
    showIdentity = true;
    return;
  }

  // Check if identity is globally revealed (due to threshold)
  if (revealSettings?['revealed'] == true) {
    showIdentity = true;
    return;
  }

  // Check if revealed specifically to this user
  final revealedTo = List<String>.from(revealSettings?['revealedTo'] ?? []);
  if (revealedTo.contains(widget.currentUserId)) {
    showIdentity = true;
    return;
  }

  showIdentity = false;
}

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

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

  void _showReportDialog() {
  final List<String> reportReasons = [
    'Inappropriate Content',
    'Harassment or Bullying',
    'Spam',
    'False Information',
    'Hate Speech',
    'Privacy Violation',
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
              'Report Confession',
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Why are you reporting this confession?',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
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
                    enabledBorder: OutlineInputBorder(
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
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: selectedReason != null
                ? () {
                    final finalReason = selectedReason == 'Other'
                        ? customReasonController.text.trim()
                        : selectedReason!;
                    if (finalReason.isNotEmpty) {
                      Navigator.pop(context);
                      widget.onReport(widget.confessionId, finalReason);
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Report',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}
void _showLikesList(String confessionId, String type) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: const BoxDecoration(
        color: Color(0xFF2A1810),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  type == 'like' ? Icons.favorite : Icons.thumb_down,
                  color: type == 'like' ? Colors.red : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  type == 'like' ? 'Liked by' : 'Disliked by',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('confessions')
                  .doc(confessionId)
                  .collection('interactions')
                  .where('type', isEqualTo: type)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No ${type}s yet',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getUserDetails(snapshot.data!.docs),
                  builder: (context, userSnapshot) {
                    if (!userSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: userSnapshot.data!.length,
                      itemBuilder: (context, index) {
                        final user = userSnapshot.data![index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(int.parse('FF${(user['username'] ?? '').hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                                      const Color(0xFF8B5CF6),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    (user['username'] ?? 'U')[0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
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
                                    Text(
                                      '@${user['username'] ?? 'Unknown'}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (user['year'] != null || user['branch'] != null)
                                      Text(
                                        '${user['year'] ?? ''} ${user['branch'] ?? ''}'.trim(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.white60,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(
                                type == 'like' ? Icons.favorite : Icons.thumb_down,
                                color: type == 'like' ? Colors.red : Colors.blue,
                                size: 16,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
void _showReactionsList(String confessionId) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A0D2E),
            Color(0xFF2D1B69),
            Color(0xFF3E2093),
            Color(0xFF5B2C87),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            blurRadius: 40,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                image: DecorationImage(
                  image: const NetworkImage('data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><pattern id="grain" width="100" height="100" patternUnits="userSpaceOnUse"><circle cx="20" cy="20" r="0.5" fill="%23FFFFFF" opacity="0.02"/><circle cx="80" cy="40" r="0.3" fill="%23FFFFFF" opacity="0.03"/><circle cx="40" cy="80" r="0.4" fill="%23FFFFFF" opacity="0.02"/></pattern></defs><rect width="100" height="100" fill="url(%23grain)"/></svg>'),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                ),
              ),
            ),
          ),
          
          Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D1B69),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFF8B5CF6),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reactions',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'See who reacted to this confession',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider with gradient
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Tab content
              Expanded(
                child: DefaultTabController(
                  length: reactionCounts.keys.length + 3,
                  child: Column(
                    children: [
                      // Custom tab bar with glassmorphism effect
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          isScrollable: false,
                          tabAlignment: TabAlignment.fill,
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF7C3AED), Color(0xFF9333EA), Color(0xFFA855F7)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                          tabs: [
                            _buildCustomTab('All', null),
                            _buildCustomTab('👍', widget.confession['likes'] ?? 0),
                            _buildCustomTab('👎', widget.confession['dislikes'] ?? 0),
                            ...reactionCounts.entries.map(
                              (entry) => _buildCustomTab(entry.key, entry.value),
                            ),
                          ],
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withOpacity(0.7),
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Tab views with custom styling
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildStyledReactionUsersList(confessionId, 'all'),
                            _buildStyledReactionUsersList(confessionId, 'like'),
                            _buildStyledReactionUsersList(confessionId, 'dislike'),
                            ...reactionCounts.keys.map(
                              (reaction) => _buildStyledReactionUsersList(confessionId, reaction),
                            ),
                          ],
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
    ),
  );
}

Widget _buildCustomTab(String label, int? count) {
  return Container(
    height: 40,
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 0.5,
              ),
            ),
            child: Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildStyledReactionUsersList(String confessionId, String reactionType) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.02),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.05),
        width: 1,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: _buildReactionUsersList(confessionId, reactionType),
    ),
  );
}
Widget _buildReactionUsersList(String confessionId, String reactionType) {
  if (reactionType == 'like' || reactionType == 'dislike') {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(confessionId)
          .collection('interactions')
          .where('type', isEqualTo: reactionType)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No ${reactionType}s yet',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          );
        }
        return _buildUsersList(snapshot.data!.docs, reactionType);
      },
    );
  } else {
    // For emoji reactions - fix the where clause
    Query query = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(confessionId)
        .collection('reactions');
    
    if (reactionType != 'all') {
      query = query.where('reaction', isEqualTo: reactionType);
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No reactions yet',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          );
        }
        return _buildUsersList(snapshot.data!.docs, reactionType);
      },
    );
  }
}
Widget _buildUsersList(List<QueryDocumentSnapshot> docs, String type) {
  return FutureBuilder<List<Map<String, dynamic>>>(
    future: _getUserDetailsForReactions(docs),
    builder: (context, userSnapshot) {
      if (!userSnapshot.hasData) {
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: userSnapshot.data!.length,
        itemBuilder: (context, index) {
          final user = userSnapshot.data![index];
          final reaction = user['reaction'] as String?;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(int.parse('FF${(user['username'] ?? '').hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                        const Color(0xFF8B5CF6),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (user['username'] ?? 'U')[0].toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
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
                      Text(
                        '@${user['username'] ?? 'Unknown'}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (user['year'] != null || user['branch'] != null)
                        Text(
                          '${user['year'] ?? ''} ${user['branch'] ?? ''}'.trim(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                    ],
                  ),
                ),
                if (reaction != null)
                  Text(
                    reaction,
                    style: const TextStyle(fontSize: 20),
                  )
                else if (type == 'like')
                  const Icon(Icons.thumb_up, color: Colors.green, size: 16)
                else if (type == 'dislike')
                  const Icon(Icons.thumb_down, color: Colors.red, size: 16),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<List<Map<String, dynamic>>> _getUserDetailsForReactions(List<QueryDocumentSnapshot> docs) async {
  final List<Map<String, dynamic>> users = [];
  
  for (final doc in docs) {
    final data = doc.data() as Map<String, dynamic>;
    final userId = data['userId'] as String;
    final reaction = data['reaction'] as String?;
    
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      
      if (userDoc.docs.isNotEmpty) {
        final userData = userDoc.docs.first.data();
        if (reaction != null) userData['reaction'] = reaction;
        users.add(userData);
      }
    } catch (e) {
      users.add({
        'userId': userId,
        'username': 'Unknown',
        'reaction': reaction,
      });
    }
  }
  
  return users;
}
Future<List<Map<String, dynamic>>> _getUserDetails(List<QueryDocumentSnapshot> interactions) async {
  final List<Map<String, dynamic>> users = [];
  
  for (final interaction in interactions) {
    final userId = interaction.data() as Map<String, dynamic>;
    final userIdString = userId['userId'] as String;
    
    try {
      // First try to get from interactions collection (has username)
      final userDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('userId', isEqualTo: userIdString)
          .limit(1)
          .get();
      
      if (userDoc.docs.isNotEmpty) {
        users.add(userDoc.docs.first.data());
      } else {
        // Fallback with just userId
        users.add({
          'userId': userIdString,
          'username': 'User${userIdString.substring(0, 4)}',
        });
      }
    } catch (e) {
      users.add({
        'userId': userIdString,
        'username': 'Unknown',
      });
    }
  }
  
  return users;
}
  @override
Widget build(BuildContext context) {
  final confession = widget.confession;
  final isAnonymous = confession['isAnonymous'] ?? true;
  final authorUsername = confession['authorUsername'] as String?;
  final authorYear = confession['authorYear'] as String?;
  final authorBranch = confession['authorBranch'] as String?;
  final content = confession['content'] as String? ?? '';
  final likes = confession['likes'] ?? 0;
  final dislikes = confession['dislikes'] ?? 0;
  final commentsCount = confession['commentsCount'] ?? 0;
  final tags = (confession['tags'] as List<dynamic>?)?.cast<String>() ?? [];
  final approvedAt = confession['approvedAt'] as Timestamp?;
  final isAuthor = confession['authorId'] == widget.currentUserId;
  final reactions = widget.userReactions?[widget.confessionId];
final hasLiked = reactions?['liked'] ?? false;
final hasDisliked = reactions?['disliked'] ?? false;
  // Map<String, Map<String, bool>> userReactions = {};

  
  final displayContent = content.length > 300 && !isExpanded 
      ? '${content.substring(0, 300)}...' 
      : content;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF8B5CF6).withOpacity(0.08),
          const Color(0xFFA855F7).withOpacity(0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: const Color(0xFF8B5CF6).withOpacity(0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF8B5CF6).withOpacity(0.1),
          blurRadius: 12,
          spreadRadius: 0,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(18), // Increased padding for better spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Header with better spacing
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  isAnonymous ? Icons.lock_outline : Icons.person_outline,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: // In ConfessionCard build method, replace the existing username display logic:
// Replace the existing username display logic around line 1090-1100
Text(
  (isAnonymous && !showIdentity) 
      ? 'Anonymous' 
      : '@${authorUsername ?? (isAnonymous ? 'Anonymous' : 'Unknown')}',
  style: GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  ),
  overflow: TextOverflow.ellipsis,
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
                        if (approvedAt != null && 
                  (widget.lastSeenTimestamp == null || 
                   approvedAt.toDate().isAfter(widget.lastSeenTimestamp!))) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    'NEW',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                )
                      ],
                      ],
                    ),
                    if ((authorYear != null || authorBranch != null) && (!isAnonymous || showIdentity))
  Container(
    margin: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        if (authorYear != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.2),
                  const Color(0xFFA855F7).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school,
                  size: 10,
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 4),
                Text(
                  authorYear!,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (authorYear != null && authorBranch != null)
          const SizedBox(width: 6),
        if (authorBranch != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF7B42C).withOpacity(0.2),
                  const Color(0xFFFF8C00).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF7B42C).withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.category,
                  size: 10,
                  color: const Color(0xFFF7B42C),
                ),
                const SizedBox(width: 4),
                Text(
                  authorBranch!,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFFF7B42C),
                    fontWeight: FontWeight.w600,
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
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatTimestamp(approvedAt),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Enhanced Content with better typography
          Container(
            width: double.infinity,
            child: Text(
              displayContent,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            ),
          ),

          if (content.length > 300)
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
                        color: const Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF8B5CF6),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),

          // Enhanced Tags with better styling
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags.take(3).map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.2),
                      const Color(0xFFA855F7).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // Enhanced Actions Row with better spacing
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: // Enhanced Actions Row with two rows
// Enhanced Actions Row with two separate scrollable rows
Column(
  children: [
    // First row: Like, Dislike, React, Comment (separately scrollable)
    SizedBox(
      height: 50, // Fixed height to prevent overflow
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildActionButton(
              icon: hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              count: likes,
              isActive: hasLiked,
              activeColor: Colors.green,
              onTap: _handleLike,
              isLikeButton: true,
              confessionId: widget.confessionId,
              userReactions: widget.userReactions ?? {},
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              icon: hasDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
              count: dislikes,
              isActive: hasDisliked,
              activeColor: Colors.red,
              onTap: _handleDislike,
              isDislikeButton: true,
              confessionId: widget.confessionId,
              userReactions: widget.userReactions ?? {},
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              icon: Icons.emoji_emotions_outlined,
              count: reactionCounts.values.isNotEmpty 
                  ? reactionCounts.values.fold<int>(0, (sum, count) => sum + count) 
                  : null,
              // isActive: userReaction != null,
              activeColor: Colors.yellow,
              onTap: _showReactionPicker,
              label: userReaction ?? 'React',
              confessionId: widget.confessionId,
              userReactions: widget.userReactions ?? {},
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              icon: Icons.comment_outlined,
              count: commentsCount,
              // isActive: false,
              activeColor: Colors.blue,
              onTap: () => _showCommentsModal(context),
              confessionId: widget.confessionId,
              userReactions: widget.userReactions ?? {},
            ),
            const SizedBox(width: 16), // Extra padding at end
          ],
        ),
      ),
    ),
    
    const SizedBox(height: 8),
    
    // Second row: Show Reactions, Reveal, Share, Report (separately scrollable)
    // Second row: Show Reactions, Reveal, Share, Report (separately scrollable)
SizedBox(
  height: 50,
  child: SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        if (reactionCounts.isNotEmpty) ...[
          _buildActionButton(
            icon: Icons.visibility_outlined,
            count: null,
            activeColor: Colors.purple,
            onTap: () => _showReactionsList(widget.confessionId),
            label: 'Reactions',
            color: Colors.purple,
            confessionId: widget.confessionId,
            userReactions: widget.userReactions ?? {},
          ),
          const SizedBox(width: 8),
        ],
        if (isAnonymous && !isAuthor && !showIdentity) ...[
          _buildActionButton(
            icon: Icons.visibility_outlined,
            count: null,
            activeColor: Colors.purple,
            onTap: () => widget.onRequestIdentity(widget.confessionId),
            label: 'Reveal',
            color: Colors.purple,
            confessionId: widget.confessionId,
            userReactions: widget.userReactions ?? {},
          ),
          const SizedBox(width: 8),
        ],
        _buildActionButton(
          icon: Icons.share_outlined,
          count: null,
          activeColor: Colors.cyan,
          onTap: () => _shareConfession(),
          label: 'Share',
          color: Colors.cyan,
          confessionId: widget.confessionId,
          userReactions: widget.userReactions ?? {},
        ),
        if (!isAuthor) ...[
          const SizedBox(width: 8),
          _buildActionButton(
            icon: Icons.flag_outlined,
            count: null,
            activeColor: Colors.red,
            onTap: _showReportDialog,
            label: 'Report',
            color: Colors.red,
            confessionId: widget.confessionId,
            userReactions: widget.userReactions ?? {},
          ),
        ],
        const SizedBox(width: 16),
      ],
    ),
  ),
),
  ],
),
          ),

          // Identity requests for author
          if (isAuthor)
            _buildIdentityRequests(),
        ],
      ),
    ),
  );
  
}


Widget _buildActionButton({
  required String confessionId,
  required Map<String, Map<String, bool>> userReactions,
  required IconData icon,
  required int? count,
  required Color activeColor,
  required VoidCallback onTap,
  String? label,
  Color? color,
  bool isLikeButton = false,
  bool isDislikeButton = false,
  bool isActive = false,
  VoidCallback? onLongPress,
  
}) {
  bool currentIsActive = false;

  if (userReactions.containsKey(confessionId)) {
    if (isLikeButton) {
      currentIsActive = userReactions[confessionId]!['liked'] ?? false;
    } else if (isDislikeButton) {
      currentIsActive = userReactions[confessionId]!['disliked'] ?? false;
    }
  }

  final buttonColor = currentIsActive ? Colors.white : (color ?? Colors.white70);
  
  // Create unique button ID
  String buttonId = '${confessionId}_';
  if (isLikeButton) buttonId += 'like';
  else if (isDislikeButton) buttonId += 'dislike';
  else if (label != null) buttonId += label.toLowerCase().replaceAll(' ', '_');
  else buttonId += icon.codePoint.toString();

  return GestureDetector(
    onTapDown: (_) => setState(() => _buttonScale[buttonId] = 0.95),
    onTapUp: (_) => setState(() => _buttonScale[buttonId] = 1.0),
    onTapCancel: () => setState(() => _buttonScale[buttonId] = 1.0),
    onTap: onTap,
    onLongPress: onLongPress,
    child: AnimatedScale(
      scale: _buttonScale[buttonId] ?? 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        key: ValueKey(currentIsActive),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: currentIsActive
              ? LinearGradient(
                  colors: [activeColor.withOpacity(0.8), activeColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: currentIsActive
                ? activeColor.withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
            width: currentIsActive ? 1.5 : 1,
          ),
          boxShadow: currentIsActive && (isLikeButton || isDislikeButton)
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: currentIsActive ? Colors.white : buttonColor,
              size: 16,
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: currentIsActive ? Colors.white : buttonColor,
                  fontWeight: currentIsActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: currentIsActive ? Colors.white : buttonColor,
                  fontWeight: currentIsActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}


  Widget _buildIdentityRequests() {
    final identityRequests = List<Map<String, dynamic>>.from(
      widget.confession['identityRequests'] ?? []
    );
    
    final pendingRequests = identityRequests
        .where((req) => req['status'] == 'pending')
        .toList();

    if (pendingRequests.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Identity Reveal Requests',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 8),
          ...pendingRequests.map((request) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '@${request['requesterUsername']} wants to know your identity',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => widget.onHandleIdentityRequest(
                        widget.confessionId,
                        request['requesterId'],
                        true,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Accept',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => widget.onHandleIdentityRequest(
                        widget.confessionId,
                        request['requesterId'],
                        false,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Reject',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
  
}


// Review Card Widget for Staff
class ReviewCard extends StatefulWidget {
  final Map<String, dynamic> confession;
  final String confessionId;
  final String currentUsername;
  final bool isOwnConfession;
  final Function(String) onApprove;
  final Function(String, String) onReject;
  final Function(String, String) onEdit;

  const ReviewCard({
    super.key,
    required this.confession,
    required this.confessionId,
    required this.currentUsername,
    this.isOwnConfession = false,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool isExpanded = false;
  final TextEditingController _editController = TextEditingController();
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    _editController.text = widget.confession['content'] ?? '';
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate());
  }

  void _showRejectDialog() {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A1810),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reject Confession',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Why are you rejecting this confession?',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: GoogleFonts.poppins(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: GoogleFonts.poppins(color: Colors.white38),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
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
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                widget.onReject(widget.confessionId, reasonController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Reject', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final confession = widget.confession;
    final content = confession['content'] as String? ?? '';
    final authorUsername = confession['authorUsername'] as String?;
    final authorYear = confession['authorYear'] as String?;
    final authorBranch = confession['authorBranch'] as String?;
    final isAnonymous = confession['isAnonymous'] ?? true;
    final createdAt = confession['createdAt'] as Timestamp?;
    final tags = (confession['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    
    final displayContent = content.length > 200 && !isExpanded 
        ? '${content.substring(0, 200)}...' 
        : content;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.withOpacity(0.08),
            Colors.red.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.pending_actions,
                    color: Colors.orange,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnonymous ? 'Anonymous User' : '@${authorUsername ?? 'Unknown'}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      if (authorYear != null || authorBranch != null)
                        Text(
                          '${authorYear ?? ''} ${authorBranch ?? ''}'.trim(),
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _formatTimestamp(createdAt),
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            if (isEditing) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: TextField(
                  controller: _editController,
                  maxLines: null,
                  maxLength: 1000,
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                    counterStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      widget.onEdit(widget.confessionId, _editController.text.trim());
                      setState(() => isEditing = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      _editController.text = confession['content'] ?? '';
                      setState(() => isEditing = false);
                    },
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                displayContent,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              if (content.length > 200)
                GestureDetector(
                  onTap: () => setState(() => isExpanded = !isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      isExpanded ? 'Show less' : 'Read more',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],

            // Tags
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            // Action Buttons
// Action Buttons
SingleChildScrollView(
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () => widget.onApprove(widget.confessionId),
          icon: const Icon(Icons.check, size: 16),
          label: Text(
            'Approve',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEF4444).withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _showRejectDialog,
          icon: const Icon(Icons.close, size: 16),
          label: Text(
            'Reject',
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextButton.icon(
          onPressed: () => setState(() => isEditing = !isEditing),
          icon: const Icon(Icons.edit, size: 16, color: Colors.white),
          label: Text(
            'Edit',
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
      ),
      const SizedBox(width: 16), // Extra padding at end
    ],
  ),
),
          ],
        ),
      ),
    );
  }
}

// Reported Confession Card Widget
class ReportedConfessionCard extends StatefulWidget {
  final Map<String, dynamic> confession;
  final String confessionId;
  final String communityId;
  final String currentUsername;
  final Function(String) onDelete;
  final Function(String) onDismissReports;

  const ReportedConfessionCard({
    super.key,
    required this.confession,
    required this.confessionId,
    required this.communityId,
    required this.currentUsername,
    required this.onDelete,
    required this.onDismissReports,
  });

  @override
  State<ReportedConfessionCard> createState() => _ReportedConfessionCardState();
}

class _ReportedConfessionCardState extends State<ReportedConfessionCard> {
  bool isExpanded = false;
  bool showReports = false;
  List<Map<String, dynamic>> reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc(widget.confessionId)
          .collection('reports')
          // .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          reports = reportsSnapshot.docs
              .map((doc) => doc.data())
              .toList();
        });
      }
    } catch (e) {
      print('Error loading reports: $e');
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final confession = widget.confession;
    final content = confession['content'] as String? ?? '';
    final authorUsername = confession['authorUsername'] as String?;
    final isAnonymous = confession['isAnonymous'] ?? true;
    final reportCount = confession['reportCount'] ?? 0;
    final reviewReason = confession['reviewReason'] as String?;
    
    final displayContent = content.length > 200 && !isExpanded 
        ? '${content.substring(0, 200)}...' 
        : content;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.withOpacity(0.08),
            Colors.orange.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with report info
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.report,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnonymous ? 'Anonymous User' : '@${authorUsername ?? 'Unknown'}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$reportCount report${reportCount > 1 ? 's' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => showReports = !showReports),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      showReports ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),

            if (reviewReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  reviewReason,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Content
            Text(
              displayContent,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                height: 1.5,
              ),
            ),

            if (content.length > 200)
              GestureDetector(
                onTap: () => setState(() => isExpanded = !isExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    isExpanded ? 'Show less' : 'Read more',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            // Reports Details
            if (showReports && reports.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reports:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...reports.map((report) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '@${report['reportedByUsername']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(report['timestamp']),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: Colors.white60,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            report['reason'] ?? 'No reason provided',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    )).toList(),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => widget.onDelete(widget.confessionId),
                  icon: const Icon(Icons.delete, size: 16),
                  label: Text(
                    'Delete',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => widget.onDismissReports(widget.confessionId),
                  icon: const Icon(Icons.check, size: 16),
                  label: Text(
                    'Dismiss Reports',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Comments Page (Modal Bottom Sheet)
class CommentsPage extends StatefulWidget {
  final String confessionId;
  final String communityId;
  final String userId;
  final String username;


  const CommentsPage({
    super.key,
    required this.confessionId,
    required this.communityId,
    required this.userId,
    required this.username,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;
  bool _isRecording = false;
  String? _recordedAudioPath;
  Map<String, bool> _userLikes = {}; // Track which comments user has liked

  // FlutterSoundRecorder? _recorder;
  // bool _isRecorderReady = false;



  @override
  void initState() {
    super.initState();
    // _initRecorder();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    // _recorder?.closeRecorder();
    super.dispose();
  }

//   Future<void> _initRecorder() async {
//     _recorder = FlutterSoundRecorder();
//     await _recorder!.openRecorder();
    
//     final status = await Permission.microphone.request();
//     if (status == PermissionStatus.granted) {
//       setState(() => _isRecorderReady = true);
//     }
//   }
  
// Future<void> _startRecording() async {
//   if (!_isRecorderReady) return;
  
//   // Check permissions first
//   var status = await Permission.microphone.status;
//   if (!status.isGranted) {
//     status = await Permission.microphone.request();
//     if (!status.isGranted) {
//       print('Microphone permission denied');
//       return;
//     }
//   }
  
//   final tempDir = await getTemporaryDirectory();
//   final path = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
  
//   await _recorder!.startRecorder(
//     toFile: path,
//     // codec: Codec.aacADTS,
//   );
  
//   setState(() {
//     _isRecording = true;
//     _recordedAudioPath = path;
//   });
// }
  
//   Future<void> _stopRecording() async {
//     await _recorder!.stopRecorder();
//     setState(() => _isRecording = false);
//   }
  
//   Future<String?> _uploadAudio(String localPath) async {
//     try {
//       final file = File(localPath);
//       final fileName = 'audio_${DateTime.now().millisecondsSinceEpoch}.aac';
//       final ref = FirebaseStorage.instance
//           .ref()
//           .child('communities')
//           .child(widget.communityId)
//           .child('audio_comments')
//           .child(fileName);
      
//       await ref.putFile(file);
//       return await ref.getDownloadURL();
//     } catch (e) {
//       print('Error uploading audio: $e');
//       return null;
//     }
//   }
  
Future<void> _postComment({String? audioPath}) async {
  final text = _commentController.text.trim();
  if (text.isEmpty && _recordedAudioPath == null) return;

  setState(() => _isPosting = true);

  try {
    String? finalAudioPath = _recordedAudioPath;
    
    // TODO: Upload audio to Firebase Storage if exists
    // if (_recordedAudioPath != null) {
    //   finalAudioPath = await _uploadAudio(_recordedAudioPath!);
    // }

    final commentRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('comments')
        .doc();

    await commentRef.set({
      'id': commentRef.id,
      'content': text,
      'audioPath': finalAudioPath, // Will be null until audio upload is implemented
      'authorId': widget.userId,
      'authorUsername': widget.username,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
      'replies': 0,
    });

    // Update comments count
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .update({'commentsCount': FieldValue.increment(1)});

    _commentController.clear();
    setState(() => _recordedAudioPath = null);
    
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to post comment: $e')),
    );
  } finally {
    if (mounted) setState(() => _isPosting = false);
  }
}
  // Add after the _postComment method:
Future<void> _replyToComment(String parentCommentId, String content) async {
  if (content.trim().isEmpty) return;

  try {
    final replyRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('comments')
        .doc(parentCommentId)
        .collection('replies')
        .doc();

    await replyRef.set({
      'id': replyRef.id,
      'content': content,
      'authorId': widget.userId,
      'authorUsername': widget.username,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
    });

    // Update replies count
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('comments')
        .doc(parentCommentId)
        .update({
      'replies': FieldValue.increment(1),
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to post reply: $e')),
    );
  }
}

Future<void> _likeComment(String commentId, bool isCurrentlyLiked) async {
  try {
    final commentRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('comments')
        .doc(commentId);

    final userLikeRef = commentRef.collection('likes').doc(widget.userId);
    
    if (isCurrentlyLiked) {
      // Unlike
      await userLikeRef.delete();
      await commentRef.update({'likes': FieldValue.increment(-1)});
      setState(() => _userLikes[commentId] = false);
    } else {
      // Like
      await userLikeRef.set({'timestamp': FieldValue.serverTimestamp()});
      await commentRef.update({'likes': FieldValue.increment(1)});
      setState(() => _userLikes[commentId] = true);
    }
  } catch (e) {
    print('Error liking comment: $e');
  }
}
void _showReplyDialog(String commentId, String username) {
  final TextEditingController replyController = TextEditingController();
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF2A1810),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Reply to @$username',
        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      content: TextField(
        controller: replyController,
        maxLines: 3,
        style: GoogleFonts.poppins(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Write your reply...',
          hintStyle: GoogleFonts.poppins(color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white60)),
        ),
        ElevatedButton(
          onPressed: () {
            if (replyController.text.trim().isNotEmpty) {
              Navigator.pop(context);
              _replyToComment(commentId, replyController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
          child: Text('Reply', style: GoogleFonts.poppins(color: Colors.white)),
        ),
      ],
    ),
  );
}

void _toggleRecording() async {
  if (_isRecording) {
    // await _stopRecording();
  } else {
    // await _startRecording();
  }
}



  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(
    bottom: MediaQuery.of(context).viewInsets.bottom,
  ),
      decoration: const BoxDecoration(
        color: Color(0xFF2A1810),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'comments',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.2
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),

          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .collection('confessions')
                  .doc(widget.confessionId)
                  .collection('comments')
                  // .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Center(
                      child: Text(
                        'wake up this comment section the way you wake her up',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                return ListView(
  controller: _scrollController,
  padding: const EdgeInsets.all(16),
  children: snapshot.data!.docs.map((doc) {
    final comment = doc.data() as Map<String, dynamic>;
    return CommentCard(
      key: Key('comment_${doc.id}'), // Add stable key
      comment: comment,
      onLike: _likeComment,
      onReply: _showReplyDialog,
      communityId: widget.communityId,
      confessionId: widget.confessionId,
      currentUserId: widget.userId,
    );
  }).toList(),
);
              },
            ),
          ),

          // Comment Input
// Comment Input
Container(
  padding: EdgeInsets.only(
    left: 16,
    right: 16,
    top: 16,
    bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
  ),
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(color: Colors.white.withOpacity(0.1)),
    ),
  ),
  child: Row(
    children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: _commentController,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            maxLines: null,
            maxLength: 500,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          ),
        ),
      ),
      const SizedBox(width: 12),
      
      // Send button
      GestureDetector(
        onTap: _isPosting ? null : () => _postComment(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            ),
            shape: BoxShape.circle,
          ),
          child: _isPosting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
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

// Comment Card Widget
// Enhanced Comment Card Widget
class CommentCard extends StatefulWidget {
  final Map<String, dynamic> comment;
  final Function(String, bool)? onLike;
  final Function(String, String)? onReply;
  final String communityId;
  final String confessionId;
  final String currentUserId;

  const CommentCard({
    super.key,
    required this.comment,
    this.onLike,
    this.onReply,
    required this.communityId,
    required this.confessionId,
    required this.currentUserId,
  });

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> with TickerProviderStateMixin {
  bool isLiked = false;
  bool isPlaying = false;
  bool showReplies = false;
  bool showReplyInput = false;
  final TextEditingController _replyController = TextEditingController();
  late AnimationController _likeController; 

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadUserLike();
  }

  @override
  void dispose() {
    _likeController.dispose();
    _replyController.dispose();
    super.dispose();
  }
  Future<void> _loadUserLike() async {
  try {
    final likeDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId) // You'll need to pass this
        .collection('confessions')
        .doc(widget.confessionId) // You'll need to pass this
        .collection('comments')
        .doc(widget.comment['id'])
        .collection('likes')
        .doc(widget.currentUserId) // You'll need to pass this
        .get();
    
    if (mounted) {
      setState(() => isLiked = likeDoc.exists);
    }
  } catch (e) {
    print('Error loading user like: $e');
  }
}
// Remove the async database call from the UI update
// Just do the optimistic update immediately:
// Replace the existing _toggleLike method:
void _toggleLike() {
  // Immediate UI update
  setState(() => isLiked = !isLiked);
  
  if (isLiked) {
    _likeController.forward();
  } else {
    _likeController.reverse();
  }
  
  // Call parent callback without await
  widget.onLike?.call(widget.comment['id'], !isLiked);
}
Future<void> _likeReply(String replyId) async {
  try {
    final replyRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('confessions')
        .doc(widget.confessionId)
        .collection('comments')
        .doc(widget.comment['id'])
        .collection('replies')
        .doc(replyId);

    final userLikeRef = replyRef.collection('likes').doc(widget.currentUserId);
    
    // Check if already liked
    final likeDoc = await userLikeRef.get();
    if (likeDoc.exists) {
      // Unlike
      await userLikeRef.delete();
      await replyRef.update({'likes': FieldValue.increment(-1)});
    } else {
      // Like
      await userLikeRef.set({'timestamp': FieldValue.serverTimestamp()});
      await replyRef.update({'likes': FieldValue.increment(1)});
    }
  } catch (e) {
    print('Error liking reply: $e');
  }
}
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
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

  @override
Widget build(BuildContext context) {
  final comment = widget.comment;
  final content = comment['content'] as String?;
  final audioPath = comment['audioPath'] as String?;
  final authorUsername = comment['authorUsername'] as String? ?? 'Unknown';
  final likes = comment['likes'] ?? 0;
  final replies = comment['replies'] ?? 0;
  final createdAt = comment['createdAt'] as Timestamp?;
  final commentId = comment['id'] as String;

  return Column(
    children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF8B5CF6).withOpacity(0.05),
              const Color(0xFFA855F7).withOpacity(0.02),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Header with avatar
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(int.parse('FF${authorUsername.hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                          const Color(0xFF8B5CF6),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        authorUsername[0].toUpperCase(),
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
                              '@$authorUsername',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: Colors.white60,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTimestamp(createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white60,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (replies > 0)
                          Text(
                            '$replies ${replies == 1 ? 'reply' : 'replies'}',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: const Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Enhanced Content with better typography
              if (content != null && content.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    content,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),

              // Enhanced Audio Player
              if (audioPath != null)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
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
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => isPlaying = !isPlaying);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Voice message',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '0:30',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: 0.3,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // Enhanced Actions Row
              Row(
                children: [
                  // Like Button with Animation
                  GestureDetector(
                    onTap: _toggleLike,
                    child: AnimatedBuilder(
                      animation: _likeController,
                      builder: (context, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isLiked
                                ? LinearGradient(
                                    colors: [
                                      Colors.red.withOpacity(0.8),
                                      Colors.pink.withOpacity(0.6),
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      Colors.white.withOpacity(0.05),
                                      Colors.white.withOpacity(0.02),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isLiked
                                  ? Colors.red.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.15),
                            ),
                            boxShadow: isLiked
                                ? [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: isLiked ? 1.2 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isLiked ? Icons.favorite : Icons.favorite_border,
                                  color: isLiked ? Colors.white : Colors.white70,
                                  size: 16,
                                ),
                              ),
                              if (likes > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  likes.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isLiked ? Colors.white : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Reply Button with Gradient
                  GestureDetector(
                    onTap: () => widget.onReply?.call(commentId, authorUsername),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF8B5CF6).withOpacity(0.15),
                            const Color(0xFFA855F7).withOpacity(0.08),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.reply_rounded,
                            color: const Color(0xFF8B5CF6),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Reply',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Show/Hide replies button
                  if (replies > 0)
                    GestureDetector(
                      onTap: () => setState(() => showReplies = !showReplies),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$replies ${replies == 1 ? 'reply' : 'replies'}',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: const Color(0xFF8B5CF6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              showReplies ? Icons.expand_less : Icons.expand_more,
                              color: const Color(0xFF8B5CF6),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Time indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatTimestamp(createdAt),
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      
      // Replies Section with proper threading
      if (showReplies)
        Container(
          margin: const EdgeInsets.only(left: 24, bottom: 12),
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('confessions')
                .doc(widget.confessionId)
                .collection('comments')
                .doc(commentId)
                .collection('replies')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Column(
                children: [
                  // Thread line
                  Container(
                    width: 2,
                    height: 20,
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    margin: const EdgeInsets.only(left: 18),
                  ),
                  ...snapshot.data!.docs.map((replyDoc) {
                    final reply = replyDoc.data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thread connector
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 2,
                                  height: 40,
                                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 12,
                                  height: 2,
                                  color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Reply content
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.03),
                                    Colors.white.withOpacity(0.01),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(int.parse('FF${(reply['authorUsername'] ?? '').hashCode.toRadixString(16).substring(0, 6).padLeft(6, '0')}', radix: 16)),
                                              const Color(0xFF8B5CF6),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            (reply['authorUsername'] ?? 'U')[0].toUpperCase(),
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '@${reply['authorUsername']}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF8B5CF6),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatTimestamp(reply['createdAt']),
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.white60,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    reply['content'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Reply like button
                                  GestureDetector(
                                    onTap: () => _likeReply(replyDoc.id),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.05),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.favorite_border,
                                            color: Colors.white60,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${reply['likes'] ?? 0}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 10,
                                              color: Colors.white60,
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
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            },
          ),
        ),
    ],
  );
}
}

// Audio Recording Helper (Placeholder)

// Enhanced Search Functionality
class SearchPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final String userRole;
  final Function(String, bool, bool) onLike;
  final Function(String, bool, bool) onDislike; 
  final Function(String, String) onReport;
  final Function(String) onRequestIdentity; 
  final Function(String, String, bool) onHandleIdentityRequest;
  final Map<String, Map<String, bool>>? userReactions;
  final DateTime? lastSeenTimestamp;


  const SearchPage({
    super.key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
    required this.onLike,
    required this.onDislike,
    required this.onReport,
     required this.onRequestIdentity,
    required this.onHandleIdentityRequest,
    this.userReactions,
    this.lastSeenTimestamp
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<QueryDocumentSnapshot> _searchResults = [];
  bool _isSearching = false;
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    // _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // Future<void> _loadRecentSearches() async {
  //   // TODO: Load from local storage or user preferences
  //   setState(() {
  //     _recentSearches = ['#college', '#life', '#anonymous', '#funny'];
  //   });
  // }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .where('status', isEqualTo: 'approved')
          .get();

      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final content = (data['content'] as String? ?? '').toLowerCase();
        final tags = (data['tags'] as List<dynamic>? ?? [])
            .map((tag) => tag.toString().toLowerCase())
            .toList();
        final searchQuery = query.toLowerCase();

        return content.contains(searchQuery) ||
               tags.any((tag) => tag.contains(searchQuery));
      }).toList();

      setState(() => _searchResults = results);
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() => _isSearching = false);
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
             const Color(0xFF2D1B69),
             const Color(0xFF1A0D2E),
           Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Search Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFFF7B42C),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          autofocus: true,
                          style: GoogleFonts.poppins(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search confessions, #tags...',
                            hintStyle: GoogleFonts.poppins(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search, color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          ),
                          onChanged: _performSearch,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search Results or Recent Searches
              Expanded(
                child: _searchController.text.isEmpty
                    ? _buildRecentSearches()
                    : _buildSearchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearches() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'Recent Searches',
          //   style: GoogleFonts.poppins(
          //     fontSize: 16,
          //     fontWeight: FontWeight.w600,
          //     color: Colors.white,
          //   ),
          // ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSearches.map((search) => GestureDetector(
              onTap: () {
                _searchController.text = search;
                _performSearch(search);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                ),
                child: Text(
                  search,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF8B5CF6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
  if (_isSearching) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
    );
  }

  if (_searchResults.isEmpty) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            color: Colors.white60,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'no confessions found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white60,
            ),
          ),
          Text(
            'try different keywords or hashtags',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  return ListView(
  padding: const EdgeInsets.all(16),
  children: _searchResults.map((doc) {
    return ConfessionCard(
      key: Key('search_${doc.id}'), // Add stable key
      confession: doc.data() as Map<String, dynamic>,
      confessionId: doc.id,
      currentUserId: widget.userId,
      currentUsername: widget.username,
      userRole: widget.userRole,
      communityId: widget.communityId,
      onLike: widget.onLike,
      onDislike: widget.onDislike,
      onReport: widget.onReport,
      onRequestIdentity: widget.onRequestIdentity,
      onHandleIdentityRequest: widget.onHandleIdentityRequest,
      userReactions: widget.userReactions,
      lastSeenTimestamp: widget.lastSeenTimestamp,
    );
  }).toList(),
);
}
}