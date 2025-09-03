import 'dart:async';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/community_dashboard.dart';
import 'package:startup/home_components/community_list_page.dart';
import 'package:startup/home_components/community_selection_widget.dart';
import 'package:startup/home_components/create_community_screen.dart';
import 'package:startup/home_components/notification_badge.dart';
import 'package:startup/home_components/user_profile_screen_editable.dart';
import 'package:startup/home_components/zonesearch.dart';
import 'package:startup/phone_mail.dart';
import 'bottom_nav_bar.dart';

class Home extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String uid;
  final String username;
  final String email;

  const Home({super.key, this.firstName, this.lastName, required this.username, required this.uid, required this.email});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  String firstName = '';
  String lastName = '';
  String username = '';
  String uid = '';
  String email = '';
  String? profileImageUrl;

  bool _isDragging = false;
  double _dragStartX = 0;

  // Community related variables
  String? userCommunityId;
  String? userCommunityRole;
  bool isLoadingCommunity = true;

  // App bar animation controllers
  bool isAppBarOpen = false;
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Settings states
  bool _notificationsEnabled = true;
  bool _darkMode = true;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool isIconTapped = false;
  StreamSubscription<QuerySnapshot>? _communityRequestsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToApprovedRequests();
    _initializeAnimations();
    _loadSettings();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 250), // Faster
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200), // Even faster for fade
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.fastEaseInToSlowEaseOut, // Smoother curve
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _darkMode = prefs.getBool('darkMode') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setBool('darkMode', _darkMode);
  }

  void _listenToApprovedRequests() {
    _communityRequestsSubscription = FirebaseFirestore.instance
        .collection('community_requests')
        .where('approved', isEqualTo: true)
        .where('processed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        await _createCommunityFromRequest(doc);
      }
    });
  }

  @override
  void dispose() {
    _communityRequestsSubscription?.cancel();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _createCommunityFromRequest(QueryDocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      
      // Create the community with isActive field
      final communityRef = await FirebaseFirestore.instance
          .collection('communities')
          .add({
        'name': data['name'],
        'description': data['description'],
        'years': data['years'],
        'branches': data['branches'],
        'createdBy': data['createdBy'],
        'createdByName': data['createdByName'],
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'memberCount': 1,
      });
      
      // Add creator to trio subcollection as admin
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityRef.id)
          .collection('trio')
          .add({
        'userId': data['createdBy'],
        'username': data['createdByName'],
        'role': 'admin',
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      
      // Mark request as processed
      await doc.reference.update({
        'processed': true,
        'communityId': communityRef.id,
        'processedAt': FieldValue.serverTimestamp(),
      });
      
      // Refresh community status for current user
      await _checkCommunityStatus();
      
    } catch (e) {
      print('Error creating community from request: $e');
    }
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    username = widget.username;
    uid = widget.uid;
    email = widget.email;

    String? cachedFirstName = prefs.getString('firstName');
    String? cachedLastName = prefs.getString('lastName');

    if (cachedFirstName != null && cachedLastName != null) {
      firstName = cachedFirstName;
      lastName = cachedLastName;
    } else {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        firstName = (data['firstName'] != null && data['firstName'].toString().trim().isNotEmpty)
            ? data['firstName'] : 'User';
        lastName = data['lastName'] ?? '';

        await prefs.setString('firstName', firstName);
        await prefs.setString('lastName', lastName);
      } else {
        firstName = 'Guest';
        lastName = '';
      }
    }
    
    // Check community status and load profile image
    await _checkCommunityStatus();
    await _loadProfileImage();
    setState(() {});
  }

  Future<void> _loadProfileImage() async {
    if (userCommunityId == null) return;
    
    try {
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(userCommunityId!)
          .collection('trio')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        final data = trioQuery.docs.first.data();
        setState(() {
          profileImageUrl = data['profileImageUrl'];
        });
        return;
      }
      
      // Check members collection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(userCommunityId!)
          .collection('members')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();
      
      if (membersQuery.docs.isNotEmpty) {
        final data = membersQuery.docs.first.data();
        setState(() {
          profileImageUrl = data['profileImageUrl'];
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  Future<void> _checkCommunityStatus() async {
  try {
    // Add debug logging to see what's happening
    print('Checking community status for user: $uid');
    
    // Check if this is a truly new session
    final prefs = await SharedPreferences.getInstance();
    final lastDeletedUser = prefs.getString('lastDeletedUser');
    
    if (lastDeletedUser == uid) {
      // This user was just deleted, force clean state
      print('User was recently deleted, forcing clean state');
      userCommunityId = null;
      userCommunityRole = null;
      await prefs.remove('lastDeletedUser');
      setState(() {
        isLoadingCommunity = false;
      });
      return;
    }
    
    // Get all communities first
    final communitiesQuery = await FirebaseFirestore.instance
        .collection('communities')
        .get();
    
    String? foundCommunityId;
    String? foundRole;
    
    // Check each community's subcollections for the user
    for (final communityDoc in communitiesQuery.docs) {
      final communityId = communityDoc.id;
      
      // Check in trio subcollection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('trio')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        final data = trioQuery.docs.first.data();
        foundCommunityId = communityId;
        foundRole = data['role'];
        print('Found user in trio: $foundCommunityId, role: $foundRole');
        break; // Found user, exit loop
      }
      
      // If not found in trio, check members subcollection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      
      if (membersQuery.docs.isNotEmpty) {
        final data = membersQuery.docs.first.data();
        foundCommunityId = communityId;
        foundRole = data['role'];
        print('Found user in members: $foundCommunityId, role: $foundRole');
        break; // Found user, exit loop
      }
    }
    
    // Update the global variables
    userCommunityId = foundCommunityId;
    userCommunityRole = foundRole;
    
    print('Final community status - ID: $userCommunityId, Role: $userCommunityRole');
    
  } catch (e) {
    print('Error checking community status: $e');
  }
  
  setState(() {
    isLoadingCommunity = false;
  });
}

  void _toggleAppBar() {
    if (!mounted) return; // Safety check
    
    setState(() {
      isAppBarOpen = !isAppBarOpen;
      _isDragging = false; // Reset drag state
    });
    
    if (isAppBarOpen) {
      _slideController.forward();
      _fadeController.forward();
    } else {
      _slideController.reverse();
      _fadeController.reverse();
    }
  }

void _handleLogout() async {
  try {
    // Show confirmation dialog with improved styling
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.logout,
              color: const Color(0xFFF7B42C),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout? You will need to sign in again to access your account.',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7B42C),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      // Close the app bar first
      if (isAppBarOpen) {
        _toggleAppBar();
      }
      
      // Show loading dialog
      // showDialog(
      //   context: context,
      //   barrierDismissible: false,
      //   builder: (BuildContext dialogContext) {
      //     return AlertDialog(
      //       backgroundColor: const Color(0xFF1A1A1D),
      //       shape: RoundedRectangleBorder(
      //         borderRadius: BorderRadius.circular(16),
      //       ),
      //       content: Column(
      //         mainAxisSize: MainAxisSize.min,
      //         children: [
      //           const CircularProgressIndicator(
      //             valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7B42C)),
      //           ),
      //           const SizedBox(height: 16),
      //           Center(
      //             child: Text(
      //               'Logging out...',
      //               style: GoogleFonts.poppins(
      //                 color: Colors.white,
      //                 fontSize: 14,
      //               ),
      //             ),
      //           ),
      //           SizedBox(height: 10,),
      //           Center(
      //             child: Text(
                    
      //               'click on back button if this does not go',
      //               style: GoogleFonts.poppins(
      //                 color: const Color.fromARGB(255, 115, 115, 115),
      //                 fontSize: 10,
      //               ),
      //             ),
      //           ),
      //         ],
      //       ),
      //     );
      //   },
      // );

      try {
        // Perform logout
        await _performLogout();
        
        // Dismiss loading dialog first
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        // Small delay for UI cleanup
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Navigate to login screen
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => PhoneMailVerify()),
            (route) => false,
          );
        }
      } catch (e) {
        // Dismiss dialog on error
        if (mounted) {
          Navigator.of(context).pop();
        }
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Logout failed. Please try again.',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        print('Logout error: $e');
      }
    }
  } catch (e) {
    // Ensure all dialogs are dismissed on any error
    while (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    // Show error message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Logout failed. Please try again.',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    
    print('Logout error: $e');
  }
}

  /// Perform comprehensive logout with proper cleanup
 Future<void> _performLogout() async {
  try {
    // 1. Cancel any active subscriptions first
    _communityRequestsSubscription?.cancel();

    // 2. Force sign out from Google completely
    final GoogleSignIn googleSignIn = GoogleSignIn();
    try {
      await googleSignIn.signOut();
      await googleSignIn.disconnect();
    } catch (e) {
      print('Google sign out error: $e');
      // Continue with logout even if Google signout fails
    }

    // 3. Force sign out from Firebase with cache clearing
    try {
      await FirebaseAuth.instance.signOut();
      // Wait for auth state to actually change
      await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
    } catch (e) {
      print('Firebase sign out error: $e');
    }

    // 4. Clear ALL SharedPreferences data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // 5. Reset all state variables to initial values
    if (mounted) {
      setState(() {
        firstName = '';
        lastName = '';
        username = '';
        uid = '';
        email = '';
        profileImageUrl = null;
        userCommunityId = null;
        userCommunityRole = null;
        isLoadingCommunity = true;
      });
    }

    // 6. Small delay to ensure state is cleared
    await Future.delayed(const Duration(milliseconds: 300));

  } catch (e) {
    throw Exception('Failed to logout: $e');
  }
}

