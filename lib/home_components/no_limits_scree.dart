import 'dart:async';
import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup/home_components/upload_meme_screen.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class NoLimitsPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const NoLimitsPage({
    super.key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  });

  @override
  State<NoLimitsPage> createState() => _NoLimitsPageState();
}

class _NoLimitsPageState extends State<NoLimitsPage> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<QuerySnapshot>? _memesSubscription;
  List<QueryDocumentSnapshot> _allMemes = [];
  List<QueryDocumentSnapshot> _filteredMemes = [];
  
  // Changed to int for discrete values
  // Map<String, dynamic>? _userProfile;
  List<String> _pinnedMemeIds = [];
  bool _isSearching = false;
  String _searchQuery = '';
  Timer? _debounceTimer;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

final TextEditingController _captionController = TextEditingController();
File? _selectedImage;
bool _postAnonymously = false;
bool _isUploading = false;

Map<String, ValueNotifier<int>> _sliderNotifiers = {};
final ValueNotifier<bool> _showUploadSectionNotifier = ValueNotifier(false);

final FocusNode _searchFocusNode = FocusNode();

  bool get isStaff => ['admin', 'moderator', 'manager'].contains(widget.userRole);

  Map<String, dynamic>? _userProfile;
final Map<String, Map<String, dynamic>?> _userCache = {};

  // Reaction definitions with discrete values
  final List<Map<String, dynamic>> reactions = [
    {'emoji': '😬', 'value': 0},
    {'emoji': '😐', 'value': 1},
    {'emoji': '😂', 'value': 2},
    {'emoji': '🤣', 'value': 3},
    {'emoji': '🔥', 'value': 4},
    {'emoji': '💀', 'value': 5},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadPinnedMemes();
    _initAnimations();
    _setupMemesStream();
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
    _scrollController.dispose();
    _searchController.dispose();
    _fadeController.dispose();
    _debounceTimer?.cancel();
    _searchFocusNode.dispose();
    _captionController.dispose();
    _showUploadSectionNotifier.dispose();
    _sliderNotifiers.forEach((key, notifier) => notifier.dispose());
    _memesSubscription?.cancel(); // Cancel stream subscription
    super.dispose();
  }

    void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

    void _setupMemesStream() {
    _memesSubscription = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        _allMemes = snapshot.docs;
        _applySearchFilter();
      }
    });
  }

  void _applySearchFilter() {
    if (_isSearching && _searchQuery.isNotEmpty) {
      _filteredMemes = _allMemes.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final caption = (data['caption'] ?? '').toString().toLowerCase();
        final username = (data['authorUsername'] ?? '').toString().toLowerCase();
        final fullName = '${data['authorFirstName'] ?? ''} ${data['authorLastName'] ?? ''}'.toLowerCase();
        
        return caption.contains(_searchQuery) ||
               username.contains(_searchQuery) ||
               fullName.contains(_searchQuery);
      }).toList();
    } else {
      _filteredMemes = _allMemes;
    }

    // Sort to put pinned memes first
    _filteredMemes.sort((a, b) {
      final isPinnedA = _pinnedMemeIds.contains(a.id);
      final isPinnedB = _pinnedMemeIds.contains(b.id);
      if (isPinnedA && !isPinnedB) return -1;
      if (!isPinnedA && isPinnedB) return 1;
      return 0;
    });

    if (mounted) {
      setState(() {});
    }
  }

  // Add these notification methods
Future<void> _createNotification({
  required String recipientUserId,
  required String title,
  required String body,
  required String type,
  String? memeId,
  String? commentId,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientUserId)
        .collection('notifications')
        .add({
      'type': type, // 'meme_reaction', 'meme_comment', 'comment_like', 'comment_reply'
      'title': title,
      'message': body, // Changed from 'body' to 'message' to match your notification structure
      'senderName': widget.username,
      'senderId': widget.userId,
      'memeId': memeId,
      'commentId': commentId,
      'timestamp': FieldValue.serverTimestamp(), // Changed from 'createdAt' to 'timestamp'
      'read': false,
    });
  } catch (e) {
    debugPrint('Error creating notification: $e');
  }
}
// Update the existing _updateMemeReaction method
Future<void> _updateMemeReaction(String memeId, int value) async {
  if (value == -1) {
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .doc(memeId)
        .update({
      'reactions.${widget.userId}': FieldValue.delete(),
    });
  } else {
    try {
      // Get meme data to find author
      final memeDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('memes')
          .doc(memeId)
          .get();
      
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('memes')
          .doc(memeId)
          .update({
        'reactions.${widget.userId}': value,
      });
      
      // Create notification for meme author
      if (memeDoc.exists) {
        final memeData = memeDoc.data() as Map<String, dynamic>;
        final authorId = memeData['authorId'];
        if (authorId != null && authorId != widget.userId && authorId != 'anonymous') {
          final reactionEmoji = reactions[value]['emoji'];
await _createNotification(
  recipientUserId: authorId,
  title: 'New Reaction',
  body: '${widget.username} reacted $reactionEmoji to your meme',
  type: 'meme_reaction',
  memeId: memeId,
);
        }
      }
    } catch (e) {
       FirebaseCrashlytics.instance.recordError(e, null, // ← ADD THIS
        information: ['Updating meme reaction for meme: $memeId']);
      debugPrint('Error updating reaction: $e');
    }
  }
}
  Future<void> _loadUserProfile() async {
    try {
      // Try members first
      var doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .doc(widget.username)
          .get();

      // If not found in members, try trio
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('trio')
            .doc(widget.username)
            .get();
      }

      if (doc.exists && mounted) {
        setState(() => _userProfile = doc.data());
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, null, // ← ADD THIS
        information: ['Loading user profile for ${widget.username}']);
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load profile: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
      debugPrint('Error loading user profile: $e');
    }
  }

  bool _isLoading = false;

  Future<void> _loadPinnedMemes() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (doc.exists && mounted) {
        setState(() {
          _pinnedMemeIds = List<String>.from(doc.data()?['pinnedMemes'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading pinned memes: $e');
    }
  }

Future<Map<String, dynamic>?> _getUserData(String username) async {
   final trace = FirebasePerformance.instance.newTrace('get_user_data'); // ← ADD THIS
    await trace.start(); 
  // Check cache first
  if (_userCache.containsKey(username)) {
      trace.setMetric('cache_hit', 1); // ← ADD THIS
        await trace.stop(); 
    return _userCache[username];
  }
  trace.setMetric('cache_hit', 0); 

  try {
    DocumentSnapshot? userDoc;
    
    // Check trio collection first
    final trioQuery = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    
    if (trioQuery.docs.isNotEmpty) {
      userDoc = trioQuery.docs.first;
    } else {
      // Check members collection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (membersQuery.docs.isNotEmpty) {
        userDoc = membersQuery.docs.first;
      }
    }

    final userData = userDoc?.data() != null 
        ? userDoc!.data() as Map<String, dynamic>
        : null;
    _userCache[username] = userData; // Cache it
    trace.setMetric('success', 1); // ← ADD THIS
        await trace.stop();
    return userData;
  } catch (e) {
    FirebaseCrashlytics.instance.recordError(e, null);
         trace.setMetric('success', 0); // ← ADD THIS
        await trace.stop(); 
    debugPrint('Error fetching user data for $username: $e');
    _userCache[username] = null; // Cache null result
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

  Future<void> _pickImage() async {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1920, // ← ADD THIS: Limit image size
    maxHeight: 1920,
    imageQuality: 100, // ← ADD THIS: Compress image
  );
  if (image != null) {
    final File imageFile = File(image.path);
    
    // ❌ YOU'RE MISSING THIS VALIDATION CALL
    if (await _validateImage(imageFile)) {
      setState(() {
        _selectedImage = imageFile;
      });
    }
    // setState(() {
    //   _selectedImage = File(image.path);
    // });
  }
}


Future<void> _refreshMemes() async {
  try {
    setState(() => _isLoading = true);
    
    // Reload pinned memes
    await _loadPinnedMemes();
    
    // The StreamBuilder will automatically refresh when this completes
    // You could also clear caches here if needed
    _userCache.clear();
    
  //   if (mounted) {
  //     _showMessage('Refreshed successfully!');
  //   }
  // } catch (e) {
  //   if (mounted) {
  //     _showMessage('Failed to refresh: $e', isError: true);
  //   }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}

void _unfocusAll() {
  _searchController.clear();
  FocusScope.of(context).unfocus();
  setState(() {
    _isSearching = false;
    _searchQuery = '';
  });
}

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus(); // Add this
    _debounceTimer?.cancel();
    if (mounted) {
      _searchQuery = '';
      _isSearching = false;
      _applySearchFilter();
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: GestureDetector(
         onTap: _dismissKeyboard,
      child: Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF3D0000),
        const Color(0xFF2A0000),
        const Color(0xFF1A0000),
        Colors.black,
      ],
    ),
  ),
  child: SafeArea(
    top: false,
    child: Column(
      children: [
        _buildHeader(),
       ValueListenableBuilder<bool>(
  valueListenable: _showUploadSectionNotifier,
  builder: (context, showUpload, child) {
    return showUpload ? _buildUploadSection() : const SizedBox.shrink();
  },
),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildMemesList(),
          ),
        ),
      ],
    ),
  ),
),
    ),
      floatingActionButton: _buildUploadFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
    padding: EdgeInsets.fromLTRB(
      ScreenUtil.responsiveWidth(context, 0.05), // 5% of screen width
      MediaQuery.of(context).padding.top + 16,
      ScreenUtil.responsiveWidth(context, 0.05),
      16,),
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //     colors: [
      //       Colors.red.shade900.withOpacity(0.3),
      //       Colors.transparent,
      //     ],
      //   ),
      // ),
      child: Column(
        children: [
          Row(
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
        color: Colors.red.shade600.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.red.shade600.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      Icons.arrow_back_ios_new,
      color: Colors.red.shade400,
      size: ScreenUtil.isTablet(context) ? 22 : 18,
    ),
  ),
),
              Container(
                margin: EdgeInsets.only(left: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade700, Colors.red.shade900],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade700.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.whatshot, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade700],
                      ).createShader(bounds),
                      child: Text(
                        'no limits',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: ResponsiveFonts.title(context),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                    Text(
                      'you gotta be cooked if \nthis gets leaked',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveFonts.caption(context),
                        color: const Color.fromARGB(255, 223, 91, 91),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
      onTap: _isLoading ? null : _refreshMemes,
      child: Container(
        
        padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 10 : 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(ScreenUtil.isTablet(context) ? 14 : 12),
          border: Border.all(
            color: Colors.red.shade600.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.red.shade600.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _isLoading
            ? SizedBox(
                width: ScreenUtil.isTablet(context) ? 22 : 18,
                height: ScreenUtil.isTablet(context) ? 22 : 18,
                child: CircularProgressIndicator(
                  color: Colors.red.shade400,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                Icons.refresh,
                color: Colors.red.shade400,
                size: ScreenUtil.isTablet(context) ? 22 : 18,
              ),
      ),
    ),
 
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.red.shade900.withOpacity(0.3),
          Colors.red.shade800.withOpacity(0.2),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.shade700.withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Meme',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        
        // Image upload area
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.shade700.withOpacity(0.3),
                style: BorderStyle.solid,
              ),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate,
                        color: Colors.red.shade300,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select image',
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Caption input
        TextField(
          controller: _captionController,

          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add a caption (optional)...',
            hintStyle: GoogleFonts.poppins(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade700.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade700.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade500),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Anonymous toggle
        Row(
          children: [
            Switch(
              value: _postAnonymously,
              onChanged: (value) {
                setState(() {
                  _postAnonymously = value;
                });
              },
              activeColor: Colors.red.shade600,
              activeTrackColor: Colors.red.shade600.withOpacity(0.3),
            ),
            const SizedBox(width: 8),
            Text(
              'Post anonymously',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // Upload button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _selectedImage != null && !_isUploading ? _uploadMeme : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isUploading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Uploading...',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Post Meme',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    ),
  );
}

 Widget _buildSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.red.shade800.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'search...',
          hintStyle: GoogleFonts.poppins(color: Colors.white38),
          prefixIcon: Icon(Icons.search, color: Colors.red.shade300, size: 20),
          suffixIcon: _isSearching 
              ? GestureDetector(
                  onTap: _clearSearch,
                  child: Icon(Icons.clear, color: Colors.red.shade300, size: 20),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        onChanged: (value) {
          // Cancel previous timer
          _debounceTimer?.cancel();
          
          // Only start new timer if value is not empty
          if (value.trim().isNotEmpty) {
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted) {
                _searchQuery = value.toLowerCase();
                _isSearching = true;
                _applySearchFilter(); // Apply filter without setState in main method
              }
            });
          } else {
            // Immediately clear search when text becomes empty
            if (mounted) {
              _searchQuery = '';
              _isSearching = false;
              _applySearchFilter(); // Apply filter without setState in main method
            }
          }
        },
      ),
    );
  }
