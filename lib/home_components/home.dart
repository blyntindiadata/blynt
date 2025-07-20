import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/events/category_selection.dart';
import 'package:startup/home_tabs/category_tabs.dart';
import 'package:startup/home_tabs/for_you.dart';
import 'package:startup/searchpageoutlets.dart';
import 'bottom_nav_bar.dart';

class Home extends StatefulWidget {
  final String? firstName;
  final String? lastName;
  final String uid;
  final String username;

  const Home({super.key, this.firstName, this.lastName, required this.username, required this.uid});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  String firstName = '';
  String lastName = '';
  String? address;
  String username = '';
  String uid = '';

  bool isDrawerOpen = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> searchOptions = ['experiences', 'turfs', 'games'];
  int _currentSearchIndex = 0;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool isIconTapped = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _scaleAnimation = Tween<double>(begin: 1, end: 0.85).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: Offset.zero, end: const Offset(0.6, 0)).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future.delayed(const Duration(seconds: 2), _startSearchScrollLoop);
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    username = widget.username;
    uid = widget.uid;

    String? cachedFirstName = prefs.getString('firstName');
    String? cachedLastName = prefs.getString('lastName');
    String? cachedAddress = prefs.getString('address');

    if (cachedFirstName != null && cachedLastName != null && cachedAddress != null) {
      firstName = cachedFirstName;
      lastName = cachedLastName;
      address = cachedAddress;
    } else {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        firstName = (data['firstName'] != null && data['firstName'].toString().trim().isNotEmpty)
            ? data['firstName'] : 'User';
        lastName = data['lastName'] ?? '';
        address = data['address'] ?? 'Location not set';

        await prefs.setString('firstName', firstName);
        await prefs.setString('lastName', lastName);
        // await prefs.setString('address', address);
      } else {
        firstName = 'Guest';
        lastName = '';
        address = 'Location not set';
      }
    }
    setState(() {});
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

  Future<List<String>> fetchSlideImages() async {
    List<String> images = [];
    for (int i = 1; i <= 6; i++) {
      final doc = await FirebaseFirestore.instance.collection('sponsors').doc('slide $i').get();
      if (doc.exists && doc.data()?['image'] != null) {
        images.add(doc['image']);
      }
    }
    return images;
  }

 Widget _buildGradientBackground() {
  return Container(
    height: 820,
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

Widget _buildSectionHeader(String text) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1F1509),
                Color(0xFF332414),
                Color(0xFF473420),
                Color(0xFF5C432C),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Color(0xFFFFD700).withOpacity(0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFFD700).withOpacity(0.25),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
              BoxShadow(
                color: Color(0xFFDBA901).withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 1,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 14,
              letterSpacing: 1.5,
              color: Color(0xFFDAA520),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
Widget _buildDot(double size) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF8008), Color(0xFFFFA726)],
      ),
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF8008).withOpacity(0.4),
          blurRadius: 4,
        ),
      ],
    ),
  );
}
Widget _buildEnhancedTabBar() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      // Darker, richer background for better contrast with gold
      color: const Color(0xFF1A1A1A),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        // Outer shadow (dark)
        BoxShadow(
          color: Colors.black.withOpacity(0.4),
          blurRadius: 15,
          offset: const Offset(8, 8),
        ),
        // Outer highlight (light)
        BoxShadow(
          color: const Color(0xFF333333).withOpacity(0.8),
          blurRadius: 15,
          offset: const Offset(-8, -8),
        ),
      ],
    ),
    child: TabBar(
      dividerColor: Colors.transparent,
      isScrollable: true,
      padding: EdgeInsets.zero,
      indicatorSize: TabBarIndicatorSize.label,
      indicatorPadding: const EdgeInsets.all(2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12),
      tabAlignment: TabAlignment.start,
      indicator: BoxDecoration(
        // Golden gradient background
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700), // Gold
            Color(0xFFB8860B), // Dark goldenrod
            Color(0xFFDAA520), // Goldenrod
            Color(0xFFFFD700), // Gold
          ],
          stops: [0.0, 0.3, 0.7, 1.0],
        ),
        borderRadius: BorderRadius.circular(25), // Increased border radius
        boxShadow: [
          // Very soft outer golden glow - largest
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 0),
            spreadRadius: -5,
          ),
          // Medium golden glow
          BoxShadow(
            color: const Color(0xFFDAA520).withOpacity(0.12),
            blurRadius: 25,
            offset: const Offset(0, 0),
            spreadRadius: -3,
          ),
          // Inner golden glow
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 0),
            spreadRadius: -2,
          ),
          // Subtle depth shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(1, 1),
            spreadRadius: -1,
          ),
        ],
      ),
      labelColor: Colors.black, // Dark text for golden background
      unselectedLabelColor: const Color(0xFF9E9E9E),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
      unselectedLabelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
      overlayColor: WidgetStateProperty.all(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      tabs: [
        _buildTab('for you'),
        _buildTab('cafe'),
        _buildTab('sports'),
        _buildTab('games'),
        _buildTab('spaces'),
        _buildTab('more'),
      ],
    ),
  );
}