Future<void> _performAccountDeletion() async {
  try {
    // Check network connectivity
    if (!(await _isOnline())) {
      _showError('No internet connection. Please try again when online.');
      return;
    }

    // Re-authenticate user first
    final isReauthenticated = await _reauthenticateUser();
    if (!isReauthenticated) {
      _showError('Authentication failed. Account deletion canceled.');
      return;
    }

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF7B42C)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Deleting account...',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Delete ALL user content completely
    await _deleteAllUserContent();

    // 2. Clear FCM tokens
    await _clearFCMToken();

    // 3. Delete user document from users collection
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .delete();

    // 4. Delete any user-specific subcollections or data
    await _deleteUserRelatedData();

    // 5. COMPLETE cache clearing before Auth deletion
    await _clearAllCachedData();

    // 6. Delete Firebase Auth account (this must be done last)
    await user.delete();

    // Hide loading dialog
    if (context.mounted) {
      Navigator.of(context).pop(); // Remove loading dialog
    }

    // Navigate to auth screen
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => PhoneMailVerify()),
        (route) => false,
      );
    }

    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Account deleted successfully',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    
  } catch (e) {
    // Hide loading dialog if showing
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    
    _showError('Account deletion failed: ${e.toString()}');
    print('Account deletion error: $e');
  }
}