Widget _buildMemesList() {
    if (_allMemes.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: Colors.red.shade600),
      );
    }

    if (_filteredMemes.isEmpty && _isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.red.shade300, size: 64),
            const SizedBox(height: 16),
            Text(
              'No memes found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Try different search terms',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
            ),
          ],
        ),
      );
    }

    if (_filteredMemes.isEmpty && !_isSearching) {
      return _buildEmptyState();
    }

    return ListView.builder(
      key: const ValueKey('memes_listview'),
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredMemes.length,
      cacheExtent: 1000,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: false,
      itemBuilder: (context, index) {
        final meme = _filteredMemes[index].data() as Map<String, dynamic>;
        final memeId = _filteredMemes[index].id;
        final isPinned = _pinnedMemeIds.contains(memeId);
        
        final userReaction = (meme['reactions'] as Map<String, dynamic>?)?[widget.userId];
        final sliderNotifier = _sliderNotifiers.putIfAbsent(
          memeId,
          () => ValueNotifier(userReaction ?? -1),
        );

        return CompactMemeCard(
          key: ValueKey('meme_$memeId'),
          meme: meme,
          memeId: memeId,
          isPinned: isPinned,
          communityId: widget.communityId,
          currentUserId: widget.userId,
          currentUsername: widget.username,
          isStaff: isStaff,
          getUserData: _getUserData,
          reactions: reactions,
          sliderNotifier: sliderNotifier,
          onSliderChanged: (value) {
            sliderNotifier.value = value;
            _updateMemeReactionDebounced(memeId, value);
          },
          onDelete: () => _deleteMeme(memeId),
          onPin: () => _togglePinMeme(memeId),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, color: Colors.red.shade300, size: 64),
          const SizedBox(height: 16),
          Text(
            'No memes yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Be the first to share a meme!',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
          ),
        ],
      ),
    );
  }

Widget _buildUploadFAB() {
  return Semantics( // ← ADD THIS WRAPPER
    label: 'Upload new meme',
    hint: 'Tap to create and upload a new meme',
    button: true,
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      gradient: LinearGradient(
        colors: [Colors.red.shade600, Colors.red.shade800],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.red.shade600.withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    
    child: FloatingActionButton.extended(
      onPressed: () {
        _dismissKeyboard();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UploadMemeScreen(
              communityId: widget.communityId,
              userId: widget.userId,
              username: widget.username,
              userProfile: _userProfile,
            ),
          ),
        ).then((uploaded) {
          if (uploaded == true) {
            _showMessage('Meme uploaded successfully!');
          }
        });
      },
      backgroundColor: Colors.transparent,
      elevation: 0,
      label: Text(
        'post meme',
        style: GoogleFonts.poppins(
          fontSize: ResponsiveFonts.body(context),
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      icon: const Icon(
        Icons.add_photo_alternate,
        color: Colors.white,
      ),
    ),
  )
  );
}

Future<bool> _validateImage(File imageFile) async {
  try {
    // Check file size (max 10MB)
    final fileSize = await imageFile.length();
    if (fileSize > 10 * 1024 * 1024) {
      _showMessage('Image too large. Please select an image under 10MB.', isError: true);
      return false;
    }
    
    // Check if it's actually an image
    final bytes = await imageFile.readAsBytes();
    if (!_isValidImageFormat(bytes)) {
      _showMessage('Invalid image format. Please select a valid image.', isError: true);
      return false;
    }
    
    return true;
  } catch (e) {
    _showMessage('Error validating image: $e', isError: true);
    return false;
  }
}

bool _isValidImageFormat(Uint8List bytes) {
  // Check for common image headers
  if (bytes.length < 4) return false;
  
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
  // PNG
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return true;
  // WebP
  if (bytes.length >= 12 && 
      bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50) return true;
  
  return false;
}
  Future<void> _uploadMeme() async {
     final trace = FirebasePerformance.instance.newTrace('upload_meme'); // ← ADD THIS
    await trace.start();
    if (!await NetworkChecker.isConnected()) {
    _showMessage('No internet connection', isError: true);
    await trace.stop();
    return;
  }
  if (_selectedImage == null) return;

  final caption = _captionController.text.trim();
  if (caption.isNotEmpty && !ContentFilter.isContentAppropriate(caption)) {
    final reason = ContentFilter.getFilterReason(caption);
    _showMessage(reason, isError: true);
    return;
  }
  
  setState(() => _isUploading = true);

  try {
    final fileName = 'meme_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('communities')
        .child(widget.communityId)
        .child('memes')
        .child(fileName);
    
    await ref.putFile(_selectedImage!);
    final imageUrl = await ref.getDownloadURL();

    final memeRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .doc();

    await memeRef.set({
  'id': memeRef.id,
  'imageUrl': imageUrl,
  'caption': _captionController.text.trim(),
  'authorId': _postAnonymously ? 'anonymous' : widget.userId,
  'actualAuthorId': widget.userId, // Always store the real author ID
  'authorUsername': _postAnonymously ? 'Anonymous' : widget.username,
  'authorFirstName': _postAnonymously ? '' : (_userProfile?['firstName'] ?? ''),
  'authorLastName': _postAnonymously ? '' : (_userProfile?['lastName'] ?? ''),
  'authorYear': _postAnonymously ? '' : (_userProfile?['year'] ?? ''),
  'authorBranch': _postAnonymously ? '' : (_userProfile?['branch'] ?? ''),
  'isAnonymous': _postAnonymously,
  'createdAt': FieldValue.serverTimestamp(),
  'reactions': {},
  'commentsCount': 0,
});

     if (!_postAnonymously) {
    _notifyMemePosted(memeRef.id);
  }


    // Reset form
    setState(() {
      _selectedImage = null;
      _captionController.clear();
      _postAnonymously = false;
      _showUploadSectionNotifier.value = false;
      _isUploading = false;
    });
         trace.setMetric('success', 1); // ← ADD THIS
        trace.setMetric('file_size_mb', (await _selectedImage!.length()) ~/ (1024 * 1024));
    _showMessage('Meme uploaded successfully!');
  } catch (e) {
    FirebaseCrashlytics.instance.recordError(e, null, // ← ADD THIS
        information: ['Uploading meme']);
        trace.setMetric('success', 0);
    setState(() => _isUploading = false);

    _showMessage('Failed to upload meme: $e', isError: true);
  }
}

