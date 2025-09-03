import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:startup/home_components/notification_service.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class BirthdaysScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const BirthdaysScreen({
    super.key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  });

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen> {
  List<Map<String, dynamic>> todaysBirthdays = [];
  bool isLoading = true;
  final Map<String, String?> _userProfileImages = {};
  final Set<String> _sentWishes = {}; // Add this after _userProfileImages declaration

  @override
  void initState() {
    super.initState();
    _setSystemUIOverlay();
    _loadTodaysBirthdays();
     _loadSentWishes();
  }

  Future<void> _loadTodaysBirthdays() async {
    try {
      final today = DateTime.now();
      final todayString = '${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Get all community members from both subcollections
      final List<String> memberIds = [];

      // Get trio members
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('status', isEqualTo: 'active')
          .get();

      memberIds.addAll(trioQuery.docs.map((doc) => doc.data()['userId'] as String));

      // Get regular members
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('status', isEqualTo: 'active')
          .get();

      memberIds.addAll(membersQuery.docs.map((doc) => doc.data()['userId'] as String));

      // Remove duplicates
      final uniqueMemberIds = memberIds.toSet().toList();

      List<Map<String, dynamic>> birthdayUsers = [];

      // Check each member's birthday
      for (String memberId in uniqueMemberIds) { 
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(memberId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final dob = userData['dob'] as String?;
          final birthday = userData['birthday'] as String?;
          final birthdayField = dob ?? birthday;

          if (birthdayField != null) {
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
                  'birthdayDate': birthdayDate,
                });
              }
            } catch (e) {
              print('Error parsing birthday for user $memberId: $e');
            }
          }
        }
      }

      setState(() {
        todaysBirthdays = birthdayUsers;
        isLoading = false;
      });
      _loadSentWishes();
    } catch (e) {
      print('Error loading birthdays: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _setSystemUIOverlay() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D1B2A), // Match your background
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
}

  Future<String?> _getUserProfileImage(String username) async {
    // Check cache first
    if (_userProfileImages.containsKey(username)) {
      return _userProfileImages[username];
    }

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

      final profileImageUrl = userDoc?.data() != null 
          ? (userDoc!.data() as Map<String, dynamic>)['profileImageUrl'] as String?
          : null;
      _userProfileImages[username] = profileImageUrl;
      return profileImageUrl;
    } catch (e) {
      print('Error fetching profile image for $username: $e');
      _userProfileImages[username] = null;
      return null;
    }
  }

  Future<Map<String, dynamic>?> _getUserData(String username) async {
    try {
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (trioQuery.docs.isNotEmpty) {
        return trioQuery.docs.first.data();
      }

      // Check members collection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (membersQuery.docs.isNotEmpty) {
        return membersQuery.docs.first.data();
      }

      return null;
    } catch (e) {
      print('Error fetching user data for $username: $e');
      return null;
    }
  }

  Future<void> _sendBirthdayWish(String recipientId, String recipientName) async {
    try {
      // Get sender's name
      final senderDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      final senderName = widget.username;

      // Use the enhanced notification service
      await NotificationService.sendBirthdayWish(
        senderId: widget.userId,
        senderName: senderName,
        recipientId: recipientId,
        recipientName: recipientName,
        communityId: widget.communityId,
      );

      final today = DateTime.now();
final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

// Save to Firestore
await FirebaseFirestore.instance
    .collection('birthday_wishes')
    .add({
  'senderId': widget.userId,
  'recipientId': recipientId,
  'date': todayString,
  'timestamp': FieldValue.serverTimestamp(),
  'communityId': widget.communityId,
});

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Birthday wish sent to $recipientName!',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
       setState(() {
  _sentWishes.add(recipientId);
});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to send birthday wish',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
            ),
          ),
        );
      }
    }
  }