Future<void> _sendAdminDeletionRequest() async {
  try {
    // Show a different dialog for admins
    final shouldSendRequest = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.admin_panel_settings, color: const Color(0xFFF7B42C), size: 24),
            const SizedBox(width: 8),
            Text(
              'Admin Account',
              style: GoogleFonts.poppins(
                color: const Color(0xFFF7B42C),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'As a ${userCommunityRole?.toLowerCase()}, you cannot directly delete your account. Would you like to send a deletion request to the developers?',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF7B42C),
              foregroundColor: Colors.black,
            ),
            child: Text(
              'Send Request',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldSendRequest == true) {
      // Send email to developers
      await FirebaseFirestore.instance.collection('admin_deletion_requests').add({
        'userId': uid,
        'username': username,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'role': userCommunityRole,
        'communityId': userCommunityId,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending'
      });

      _showInfo('Deletion request sent to blynt. You will be contacted via email within 24-48 hours.');
    }
  } catch (e) {
    _showError('Failed to send deletion request. Please try again.');
    print('Admin deletion request error: $e');
  }
}

Future<void> _deleteAllUserContent() async {
  try {
    final communities = await FirebaseFirestore.instance.collection('communities').get();
    
    for (final community in communities.docs) {
      final communityId = community.id;
      
      // Delete from trio subcollection completely
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('trio')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (final doc in trioQuery.docs) {
        await doc.reference.delete();
      }
      
      // Delete from members subcollection completely
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (final doc in membersQuery.docs) {
        await doc.reference.delete();
      }

      // DELETE ALL CONFESSIONS by this user completely
      final confessionsQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('confessions')
          .where('authorId', isEqualTo: uid)
          .get();
      
      for (final confessionDoc in confessionsQuery.docs) {
        // Delete all comments on this confession first
        final commentsQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .collection('confessions')
            .doc(confessionDoc.id)
            .collection('comments')
            .get();
        
        for (final commentDoc in commentsQuery.docs) {
          // Delete all replies to each comment
          final repliesQuery = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('confessions')
              .doc(confessionDoc.id)
              .collection('comments')
              .doc(commentDoc.id)
              .collection('replies')
              .get();
          
          for (final replyDoc in repliesQuery.docs) {
            await replyDoc.reference.delete();
          }
          
          await commentDoc.reference.delete();
        }
        
        // Delete all interactions (likes, reactions) on this confession
        final interactionsQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .collection('confessions')
            .doc(confessionDoc.id)
            .collection('interactions')
            .get();
        
        for (final interactionDoc in interactionsQuery.docs) {
          await interactionDoc.reference.delete();
        }
        
        final reactionsQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .collection('confessions')
            .doc(confessionDoc.id)
            .collection('reactions')
            .get();
        
        for (final reactionDoc in reactionsQuery.docs) {
          await reactionDoc.reference.delete();
        }
        
        // Finally delete the confession itself
        await confessionDoc.reference.delete();
      }
      
      // DELETE COMMENTS by this user on OTHER people's confessions
      final allConfessionsQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('confessions')
          .get();
      
      for (final confessionDoc in allConfessionsQuery.docs) {
        final userCommentsQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .collection('confessions')
            .doc(confessionDoc.id)
            .collection('comments')
            .where('authorId', isEqualTo: uid)
            .get();
        
        for (final commentDoc in userCommentsQuery.docs) {
          // Delete replies to this comment first
          final repliesQuery = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .collection('confessions')
              .doc(confessionDoc.id)
              .collection('comments')
              .doc(commentDoc.id)
              .collection('replies')
              .get();
          
          for (final replyDoc in repliesQuery.docs) {
            await replyDoc.reference.delete();
          }
          
          await commentDoc.reference.delete();
          
          // Decrement the comment count on the confession
          await confessionDoc.reference.update({
            'commentsCount': FieldValue.increment(-1)
          });
        }
      }
      
      // DELETE ALL INTERACTIONS (likes, reactions) by this user
      final allConfessionsForInteractions = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('confessions')
          .get();
      
      for (final confessionDoc in allConfessionsForInteractions.docs) {
        // Delete user's likes/dislikes
        final likesQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .collection('confessions')
            .doc(confessionDoc.id)
            .collection('interactions')
            .where('userId', isEqualTo: uid)
            .get();
        
        for (final likeDoc in likesQuery.docs) {
          await likeDoc.reference.delete();
        }
        
        // Delete user's emoji reactions
        final reactionsQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .collection('confessions')
            .doc(confessionDoc.id)
            .collection('reactions')
            .where('userId', isEqualTo: uid)
            .get();
        
        for (final reactionDoc in reactionsQuery.docs) {
          await reactionDoc.reference.delete();
        }
      }
    }
  } catch (e) {
    print('Error deleting user content: $e');
    throw e;
  }
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('lastDeletedUser', uid);
}