Future<void> _notifyMemePosted(String memeId) async {
  try {
    // Get community members (optional - you can skip this if you don't want to spam)
    // This is just an example - you might want to notify only followers or friends
    final membersSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .limit(50) // Limit to prevent too many notifications
        .get();

    // Create notifications for a subset of members
    for (var memberDoc in membersSnapshot.docs.take(10)) { // Only notify first 10
      final memberData = memberDoc.data();
      final memberId = memberData['userId'];
      
      if (memberId != null && memberId != widget.userId) {
        await _createNotification(
          recipientUserId: memberId,
          title: 'New meme posted',
          body: '${widget.username} shared a new meme in No Limits',
          type: 'meme_posted',
          memeId: memeId,
        );
      }
    }
  } catch (e) {
    debugPrint('Error notifying meme posted: $e');
  }
}

  // Debounced reaction update to prevent frequent rebuilds
  void _updateMemeReactionDebounced(String memeId, int value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateMemeReaction(memeId, value);
    });
  }

//   Future<void> _updateMemeReaction(String memeId, int value) async {
//     if (value == -1) {
//   // Remove reaction
//   await FirebaseFirestore.instance
//       .collection('communities')
//       .doc(widget.communityId)
//       .collection('memes')
//       .doc(memeId)
//       .update({
//     'reactions.${widget.userId}': FieldValue.delete(),
//   });
// } else {
//     try {
//       await FirebaseFirestore.instance
//           .collection('communities')
//           .doc(widget.communityId)
//           .collection('memes')
//           .doc(memeId)
//           .update({
//         'reactions.${widget.userId}': value,
//       });
//     } catch (e) {
//       debugPrint('Error updating reaction: $e');
//     }
    
//   }
  
//   }

  Future<void> _deleteMeme(String memeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A0000),
        title: Text(
          'Delete Meme?',
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete this meme?',
          style: GoogleFonts.poppins(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('memes')
            .doc(memeId)
            .delete();
        _showMessage('Meme deleted successfully');
      } catch (e) {
        _showMessage('Failed to delete meme: $e', isError: true);
      }
    }
  }

  Future<void> _togglePinMeme(String memeId) async {
    try {
      final isPinned = _pinnedMemeIds.contains(memeId);
      
      if (isPinned) {
        _pinnedMemeIds.remove(memeId);
      } else {
        if (_pinnedMemeIds.length >= 3) {
          _showMessage('Maximum 3 memes can be pinned', isError: true);
          return;
        }
        _pinnedMemeIds.add(memeId);
      }

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .update({'pinnedMemes': _pinnedMemeIds});

      setState(() {});
      _showMessage(isPinned ? 'Meme unpinned' : 'Meme pinned');
    } catch (e) {
      _showMessage('Failed to update pin status: $e', isError: true);
    }
  }
}



class CompactMemeCard extends StatefulWidget {
  final Map<String, dynamic> meme;
  final String memeId;
  final bool isPinned;
  final String communityId;
  final String currentUserId;
  final String currentUsername;
  final bool isStaff;
  final List<Map<String, dynamic>> reactions;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  // With:
final ValueNotifier<int> sliderNotifier;
final ValueChanged<int> onSliderChanged;
final Future<Map<String, dynamic>?> Function(String)? getUserData;

  const CompactMemeCard({
    super.key,
    required this.meme,
    required this.memeId,
    required this.isPinned,
    required this.communityId,
    required this.currentUserId,
    required this.currentUsername,
    required this.isStaff,
    required this.reactions,
    required this.onSliderChanged,
    required this.onDelete,
    required this.onPin,
     required this.sliderNotifier,
     this.getUserData,
  });

  @override
  State<CompactMemeCard> createState() => _CompactMemeCardState();
}

class _CompactMemeCardState extends State<CompactMemeCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Map<int, int> _reactionCounts = {};





  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _calculateReactionCounts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }



  void _calculateReactionCounts() {
    final reactions = widget.meme['reactions'] as Map<String, dynamic>? ?? {};
    _reactionCounts = {};
    
    for (int i = 0; i < widget.reactions.length; i++) {
      _reactionCounts[i] = 0;
    }
    
    // In reaction counts calculation, handle -1:
reactions.forEach((userId, value) {
  if (value is int && value >= 0 && value < widget.reactions.length) {
    _reactionCounts[value] = (_reactionCounts[value] ?? 0) + 1;
  }
});
  }

