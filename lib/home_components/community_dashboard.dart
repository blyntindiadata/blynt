import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/anonymous_chat_landing.dart';
import 'package:startup/home_components/barter_system_page.dart';
import 'package:startup/home_components/birthdays_screen.dart';
import 'package:startup/home_components/chat_screen.dart';
import 'package:startup/home_components/chat_service.dart';
import 'package:startup/home_components/committee_mainpage.dart';
import 'package:startup/home_components/confessions.dart';
import 'package:startup/home_components/doubt_screen.dart';
import 'package:startup/home_components/games_screen.dart';
import 'package:startup/home_components/lostfoundpage.dart';
import 'package:startup/home_components/manage_members.dart';
import 'package:startup/home_components/manage_notice.dart';
import 'package:startup/home_components/no_limits_scree.dart';
import 'package:startup/home_components/notice_carousel.dart';
import 'package:startup/home_components/notification_service.dart';
import 'package:startup/home_components/polls_screen.dart';
import 'package:startup/home_components/shitiwishiknew.dart';
import 'package:startup/home_components/thegarage.dart';
import 'package:startup/home_components/your_neighbourhood.dart';
import 'pending_requests_page.dart';
import 'package:flutter/services.dart';

class CommunityDashboard extends StatefulWidget {
  final String communityId;
  final String userRole;
  final String userId;
  final VoidCallback onRefresh;

  const CommunityDashboard({
    super.key,
    required this.communityId,
    required this.userRole,
    required this.userId,
    required this.onRefresh,
  });

  @override
  State<CommunityDashboard> createState() => _CommunityDashboardState();
}

class _CommunityDashboardState extends State<CommunityDashboard> {
  Map<String, dynamic>? communityData;
  int memberCount = 0;
  int pendingRequestsCount = 0;
  bool isLoading = true;
  String? _username;
  List<Map<String, dynamic>> todaysBirthdays = [];
  List<Map<String, dynamic>> filteredZones = [];
  bool isSearching = false;
  bool hasError = false;


  Future<T?> _safeAsyncOperation<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e) {
      print('Safe async operation error: $e');
      if (mounted) {
        setState(() {
          hasError = true;
        });
      }
      return null;
    }
  }