Future<void> _loadSentWishes() async {
  try {
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final wishesQuery = await FirebaseFirestore.instance
        .collection('birthday_wishes')
        .where('senderId', isEqualTo: widget.userId)
        .where('date', isEqualTo: todayString)
        .get();
    
    setState(() {
      _sentWishes.clear();
      _sentWishes.addAll(
        wishesQuery.docs.map((doc) => doc.data()['recipientId'] as String)
      );
    });
  } catch (e) {
    print('Error loading sent wishes: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
  value: const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D1B2A),
    systemNavigationBarIconBrightness: Brightness.light,
  ),
  child: Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      const Color(0xFF1B263B),
      const Color(0xFF1B263B),
      const Color(0xFF0D1B2A),
      const Color(0xFF041426),
      Colors.black,
    ],
    stops: [0.0, 0.1, 0.4, 0.7, 1.0],
  ),
),
        child: Stack(
          children: [
            // Cute decorative elements
            _buildDecorations(screenWidth, isTablet),
        Column(
  children: [
    _buildHeader(screenWidth, isTablet),
    Expanded(
      child: _buildContent(screenWidth, isTablet),
    ),
  ],
),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildDecorations(double screenWidth, bool isTablet) {
    return Stack(
      children: [
        // Top right confetti
        Positioned(
          top: 100,
          right: 30,
          child: Opacity(
            opacity: 0.1,
            child: Transform.rotate(
              angle: 0.2,
              child: Text(
                '🎉',
                style: TextStyle(
                  fontSize: isTablet ? 32 : 24,
                ),
              ),
            ),
          ),
        ),
        // Top left cake
        Positioned(
          top: 150,
          left: 20,
          child: Opacity(
            opacity: 0.08,
            child: Transform.rotate(
              angle: -0.1,
              child: Text(
                '🎂',
                style: TextStyle(
                  fontSize: isTablet ? 28 : 20,
                ),
              ),
            ),
          ),
        ),
        // Middle right balloons
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          right: 15,
          child: Opacity(
            opacity: 0.06,
            child: Transform.rotate(
              angle: 0.15,
              child: Text(
                '🎈',
                style: TextStyle(
                  fontSize: isTablet ? 26 : 18,
                ),
              ),
            ),
          ),
        ),
        // Middle left present
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: 25,
          child: Opacity(
            opacity: 0.07,
            child: Transform.rotate(
              angle: -0.2,
              child: Text(
                '🎁',
                style: TextStyle(
                  fontSize: isTablet ? 24 : 16,
                ),
              ),
            ),
          ),
        ),
        // Bottom right party hat
        Positioned(
          bottom: 200,
          right: 40,
          child: Opacity(
            opacity: 0.05,
            child: Transform.rotate(
              angle: 0.3,
              child: Text(
                '🎪',
                style: TextStyle(
                  fontSize: isTablet ? 22 : 14,
                ),
              ),
            ),
          ),
        ),
        // Bottom left birthday cake slice
        Positioned(
          bottom: 150,
          left: 35,
          child: Opacity(
            opacity: 0.06,
            child: Transform.rotate(
              angle: -0.15,
              child: Text(
                '🍰',
                style: TextStyle(
                  fontSize: isTablet ? 20 : 16,
                ),
              ),
            ),
          ),
        ),
        // Subtle watermark in center-bottom
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Center(
            child: Opacity(
              opacity: 0.03,
              child: Text(
                'birthdays',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 48 : 36,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(double screenWidth, bool isTablet) {
    final isCompact = screenWidth < 350;

    return Container(
      padding: EdgeInsets.fromLTRB(
  isTablet ? 24 : (isCompact ? 16 : 20),
  MediaQuery.of(context).padding.top + (isTablet ? 24 : (isCompact ? 16 : 20)),
  isTablet ? 24 : (isCompact ? 16 : 20),
  isTablet ? 20 : (isCompact ? 12 : 16),
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
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 10 : (isCompact ? 8 : 8)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                border: Border.all(
                  color: const Color(0xFF64B5F6).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: isTablet ? 22 : (isCompact ? 18 : 18),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 15),
            padding: EdgeInsets.all(isTablet ? 16 : (isCompact ? 10 : 12)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1B263B), const Color(0xFF0D1B2A)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1B263B).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.cake,
              color: Colors.white,
              size: isTablet ? 28 : (isCompact ? 20 : 24),
            ),
          ),
          SizedBox(width: isTablet ? 20 : (isCompact ? 12 : 16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [const Color(0xFF64B5F6), const Color(0xFF1976D2)],
                  ).createShader(bounds),
                  child: Text(
                    'birthdays today',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: isTablet ? 28 : (isCompact ? 18 : 22),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  todaysBirthdays.isNotEmpty
                      ? 'celebrate together'
                      : 'none today',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 14 : (isCompact ? 10 : 12),
                    color: const Color(0xFF64B5F6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: const Color(0xFF64B5F6),
              size: isTablet ? 28 : (isCompact ? 20 : 24),
            ),
            onPressed: _loadTodaysBirthdays,
          ),
        ],
      ),
    );
  }

  Widget _buildContent(double screenWidth, bool isTablet) {
    final isCompact = screenWidth < 350;

    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: const Color(0xFF64B5F6),
          strokeWidth: isTablet ? 4 : 3,
        ),
      );
    }

    if (todaysBirthdays.isEmpty) {
      return _buildEmptyState(screenWidth, isTablet);
    }

    return RefreshIndicator(
      onRefresh: _loadTodaysBirthdays,
      color: const Color(0xFF64B5F6),
      backgroundColor: const Color(0xFF1B263B),
      child: ListView.builder(
        padding: EdgeInsets.all(isTablet ? 20 : (isCompact ? 12 : 16)),
        itemCount: todaysBirthdays.length,
        itemBuilder: (context, index) {
          final birthday = todaysBirthdays[index];
          return _buildBirthdayCard(birthday, screenWidth, isTablet);
        },
      ),
    );
  }

  Widget _buildEmptyState(double screenWidth, bool isTablet) {
    final isCompact = screenWidth < 350;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cake_outlined,
            color: const Color(0xFF64B5F6),
            size: isTablet ? 72 : (isCompact ? 48 : 64),
          ),
          SizedBox(height: isTablet ? 20 : (isCompact ? 12 : 16)),
          Text(
            'No birthdays today',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 20 : (isCompact ? 16 : 18),
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isTablet ? 8 : 4),
          Text(
            'But there might be some tomorrow!\nStay tuned for upcoming celebrations.',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
              color: Colors.white60,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBirthdayCard(Map<String, dynamic> birthday, double screenWidth, bool isTablet) {
    final isCurrentUser = birthday['userId'] == widget.userId;
    final isCompact = screenWidth < 350;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : (isCompact ? 12 : 16)),
      padding: EdgeInsets.all(isTablet ? 24 : (isCompact ? 16 : 20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1B263B).withOpacity(0.2),
            const Color(0xFF0D1B2A).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: isCurrentUser
              ? const Color(0xFF64B5F6).withOpacity(0.3)
              : const Color(0xFF1B263B).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: isTablet ? 12 : (isCompact ? 6 : 8),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with user info
          FutureBuilder<Map<String, dynamic>?>(
            future: _getUserData(birthday['username'] ?? ''),
            builder: (context, snapshot) {
              final userData = snapshot.data;
              final firstName = userData?['firstName'] ?? '';
              final lastName = userData?['lastName'] ?? '';
              final branch = userData?['branch'] ?? '';
              final year = userData?['year'] ?? '';
              final profileImageUrl = userData?['profileImageUrl'];

              return _buildUserHeader(
                birthday, firstName, lastName, branch, year, profileImageUrl, 
                screenWidth, isTablet, isCurrentUser
              );
            },
          ),

          SizedBox(height: isTablet ? 20 : (isCompact ? 12 : 16)),

          // Birthday info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isTablet ? 16 : (isCompact ? 12 : 14)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.08),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1B263B).withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                // Cute little decoration in corner
                Positioned(
                  top: 0,
                  right: 0,
                  child: Opacity(
                    opacity: 0.15,
                    child: Text(
                      '🎈',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : (isCompact ? 14 : 16),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.cake,
                      color: const Color(0xFF64B5F6),
                      size: isTablet ? 24 : (isCompact ? 18 : 20),
                    ),
                    SizedBox(width: isTablet ? 12 : (isCompact ? 8 : 10)),
                    Expanded(
                      child: Text(
                        'Turns ${birthday['age']} today! 🎉',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 18 : (isCompact ? 14 : 16),
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

 if (!isCurrentUser) ...[
  SizedBox(height: isTablet ? 20 : (isCompact ? 12 : 16)),
  SizedBox(
    width: double.infinity,
    height: isTablet ? 52 : (isCompact ? 44 : 48),
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _sentWishes.contains(birthday['userId'])
              ? [Colors.green.shade600, Colors.green.shade700]
              : [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _sentWishes.contains(birthday['userId'])
                ? Colors.green.withOpacity(0.3)
                : const Color(0xFF1976D2).withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _sentWishes.contains(birthday['userId'])
            ? null
            : () => _sendBirthdayWish(
                birthday['userId'],
                birthday['firstName'],
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              right: 15,
              child: Opacity(
                opacity: 0.3,
                child: Text(
                  _sentWishes.contains(birthday['userId']) ? '✅' : '✨',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _sentWishes.contains(birthday['userId']) ? Icons.check : Icons.cake,
                  size: isTablet ? 22 : (isCompact ? 18 : 20),
                  color: Colors.white,
                ),
                SizedBox(width: isTablet ? 10 : (isCompact ? 6 : 8)),
                Text(
                  _sentWishes.contains(birthday['userId'])
                      ? 'Wish Sent!'
                      : 'Send Birthday Wish',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : (isCompact ? 13 : 14),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
]else ...[
            SizedBox(height: isTablet ? 16 : (isCompact ? 10 : 12)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : (isCompact ? 12 : 14),
                vertical: isTablet ? 12 : (isCompact ? 8 : 10),
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cute decoration
                  Positioned(
                    right: 10,
                    child: Opacity(
                      opacity: 0.2,
                      child: Text(
                        '🎂',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : (isCompact ? 14 : 16),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: isTablet ? 20 : (isCompact ? 16 : 18),
                      ),
                      SizedBox(width: isTablet ? 8 : (isCompact ? 6 : 6)),
                      Text(
                        'It\'s your birthday! 🎂',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 16 : (isCompact ? 13 : 14),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserHeader(
    Map<String, dynamic> birthday,
    String firstName, 
    String lastName, 
    String branch, 
    String year, 
    String? profileImageUrl,
    double screenWidth,
    bool isTablet,
    bool isCurrentUser,
  ) {
    final isCompact = screenWidth < 350;

    return Column(
      children: [
        GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          username: birthday['username'] ?? '',
          communityId: widget.communityId,
        ),
      ),
    );
  },
        child:Row(
          children: [
            FutureBuilder<String?>(
              future: _getUserProfileImage(birthday['username'] ?? ''),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return CircleAvatar(
                    radius: isTablet ? 28 : (isCompact ? 20 : 24),
                    backgroundImage: NetworkImage(snapshot.data!),
                    backgroundColor: const Color(0xFF64B5F6),
                    onBackgroundImageError: (exception, stackTrace) {
                      // Handle image load error - will show fallback
                    },
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? SizedBox(
                            width: isTablet ? 20 : (isCompact ? 14 : 16),
                            height: isTablet ? 20 : (isCompact ? 14 : 16),
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : null,
                  );
                } else {
                  return CircleAvatar(
                    radius: isTablet ? 28 : (isCompact ? 20 : 24),
                    backgroundColor: const Color(0xFF64B5F6),
                    child: Text(
                      birthday['username']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: isTablet ? 18 : (isCompact ? 14 : 16),
                      ),
                    ),
                  );
                }
              },
            ),
            SizedBox(width: isTablet ? 16 : (isCompact ? 10 : 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$firstName $lastName'.trim().isNotEmpty 
                              ? '$firstName $lastName'.trim()
                              : birthday['username'] ?? 'Unknown',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            fontSize: isTablet ? 20 : (isCompact ? 15 : 17),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : (isCompact ? 6 : 7),
                            vertical: isTablet ? 4 : (isCompact ? 2 : 3),
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.amber, Colors.orange],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'YOU',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 12 : (isCompact ? 8 : 10),
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (firstName.isNotEmpty && lastName.isNotEmpty) ...[
                    SizedBox(height: isTablet ? 4 : 2),
                    Text(
                      '@${birthday['username'] ?? 'Unknown'}',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: isTablet ? 14 : (isCompact ? 11 : 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        )
    ),
        if (branch.isNotEmpty || year.isNotEmpty) ...[
          SizedBox(height: isTablet ? 12 : (isCompact ? 6 : 8)),
          Row(
            children: [
              SizedBox(width: isTablet ? 72 : (isCompact ? 52 : 60)), // Avatar width + spacing
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (branch.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF1976D2), const Color(0xFF64B5F6)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school, 
                              color: Colors.white, 
                              size: isTablet ? 12 : (isCompact ? 9 : 10)
                            ),
                            SizedBox(width: isTablet ? 4 : 3),
                            Text(
                              branch,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 11 : (isCompact ? 8 : 9),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (year.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF1565C0), const Color(0xFF1976D2)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today, 
                              color: Colors.white, 
                              size: isTablet ? 12 : (isCompact ? 9 : 10)
                            ),
                            SizedBox(width: isTablet ? 4 : 3),
                            Text(
                              year,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 11 : (isCompact ? 8 : 9),
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
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
        ],
      ],
    );
  }
}