void _showCommentsModal() {
  // Dismiss keyboard first
  FocusScope.of(context).unfocus();
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    enableDrag: true,
    isDismissible: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: CommentsModal(
        memeId: widget.memeId,
        communityId: widget.communityId,
        userId: widget.currentUserId,
        username: widget.currentUsername,
      ),
    ),
  );
}

  void _showEnlargedImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: widget.meme['imageUrl'],
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return '';
  
  DateTime dateTime;
  if (timestamp is Timestamp) {
    dateTime = timestamp.toDate();
  } else {
    return '';
  }
  
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays > 0) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours > 0) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'now';
  }
}

  

  @override
  Widget build(BuildContext context) {
    final meme = widget.meme;
    final authorUsername = meme['authorUsername'] ?? 'Unknown';
    final authorFirstName = meme['authorFirstName'] ?? '';
    final authorLastName = meme['authorLastName'] ?? '';
    final fullName = '$authorFirstName $authorLastName'.trim();
    final year = meme['authorYear'] ?? '';
    final branch = meme['authorBranch'] ?? '';
    final caption = meme['caption'] ?? '';
    final isAuthor = (widget.meme['actualAuthorId'] == widget.currentUserId) || 
                 (widget.meme['authorId'] == widget.currentUserId);

    _calculateReactionCounts();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade900.withOpacity(0.2),
            Colors.red.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isPinned
              ? Colors.amber.shade600
              : Colors.red.shade700.withOpacity(0.3),
          width: widget.isPinned ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact Header
          // Compact Header
// Replace the existing Padding widget with user info with:
Padding(
  padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 16 : 12),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: widget.getUserData != null ? widget.getUserData!(authorUsername) : Future.value(null),
            builder: (context, snapshot) {
              final userData = snapshot.data;
              final profileImageUrl = userData?['profileImageUrl'];
              final firstName = userData?['firstName'] ?? '';
              final lastName = userData?['lastName'] ?? '';
              final fullName = '$firstName $lastName'.trim();
              final branch = userData?['branch']?.toString() ?? '';
              final year = userData?['year']?.toString() ?? '';
              
              // Responsive sizes
              final isTablet = ScreenUtil.isTablet(context);
              final avatarSize = isTablet ? 48.0 : 40.0;
              final primaryFontSize = isTablet ? 16.0 : 14.0;
              final secondaryFontSize = isTablet ? 14.0 : 12.0;
              final captionFontSize = isTablet ? 12.0 : 10.0;
              final badgeFontSize = isTablet ? 12.0 : 10.0;
              final spacing = isTablet ? 16.0 : 12.0;
              
              return Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!widget.meme['isAnonymous']) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                username: authorUsername,
                                communityId: widget.communityId,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.red.shade600,
                            width: isTablet ? 3 : 2,
                          ),
                        ),
                        child: profileImageUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  profileImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.red.shade600, Colors.red.shade800],
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        firstName.isNotEmpty
                                            ? firstName[0].toUpperCase()
                                            : authorUsername[0].toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: primaryFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.red.shade600, Colors.red.shade800],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    firstName.isNotEmpty
                                        ? firstName[0].toUpperCase()
                                        : authorUsername[0].toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: primaryFontSize,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!(widget.meme['isAnonymous'] == true)) ...[
                            // Full name as primary text
                            if (fullName.isNotEmpty)
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
                                  fullName,
                                  style: GoogleFonts.poppins(
                                    fontSize: primaryFontSize,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // Username as secondary text
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
                                '@$authorUsername',
                                style: GoogleFonts.poppins(
                                  fontSize: secondaryFontSize,
                                  color: Colors.red.shade300,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else ...[
                            Text(
                              'Anonymous',
                              style: GoogleFonts.poppins(
                                fontSize: primaryFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                          // Time display
                          SizedBox(height: isTablet ? 4 : 2),
                          Text(
                            _formatTimestamp(widget.meme['createdAt']),
                            style: GoogleFonts.poppins(fontSize: captionFontSize, color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    // Branch and Year badges - responsive layout
                   // Branch and Year badges - horizontal layout
if (!(widget.meme['isAnonymous'] == true) && (branch.isNotEmpty || year.isNotEmpty))
  Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (branch.isNotEmpty)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 10 : 8, 
            vertical: isTablet ? 6 : 4
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700.withOpacity(0.3), Colors.red.shade800.withOpacity(0.2)],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
            border: Border.all(color: Colors.red.shade600.withOpacity(0.4)),
          ),
          child: Text(
            branch,
            style: GoogleFonts.poppins(
              fontSize: badgeFontSize,
              fontWeight: FontWeight.w500,
              color: Colors.red.shade200,
            ),
          ),
        ),
      if (branch.isNotEmpty && year.isNotEmpty) SizedBox(width: isTablet ? 6 : 4),
      if (year.isNotEmpty)
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 10 : 8, 
            vertical: isTablet ? 6 : 4
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700.withOpacity(0.3), Colors.red.shade800.withOpacity(0.2)],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
            border: Border.all(color: Colors.red.shade600.withOpacity(0.4)),
          ),
          child: Text(
            year,
            style: GoogleFonts.poppins(
              fontSize: badgeFontSize,
              fontWeight: FontWeight.w500,
              color: Colors.red.shade200,
            ),
          ),
        ),
    ],
  ),
                  ],
                ),
              );
            },
          ),
          // Pinned badge and menu - responsive
          if (widget.isPinned) ...[
            SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: ScreenUtil.isTablet(context) ? 6 : 4, 
                vertical: ScreenUtil.isTablet(context) ? 3 : 1
              ),
              decoration: BoxDecoration(
                color: Colors.amber.shade600,
                borderRadius: BorderRadius.circular(ScreenUtil.isTablet(context) ? 5 : 3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin, 
                    color: Colors.white, 
                    size: ScreenUtil.isTablet(context) ? 12 : 8
                  ),
                  SizedBox(width: ScreenUtil.isTablet(context) ? 4 : 2),
                  Text(
                    'PINNED',
                    style: GoogleFonts.poppins(
                      fontSize: ScreenUtil.isTablet(context) ? 9 : 7,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert, 
              color: Colors.red.shade300, 
              size: ScreenUtil.isTablet(context) ? 22 : 18
            ),
            color: const Color(0xFF2A0000),
            itemBuilder: (context) => [
              if (widget.isStaff) ...[
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        widget.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                        color: Colors.white70,
                        size: ScreenUtil.isTablet(context) ? 18 : 16,
                      ),
                      SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
                      Text(
                        widget.isPinned ? 'Unpin' : 'Pin',
                        style: GoogleFonts.poppins(
                          color: Colors.white, 
                          fontSize: ScreenUtil.isTablet(context) ? 14 : 12
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isAuthor || widget.isStaff) ...[
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete, 
                        color: Colors.red, 
                        size: ScreenUtil.isTablet(context) ? 18 : 16
                      ),
                      SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
                      Text(
                        'Delete',
                        style: GoogleFonts.poppins(
                          color: Colors.red, 
                          fontSize: ScreenUtil.isTablet(context) ? 14 : 12
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            onSelected: (value) {
              if (value == 'pin') {
                widget.onPin();
              } else if (value == 'delete') {
                widget.onDelete();
              }
            },
          ),
        ],
      ),
    ],
  ),
),
          // Compact Meme Image
          // Stack(
          //   children: [
          //     Container(
          //       constraints: const BoxConstraints(maxHeight: 200),
          //       width: double.infinity,
          //       child: ClipRRect(
          //         borderRadius: BorderRadius.zero,
          //         child: CachedNetworkImage(
          //           imageUrl: meme['imageUrl'],
          //           fit: BoxFit.fitWidth,
          //           // fit: BoxFit.cover,
          //           placeholder: (context, url) => Container(
          //             height: 150,
          //             color: Colors.red.shade900.withOpacity(0.2),
          //             child: Center(
          //               child: CircularProgressIndicator(color: Colors.red.shade600),
          //             ),
          //           ),
          //           errorWidget: (context, url, error) => Container(
          //             height: 150,
          //             color: Colors.red.shade900.withOpacity(0.2),
          //             child: Icon(Icons.error, color: Colors.red.shade600),
          //           ),
          //         ),
          //       ),
          //     ),
          //     Positioned(
          //       bottom: 6,
          //       right: 6,
          //       child: GestureDetector(
          //         onTap: _showEnlargedImage,
          //         child: Container(
          //           padding: const EdgeInsets.all(6),
          //           decoration: BoxDecoration(
          //             color: Colors.black.withOpacity(0.7),
          //             borderRadius: BorderRadius.circular(6),
          //           ),
          //           child: const Icon(Icons.fullscreen, color: Colors.white, size: 16),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
          // Compact Meme Image