Future<void> _clearAllCachedData() async {
  try {
    // Clear ALL SharedPreferences data
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Specifically clear community-related data
    await prefs.remove('userCommunityId');
    await prefs.remove('userCommunityRole');
    await prefs.remove('communityMembership');
    await prefs.remove('isLoggedIn');
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('firstName');
    await prefs.remove('lastName');
    await prefs.remove('username');

    // Reset all state variables to initial values
    setState(() {
      firstName = '';
      lastName = '';
      username = '';
      uid = '';
      email = '';
      profileImageUrl = null;
      userCommunityId = null;
      userCommunityRole = null;
      isLoadingCommunity = true;
    });
  } catch (e) {
    print('Error clearing cached data: $e');
  }
}
Future<bool> _reauthenticateUser() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    // Re-authenticate with Google
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) {
      // User canceled sign-in
      return false;
    }
    
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    await user.reauthenticateWithCredential(credential);
    return true;
    
  } catch (e) {
    print('Re-authentication error: $e');
    _showError('Authentication failed. Please try again.');
    return false;
  }
}

Future<void> _deleteUserRelatedData() async {
  try {
    // Delete community requests
    final requestsQuery = await FirebaseFirestore.instance
        .collection('community_requests')
        .where('createdBy', isEqualTo: uid)
        .get();
    
    for (final doc in requestsQuery.docs) {
      await doc.reference.delete();
    }

    // Delete admin deletion requests
    final adminRequestsQuery = await FirebaseFirestore.instance
        .collection('admin_deletion_requests')
        .where('userId', isEqualTo: uid)
        .get();
    
    for (final doc in adminRequestsQuery.docs) {
      await doc.reference.delete();
    }

    // Delete all user notifications
    final notificationsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .get();
    
    for (final doc in notificationsQuery.docs) {
      await doc.reference.delete();
    }
    
  } catch (e) {
    print('Error deleting user related data: $e');
  }
}

