import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/community_dashboard.dart';
import 'package:startup/home_components/community_selection_widget.dart';
import 'package:startup/home_components/create_community_screen.dart';
import 'package:startup/searchpageoutlets.dart';
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

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  String firstName = '';
  String lastName = '';
  String username = '';
  String uid = '';
  String email = '';

  // Community related variables
  String? userCommunityId;
  String? userCommunityRole;
  bool isLoadingCommunity = true;

  bool isDrawerOpen = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> searchOptions = ['experiences', 'turfs', 'games'];
  int _currentSearchIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool isIconTapped = false;
  StreamSubscription<QuerySnapshot>? _communityRequestsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToApprovedRequests();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _scaleAnimation = Tween<double>(begin: 1, end: 0.85).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0.6, 0)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(const Duration(seconds: 2), _startSearchScrollLoop);
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
    _controller.dispose();
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
    
    // Check community status
    await _checkCommunityStatus();
    setState(() {});
  }

  Future<void> _checkCommunityStatus() async {
    try {
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
          break; // Found user, exit loop
        }
      }
      
      // Update the global variables
      userCommunityId = foundCommunityId;
      userCommunityRole = foundRole;
      
    } catch (e) {
      print('Error checking community status: $e');
    }
    
    setState(() {
      isLoadingCommunity = false;
    });
  }

  void _startSearchScrollLoop() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return false;
      setState(() {
        _currentSearchIndex = (_currentSearchIndex + 1) % searchOptions.length;
      });
      return true;
    });
  }

  void toggleDrawer() {
    setState(() {
      isDrawerOpen = !isDrawerOpen;
      isDrawerOpen ? _controller.forward() : _controller.reverse();
    });
  }

  Widget buildDrawer() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
           Colors.transparent,
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.only(top: 100, left: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFF7B42C), Color(0xFFFFE066)],
            ).createShader(bounds),
            child: Text(
              '$firstName $lastName',
              style: GoogleFonts.poppins(
                fontSize: 26,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 50,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFF7B42C), Color(0xFFFFE066)]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 40),
          drawerItem(Icons.person_outline, 'Profile'),
          drawerItem(Icons.description_outlined, 'Terms & Conditions'),
          drawerItem(Icons.help_outline_rounded, 'FAQs'),
          drawerItem(Icons.privacy_tip_outlined, 'Privacy Policy'),
          drawerItem(Icons.logout_rounded, 'Logout'),
        ],
      ),
    );
  }

  Widget drawerItem(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFF7B42C), size: 20),
          ),
          const SizedBox(width: 15),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF7B42C).withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
          cursorColor: const Color(0xFFF7B42C),
          showCursor: !isDrawerOpen,
          onTap: () {
            setState(() => isIconTapped = true);
            Future.delayed(const Duration(milliseconds: 300), () => setState(() => isIconTapped = false));
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            prefixIcon: AnimatedScale(
              scale: isIconTapped || _focusNode.hasFocus ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.search_rounded, color: Color(0xFFF7B42C), size: 22),
            ),
            hintStyle: GoogleFonts.poppins(color: Colors.white60, fontSize: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF7B42C), width: 2),
            ),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('search ', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w400)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return SlideTransition(
                      position: Tween<Offset>(begin: const Offset(0, 0.6), end: Offset.zero)
                          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: SizedBox(
                    key: ValueKey(_currentSearchIndex),
                    width: 160,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Shimmer.fromColors(
                        baseColor: const Color(0xFFF7B42C),
                        highlightColor: const Color(0xFFFFE066),
                        child: Text(
                          searchOptions[_currentSearchIndex],
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFF7B42C),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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

  // Community Creation Widget
  Widget _buildCommunitySelectionWithCreate() {
    return SingleChildScrollView(
      child: Column(
        children: [
          CommunitySelectionWidget(
            userId: uid,
            username: username,
            onCommunityJoined: _checkCommunityStatus,
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFF7B42C).withOpacity(0.1),
                  const Color(0xFFFFE066).withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
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
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Create Your Own Community',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a new community and invite others to join',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Create Community',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String initial = (firstName.isNotEmpty) ? firstName[0].toUpperCase() : 'G';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          buildDrawer(),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: _slideAnimation.value * MediaQuery.of(context).size.width,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isDrawerOpen ? 30 : 0),
                    child: GestureDetector(
                      onTap: () {
                        if (isDrawerOpen) toggleDrawer();
                      },
                      child: Scaffold(
                        backgroundColor: Colors.black,
                        body: Stack(
                          children: [
                            _buildGradientBackground(),
                            SafeArea(
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        GestureDetector(
                                          onTap: toggleDrawer,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                                              ),
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFF7B42C).withOpacity(0.4),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              backgroundColor: Colors.transparent,
                                              child: Text(
                                                initial,
                                                style: GoogleFonts.poppins(
                                                  color: Colors.black87,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                          ),
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
                                            style: GoogleFonts.poppins(fontSize: 25, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        const SizedBox(width: 50),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => Searchpageoutlets()),
                                      );
                                    },
                                    child: AbsorbPointer(child: buildSearchBar()),
                                  ),
                                  const SizedBox(height: 20),
                                  // COMMUNITY CONTENT WITH CREATE OPTION
                                  Expanded(
                                    child: isLoadingCommunity 
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFF7B42C),
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
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}