ClipRRect(
  borderRadius: BorderRadius.zero,
  child: CachedNetworkImage(
    imageUrl: meme['imageUrl'],
    fit: BoxFit.fitWidth,
    width: double.infinity,
    memCacheWidth: (ScreenUtil.screenWidth(context) * 2).round(),
    placeholder: (context, url) => Container(
      height: 150,
      color: Colors.red.shade900.withOpacity(0.2),
      child: Center(
        child: CircularProgressIndicator(color: Colors.red.shade600),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      height: 150,
      color: Colors.red.shade900.withOpacity(0.2),
      child: Icon(Icons.error, color: Colors.red.shade600),
    ),
  ),
),

          // Caption (if exists)
          // Caption card (if exists)
if (caption.isNotEmpty)
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade700.withOpacity(0.2)),
      ),
      child: Text(
        caption,
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: Colors.white,
          height: 1.4,
        ),
      ),
    ),
  ),

          // Compact Reaction System
          Padding(
  padding: const EdgeInsets.all(12),
  child: ValueListenableBuilder<int>(
    valueListenable: widget.sliderNotifier,
    builder: (context, sliderValue, child) {
      return Column(
        children: [
          // Emoji row with counts
          // Replace the existing emoji row in CompactMemeCard's build method
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: widget.reactions.map((reaction) {
    final count = _reactionCounts[reaction['value']] ?? 0;
    final isSelected = sliderValue == reaction['value'];
    
    return GestureDetector(
      onTap: () => widget.onSliderChanged(reaction['value']),
      onLongPress: () {
        if (isSelected) {
          widget.onSliderChanged(-1);
        } else {
          // Show reaction details for this specific reaction
          if (count > 0) {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => ReactionDetailsModal(
                meme: widget.meme,
                reactions: widget.reactions,
                communityId: widget.communityId,
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.red.shade600.withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(color: Colors.red.shade500, width: 1)
              : null,
        ),
        child: Column(
          children: [
            Text(
              reaction['emoji'],
              style: TextStyle(
                fontSize: isSelected ? 18 : 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 8,
                color: isSelected ? Colors.red.shade300 : Colors.white60,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }).toList(),
),
          
          const SizedBox(height: 8),
          
          // Discrete slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.red.shade600,
                    inactiveTrackColor: Colors.red.shade900.withOpacity(0.3),
                    thumbColor: Colors.red.shade500,
                    overlayColor: Colors.red.shade600.withOpacity(0.3),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
                    activeTickMarkColor: Colors.red.shade400,
                    inactiveTickMarkColor: Colors.red.shade800,
                  ),
            // ... theme data
            child: Slider(
  value: sliderValue == -1 ? 2.0 : sliderValue.toDouble(), // Default to 2 if unreacted
  onChanged: (value) => widget.onSliderChanged(value.round()),
  min: 0,
  max: 5,
  divisions: 5,
),
          ),
          const SizedBox(height: 8),

// View Reactions button - only show if there are reactions
if (_reactionCounts.values.any((count) => count > 0))
  GestureDetector(
    onTap: () {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => ReactionDetailsModal(
          meme: widget.meme,
          reactions: widget.reactions,
          communityId: widget.communityId,
        ),
      );
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.shade700.withOpacity(0.3),
            Colors.red.shade800.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade600.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.visibility,
            color: Colors.red.shade300,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            'View Reactions',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.red.shade300,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  ),
        ],
      );
    },
  ),
),

          // Compact Comments Section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: GestureDetector(
              onTap: _showCommentsModal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade700.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.comment_outlined, color: Colors.red.shade300, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Comments',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11),
                    ),
                    const Spacer(),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('communities')
                          .doc(widget.communityId)
                          .collection('memes')
                          .doc(widget.memeId)
                          .collection('comments')
                          .snapshots(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? 0;
                        return Text(
                          count.toString(),
                          style: GoogleFonts.poppins(
                            color: Colors.red.shade300,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// Replace your existing CommentsModal class with this improved version

// Updated CommentsModal with stable sorting and controlled scrolling

class CommentsModal extends StatefulWidget {
  final String memeId;
  final String communityId;
  final String userId;
  final String username;

  const CommentsModal({
    super.key,
    required this.memeId,
    required this.communityId,
    required this.userId,
    required this.username,
  });

  @override
  State<CommentsModal> createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isPosting = false;
  List<QueryDocumentSnapshot> _comments = [];
  StreamSubscription<QuerySnapshot>? _commentsSubscription;

  final Map<String, ValueNotifier<bool>> _commentLikeNotifiers = {};
  final Map<String, ValueNotifier<int>> _commentLikeCountNotifiers = {};
  final Map<String, Map<String, dynamic>?> _userCache = {};

  // Track initial load and user interactions
  bool _isInitialLoad = true;
  bool _userJustPosted = false;
  String? _lastCommentId;
   bool _isLoadingComments = true;
  
  // Stable sorting - only sort on initial load and new comments
  List<String> _stableCommentOrder = [];


  @override
  void initState() {
    super.initState();
    _setupCommentsStream();
    
    // Only scroll when keyboard appears, not on focus
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        // Small delay to let keyboard animation start
        Future.delayed(const Duration(milliseconds: 200), () {
          if (_scrollController.hasClients) {
            _scrollToBottom();
          }
        });
      }
    });
  }

  void _setupCommentsStream() {
    _commentsSubscription = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .doc(widget.memeId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      if (_isLoadingComments) {
      setState(() {
        _isLoadingComments = false;
      });
    }
      
      final newComments = snapshot.docs;
      final oldLength = _comments.length;
      
      // Check if this is a new comment (user just posted)
      final hasNewComment = newComments.length > oldLength;
      if (hasNewComment && oldLength > 0) {
        _userJustPosted = true;
        _lastCommentId = newComments.last.id;
      }
      
      // Only re-sort if it's initial load or we have completely new data structure
      if (_isInitialLoad || _shouldResort(newComments)) {
        _sortAndSetOrder(newComments);
        _isInitialLoad = false;
      } else {
        // Keep existing order, just update the comments list
        _comments = _reorderCommentsStably(newComments);
      }
      
      // Initialize notifiers for any new comments
      for (var doc in newComments) {
        final commentId = doc.id;
        final comment = doc.data() as Map<String, dynamic>;
        final likedBy = comment['likedBy'] as Map<String, dynamic>? ?? {};
        final isLiked = likedBy.containsKey(widget.userId);
        final likesCount = comment['likesCount'] ?? 0;
        
        _commentLikeNotifiers.putIfAbsent(
          commentId, 
          () => ValueNotifier(isLiked),
        );
        _commentLikeCountNotifiers.putIfAbsent(
          commentId, 
          () => ValueNotifier(likesCount),
        );
        
        // Update notifiers with current values (for likes that changed)
        _commentLikeNotifiers[commentId]?.value = isLiked;
        _commentLikeCountNotifiers[commentId]?.value = likesCount;
      }
      
      setState(() {});
      
      // Only auto-scroll for new comments the user just posted
      if (_userJustPosted && hasNewComment) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
          _userJustPosted = false; // Reset flag
        });
      }
    });
  }

  // Check if we need to resort (only for major changes, not likes)
  bool _shouldResort(List<QueryDocumentSnapshot> newComments) {
    if (_stableCommentOrder.isEmpty) return true;
    
    final newIds = newComments.map((doc) => doc.id).toSet();
    final oldIds = _stableCommentOrder.toSet();
    
    // Resort only if comments were added or removed, not if just likes changed
    return !newIds.equals(oldIds);
  }
  
  // Create stable order based on likes + time
  void _sortAndSetOrder(List<QueryDocumentSnapshot> comments) {
    final sortedComments = comments.toList();
    
    // Sort by likes (desc) then by time (asc)
    sortedComments.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aLikes = aData['likesCount'] ?? 0;
      final bLikes = bData['likesCount'] ?? 0;
      
      if (aLikes != bLikes) {
        return bLikes.compareTo(aLikes);
      }
      
      final aTime = aData['createdAt'] as Timestamp?;
      final bTime = bData['createdAt'] as Timestamp?;
      if (aTime != null && bTime != null) {
        return aTime.compareTo(bTime);
      }
      
      return 0;
    });
    
    _stableCommentOrder = sortedComments.map((doc) => doc.id).toList();
    _comments = sortedComments;
  }
  
  // Reorder comments according to stable order
  List<QueryDocumentSnapshot> _reorderCommentsStably(List<QueryDocumentSnapshot> newComments) {
    final commentMap = <String, QueryDocumentSnapshot>{};
    for (var comment in newComments) {
      commentMap[comment.id] = comment;
    }
    
    final reorderedComments = <QueryDocumentSnapshot>[];
    
    // Add comments in stable order
    for (var id in _stableCommentOrder) {
      if (commentMap.containsKey(id)) {
        reorderedComments.add(commentMap[id]!);
        commentMap.remove(id);
      }
    }
    
    // Add any new comments at the end and update stable order
    if (commentMap.isNotEmpty) {
      final newCommentsList = commentMap.values.toList();
      // Sort new comments by time
      newCommentsList.sort((a, b) {
        final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        if (aTime != null && bTime != null) {
          return aTime.compareTo(bTime);
        }
        return 0;
      });
      
      reorderedComments.addAll(newCommentsList);
      _stableCommentOrder.addAll(newCommentsList.map((doc) => doc.id));
    }
    
    return reorderedComments;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _commentsSubscription?.cancel();
    _commentLikeNotifiers.forEach((key, notifier) => notifier.dispose());
    _commentLikeCountNotifiers.forEach((key, notifier) => notifier.dispose());
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getUserData(String username) async {
      final trace = FirebasePerformance.instance.newTrace('get_user_data'); // ← ADD THIS
    await trace.start(); 
    if (_userCache.containsKey(username)) {
      trace.setMetric('cache_hit', 1); // ← ADD THIS
        await trace.stop();
      return _userCache[username];
    }

    trace.setMetric('cache_hit', 0); 

    try {
      DocumentSnapshot? userDoc;
      
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        userDoc = trioQuery.docs.first;
      } else {
        final membersQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();
        
        if (membersQuery.docs.isNotEmpty) {
          userDoc = membersQuery.docs.first;
        }
      }

      final userData = userDoc?.data() != null 
          ? userDoc!.data() as Map<String, dynamic>
          : null;
      _userCache[username] = userData;
       trace.setMetric('success', 1); // ← ADD THIS
        await trace.stop(); 
      return userData;
    } catch (e) {
         FirebaseCrashlytics.instance.recordError(e, null);
          trace.setMetric('success', 0); // ← ADD THIS
        await trace.stop(); 
      debugPrint('Error fetching user data for $username: $e');
      _userCache[username] = null;
      return null;
    }
  }

  // Add this field to track pending operations
final Set<String> _pendingLikeOperations = <String>{};

