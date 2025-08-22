import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/anonymous_chat_landing.dart';
import 'package:startup/home_components/barter_system_page.dart';
import 'package:startup/home_components/chat_screen.dart';
import 'package:startup/home_components/chat_service.dart';
import 'package:startup/home_components/committee_mainpage.dart';
import 'package:startup/home_components/confessions.dart';
import 'package:startup/home_components/doubt_screen.dart';
import 'package:startup/home_components/games_screen.dart';
import 'package:startup/home_components/lostfoundpage.dart';
import 'package:startup/home_components/manage_members.dart';
import 'package:startup/home_components/no_limits_scree.dart';
import 'package:startup/home_components/onetruthtwolies.dart';
import 'package:startup/home_components/polls_screen.dart';
import 'package:startup/home_components/shitiwishiknew.dart';
import 'package:startup/home_components/thegarage.dart';
import 'package:startup/home_components/your_neighbourhood.dart';
import 'pending_requests_page.dart';

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

  final List<Map<String, dynamic>> allZones = [
    {'name': 'the confession vault', 'desc': 'we know you cannot face that baddie💔🥀...', 'icon': Icons.lock_outline, 'colors': [Color(0xFF8B5CF6), Color(0xFFA855F7)], 'type': 'confessions'},
    {'name': 'no limits', 'desc': 'show your college who is the goat🐐', 'icon': Icons.all_inclusive, 'colors': [Color(0xFFEF4444), Color(0xFFDC2626)], 'type': 'no_limits'},
    {'name': 'shit i wish i knew', 'desc': 'do not make the mistake that your parents did', 'icon': Icons.lightbulb_outline, 'colors': [Color(0xFFF59E0B), Color(0xFFD97706)], 'type': 'shit_i_wish'},
    {'name': 'barter?\nhell yeah', 'desc': 'trade skills, not drugs', 'icon': Icons.swap_horiz, 'colors': [Color(0xFF10B981), Color(0xFF059669)], 'type': 'barter'},
    {'name': 'anonymous chatting', 'desc': 'the most peaceful section in blynt', 'icon': Icons.people_sharp, 'colors': [Color(0xFF3B82F6), Color(0xFF2563EB)], 'type': 'chat'},
    {'name': 'startup garage', 'desc': 'here comes the mature talk🍻', 'icon': Icons.rocket_launch, 'colors': [Color(0xFF6366F1), Color(0xFF4F46E5)], 'type': 'garage'},
    {'name': 'doubts', 'desc': 'make projects, either increase aura or get roa...', 'icon': Icons.construction, 'colors': [Color(0xFFEC4899), Color(0xFFDB2777)], 'type': 'doubts'},
    {'name': 'lost it', 'desc': 'you might find your lost tiffin but not her', 'icon': Icons.search_off, 'colors': [Color.fromARGB(255, 102, 75, 63), Color.fromARGB(255, 103, 62, 44)], 'type': 'lost'},
    {'name': 'the polls', 'desc': 'organize mass bunks', 'icon': Icons.poll_sharp, 'colors': [Color(0xFF1976D2), Color(0xFF64B5F6)], 'type': 'polls'},
    {'name': 'your neighbourhood', 'desc': 'places where you go', 'icon': Icons.location_on_outlined, 'colors': [Color(0xFF84CC16), Color(0xFF65A30D)], 'type': 'neighbourhood'},
    {'name': 'gaming arena', 'desc': 'yeah that boring ones', 'icon': Icons.theater_comedy, 'colors': [const Color(0xFFE91E63), const Color(0xFF8B2635)], 'type': 'shows'},
    {'name': 'committees', 'desc': 'ah shit here we go again', 'icon': Icons.groups_outlined, 'colors': [Color(0xFF0EA5E9), Color(0xFF0284C7)], 'type': 'committees'},
  ];

  @override
  void initState() {
    super.initState();
    _loadCommunityData();
    _loadUsername();
    _loadTodaysBirthdays();
    filteredZones = List.from(allZones);
  }

  Future<void> _loadUsername() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _username = userDoc.data()?['username'] ?? userDoc.data()?['name'] ?? 'Anonymous';
        });
      }
    } catch (e) {
      print('Error loading username: $e');
      _username = 'Anonymous';
    }
  }

  Future<void> _loadTodaysBirthdays() async {
    try {
      // Get today's date in MM-DD format
      final today = DateTime.now();
      final todayString = '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      
      // Get all users who have birthdays today and are in this community
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('communityId', isEqualTo: widget.communityId)
          .get();

      List<Map<String, dynamic>> birthdayUsers = [];

      // Check each user's birthday
      for (var userDoc in usersQuery.docs) {
        final userData = userDoc.data();
        
        // Check both 'dob' and 'birthday' fields for compatibility
        final dob = userData['dob'] as String?;
        final birthday = userData['birthday'] as String?;
        final birthdayField = dob ?? birthday;
        
        if (birthdayField != null) {
          try {
            // Parse birthday/dob string (format: 2006-08-14T00:00:00.000 or 2006-08-14)
            final birthdayDate = DateTime.parse(birthdayField);
            final birthdayString = '${birthdayDate.month.toString().padLeft(2, '0')}-${birthdayDate.day.toString().padLeft(2, '0')}';
            
            if (birthdayString == todayString) {
              final age = today.year - birthdayDate.year;
              birthdayUsers.add({
                'userId': userDoc.id,
                'username': userData['username'] ?? 'Unknown',
                'firstName': userData['firstName'] ?? 'User',
                'lastName': userData['lastName'] ?? '',
                'age': age,
              });
            }
          } catch (e) {
            print('Error parsing birthday for user ${userDoc.id}: $e');
          }
        }
      }

      setState(() {
        todaysBirthdays = birthdayUsers;
      });
    } catch (e) {
      print('Error loading birthdays: $e');
    }
  }

  Future<void> _sendBirthdayWish(String recipientId, String recipientName) async {
    try {
      // Get sender's name
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      final senderName = senderDoc.exists 
          ? (senderDoc.data()?['firstName'] ?? _username ?? 'Someone')
          : 'Someone';

      // Add notification to recipient
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .add({
        'type': 'birthday_wish',
        'title': 'Birthday Wish 🎉',
        'message': '$senderName sent you birthday wishes!',
        'senderName': senderName,
        'senderId': widget.userId,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Birthday wish sent to $recipientName! 🎉',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to send birthday wish',
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

  void _showBirthdayDialog() {
    if (todaysBirthdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No birthdays today! 🎂',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFF4299E1).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4299E1), Color(0xFF3182CE)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.cake,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Today\'s Birthdays 🎉',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: todaysBirthdays.length,
              itemBuilder: (context, index) {
                final user = todaysBirthdays[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2D3748).withOpacity(0.8),
                        const Color(0xFF4A5568).withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4299E1).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4299E1), Color(0xFF3182CE)],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              user['firstName'][0].toUpperCase(),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user['firstName']} ${user['lastName']}'.trim(),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Turns ${user['age']} today',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (user['userId'] != widget.userId)
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: () {
                                _sendBirthdayWish(user['userId'], user['firstName']);
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4299E1),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.cake_outlined, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Wish',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF4299E1).withOpacity(0.5),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                'You 🎂',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF4299E1),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
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
      final subcollections = ['trio', 'members', 'join_requests', 'left_members', 'removed_members', 'banned_users'];
      
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
    // Check if this is the last admin
    final isLastAdmin = await _isLastAdmin();
    
    final String title = isLastAdmin ? 'Dissolve Community' : 'Leave Community';
    final String content = isLastAdmin 
        ? 'You are the last admin. Leaving will dissolve the entire community and delete all data. This action cannot be undone.'
        : 'Are you sure you want to leave this community? This action cannot be undone.';
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: (isLastAdmin ? Colors.orange : Colors.red).withOpacity(0.3),
              width: 1,
            ),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                isLastAdmin ? 'Dissolve' : 'Leave',
                style: GoogleFonts.poppins(
                  color: isLastAdmin ? Colors.orange : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (isLastAdmin) {
        await _dissolveCommunity();
      } else {
        // Existing leave community logic remains the same
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
          widget.onRefresh();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You have left the community',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to leave community: $e',
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFF7B42C),
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      fontSize: 14,
                      color: Colors.white60,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Community Header
            Container(
              padding: const EdgeInsets.all(20),
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
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.groups,
                          color: Colors.black87,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              communityData?['name'] ?? 'Community',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
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
                                  fontSize: 12,
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
                  const SizedBox(height: 16),
                  if (communityData?['description'] != null)
                    Text(
                      communityData!['description'],
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatCard(
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
                      ),
                      const SizedBox(width: 12),
                      if (widget.userRole == 'admin' || widget.userRole == 'moderator')
                        _buildStatCard(
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
                          pendingRequestsCount > 0 ? pendingRequestsCount : null,
                        ),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        'Birthdays', 
                        todaysBirthdays.length.toString(), 
                        Icons.cake,
                        _showBirthdayDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Zones Section
            Text(
              isSearching ? 'Search Results' : 'explore different zones',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 16),

            // Zones Grid/List
            if (isSearching) _buildSearchResults() else _buildZonesGrid(),

            const SizedBox(height: 30),

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
                    fontSize: 14,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (filteredZones.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Colors.white60,
            ),
            const SizedBox(height: 16),
            Text(
              'No zones found',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching for confessions, polls, garage, etc.',
              style: GoogleFonts.poppins(
                fontSize: 14,
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
          margin: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _navigateToZone(zone),
            child: Container(
              padding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: zone['colors'] as List<Color>,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      zone['icon'] as IconData,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone['name'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          zone['desc'] as String,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.white60,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white60,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildZonesGrid() {
    return Column(
      children: allZones.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> zone = entry.value;
        bool isLeftAligned = index % 2 == 0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            onTap: () => _navigateToZone(zone),
            child: Container(
              height: 120,
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
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: isLeftAligned ? [
                    // Left aligned: Icon + Text on left, Description on right
                    Container(
                      padding: const EdgeInsets.all(8),
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
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            zone['name'] as String,
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            zone['desc'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.right,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ] : [
                    // Right aligned: Description on left, Icon + Text on right
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            zone['desc'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.white70,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.left,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            zone['name'] as String,
                            style: GoogleFonts.dmSerifDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
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
                        size: 22,
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

  Widget _buildStatCard(String label, String value, IconData icon, VoidCallback onTap, [int? badgeCount]) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
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
                    size: 20,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
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
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 10,
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