Future<bool> _isOnline() async {
  try {
    await FirebaseFirestore.instance.doc('test/connectivity').get();
    return true;
  } catch (e) {
    return false;
  }
}

Future<void> _clearFCMToken() async {
  try {
    // Remove FCM token from wherever it's stored
    await FirebaseFirestore.instance
        .collection('fcm_tokens')
        .doc(uid)
        .delete();
  } catch (e) {
    print('Error clearing FCM token: $e');
  }
}

Future<void> _clearLocalData() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

void _showError(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void _showInfo(String message) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: const Color.fromARGB(255, 197, 131, 0),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

 void _handleDeleteAccount() async {
  // Check admin role FIRST, before any warnings
  if (['admin', 'manager', 'moderator'].contains(userCommunityRole?.toLowerCase())) {
    await _sendAdminDeletionRequest();
    _toggleAppBar();
    return;
  }

  // Only regular users get the warning dialogs
  // First warning
  final firstConfirm = await _showDeletionWarning(
    'Delete Account?',
    'This will permanently delete your account and associated details. However, you can modify your digital footprint if a new account is created with this same Gmail ID.',
    'Continue',
    false
  );

  if (firstConfirm != true) return;

  // Second warning (more severe)
  final secondConfirm = await _showDeletionWarning(
    'Final Warning',
    'Are you absolutely sure? Your account will be permanently deleted.',
    'Delete Forever',
    true
  );

  if (secondConfirm == true) {
    _toggleAppBar();
    await _performAccountDeletion();
  }
}

Future<bool?> _showDeletionWarning(String title, String content, String actionText, bool isFinal) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isFinal ? Icons.warning : Icons.delete_forever,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Text(
          content,
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            actionText,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

  // Zone search functionality
 

Widget buildSearchBar() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: GestureDetector(
      onTap: () {
        if (userCommunityId != null) {
          // User is part of community - open zone search
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ZoneSearchScreen(
                communityId: userCommunityId!,
                userId: uid,
                userRole: userCommunityRole!,
                username: username,
              ),
            ),
          );
        } else {
          // User not in community - open community search
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityListPage(
                userId: uid,
                username: username,
                onCommunityJoined: _checkCommunityStatus,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF7B42C).withOpacity(0.1),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: Color(0xFFF7B42C),
              size: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Row(
                children: [
                  Text(
                    'search ',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Shimmer.fromColors(
                    baseColor: const Color(0xFFF7B42C),
                    highlightColor: const Color(0xFFFFE066),
                    child: Text(
                      userCommunityId != null ? 'zones' : 'communities',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFFF7B42C),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

  Widget _buildGradientBackground() {
    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF2A1810).withOpacity(0.9),
            const Color(0xFF3D2914).withOpacity(0.7),
            const Color(0xFF4A3218).withOpacity(0.5),
            Colors.black,
          ],
          stops: const [0.0, 0.3, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildCommunitySelectionWithCreate() {
    return SingleChildScrollView(
      child: Column(
        children: [
          CommunitySelectionWidget(
            userId: uid,
            username: username,
            onCommunityJoined: _checkCommunityStatus,
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF7B42C).withOpacity(0.1),
                  const Color(0xFFFFE066).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFF7B42C).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: const Color(0xFFF7B42C),
                  size: 32,
                ),
                const SizedBox(height: 10),
                Text(
                  'Create Your Own Community',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Start a new community and invite others to join',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateCommunityScreen(
                          userId: uid,
                          firstName: firstName,
                          lastName: lastName,
                          username: username,
                          email: email,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7B42C),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Create Community',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF7B42C).withOpacity(0.8),
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, String subtitle, 
      {String? badge, bool isDanger = false, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            // HapticFeedback.lightImpact();
            onTap?.call();
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDanger 
                        ? const Color(0xFFEF4444).withOpacity(0.2)
                        : const Color(0xFFF7B42C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isDanger ? const Color(0xFFEF4444) : const Color(0xFFF7B42C),
                    size: 18,
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
                            title,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDanger ? const Color(0xFFEF4444) : Colors.white,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7B42C),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                badge,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF9CA3AF),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withOpacity(0.4),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem(IconData icon, String title, String subtitle, 
      bool value, Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A2D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF7B42C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFFF7B42C),
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 24,
              decoration: BoxDecoration(
                color: value ? const Color(0xFFF7B42C) : const Color(0xFF4B5563),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    left: value ? 24 : 2,
                    top: 2,
                    child: GestureDetector(
                      onTap: () {
                        // HapticFeedback.lightImpact();
                        onChanged(!value);
                        _saveSettings();
                      },
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
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
    );
  }

// Enhanced _buildProfileAvatar method with smooth loading
Widget _buildProfileAvatar() {
  final String initial = (firstName.isNotEmpty) ? firstName[0].toUpperCase() : 'G';
  
  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: const Color(0xFFF7B42C),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFF7B42C).withOpacity(0.3),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ],
    ),
    child: ClipOval(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: profileImageUrl != null && userCommunityId != null
            ? Image.network(
                profileImageUrl!,
                key: ValueKey(profileImageUrl),
                fit: BoxFit.cover,
                width: 36,
                height: 36,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeIn,
                    child: child,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  
                  return Stack(
                    children: [
                      _buildAvatarFallback(initial),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF7B42C),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildAvatarFallback(initial);
                },
              )
            : _buildAvatarFallback(initial),
      ),
    ),
  );
}

// Enhanced fallback avatar with smooth appearance (no scaling)
Widget _buildAvatarFallback(String initial) {
  return AnimatedOpacity(
    duration: const Duration(milliseconds: 400),
    opacity: 1.0,
    curve: Curves.easeOutCubic,
    child: Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    ),
  );
}

// Enhanced sidebar profile image with smooth transitions (no scaling)
Widget _buildSidebarProfileImage(String initial) {
  return Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.black.withOpacity(0.3),
        width: 2,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: profileImageUrl != null && userCommunityId != null
            ? Image.network(
                profileImageUrl!,
                key: ValueKey(profileImageUrl),
                fit: BoxFit.cover,
                width: 50,
                height: 50,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: child,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  
                  return Stack(
                    children: [
                      _buildSidebarFallback(initial),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2.5,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFF7B42C),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return _buildSidebarFallback(initial);
                },
              )
            : _buildSidebarFallback(initial),
      ),
    ),
  );
}