Future<void> _toggleCommentLike(String commentId, bool currentlyLiked) async {
  // Prevent multiple simultaneous operations on the same comment
  if (_pendingLikeOperations.contains(commentId)) {
    return;
  }
  
  _pendingLikeOperations.add(commentId);
  
  try {
    final docRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .doc(widget.memeId)
        .collection('comments')
        .doc(commentId);

    // Update UI immediately to prevent lag
    _commentLikeNotifiers[commentId]?.value = !currentlyLiked;
    _commentLikeCountNotifiers[commentId]?.value = 
        currentlyLiked 
          ? (_commentLikeCountNotifiers[commentId]?.value ?? 1) - 1
          : (_commentLikeCountNotifiers[commentId]?.value ?? 0) + 1;

    // Then update database
    if (currentlyLiked) {
      await docRef.update({
        'likedBy.${widget.userId}': FieldValue.delete(),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await docRef.update({
        'likedBy.${widget.userId}': true,
        'likesCount': FieldValue.increment(1),
      });
      
      final commentDoc = await docRef.get();
      if (commentDoc.exists) {
        final commentData = commentDoc.data() as Map<String, dynamic>;
        final authorId = commentData['authorId'];
        if (authorId != null && authorId != widget.userId) {
          await _createNotification(
            recipientUserId: authorId,
            title: 'Comment Liked',
            body: '${widget.username} liked your comment',
            type: 'comment_like',
            memeId: widget.memeId,
            commentId: commentId,
          );
        }
      }
    }
  } catch (e) {
    // Revert UI on error
    _commentLikeNotifiers[commentId]?.value = currentlyLiked;
    _commentLikeCountNotifiers[commentId]?.value = 
        currentlyLiked 
          ? (_commentLikeCountNotifiers[commentId]?.value ?? 0) + 1
          : (_commentLikeCountNotifiers[commentId]?.value ?? 1) - 1;
    
    debugPrint('Error toggling comment like: $e');
  } finally {
    // Always remove from pending operations
    _pendingLikeOperations.remove(commentId);
  }
}

  Future<void> _createNotification({
    required String recipientUserId,
    required String title,
    required String body,
    required String type,
    String? memeId,
    String? commentId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientUserId)
          .collection('notifications')
          .add({
        'title': title,
        'message': body,
        'type': type,
        'memeId': memeId,
        'commentId': commentId,
        'requesterId': widget.userId,
        'requesterUsername': widget.username,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

Future<void> _postComment({String? parentId}) async {
  final trace = FirebasePerformance.instance.newTrace('post_comment');
  await trace.start();
  
  try {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // ... existing validation code ...

    final collection = parentId != null
        ? FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('memes')
            .doc(widget.memeId)
            .collection('comments')
            .doc(parentId)
            .collection('replies')
        : FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('memes')
            .doc(widget.memeId)
            .collection('comments');

    final commentRef = await collection.add({
      'content': text,
      'authorId': widget.userId,
      'authorUsername': widget.username,
      'createdAt': FieldValue.serverTimestamp(),
      'likedBy': {},
      'likesCount': 0,
    });

    if (parentId == null) {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('memes')
          .doc(widget.memeId)
          .update({'commentsCount': FieldValue.increment(1)});

      // ADD THIS: Notify meme author about new comment
      await _notifyMemeComment(widget.memeId);
    } else {
      // ADD THIS: Notify parent comment author about reply
      await _notifyCommentReply(parentId, commentRef.id);
    }

    _commentController.clear();
    _focusNode.unfocus();
    
  } catch (e) {
    // ... existing error handling ...
  } finally {
    if (mounted) setState(() => _isPosting = false);
    await trace.stop();
  }
}

// ADD THESE METHODS
Future<void> _notifyMemeComment(String memeId) async {
  try {
    final memeDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .doc(memeId)
        .get();

    if (memeDoc.exists) {
      final memeData = memeDoc.data() as Map<String, dynamic>;
      final authorId = memeData['authorId'];
      
     if (authorId != null && authorId != widget.userId && 
    memeData['actualAuthorId'] != widget.userId) {
        await _createNotification(
          recipientUserId: authorId,
          title: 'New comment on your meme',
          body: '${widget.username} commented on your meme',
          type: 'meme_comment',
          memeId: memeId,
        );
      }
    }
  } catch (e) {
    debugPrint('Error notifying meme comment: $e');
  }
}

Future<void> _notifyCommentReply(String parentCommentId, String replyId) async {
  try {
    final commentDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .doc(widget.memeId)
        .collection('comments')
        .doc(parentCommentId)
        .get();

    if (commentDoc.exists) {
      final commentData = commentDoc.data() as Map<String, dynamic>;
      final authorId = commentData['authorId'];
      
      if (authorId != null && authorId != widget.userId) {
        await _createNotification(
          recipientUserId: authorId,
          title: 'New reply to your comment',
          body: '${widget.username} replied to your comment',
          type: 'comment_reply',
          memeId: widget.memeId,
          commentId: parentCommentId,
        );
      }
    }
  } catch (e) {
    debugPrint('Error notifying comment reply: $e');
  }
}
  void _showReplyDialog(String parentCommentId) {
    final replyController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A0000),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reply to comment',
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
              borderSide: BorderSide(color: Colors.red.shade700),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red.shade700),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () async {
              final text = replyController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                await _postReply(parentCommentId, text);
              }
            },
            child: Text('Reply', style: GoogleFonts.poppins(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
  }

  Future<void> _postReply(String parentCommentId, String text) async {
    if (text.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('memes')
          .doc(widget.memeId)
          .collection('comments')
          .doc(parentCommentId)
          .collection('replies')
          .add({
        'content': text.trim(),
        'authorId': widget.userId,
        'authorUsername': widget.username,
        'createdAt': FieldValue.serverTimestamp(),
        'likedBy': {},
        'likesCount': 0,
      });
      
      final commentDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('memes')
          .doc(widget.memeId)
          .collection('comments')
          .doc(parentCommentId)
          .get();
          
      if (commentDoc.exists) {
        final commentData = commentDoc.data() as Map<String, dynamic>;
        final authorId = commentData['authorId'];
        if (authorId != null && authorId != widget.userId) {
          await _createNotification(
            recipientUserId: authorId,
            title: 'New Reply',
            body: '${widget.username} replied to your comment',
            type: 'comment_reply',
            memeId: widget.memeId,
            commentId: parentCommentId,
          );
        }
      }
    } catch (e) {
      debugPrint('Error posting reply: $e');
    }
  }
   Widget _buildCommentsShimmer(bool isSmallScreen) {
    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      itemCount: 5, // Show 5 shimmer items
      itemBuilder: (context, index) {
        return _buildCommentShimmerItem(isSmallScreen);
      },
    );
  }
  Widget _buildCommentShimmerItem(bool isSmallScreen) {
  final spacing = isSmallScreen ? 8.0 : 12.0;
  final padding = isSmallScreen ? 8.0 : 12.0;
  final avatarSize = isSmallScreen ? 28.0 : 32.0;

  return Container(
    margin: EdgeInsets.only(bottom: spacing),
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
      border: Border.all(color: Colors.red.shade700.withOpacity(0.2)),
    ),
    child: ShimmerLoading(
      isLoading: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and user info shimmer
          Row(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: spacing * 0.7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: spacing * 0.7),
          // Content shimmer
          Container(
            height: 16,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            height: 16,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    ),
  );
}
  

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions and keyboard height
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;
    
    // Responsive sizing
    final isSmallScreen = screenHeight < 700;
    final modalHeight = isSmallScreen 
        ? availableHeight * 0.95 
        : availableHeight * 0.8;

    return Container(
      height: modalHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF2A0000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with sort info
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.red.shade900.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (_comments.isNotEmpty)
                      Text(
                        'Sorted by likes',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 10 : 12,
                          color: Colors.red.shade300,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.close, 
                    color: Colors.red.shade300,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
              ],
            ),
          ),

          // Comments List - no auto scroll on data changes
          Expanded(
            child: _isLoadingComments
                ? _buildCommentsShimmer(isSmallScreen)
                : _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.comment_outlined,
                          color: Colors.red.shade300,
                          size: isSmallScreen ? 48 : 64,
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 16),
                        Text(
                          'No comments yet',
                          style: GoogleFonts.poppins(
                            color: Colors.white60,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                        ),
                        Text(
                          'Be the first to comment!',
                          style: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: isSmallScreen ? 10 : 12,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    itemCount: _comments.length,
                    cacheExtent: 2000, // Increase cache
  addAutomaticKeepAlives: true, // Keep items alive
  addRepaintBoundaries: true, // Reduce repaints
  physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final doc = _comments[index];
                      final comment = doc.data() as Map<String, dynamic>;
                      final commentId = doc.id;
                      
                      return CommentCard(
                        comment: comment,
                        commentId: commentId,
                        memeId: widget.memeId,
                        communityId: widget.communityId,
                        currentUserId: widget.userId,
                        likeNotifier: _commentLikeNotifiers[commentId]!,
                        likeCountNotifier: _commentLikeCountNotifiers[commentId]!,
                        getUserData: _getUserData,
                        onLike: () => _toggleCommentLike(commentId, _commentLikeNotifiers[commentId]!.value),
                        onReply: () => _showReplyDialog(commentId),
                        isSmallScreen: isSmallScreen,
                      );
                    },
                  ),
          ),

          // Comment Input - Keyboard aware
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.only(
              left: isSmallScreen ? 12 : 16,
              right: isSmallScreen ? 12 : 16,
              top: isSmallScreen ? 12 : 16,
              bottom: Math.max(mediaQuery.padding.bottom, isSmallScreen ? 12 : 16),
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF2A0000),
              border: Border(
                top: BorderSide(color: Colors.red.shade900.withOpacity(0.3)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: isSmallScreen ? 80 : 100,
                      minHeight: isSmallScreen ? 36 : 44,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 18 : 22),
                      border: Border.all(color: Colors.red.shade700.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _commentController,
                      focusNode: _focusNode,
                      style: GoogleFonts.poppins(
                        color: Colors.white, 
                        fontSize: isSmallScreen ? 12 : 14
                      ),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: isSmallScreen ? 12 : 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 12,
                        ),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.newline,
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                
                // Send button
                GestureDetector(
                  onTap: _isPosting ? null : _postComment,
                  child: Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red.shade600, Colors.red.shade800],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade600.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _isPosting
                        ? SizedBox(
                            width: isSmallScreen ? 16 : 20,
                            height: isSmallScreen ? 16 : 20,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.send,
                            color: Colors.white,
                            size: isSmallScreen ? 16 : 20,
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

// Extension for Set equality check
extension SetEquality<T> on Set<T> {
  bool equals(Set<T> other) {
    if (length != other.length) return false;
    return every(other.contains);
  }
}
// Updated CommentCard class with better responsiveness and reply sorting

class CommentCard extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String commentId;
  final String memeId;
  final String communityId;
  final String currentUserId;
  final ValueNotifier<bool> likeNotifier;
  final ValueNotifier<int> likeCountNotifier;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final Future<Map<String, dynamic>?> Function(String) getUserData;
  final bool isSmallScreen;

  const CommentCard({
    super.key,
    required this.comment,
    required this.commentId,
    required this.memeId,
    required this.communityId,
    required this.currentUserId,
    required this.likeNotifier,
    required this.likeCountNotifier,
    required this.onLike,
    required this.onReply,
    required this.getUserData,
    this.isSmallScreen = false,
  });

  @override
  Widget build(BuildContext context) {
    final authorUsername = comment['authorUsername'] ?? 'Unknown';
    final content = comment['content'] ?? '';
    final createdAt = comment['createdAt'] as Timestamp?;

    // Responsive sizing
    final avatarSize = isSmallScreen ? 28.0 : 32.0;
    final primaryFontSize = isSmallScreen ? 11.0 : 12.0;
    final secondaryFontSize = isSmallScreen ? 9.0 : 10.0;
    final badgeFontSize = isSmallScreen ? 7.0 : 8.0;
    final contentFontSize = isSmallScreen ? 11.0 : 13.0;
    final spacing = isSmallScreen ? 8.0 : 12.0;
    final padding = isSmallScreen ? 8.0 : 12.0;

    return Container(
      margin: EdgeInsets.only(bottom: spacing),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
        border: Border.all(
          color: Colors.red.shade700.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header with responsive design
          FutureBuilder<Map<String, dynamic>?>(
            future: getUserData(authorUsername),
            builder: (context, snapshot) {
              final userData = snapshot.data;
              final firstName = userData?['firstName'] ?? '';
              final lastName = userData?['lastName'] ?? '';
              final fullName = '$firstName $lastName'.trim();
              final branch = userData?['branch']?.toString() ?? '';
              final year = userData?['year']?.toString() ?? '';
              final profileImageUrl = userData?['profileImageUrl'];

              return Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfileScreen(
                            username: authorUsername,
                            communityId: communityId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.shade600,
                          width: isSmallScreen ? 1 : 1.5,
                        ),
                      ),
                      child: profileImageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => _buildAvatarFallback(
                                  firstName, authorUsername, primaryFontSize),
                              ),
                            )
                          : _buildAvatarFallback(firstName, authorUsername, primaryFontSize),
                    ),
                  ),
                  SizedBox(width: spacing * 0.7),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullName.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfileScreen(
                                    username: authorUsername,
                                    communityId: communityId,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              fullName,
                              style: GoogleFonts.poppins(
                                fontSize: primaryFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(
                                  username: authorUsername,
                                  communityId: communityId,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            '@$authorUsername',
                            style: GoogleFonts.poppins(
                              fontSize: secondaryFontSize,
                              color: Colors.red.shade300,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimestamp(createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: badgeFontSize,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Branch and Year badges (horizontal)
                  if (branch.isNotEmpty || year.isNotEmpty)
                    _buildUserBadges(branch, year, badgeFontSize),
                ],
              );
            },
          ),
          
          SizedBox(height: spacing * 0.7),
          
          // Like and Reply buttons (moved before content)
          Row(
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: likeNotifier,
                builder: (context, isLiked, child) {
                  return GestureDetector(
                    onTap: onLike,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 10, 
                        vertical: isSmallScreen ? 3 : 6
                      ),
                      decoration: BoxDecoration(
                        gradient: isLiked 
                            ? LinearGradient(
                                colors: [Colors.red.shade500, Colors.red.shade700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.red.shade700.withOpacity(0.3),
                                  Colors.red.shade800.withOpacity(0.2),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                        border: Border.all(
                          color: isLiked 
                              ? Colors.red.shade400
                              : Colors.red.shade600.withOpacity(0.4),
                          width: 1,
                        ),
                        boxShadow: isLiked ? [
                          BoxShadow(
                            color: Colors.red.shade500.withOpacity(0.3),
                            blurRadius: isSmallScreen ? 3 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? Colors.white : Colors.red.shade300,
                            size: isSmallScreen ? 12 : 16,
                          ),
                          SizedBox(width: isSmallScreen ? 3 : 6),
                          ValueListenableBuilder<int>(
                            valueListenable: likeCountNotifier,
                            builder: (context, count, child) {
                              if (count == 0) return const SizedBox.shrink();
                              return Text(
                                count.toString(),
                                style: GoogleFonts.poppins(
                                  fontSize: isSmallScreen ? 9 : 12,
                                  color: isLiked ? Colors.white : Colors.red.shade300,
                                  fontWeight: FontWeight.w600,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              SizedBox(width: isSmallScreen ? 4 : 8),
              GestureDetector(
                onTap: onReply,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 4 : 8, 
                    vertical: isSmallScreen ? 2 : 4
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.reply,
                        color: Colors.red.shade300,
                        size: isSmallScreen ? 10 : 14,
                      ),
                      SizedBox(width: isSmallScreen ? 2 : 4),
                      Text(
                        'Reply',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 8 : 11,
                          color: Colors.red.shade300,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: spacing * 0.7),
          
          // Comment content
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: contentFontSize,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          
          // Show replies with enhanced design and sorting
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communities')
                .doc(communityId)
                .collection('memes')
                .doc(memeId)
                .collection('comments')
                .doc(commentId)
                .collection('replies')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const SizedBox.shrink();
              }
              
              // Sort replies by likes count (most liked first)
              final replies = snapshot.data!.docs.toList();
              replies.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;
                final aLikes = aData['likesCount'] ?? 0;
                final bLikes = bData['likesCount'] ?? 0;
                
                // Primary sort: likes (descending)
                if (aLikes != bLikes) {
                  return bLikes.compareTo(aLikes);
                }
                
                // Secondary sort: creation time (ascending)
                final aTime = aData['createdAt'] as Timestamp?;
                final bTime = bData['createdAt'] as Timestamp?;
                if (aTime != null && bTime != null) {
                  return aTime.compareTo(bTime);
                }
                
                return 0;
              });
              
              return Container(
                margin: EdgeInsets.only(top: spacing),
                padding: EdgeInsets.only(left: isSmallScreen ? 16 : 24),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Colors.red.shade700.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: replies.map((replyDoc) {
                    final reply = replyDoc.data() as Map<String, dynamic>;
                    final replyId = replyDoc.id;
                    return ReplyCard(
                      reply: reply,
                      replyId: replyId,
                      commentId: commentId,
                      memeId: memeId,
                      communityId: communityId,
                      currentUserId: currentUserId,
                      getUserData: getUserData,
                      isCompact: isSmallScreen,
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String firstName, String authorUsername, double fontSize) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade600, Colors.red.shade800],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstName.isNotEmpty
              ? firstName[0].toUpperCase()
              : authorUsername[0].toUpperCase(),
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildUserBadges(String branch, String year, double fontSize) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (branch.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 4 : 6, 
              vertical: isSmallScreen ? 1 : 2
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700.withOpacity(0.3), Colors.red.shade800.withOpacity(0.2)],
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 4 : 6),
              border: Border.all(color: Colors.red.shade600.withOpacity(0.4)),
            ),
            child: Text(
              branch,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade200,
              ),
            ),
          ),
        if (branch.isNotEmpty && year.isNotEmpty) SizedBox(width: isSmallScreen ? 2 : 4),
        if (year.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 4 : 6, 
              vertical: isSmallScreen ? 1 : 2
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade700.withOpacity(0.3), Colors.red.shade800.withOpacity(0.2)],
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 4 : 6),
              border: Border.all(color: Colors.red.shade600.withOpacity(0.4)),
            ),
            child: Text(
              year,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade200,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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
class ReplyCard extends StatefulWidget {
  final Map<String, dynamic> reply;
  final String replyId;
  final String commentId;
  final String memeId;
  final String communityId;
  final String currentUserId;
  final Future<Map<String, dynamic>?> Function(String) getUserData;
  final bool isCompact;

  const ReplyCard({
    super.key,
    required this.reply,
    required this.replyId,
    required this.commentId,
    required this.memeId,
    required this.communityId,
    required this.currentUserId,
    required this.getUserData,
    required this.isCompact,
  });

  @override
  State<ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<ReplyCard> {
  late ValueNotifier<bool> _likeNotifier;
  late ValueNotifier<int> _likeCountNotifier;

  @override
  void initState() {
    super.initState();
    final likedBy = widget.reply['likedBy'] as Map<String, dynamic>? ?? {};
    final isLiked = likedBy.containsKey(widget.currentUserId);
    final likesCount = widget.reply['likesCount'] ?? 0;
    
    _likeNotifier = ValueNotifier(isLiked);
    _likeCountNotifier = ValueNotifier(likesCount);
  }

  @override
  void dispose() {
    _likeNotifier.dispose();
    _likeCountNotifier.dispose();
    super.dispose();
  }

  Future<void> _toggleReplyLike() async {
  try {
    final docRef = FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('memes')
        .doc(widget.memeId)
        .collection('comments')
        .doc(widget.commentId)
        .collection('replies')
        .doc(widget.replyId);

    final currentlyLiked = _likeNotifier.value;
    
    // Update UI immediately
    _likeNotifier.value = !currentlyLiked;
    _likeCountNotifier.value = currentlyLiked 
        ? Math.max(0, _likeCountNotifier.value - 1)  // Use Math.max instead of clamp
        : _likeCountNotifier.value + 1;

    // Then update database
    if (currentlyLiked) {
      await docRef.update({
        'likedBy.${widget.currentUserId}': FieldValue.delete(),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await docRef.update({
        'likedBy.${widget.currentUserId}': true,
        'likesCount': FieldValue.increment(1),
      });
    }
  } catch (e) {
        FirebaseCrashlytics.instance.recordError(e, null, // ← ADD THIS
        information: ['Toggling reply like']);
    // Revert UI on error
    _likeNotifier.value = !_likeNotifier.value;
    _likeCountNotifier.value = _likeNotifier.value 
        ? _likeCountNotifier.value + 1
        : Math.max(0, _likeCountNotifier.value - 1);  // Use Math.max instead of clamp
    
    debugPrint('Error toggling reply like: $e');
  }
}


  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    
    try {
      final dateTime = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authorUsername = widget.reply['authorUsername'] ?? 'Unknown';
    final content = widget.reply['content'] ?? '';
    final createdAt = widget.reply['createdAt'];
    
    final avatarSize = widget.isCompact ? 24.0 : 28.0;
    final primaryFontSize = widget.isCompact ? 10.0 : 11.0;
    final secondaryFontSize = widget.isCompact ? 8.0 : 9.0;
    final badgeFontSize = widget.isCompact ? 6.0 : 7.0;

    return Container(
      margin: EdgeInsets.only(bottom: widget.isCompact ? 6 : 8),
      padding: EdgeInsets.all(widget.isCompact ? 6 : 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(widget.isCompact ? 6 : 8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: widget.getUserData(authorUsername),
            builder: (context, snapshot) {
              final userData = snapshot.data;
              final firstName = userData?['firstName'] ?? '';
              final lastName = userData?['lastName'] ?? '';
              final fullName = '$firstName $lastName'.trim();
              final branch = userData?['branch']?.toString() ?? '';
              final year = userData?['year']?.toString() ?? '';
              final profileImageUrl = userData?['profileImageUrl'];

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
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.red.shade600,
                          width: widget.isCompact ? 0.5 : 1,
                        ),
                      ),
                      child: profileImageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                profileImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.red.shade600, Colors.red.shade800],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      firstName.isNotEmpty
                                          ? firstName[0].toUpperCase()
                                          : authorUsername[0].toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: primaryFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.red.shade600, Colors.red.shade800],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  firstName.isNotEmpty
                                      ? firstName[0].toUpperCase()
                                      : authorUsername[0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: primaryFontSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: widget.isCompact ? 4 : 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (fullName.isNotEmpty)
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
                              fullName,
                              style: GoogleFonts.poppins(
                                fontSize: primaryFontSize,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
                            '@$authorUsername',
                            style: GoogleFonts.poppins(
                              fontSize: secondaryFontSize,
                              color: Colors.red.shade300,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatTimestamp(createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: badgeFontSize,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Branch and Year for replies
                  if (branch.isNotEmpty || year.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (branch.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isCompact ? 3 : 4, 
                              vertical: widget.isCompact ? 1 : 1
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red.shade700.withOpacity(0.3), Colors.red.shade800.withOpacity(0.2)],
                              ),
                              borderRadius: BorderRadius.circular(widget.isCompact ? 3 : 4),
                              border: Border.all(color: Colors.red.shade600.withOpacity(0.4)),
                            ),
                            child: Text(
                              branch,
                              style: GoogleFonts.poppins(
                                fontSize: badgeFontSize,
                                fontWeight: FontWeight.w500,
                                color: Colors.red.shade200,
                              ),
                            ),
                          ),
                        if (branch.isNotEmpty && year.isNotEmpty) SizedBox(width: widget.isCompact ? 1 : 2),
                        if (year.isNotEmpty)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isCompact ? 3 : 4, 
                              vertical: widget.isCompact ? 1 : 1
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red.shade700.withOpacity(0.3), Colors.red.shade800.withOpacity(0.2)],
                              ),
                              borderRadius: BorderRadius.circular(widget.isCompact ? 3 : 4),
                              border: Border.all(color: Colors.red.shade600.withOpacity(0.4)),
                            ),
                            child: Text(
                              year,
                              style: GoogleFonts.poppins(
                                fontSize: badgeFontSize,
                                fontWeight: FontWeight.w500,
                                color: Colors.red.shade200,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              );
            },
          ),
          SizedBox(height: widget.isCompact ? 3 : 4),
          
          // Like button for replies
          ValueListenableBuilder<bool>(
            valueListenable: _likeNotifier,
            builder: (context, isLiked, child) {
              return GestureDetector(
                onTap: _toggleReplyLike,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isCompact ? 4 : 6, 
                    vertical: widget.isCompact ? 2 : 3
                  ),
                  decoration: BoxDecoration(
                    gradient: isLiked 
                        ? LinearGradient(
                            colors: [Colors.red.shade500, Colors.red.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.red.shade700.withOpacity(0.3),
                              Colors.red.shade800.withOpacity(0.2),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(widget.isCompact ? 6 : 8),
                    border: Border.all(
                      color: isLiked 
                          ? Colors.red.shade400
                          : Colors.red.shade600.withOpacity(0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: isLiked ? Colors.white : Colors.red.shade300,
                        size: widget.isCompact ? 10 : 12,
),
SizedBox(width: widget.isCompact ? 2 : 4),
ValueListenableBuilder<int>(
valueListenable: _likeCountNotifier,
builder: (context, count, child) {
if (count == 0) return const SizedBox.shrink();
return Text(
count.toString(),
style: GoogleFonts.poppins(
fontSize: widget.isCompact ? 7 : 9,
color: isLiked ? Colors.white : Colors.red.shade300,
fontWeight: FontWeight.w600,
),
);
},
),
],
),
),
);
},
),
      SizedBox(height: widget.isCompact ? 3 : 4),
      
      Text(
        content,
        style: GoogleFonts.poppins(
          fontSize: widget.isCompact ? 10 : 12,
          color: Colors.white,
          height: 1.4,
        ),
      ),
    ],
  ),
);
}
}

class ReactionDetailsModal extends StatelessWidget {
  final Map<String, dynamic> meme;
  final List<Map<String, dynamic>> reactions;
  final String communityId;

  const ReactionDetailsModal({
    super.key,
    required this.meme,
    required this.reactions,
    required this.communityId,
  });

  @override
  Widget build(BuildContext context) {
    final memeReactions = meme['reactions'] as Map<String, dynamic>? ?? {};
    
    // Group reactions by type
    Map<int, List<String>> groupedReactions = {};
    memeReactions.forEach((userId, reactionValue) {
      if (reactionValue is int && reactionValue >= 0) {
        groupedReactions.putIfAbsent(reactionValue, () => []).add(userId);
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(0xFF2A0000),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.red.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.red.shade900.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Reactions',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Colors.red.shade300),
                ),
              ],
            ),
          ),

          Expanded(
            child: groupedReactions.isEmpty
                ? Center(
                    child: Text(
                      'No reactions yet',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: groupedReactions.entries.map((entry) {
                      final reactionType = entry.key;
                      final userIds = entry.value;
                      final reaction = reactions[reactionType];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.shade700.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  reaction['emoji'],
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 8),
                                Text(
  'Reactions',
  style: GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  ),
),
                                const Spacer(),
                                Text(
                                  '${userIds.length}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.red.shade300,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: userIds.map((userId) {
                                return FutureBuilder<DocumentSnapshot>(
                                  future: _getUserData(userId),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade700.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Loading...',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      );
                                    }
                                    
                                    final userData = snapshot.data!.data() as Map<String, dynamic>?;
                                    final username = userData?['username'] ?? 'Unknown';
                                    
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade700.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '@$username',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Future<DocumentSnapshot> _getUserData(String userId) async {
    try {
      // Try users collection first
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) return doc;
      
      // Try communities/{communityId}/members
      doc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get()
          .then((snapshot) => snapshot.docs.first);
      
      return doc;
    } catch (e) {
      // Return empty doc if not found
      return FirebaseFirestore.instance.collection('users').doc('dummy').get();
    }
  }
}

// Add these responsive utilities
class ScreenUtil {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
  
  static bool isTablet(BuildContext context) => screenWidth(context) > 600;
  static bool isDesktop(BuildContext context) => screenWidth(context) > 1200;
  
  static double responsiveWidth(BuildContext context, double fraction) {
    return screenWidth(context) * fraction;
  }
  
  static double responsiveHeight(BuildContext context, double fraction) {
    return screenHeight(context) * fraction;
  }
}

// Update font sizes for different screen sizes
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
class NetworkChecker {
  static Future<bool> isConnected() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
class ContentFilter {
  // Just the basics to show you have automated moderation
  static const List<String> blockedWords = [
    // Hate speech
    'terrorist', 
    
    // Violence
    'kill', 'murder', 'bomb', 'weapon',
    
    // Self-harm
    'suicide', 'kill yourself', 'kys',
    
    // Explicit content
    'porn', 'sex', 'nude', 
    
    // Spam indicators
    'buy now', 'click here', 'free money', 'scam',
    
    // Illegal activities
    'drug dealer', 'cocaine', 'heroin', 'meth', 'ganja', 'lsd'
  ];
  
  static bool isContentAppropriate(String content) {
    if (content.trim().isEmpty) return true;
    
    final lowerContent = content.toLowerCase();
    
    // Check for blocked words
    for (String word in blockedWords) {
      if (lowerContent.contains(word)) {
        return false;
      }
    }
    
    // Check for repeated characters (spam indicator)
    if (_hasExcessiveRepeatedChars(content)) {
      return false;
    }
    
    return true;
  }
  
  
  static bool _hasExcessiveRepeatedChars(String text) {
    // Check for patterns like "aaaaaaa" or "!!!!!!"
    RegExp repeatedPattern = RegExp(r'(.)\1{4,}');
    return repeatedPattern.hasMatch(text);
  }
  
  // Optional: Add this method to show you're thinking about context
  static String getFilterReason(String content) {
    final lowerContent = content.toLowerCase();
    
    for (String word in blockedWords) {
      if (lowerContent.contains(word)) {
        return 'Contains inappropriate language';
      }
    }
    
    if (_hasExcessiveRepeatedChars(content)) {
      return 'Contains spam-like repeated characters';
    }
    
    return 'Content violates community guidelines';
  }
}

class ShimmerLoading extends StatelessWidget {
  final Widget child;
  final bool isLoading;

  const ShimmerLoading({
    super.key,
    required this.child,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLoading) return child;
    
    return Shimmer.fromColors(
      baseColor: Colors.red.shade900.withOpacity(0.3),
      highlightColor: Colors.red.shade700.withOpacity(0.1),
      child: child,
    );
  }
}