final List<Map<String, dynamic>> allZones = [
  {'name': 'anonymous\nchatting', 'desc': 'wait till the identities get revealed🥷', 'icon': Icons.people_sharp, 'colors': [Color(0xFF3B82F6), Color(0xFF2563EB)], 'type': 'chat'},
  {'name': 'gamer\'s garage', 'desc': 'show your college who is the goat🐐', 'icon': Icons.theater_comedy, 'colors': [const Color(0xFFE91E63), const Color(0xFF8B2635)], 'type': 'shows'},
  {'name': 'the\nconfession\nvault', 'desc': 'simp your crush, roast your ex🍻', 'icon': Icons.lock_outline, 'colors': [Color(0xFF8B5CF6), Color(0xFFA855F7)], 'type': 'confessions'},
  {'name': 'sh*t i\nwish i\nknew', 'desc': 'do not make the mistake that your parents did', 'icon': Icons.lightbulb_outline, 'colors': [Color(0xFFF59E0B), Color(0xFFD97706)], 'type': 'shit_i_wish'},
  {'name': 'no limits', 'desc': '1 banger away from getting her number🗿', 'icon': Icons.all_inclusive, 'colors': [Color(0xFFEF4444), Color(0xFFDC2626)], 'type': 'no_limits'},
  {'name': 'where\'s my crap', 'desc': 'you might find your lost tiffin but not her🥀', 'icon': Icons.search_off, 'colors': [Color.fromARGB(255, 102, 75, 63), Color.fromARGB(255, 103, 62, 44)], 'type': 'lost'},
  {'name': 'chamber of \nconfusions', 'desc': 'coz your prof doesn\'t know sh*t', 'icon': Icons.construction, 'colors': [const Color(0xFF4A4A4A), const Color(0xFF2C2C2C)], 'type': 'doubts'},
  {'name': 'barter?\nhell yeah', 'desc': 'trade skills, not drugs', 'icon': Icons.swap_horiz, 'colors': [Color(0xFF10B981), Color(0xFF059669)], 'type': 'barter'},
  {'name': 'the polls', 'desc': 'one vote that ruins everything ', 'icon': Icons.poll_sharp, 'colors': [Color(0xFF1976D2), Color(0xFF64B5F6)], 'type': 'polls'},
  {'name': 'your\nneighbourhood', 'desc': 'because the best places aren\'t marked', 'icon': Icons.location_on_outlined, 'colors': [Color(0xFF84CC16), Color(0xFF65A30D)], 'type': 'neighbourhood'},
  // {'name': 'committees', 'desc': 'ah shit here we go again', 'icon': Icons.groups_outlined, 'colors': [Color(0xFF0EA5E9), Color(0xFF0284C7)], 'type': 'committees'},
];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
    _loadCommunityData();
    _loadUsername();
    _loadTodaysBirthdays();
    filteredZones = List.from(allZones);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _safeAsyncOperation(() async {
      await _loadCommunityData();
      await _loadUsername();
      await _loadTodaysBirthdays();
      if (mounted) {
        setState(() {
          filteredZones = List.from(allZones);
        });
      }
    });
  }

  Future<void> _loadUsername() async {
    try {
      if (widget.userId.isEmpty) return;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      if (userDoc.exists && userDoc.data() != null) {
        if (mounted) {
          setState(() {
            _username = userDoc.data()?['username'] ?? 
                      userDoc.data()?['name'] ?? 
                      'Anonymous';
          });
        }
      }
    } catch (e) {
      print('Error loading username: $e');
      if (mounted) {
        setState(() {
          _username = 'Anonymous';
        });
      }
    }
  }

  Future<void> _loadTodaysBirthdays() async {
    try {
      if (widget.communityId.isEmpty) return;

      final today = DateTime.now();
      final todayString = '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Get community members with error handling
      final List<String> memberIds = [];

      try {
        // Get trio members
        final trioQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('trio')
            .where('status', isEqualTo: 'active')
            .get();

        memberIds.addAll(
          trioQuery.docs
            .where((doc) => doc.data()['userId'] != null)
            .map((doc) => doc.data()['userId'] as String)
        );

        // Get regular members
        final membersQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .where('status', isEqualTo: 'active')
            .get();

        memberIds.addAll(
          membersQuery.docs
            .where((doc) => doc.data()['userId'] != null)
            .map((doc) => doc.data()['userId'] as String)
        );
      } catch (e) {
        print('Error fetching community members: $e');
        return;
      }

      // Remove duplicates
      final uniqueMemberIds = memberIds.toSet().toList();

      List<Map<String, dynamic>> birthdayUsers = [];

      // Check each member's birthday
      for (String memberId in uniqueMemberIds) {
        if (memberId.isEmpty) continue;
        
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(memberId)
              .get();

          if (userDoc.exists && userDoc.data() != null) {
            final userData = userDoc.data()!;
            final dob = userData['dob'] as String?;
            final birthday = userData['birthday'] as String?;
            final birthdayField = dob ?? birthday;

            if (birthdayField != null && birthdayField.isNotEmpty) {
              try {
                final birthdayDate = DateTime.parse(birthdayField);
                final birthdayString = '${birthdayDate.month.toString().padLeft(2, '0')}-${birthdayDate.day.toString().padLeft(2, '0')}';

                if (birthdayString == todayString) {
                  final age = today.year - birthdayDate.year;
                  birthdayUsers.add({
                    'userId': memberId,
                    'username': userData['username'] ?? 'Unknown',
                    'firstName': userData['firstName'] ?? 'User',
                    'lastName': userData['lastName'] ?? '',
                    'age': age,
                  });
                }
              } catch (e) {
                print('Error parsing birthday for user $memberId: $e');
              }
            }
          }
        } catch (e) {
          print('Error fetching user data for $memberId: $e');
        }
      }

      if (mounted) {
        setState(() {
          todaysBirthdays = birthdayUsers;
        });
      }
    } catch (e) {
      print('Error loading birthdays: $e');
    }
  }

  Future<void> _testLocalNotifications() async {
    print('🧪 Testing local notifications from UI...');
    
    // Check if notifications are enabled
    final bool enabled = await NotificationService.areNotificationsEnabled();
    print('📱 Notifications enabled: $enabled');
    
    if (!enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notifications are disabled. Please enable in device settings.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                // You can add code to open app settings here
                print('📱 User should go to app settings to enable notifications');
              },
            ),
          ),
        );
      }
      return;
    }

    try {
      // await NotificationService.testNotification();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test notification sent! Check your notification panel.',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      print('❌ Test notification failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test notification failed: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _sendBirthdayWish(String recipientId, String recipientName) async {
    print('🎂 === BIRTHDAY WISH DEBUG START ===');
    print('🎂 Recipient ID: $recipientId');
    print('🎂 Recipient Name: $recipientName');
    print('🎂 Sender ID: ${widget.userId}');
    print('🎂 Community ID: ${widget.communityId}');

    try {
      print('🎂 Step 1: Getting sender name...');
      
      // Get sender name
      String senderName = _username ?? 'Someone';
      try {
        final senderDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();
        
        if (senderDoc.exists && senderDoc.data() != null) {
          senderName = senderDoc.data()!['firstName'] ?? senderName;
          print('🎂 ✅ Sender name found: $senderName');
        } else {
          print('🎂 ⚠️ Sender document not found, using: $senderName');
        }
      } catch (e) {
        print('🎂 ❌ Error getting sender name: $e');
      }

      print('🎂 Step 2: Calling NotificationService.sendBirthdayWish...');

      // Send birthday wish using unified service
      await NotificationService.sendBirthdayWish(
        senderId: widget.userId,
        senderName: senderName,
        recipientId: recipientId,
        recipientName: recipientName,
        communityId: widget.communityId,
      );

      print('🎂 ✅ NotificationService.sendBirthdayWish completed successfully');

      // Show success message
      if (mounted) {
        print('🎂 Step 3: Showing success SnackBar...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cake, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Birthday wish sent to $recipientName! 🎉',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF6A4C93),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        print('🎂 ✅ Success SnackBar shown');
      }

      print('🎂 === BIRTHDAY WISH DEBUG END (SUCCESS) ===');

    } catch (e) {
      print('🎂 ❌ Birthday wish failed at top level: $e');
      print('🎂 ❌ Error type: ${e.runtimeType}');
      print('🎂 ❌ Stack trace: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send birthday wish: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      
      print('🎂 === BIRTHDAY WISH DEBUG END (FAILED) ===');
    }
  }

 void _filterZones(String query) {
  setState(() {
    if (query.isEmpty) {
      filteredZones = List.from(allZones);
      isSearching = false;
    } else {
      isSearching = true;
      filteredZones = allZones.where((zone) {
        return zone['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
               zone['desc'].toString().toLowerCase().contains(query.toLowerCase());
      }).toList();
    }
  });
}

  // Public method to be called from Home widget
  void filterZones(String query) {
    _filterZones(query);
  }


  void _navigateToViewNotices() {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ManageNoticesScreen(
        communityId: widget.communityId,
        userId: widget.userId,
        userRole: widget.userRole,
        username: _username ?? 'Anonymous',
      ),
    ),
  );
}

  void _navigateToZone(Map<String, dynamic> zone) async {
    if (zone['type'] == 'confessions') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConfessionsPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'no_limits') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NoLimitsPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'barter') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarterSystemPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'polls') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PollsPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'garage') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TheGaragePage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'shit_i_wish') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ShitIWishIKnewPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'chat') {
      if (_username != null) {
        final chatService = ChatService();
        final activeSession = await chatService.getActiveSession(widget.communityId, widget.userId);
        
        if (activeSession != null) {
          final partnerId = activeSession.getPartnerId(widget.userId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                communityId: widget.communityId,
                userId: widget.userId,
                username: _username!,
                sessionId: activeSession.sessionId,
                partnerId: partnerId,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AnonymousChatLanding(
                communityId: widget.communityId,
                userId: widget.userId,
                username: _username!,
              ),
            ),
          );
        }
      }
    } else if (zone['type'] == 'lost') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LostAndFoundPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'neighbourhood') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => YourNeighbourhoodScreen(
              communityId: widget.communityId,
              userRole: widget.userRole,
            ),
          ),
        );
      }
    } 
    else if (zone['type'] == 'doubts') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoubtsPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'shows') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GamesPage(
              communityId: widget.communityId,
              userId: widget.userId,
              username: _username!,
            ),
          ),
        );
      }
    } else if (zone['type'] == 'committees') {
      if (_username != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CommitteesPage(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username!,
            ),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Coming soon: ${zone['name']}',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<bool> _isLastAdmin() async {
    if (widget.userRole != 'admin') return false;
    
    // Count total admins in both collections
    final trioAdmins = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .where('role', isEqualTo: 'admin')
        .where('status', isEqualTo: 'active')
        .get();

    final memberAdmins = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .where('role', isEqualTo: 'admin')
        .where('status', isEqualTo: 'active')
        .get();

    final totalAdmins = trioAdmins.docs.length + memberAdmins.docs.length;
    return totalAdmins == 1; // Only current user is admin
  }

  Future<void> _dissolveCommunity() async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Delete all subcollections
      final subcollections = ['trio', 'members', 'join_requests', 'left_members', 'removed_members', 'banned_users', 'notices'];
      
      for (String subcollection in subcollections) {
        final snapshot = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection(subcollection)
            .get();
        
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
      }
      
      // Delete main community document
      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId);
      batch.delete(communityRef);
      
      // Remove community reference from all users
      final allUsers = await FirebaseFirestore.instance
          .collection('users')
          .where('communityId', isEqualTo: widget.communityId)
          .get();
      
      for (var userDoc in allUsers.docs) {
        batch.update(userDoc.reference, {
          'communityId': FieldValue.delete(),
        });
      }
      
      await batch.commit();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Community dissolved successfully',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        
        // Navigate back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to dissolve community: $e',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadCommunityData() async {
    try {
      // Get community data
      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .get();

      if (communityDoc.exists) {
        communityData = communityDoc.data();
      }

      // Get member count from both subcollections
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('status', isEqualTo: 'active')
          .get();

      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .get();

      memberCount = trioQuery.docs.length + membersQuery.docs.length;

      // Get pending requests count (only for admin/moderator)
      if (widget.userRole == 'admin' || widget.userRole == 'moderator') {
        final pendingQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('join_requests')
            .where('processed', isEqualTo: false)
            .get();

        pendingRequestsCount = pendingQuery.docs.length;
      }
    } catch (e) {
      print('Error loading community data: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

Future<void> _leaveCommunity() async {
  final screenWidth = MediaQuery.of(context).size.width;
  final isPhone = screenWidth < 600;
final isTablet = screenWidth >= 600 && screenWidth < 1024;
final isDesktop = screenWidth >= 1024;
final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.3);
  
  // Check if user has administrative privileges
  final List<String> restrictedRoles = ['admin', 'moderator', 'manager'];
  
  if (restrictedRoles.contains(widget.userRole.toLowerCase())) {
    // Show dialog explaining why they can't leave
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 16,
              vertical: isTablet ? 20 : 16,
            ),
            titlePadding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 16,
              isTablet ? 20 : 16,
              isTablet ? 24 : 16,
              0,
            ),
            actionsPadding: EdgeInsets.fromLTRB(
              isTablet ? 24 : 16,
              0,
              isTablet ? 24 : 16,
              isTablet ? 16 : 12,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  color: Colors.orange,
                  size: isPhone ? 18 : isTablet ? 22 : 24,
                ),
                SizedBox(width: isTablet ? 8 : 6),
                Flexible(
                  child: Text(
                    'Cannot Leave Community',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: isPhone ? screenWidth * 0.9 : isTablet ? 400 : 450,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'As a ${widget.userRole.toLowerCase()}, you cannot leave the community directly.',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 14 : 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To leave this community:',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                          SizedBox(height: isTablet ? 8 : 6),
                          Text(
                            '1. Talk to your assigned blynt representative regarding the leaving clause\n\n'
                            '2. Then you can leave the community',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 13 : 11,
                              color: Colors.white60,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTablet ? 16 : 12),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 8,
                        vertical: isTablet ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue,
                            size: isTablet ? 16 : 14,
                          ),
                          SizedBox(width: isTablet ? 8 : 6),
                          Expanded(
                            child: Text(
                              'This ensures the community always has proper leadership.',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 12 : 10,
                                color: Colors.blue,
                                fontStyle: FontStyle.italic,
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
            actions: [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: Colors.orange.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      vertical: isTablet ? 16 : 12,
                    ),
                  ),
                  child: Text(
                    'I Understand',
                    style: GoogleFonts.poppins(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: (isPhone ? 14 : isTablet ? 16 : 18) * textScale,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return; // Exit early, don't proceed with leaving
  }

  // Original leave community logic for regular members
  final String title = 'Leave Community';
  final String content = 'Are you sure you want to leave this community? This action cannot be undone.';
  
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return SafeArea(
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 24 : 16,
            vertical: isTablet ? 20 : 16,
          ),
          titlePadding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            isTablet ? 20 : 16,
            isTablet ? 24 : 16,
            0,
          ),
          actionsPadding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            0,
            isTablet ? 24 : 16,
            isTablet ? 16 : 12,
          ),
          title: Row(
            children: [
              Icon(
                Icons.exit_to_app,
                color: Colors.red,
                size: isPhone ? 18 : isTablet ? 22 : 24,
              ),
              SizedBox(width: isTablet ? 8 : 6),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
                maxWidth: screenWidth > 400 ? 300 : screenWidth * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 16 : 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: isTablet ? 20 : 18,
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        Expanded(
                          child: Text(
                            content,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 13,
                              color: Colors.white70,
                              height: 1.4,
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
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 16 : 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontWeight: FontWeight.w500,
                        fontSize: (isPhone ? 14 : isTablet ? 16 : 18) * textScale,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.red.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 16 : 12,
                      ),
                    ),
                    child: Text(
                      'Leave',
                      style: GoogleFonts.poppins(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 16 : 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );

  if (confirm == true) {
    // Show loading indicator
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return SafeArea(
            child: AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: EdgeInsets.all(isTablet ? 32 : 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    color: const Color(0xFFF7B42C),
                    strokeWidth: isTablet ? 3 : 2,
                  ),
                  SizedBox(height: isTablet ? 20 : 16),
                  Text(
                    'Leaving community...',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: (isPhone ? 14 : isTablet ? 16 : 18) * textScale,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Existing leave community logic for regular members
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Remove from trio subcollection
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('userId', isEqualTo: widget.userId)
          .get();

      for (var doc in trioQuery.docs) {
        batch.delete(doc.reference);
      }

      // Remove from members subcollection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('userId', isEqualTo: widget.userId)
          .get();

      for (var doc in membersQuery.docs) {
        batch.delete(doc.reference);
      }

      // Remove from old community_members collection (if exists)
      final memberQuery = await FirebaseFirestore.instance
          .collection('community_members')
          .where('userId', isEqualTo: widget.userId)
          .where('communityId', isEqualTo: widget.communityId)
          .get();

      for (var doc in memberQuery.docs) {
        batch.delete(doc.reference);
      }

      // Update member count in community
      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId);
      batch.update(communityRef, {
        'memberCount': FieldValue.increment(-1),
      });

      // Add to left_members log for tracking
      final leftMemberRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('left_members')
          .doc();
      batch.set(leftMemberRef, {
        'userId': widget.userId,
        'leftAt': FieldValue.serverTimestamp(),
        'previousRole': widget.userRole,
      });

      // Update user's community mapping
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
      batch.update(userRef, {
        'communityId': FieldValue.delete(),
      });

      await batch.commit();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: isPhone ? 18 : isTablet ? 22 : 24,
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Expanded(
                  child: Text(
                    'You have successfully left the community',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: (isPhone ? 14 : isTablet ? 16 : 18) * textScale,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 20 : 16,
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: isPhone ? 18 : isTablet ? 22 : 24,
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Expanded(
                  child: Text(
                    'Failed to leave community. Please try again.',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: (isPhone ? 14 : isTablet ? 16 : 18) * textScale,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 20 : 16,
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isPhone = screenWidth < 600;
  final isTablet = screenWidth >= 600 && screenWidth < 1024;
  final isDesktop = screenWidth >= 1024;
  final textScale = MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.3);

  if (isLoading) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
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
          ),
          Center(
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
          ),
        ],
      ),
    );
  }

 

    return RefreshIndicator(
      onRefresh: () async {
        await _loadCommunityData();
        await _loadTodaysBirthdays();
      },
      color: const Color(0xFFF7B42C),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
  horizontal: isPhone ? 16 : isTablet ? 24 : isDesktop ? 32 : 48,
),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Community Info
            Center(
              child: Column(
                children: [
                  Text(
                    'you are a part of',
                    style: GoogleFonts.poppins(
                      fontSize: (isPhone ? 12 : isTablet ? 14 : 16) * textScale,
                      color: Colors.white60,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: screenHeight * (isPhone ? 0.02 : isTablet ? 0.025 : 0.03)),

            // Community Header
            Container(
  padding: EdgeInsets.all(isPhone ? 16 : isTablet ? 20 : 24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.08),
        Colors.white.withOpacity(0.04),
      ],
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xFFF7B42C).withOpacity(0.3),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFF7B42C).withOpacity(0.1),
        blurRadius: 20,
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
                        padding: EdgeInsets.all(isTablet ? 16 : 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.groups,
                          color: Colors.black87,
                          size: isPhone ? 20 : isTablet ? 24 : 28,
                        ),
                      ),
                      SizedBox(width: isTablet ? 20 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              communityData?['name'] ?? 'Community',
                              style: GoogleFonts.poppins(
                                fontSize: (isPhone ? 18 : isTablet ? 22 : 26) * textScale,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 16 : 12,
                                vertical: isTablet ? 6 : 4,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _getRoleGradient(widget.userRole),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.userRole.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 14 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isTablet ? 20 : 16),
                  if (communityData?['description'] != null)
                    Text(
                      communityData!['description'],
                      style: GoogleFonts.poppins(
                        fontSize: (isPhone ? 14 : isTablet ? 16 : 18) * textScale,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  SizedBox(height: isTablet ? 20 : 16),
               Row(
  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
  children: [
    Flexible(
      flex: 1,
      child: _buildStatCard(
        'Members', 
        memberCount.toString(), 
        Icons.people,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ManageMembersPage(
                communityId: widget.communityId,
                currentUserId: widget.userId,
                currentUserRole: widget.userRole,
              ),
            ),
          );
        },
        isTablet,
      ),
    ),
    if (widget.userRole == 'admin' || widget.userRole == 'moderator') ...[
      SizedBox(width: isTablet ? 16 : 12),
      Flexible(
        flex: 1,
        child: _buildStatCard(
          'Pending', 
          pendingRequestsCount.toString(), 
          Icons.pending_actions,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PendingRequestsPage(
                  communityId: widget.communityId,
                  onRequestProcessed: _loadCommunityData,
                ),
              ),
            );
          },
          isTablet,
          pendingRequestsCount > 0 ? pendingRequestsCount : null,
        ),
      ),
    ],
    SizedBox(width: isTablet ? 16 : 12),
    Flexible(
      flex: 1,
      child: _buildStatCard(
        'Birthdays', 
        todaysBirthdays.length.toString(), 
        Icons.cake,
        () {
          Navigator.push(
            context,
            MaterialPageRoute(
            builder: (context) => BirthdaysScreen(
              communityId: widget.communityId,
              userId: widget.userId,
              userRole: widget.userRole,
              username: _username ?? 'Anonymous',
            ),
          ),
        );
      },
      isTablet,
    ),
  ),
  ]
)
                
                ],
              ),
            ),

            SizedBox(height: screenHeight * 0.045),

            // Notices Card
            GestureDetector(
              onTap: _navigateToViewNotices,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isTablet ? 20 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFFB8860B).withOpacity(0.25), // Dark golden
                      const Color(0xFFCD7F32).withOpacity(0.15), // Bronze
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFDAA520).withOpacity(0.4), // Golden rod
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB8860B).withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFB8860B), // Dark golden
                            Color(0xFFDAA520), // Golden rod
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFB8860B).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.campaign_outlined,
                        color: Colors.white,
                        size: isPhone ? 18 : isTablet ? 22 : 24,
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Community Notices',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: isTablet ? 6 : 4),
                          Text(
                            'View important announcements and updates',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 14 : 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white60,
                      size: isTablet ? 18 : 16,
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: screenHeight * 0.005),

            SizedBox(height: screenHeight * 0.04),

            // Zones Section
            Center(

  child: Text(
    'explore different zones',
    style: GoogleFonts.dmSerifDisplay(
      fontSize: (isPhone ? 20 : isTablet ? 28 : 24) * textScale,
      fontWeight: FontWeight.w400,
      color: Colors.white,
      letterSpacing: 0.5,
    ),
  ),
),
SizedBox(height: isTablet ? 20 : 16),