// Sidebar fallback with gentle fade-in (no scaling)
Widget _buildSidebarFallback(String initial) {
  return AnimatedOpacity(
    duration: const Duration(milliseconds: 400),
    opacity: 1.0,
    curve: Curves.easeOutCubic,
    child: Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ),
    ),
  );
}
  


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (isAppBarOpen) _toggleAppBar();
              },
              onPanStart: (details) {
                if (isAppBarOpen) {
                  _isDragging = true;
                  _dragStartX = details.globalPosition.dx;
                }
              },
              onPanUpdate: (details) {
                if (isAppBarOpen && _isDragging) {
                  double dragDistance = details.globalPosition.dx - _dragStartX;
                  if (dragDistance < -20) { // Minimum drag distance
                    _toggleAppBar();
                    _isDragging = false;
                  }
                }
              },
              onPanEnd: (details) {
                _isDragging = false;
              },
              child: Scaffold(
                backgroundColor: Colors.black,
                body: Stack(
                  children: [
                    _buildGradientBackground(),
                    SafeArea(
                      child: Column(
                        children: [
                          // Top App Bar with Menu Button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: _toggleAppBar,
                                  child: _buildProfileAvatar(),
                                ),
                                ShaderMask(
                                  shaderCallback: (bounds) => const LinearGradient(
                                    colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(bounds),
                                  blendMode: BlendMode.srcIn,
                                  child: Text(
                                    'blynt',
                                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                // SAFE NOTIFICATION BADGE - only show if uid is available
                                if (uid.isNotEmpty && userCommunityId != null) 
  NotificationBadge(
    userId: uid,
    communityId: userCommunityId!,
  ) 
else const SizedBox(width: 44),
                              ],
                            ),
                          ),
                          buildSearchBar(),
                          const SizedBox(height: 16),
                          // COMMUNITY CONTENT WITH CREATE OPTION
                        // COMMUNITY CONTENT WITH CREATE OPTION
Expanded(
  child: Container(
    color: Colors.transparent,
    child: isLoadingCommunity 
      ? Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Color(0xFFF7B42C),
                  strokeWidth: 2,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'trynna be faster',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        )
      : userCommunityId != null 
        ? CommunityDashboard(
            communityId: userCommunityId!,
            userRole: userCommunityRole!,
            userId: uid,
            onRefresh: _checkCommunityStatus,
          )
        : _buildCommunitySelectionWithCreate(),
  ),
),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Overlay when app bar is open
          if (isAppBarOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleAppBar,
                onPanStart: (details) {
                  // Only handle swipes that start outside the drawer area
                  if (details.globalPosition.dx > MediaQuery.of(context).size.width * 0.85) {
                    return;
                  }
                  _isDragging = true;
                  _dragStartX = details.globalPosition.dx;
                },
                onPanUpdate: (details) {
                  if (_isDragging) {
                    double dragDistance = details.globalPosition.dx - _dragStartX;
                    if (dragDistance < -25) {
                      _toggleAppBar();
                      _isDragging = false;
                    }
                  }
                },
                onPanEnd: (details) {
                  _isDragging = false;
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          
          // Sliding App Bar - Changed to slide from left
          SlideTransition(
            position: _slideAnimation,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    // Add swipe to close functionality for the drawer itself
                    if (details.delta.dx < -2) {
                      _toggleAppBar();
                    }
                  },
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1A1A1D),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 20,
                          offset: Offset(5, 0),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Close button
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Menu',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _toggleAppBar,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2A2D),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // User Info Section
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors:  [Color.fromARGB(255, 146, 98, 49),Color(0xFFB8860B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color.fromARGB(255, 255, 170, 0).withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                               child: profileImageUrl != null && userCommunityId != null
    ? ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 400),
          opacity: 1.0,
          child: Image.network(
            profileImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: Text(
                  (firstName.isNotEmpty) ? firstName[0].toUpperCase() : 'G',
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(
                (firstName.isNotEmpty) ? firstName[0].toUpperCase() : 'G',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
      )
    : Center(
        child: Text(
          (firstName.isNotEmpty) ? firstName[0].toUpperCase() : 'G',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 20,
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
                                        '$firstName $lastName',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        email,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        userCommunityRole != null 
                                            ? '${userCommunityRole!.toUpperCase()} '
                                            : 'BLYNT USER',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.black45,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Menu Items
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader('Account'),
                                  const SizedBox(height: 15),
                                  _buildMenuItem(
                                    Icons.person_outline, 
                                    'Profile', 
                                    'Manage your profile',
                                    onTap: () {
                                      _toggleAppBar();
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditableUserProfileScreen(
                                            userId: uid,
                                            username: username,
                                            communityId: userCommunityId,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  _buildSectionHeader('Legal & Support [DO NOT TOUCH]'),
                                  const SizedBox(height: 15),
                                  _buildMenuItem(
                                    Icons.shield_outlined, 
                                    'Privacy Policy', 
                                    'How we protect your data',
                                    onTap: () {
                                      _toggleAppBar();
                                      // Navigate to privacy policy screen
                                    },
                                  ),
                                  const SizedBox(height: 15),
                                  _buildMenuItem(
                                    Icons.description_outlined, 
                                    'Terms & Conditions', 
                                    'Service agreement',
                                    onTap: () {
                                      _toggleAppBar();
                                      // Navigate to terms screen
                                    },
                                  ),
                                  const SizedBox(height: 15),
                                  _buildMenuItem(
                                    Icons.info_outlined, 
                                    'About', 
                                    'App version 2.1.0',
                                    onTap: () {
                                      _toggleAppBar();
                                      // Navigate to about screen
                                    },
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  _buildSectionHeader('Account Actions'),
                                  const SizedBox(height: 15),
                                  _buildMenuItem(
                                    Icons.logout, 
                                    'Logout', 
                                    'Sign out of your account',
                                    onTap: _handleLogout,
                                  ),
                                  const SizedBox(height: 15),
                                  _buildMenuItem(
                                    Icons.delete_outline, 
                                    'Delete Account', 
                                    'Permanently delete account', 
                                    isDanger: true,
                                    onTap: _handleDeleteAccount,
                                  ),
                                  
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}