Widget _buildTab(String text) {
  return Tab(
    child: Container(
      // Fixed width for consistent background sizing
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
      ),
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
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 20),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF7B42C).withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(Icons.location_on_rounded,
                                                      color: Color(0xFFF7B42C), size: 18),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    address ?? "Fetching location...",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 15,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w500,
                                                      letterSpacing: 0.3,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Center(child: _buildSectionHeader('FEATURED', ),),
                                          const SizedBox(height: 10),
                                          FutureBuilder<List<String>>(
                                            future: fetchSlideImages(),
                                            builder: (context, snapshot) {
                                              if (!snapshot.hasData) {
                                                return SizedBox(
                                                  height: 220,
                                                  child: Center(
                                                    child: CircularProgressIndicator(color: Color(0xFFF7B42C)),
                                                  ),
                                                );
                                              }
                                              return CarouselSliderWidget(imageUrl: snapshot.data!);
                                            },
                                          ),
                                          const SizedBox(height: 50),
                                          Center(
                                            child: Center(child: _buildSectionHeader('ALL VENUES', ),),
                                          ),
                                          const SizedBox(height: 25),
                                          DefaultTabController(
                                            length: 6,
                                            child: Column(
                                              children: [
                                                _buildEnhancedTabBar(),
                                                const SizedBox(height: 25),
                                                SizedBox(
                                                  height: 400,
                                                  child: TabBarView(
                                                    children: [
                                                      ForYouTab(),
                                                      CategoryTabContent(category: 'cafe'),
                                                      CategoryTabContent(category: 'sports'),
                                                      CategoryTabContent(category: 'games'),
                                                      CategoryTabContent(category: 'spaces'),
                                                      CategoryTabContent(category: 'cafes'),
                                                    ],
                                                  ),
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

class EnhancedSemiCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.5),
        radius: 1.5,
        colors: [
          const Color(0xFF2A1810).withOpacity(0.8),
          const Color(0xFF3D2914).withOpacity(0.6),
          const Color(0xFF4A3218).withOpacity(0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
      
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height * 0.75);
    
    path.quadraticBezierTo(
      size.width * 0.75, size.height * 1.1,
      size.width / 2, size.height * 0.9
    );
    
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.7,
      0, size.height * 0.75
    );
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Carousel widget with enhanced styling
class CarouselSliderWidget extends StatefulWidget {
  final List<String> imageUrl;
  const CarouselSliderWidget({super.key, required this.imageUrl});

  @override
  State<CarouselSliderWidget> createState() => _CarouselSliderWidgetState();
}

class _CarouselSliderWidgetState extends State<CarouselSliderWidget> {
  late PageController _pageController;
  int _currentPage = 1;
  Timer? _timer;
  List<Map<String, String>> slides = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.8, initialPage: 1);
    fetchSlidesFromFirestore();
  }

  Future<void> fetchSlidesFromFirestore() async {
    List<Map<String, String>> fetchedSlides = [];
    for (int i = 1; i <= 6; i++) {
      final doc = await FirebaseFirestore.instance.collection('sponsors').doc('slide $i').get();
      if (doc.exists) {
        final data = doc.data()!;
        final image = data['image'] ?? '';
        final title = data['title'] ?? 'Place $i';
        final tag = data['tag'] ?? 'Featured';

        if (image.isNotEmpty) {
          fetchedSlides.add({'image': image, 'title': title, 'tag': tag});
        }
      }
    }

    if (mounted) {
      setState(() {
        slides = [fetchedSlides.last, ...fetchedSlides, fetchedSlides.first];
      });
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_pageController.hasClients && slides.length > 2) {
        int nextPage = _currentPage + 1;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  LinearGradient _getTagGradient(String tag) {
    switch (tag.toLowerCase()) {
      case 'trending':
        return const LinearGradient(colors: [Colors.red, Color(0xFFA61D13)]);
      case 'highly visited':
        return const LinearGradient(colors: [Color(0xFFF36721), Color(0xFFB56A3F)]);
      case 'our choice':
        return const LinearGradient(colors: [Colors.green, Colors.teal]);
      case 'hot pick':
        return const LinearGradient(colors: [Colors.orange, Colors.yellow]);
      case 'new':
        return const LinearGradient(colors: [Colors.pink, Colors.redAccent]);
      case 'on the top':
        return const LinearGradient(colors: [Colors.purple, Colors.deepPurple]);
      default:
        return const LinearGradient(colors: [Color(0xFFF7B42C), Color(0xFFFFD700)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (slides.length <= 2) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: Color(0xFFF7B42C))),
      );
    }

    return SizedBox(
      height: 320,
      child: PageView.builder(
        controller: _pageController,
        itemCount: slides.length,
        onPageChanged: (index) {
          setState(() => _currentPage = index);
          if (index == slides.length - 1) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _pageController.jumpToPage(1);
              setState(() => _currentPage = 1);
            });
          } else if (index == 0) {
            Future.delayed(const Duration(milliseconds: 300), () {
              _pageController.jumpToPage(slides.length - 2);
              setState(() => _currentPage = slides.length - 2);
            });
          }
        },
        itemBuilder: (context, index) {
          final slide = slides[index];
          final imageUrl = slide['image']!;
          final title = slide['title']!;
          final tag = slide['tag']!;
          final isCenter = index == _currentPage;

          return AnimatedOpacity(
            duration: const Duration(milliseconds: 400),
            opacity: isCenter ? 1.0 : 0.5,
            child: Transform.scale(
              scale: isCenter ? 1.0 : 0.9,
              child: _buildCard(imageUrl, title, tag),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(String imageUrl, String title, String tag) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF3B2F2F), Color(0xFF1E1A18)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: Colors.amber,
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent,
              blurRadius: 8,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(height: 180, color: Colors.grey[900]),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: _getTagGradient(tag),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}