if (isSearching)
  Text(
    'Search Results',
    style: GoogleFonts.poppins(
      fontSize: isTablet ? 18 : 16,
      fontWeight: FontWeight.w600,
      color: Colors.white70,
    ),
  ),
if (isSearching) SizedBox(height: isTablet ? 16 : 12),
            SizedBox(height: isTablet ? 20 : 16),

            // Zones Grid/List
            if (isSearching) _buildSearchResults(isTablet) else _buildZonesGrid(isTablet),

            SizedBox(height: screenHeight * 0.04),

            // Leave Community Button
            Center(
              child: TextButton.icon(
                onPressed: _leaveCommunity,
                icon: const Icon(
                  Icons.exit_to_app,
                  color: Colors.red,
                  size: 20,
                ),
                label: Text(
                  'Leave Community',
                  style: GoogleFonts.poppins(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: (isPhone ? 12 : isTablet ? 14 : 16) * textScale,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 12 : 8,
                  ),
                ),
              ),
            ),

            SizedBox(height: screenHeight * 0.05),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isTablet) {
    if (filteredZones.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isTablet ? 48 : 40),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: isTablet ? 56 : 48,
              color: Colors.white60,
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'No zones found',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              'Try searching for confessions, polls, garage, etc.',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 16 : 14,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: filteredZones.map((zone) {
        return Container(
          margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
          child: GestureDetector(
            onTap: () => _navigateToZone(zone),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 20 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (zone['colors'] as List<Color>)[0].withOpacity(0.2),
                    (zone['colors'] as List<Color>)[1].withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (zone['colors'] as List<Color>)[0].withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: zone['colors'] as List<Color>,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      zone['icon'] as IconData,
                      color: Colors.white,
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                     Text(
  zone['name'] as String,
  style: GoogleFonts.poppins(
    fontSize: isTablet ? 17 : 15,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    height: 1.2,
  ),
  maxLines: 2,
  overflow: TextOverflow.visible,
  softWrap: true,
),
                        SizedBox(height: isTablet ? 6 : 4),
                        Text(
                          zone['desc'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 12 : 10,
                            color: Colors.white60,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white60,
                    size: isTablet ? 18 : 16,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

Widget _buildZonesGrid(bool isTablet) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  
  int crossAxisCount;
  double childAspectRatio;

  if (isLandscape) {
    // Landscape-specific logic
    if (screenWidth < 500) {
      crossAxisCount = 1;
      childAspectRatio = 3.5;
    } else if (screenWidth < 700) {
      crossAxisCount = 2;
      childAspectRatio = 2.2;
    } else if (screenWidth < 1000) {
      crossAxisCount = 2;
      childAspectRatio = 2.5;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 2.2;
    }
  } else {
    // Portrait logic
    if (screenWidth < 400) {
      crossAxisCount = 1;
      childAspectRatio = 2.8;
    } else if (screenWidth < 600) {
      crossAxisCount = 1;
      childAspectRatio = 2.5;
    } else if (screenWidth < 900) {
      crossAxisCount = 2;
      childAspectRatio = 1.8;
    } else if (screenWidth < 1200) {
      crossAxisCount = 2;
      childAspectRatio = 2.0;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 1.9;
    }
  }
  
  if (crossAxisCount > 1) {
    // Grid layout for larger screens
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isTablet ? 1.8 : 2.2,
        crossAxisSpacing: isTablet ? 16 : 12,
        mainAxisSpacing: isTablet ? 16 : 12,
      ),
      itemCount: filteredZones.length,
      itemBuilder: (context, index) {
        final zone = filteredZones[index];
        return _buildZoneCard(zone, isTablet);
      },
    );
  }

  // Vertical list for mobile
  return Column(
    children: filteredZones.asMap().entries.map((entry) {
      int index = entry.key;
      Map<String, dynamic> zone = entry.value;
      bool isLeftAligned = index % 2 == 0;
      
      return Container(
        margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
        child: GestureDetector(
          onTap: () => _navigateToZone(zone),
          child:Container(
  height: () {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      if (screenWidth < 500) return 100.0;
      return isTablet ? 120.0 : 110.0;
    }
    return isTablet ? 140.0 : 120.0;
  }(),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: isLeftAligned ? Alignment.centerLeft : Alignment.centerRight,
                end: isLeftAligned ? Alignment.centerRight : Alignment.centerLeft,
                colors: [
                  (zone['colors'] as List<Color>)[0].withOpacity(0.3),
                  (zone['colors'] as List<Color>)[1].withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (zone['colors'] as List<Color>)[0].withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (zone['colors'] as List<Color>)[0].withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              child: Row(
                children: isLeftAligned ? [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: zone['colors'] as List<Color>,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: (zone['colors'] as List<Color>)[0].withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      zone['icon'] as IconData,
                      color: Colors.white,
                      size: isTablet ? 26 : 22,
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
  zone['name'] as String,
  style: GoogleFonts.dmSerifDisplay(
    fontSize: isTablet ? 17 : 15,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    height: 1.1,
  ),
  maxLines: 4,
  overflow: TextOverflow.visible,
  softWrap: true,
),
                      ],
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
  zone['desc'] as String,
  style: GoogleFonts.poppins(
    fontSize: isTablet ? 12 : 10,
    color: Colors.white70,
    height: 1.3,
    fontWeight: FontWeight.w400,
  ),
  textAlign: TextAlign.right,
  maxLines: 4,
  overflow: TextOverflow.visible,
  softWrap: true,
),
                      ],
                    ),
                  ),
                ] : [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
  zone['desc'] as String,
  style: GoogleFonts.poppins(
    fontSize: isTablet ? 12 : 10,
    color: Colors.white70,
    height: 1.3,
    fontWeight: FontWeight.w400,
  ),
  textAlign: TextAlign.left,
  maxLines: 4,
  overflow: TextOverflow.visible,
  softWrap: true,
),
                      ],
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Text(
  zone['name'] as String,
  style: GoogleFonts.dmSerifDisplay(
    fontSize: isTablet ? 17 : 15,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    height: 1.1,
  ),
  textAlign: TextAlign.right,
  maxLines: 4,
  overflow: TextOverflow.visible,
  softWrap: true,
),
                      ],
                    ),
                  ),
                  SizedBox(width: isTablet ? 20 : 16),
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: zone['colors'] as List<Color>,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: (zone['colors'] as List<Color>)[0].withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      zone['icon'] as IconData,
                      color: Colors.white,
                      size: isTablet ? 26 : 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

Widget _buildZoneCard(Map<String, dynamic> zone, bool isTablet) {
  return GestureDetector(
    onTap: () => _navigateToZone(zone),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (zone['colors'] as List<Color>)[0].withOpacity(0.3),
            (zone['colors'] as List<Color>)[1].withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (zone['colors'] as List<Color>)[0].withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (zone['colors'] as List<Color>)[0].withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 12 : 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: zone['colors'] as List<Color>,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: (zone['colors'] as List<Color>)[0].withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                zone['icon'] as IconData,
                color: Colors.white,
                size: isTablet ? 24 : 20,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
         Text(
  zone['name'] as String,
  style: GoogleFonts.dmSerifDisplay(
    fontSize: isTablet ? 17 : 15,
    fontWeight: FontWeight.w500,
    color: Colors.white,
    height: 1.1,
  ),
  textAlign: TextAlign.center,
  maxLines: 4,
  overflow: TextOverflow.visible,
  softWrap: true,
),
            SizedBox(height: isTablet ? 8 : 4),
            Text(
  zone['desc'] as String,
  style: GoogleFonts.poppins(
    fontSize: isTablet ? 12 : 10,
    color: Colors.white70,
    height: 1.3,
    fontWeight: FontWeight.w400,
  ),
  textAlign: TextAlign.center,
  maxLines: 4,
  overflow: TextOverflow.visible,
  softWrap: true,
),
          ],
        ),
      ),
    ),
  );
}
  Widget _buildStatCard(String label, String value, IconData icon, VoidCallback onTap, bool isTablet, [int? badgeCount]) {
    return Container(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(isTablet ? 22 : 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7B42C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFF7B42C).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                 
                  Icon(
                    icon,
                    color: const Color(0xFFF7B42C),
                    size: isTablet ? 24 : 20,
                  ),
                   Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 20 : 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                   SizedBox(height: isTablet ? 10 : 8),
                 
                  
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 12 : 10,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: EdgeInsets.all(isTablet ? 6 : 4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: isTablet ? 20 : 16,
                      minHeight: isTablet ? 20 : 16,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isTablet ? 12 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getRoleGradient(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return [const Color.fromARGB(255, 248, 178, 0), const Color.fromARGB(255, 255, 119, 0)];
      case 'moderator':
        return [Colors.blue, Colors.lightBlue];
      default:
        return [const Color(0xFFF7B42C), const Color(0xFFFFD700)];
    }
  }
} 