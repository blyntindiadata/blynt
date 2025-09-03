import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class DoubtsPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const DoubtsPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  }) : super(key: key);

  @override
  State<DoubtsPage> createState() => _DoubtsPageState();
}

class _DoubtsPageState extends State<DoubtsPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _selectedFilter = 'recent';
  String _selectedYear = 'all';
  String _selectedBranch = 'all';
  
  Map<String, dynamic>? _userProfile;
  List<String> _availableYears = ['all'];
  List<String> _availableBranches = ['all'];
  
@override
void initState() {
  super.initState();
  _tabController = TabController(length: 2, vsync: this);
  _initAnimations();
  _loadUserProfile();
  _loadFilterOptions();
  _loadDoubtsOnce();
}

// Add these new properties at the top of the class
final ValueNotifier<List<Map<String, dynamic>>> _allDoubtsNotifier = ValueNotifier([]);
final ValueNotifier<bool> _isInitialLoadingNotifier = ValueNotifier(true);

  void _dismissKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
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
  _searchController.dispose();
  _searchFocusNode.dispose();
  _tabController.dispose();
  _fadeController.dispose();
  super.dispose();
}

  // Helper methods for responsive design
  // Helper methods for responsive design

// Responsive breakpoints
static const double mobileBreakpoint = 600;
static const double tabletBreakpoint = 900;
static const double desktopBreakpoint = 1200;

// Helper methods for responsive design
bool get isMobile => MediaQuery.of(context).size.width < mobileBreakpoint;
bool get isTablet => MediaQuery.of(context).size.width >= mobileBreakpoint && 
                   MediaQuery.of(context).size.width < tabletBreakpoint;
bool get isDesktop => MediaQuery.of(context).size.width >= tabletBreakpoint;

double get screenWidth => MediaQuery.of(context).size.width;
double get screenHeight => MediaQuery.of(context).size.height;

EdgeInsets get responsivePadding {
  final width = screenWidth;
  final height = screenHeight;
  
  // Consider both width and height for better mobile responsiveness
  if (width < 360 || height < 640) return const EdgeInsets.all(8);
  if (width < 400) return const EdgeInsets.all(12);
  if (width < mobileBreakpoint) return const EdgeInsets.all(16);
  if (width < tabletBreakpoint) return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  if (width < desktopBreakpoint) return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
  return const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
}

double get responsiveFontSize {
  final width = screenWidth;
  final pixelRatio = MediaQuery.of(context).devicePixelRatio;
  
  // Adjust for high-density screens
  double baseScale = 1.0;
  if (pixelRatio > 2.5) baseScale = 0.9;
  
  if (width < 360) return 0.8 * baseScale;
  if (width < 400) return 0.9 * baseScale;
  if (width < mobileBreakpoint) return 1.0 * baseScale;
  if (width < tabletBreakpoint) return 1.1 * baseScale;
  if (width < desktopBreakpoint) return 1.2 * baseScale;
  return 1.3 * baseScale;
}

double get responsiveIconSize {
 final width = screenWidth;
 final pixelRatio = MediaQuery.of(context).devicePixelRatio;
 
 // Adjust for high-density screens
 double baseScale = 1.0;
 if (pixelRatio > 2.5) baseScale = 0.95;
 
 if (width < 360) return 0.8 * baseScale;
 if (width < 400) return 0.9 * baseScale;
 if (width < mobileBreakpoint) return 1.0 * baseScale;
 if (width < tabletBreakpoint) return 1.1 * baseScale;
 return 1.2 * baseScale;
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
    }
  }

  // LOAD DOUBTS ONLY ONCE - NO RELOADING
Future<void> _loadDoubtsOnce() async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('doubts')
        .orderBy('createdAt', descending: true)
        .get();

    final doubts = <Map<String, dynamic>>[];
    
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final doubtData = {
        'id': doc.id,
        ...data,
      };
      doubts.add(doubtData);
    }

    _allDoubtsNotifier.value = doubts;
  } catch (e) {
    print('Error loading doubts: $e');
  } finally {
    _isInitialLoadingNotifier.value = false;
  }
}

// GET FILTERED DOUBTS - NO DATABASE CALLS
List<Map<String, dynamic>> _getFilteredDoubts(List<Map<String, dynamic>> allDoubts) {
  return allDoubts.where((doubt) {
    // Apply visibility filters
    if (!_canUserSeeDoubt(doubt)) return false;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final question = (doubt['question'] ?? '').toString().toLowerCase();
      final tags = (doubt['tags'] as List<dynamic>?)
          ?.map((tag) => tag.toString().toLowerCase()).toList() ?? [];
      
      if (!question.contains(_searchQuery) && 
          !tags.any((tag) => tag.contains(_searchQuery))) {
        return false;
      }
    }
    
    // Apply year filter
    if (_selectedYear != 'all') {
      final doubtYear = doubt['authorYear']?.toString();
      if (doubtYear != _selectedYear) return false;
    }
    
    // Apply branch filter
    if (_selectedBranch != 'all') {
      final doubtBranch = doubt['authorBranch']?.toString();
      if (doubtBranch != _selectedBranch) return false;
    }
    
    return true;
  }).toList();
}

// ADD NEW DOUBT TO LIST - NO RELOAD
void _addDoubtToList(String doubtId, Map<String, dynamic> doubtData) {
  final newDoubt = {
    'id': doubtId,
    ...doubtData,
    'createdAt': Timestamp.now(),
    'answersCount': 0,
  };

  final currentDoubts = List<Map<String, dynamic>>.from(_allDoubtsNotifier.value);
  currentDoubts.insert(0, newDoubt);
  _allDoubtsNotifier.value = currentDoubts;
}

// UPDATE ANSWER COUNT - NO RELOAD
void _updateAnswerCount(String doubtId, int increment) {
  final currentDoubts = List<Map<String, dynamic>>.from(_allDoubtsNotifier.value);
  final doubtIndex = currentDoubts.indexWhere((doubt) => doubt['id'] == doubtId);
  
  if (doubtIndex != -1) {
    currentDoubts[doubtIndex]['answersCount'] = 
        (currentDoubts[doubtIndex]['answersCount'] ?? 0) + increment;
    _allDoubtsNotifier.value = currentDoubts;
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
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  }

@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: _dismissKeyboard,
    behavior: HitTestBehavior.opaque,
    child: Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              const Color(0xFF0F0F23),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildTabBarView(),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedSlide(
        duration: Duration(milliseconds: 200),
        offset: MediaQuery.of(context).viewInsets.bottom > 0 ? Offset(0, 2) : Offset.zero,
        child: _buildCreateFAB(),
      ),
    ),
  );
}

Widget _buildHeader() {
  return Container(
    padding: responsivePadding,
    // decoration: BoxDecoration(
    //   gradient: LinearGradient(
    //     begin: Alignment.topLeft,
    //     end: Alignment.bottomRight,
    //     colors: [
    //       const Color(0xFF1A1A2E).withOpacity(0.3),
    //       Colors.transparent,
    //     ],
    //   ),
    // ),
    child: Column(
      children: [
        Row(
          children: [
            // UPDATED BACK BUTTON - SAME STYLE AS COMMENTS PAGE BUT DOUBTS COLORS
            GestureDetector(
              onTap: () {
                _dismissKeyboard();
                Navigator.pop(context);
              },
              child: Container(
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 14),
                  border: Border.all(
                    color: const Color(0xFF9CA3AF).withOpacity(0.3), // DOUBTS THEME COLOR
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: isMobile ? 18 : 22,
                ),
              ),
            ),
            SizedBox(width: isMobile ? 16 : 20), // SPACING LIKE COMMENTS PAGE
            Container(
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF4A4A4A), const Color(0xFF2C2C2C)], // KEEP DOUBTS GRADIENT
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A4A4A).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.help_outline, 
                color: Colors.white, 
                size: isMobile ? 20 : 24
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [const Color(0xFF9CA3AF), const Color(0xFF6B7280)], // KEEP DOUBTS COLORS
                    ).createShader(bounds),
                    child: Text(
                      'chamber of confusions',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: (isMobile ? 20 : 24) * responsiveFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5
                      ),
                    ),
                  ),
                  Text(
                    'the most dreaded zone of blynt',
                    style: GoogleFonts.poppins(
                      fontSize: (isMobile ? 10 : 12) * responsiveFontSize,
                      color: const Color(0xFF9CA3AF), // KEEP DOUBTS COLORS
                    ),
                  ),
                ],
              ),
            ),
            // REMOVE THE OLD REFRESH BUTTON SINCE WE HAVE PULL TO REFRESH
          ],
        ),
        SizedBox(height: isMobile ? 12 : 16),
        _buildSearchBar(),
      ],
    ),
  );
}

Widget _buildSearchBar() {
  final height = isMobile ? 
    (screenHeight < 640 ? 36 : 40) : 
    (isTablet ? 42 : 45);
    
  return Container(
    height: isMobile ? 40 : 45,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(height / 2),
      border: Border.all(color: const Color(0xFF1A1A2E).withOpacity(0.3)),
    ),
    child: TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      enableInteractiveSelection: true,
      style: GoogleFonts.poppins(
        color: Colors.white, 
        fontSize: (isMobile ? 12 : 14) * responsiveFontSize
      ),
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: 'search...',
        hintStyle: GoogleFonts.poppins(
          color: Colors.white38,
          fontSize: (isMobile ? 12 : 14) * responsiveFontSize
        ), 
        prefixIcon: Icon(
          Icons.search, 
          color: const Color(0xFF9CA3AF), 
          size: (isMobile ? 18 : 20) * responsiveIconSize
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth < 360 ? 12 : (isMobile ? 16 : 20), 
          vertical: 0
        ),
        isDense: true,
      ),
      onChanged: (value) {
        if (mounted) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        }
      },
      onEditingComplete: () {
        _searchFocusNode.unfocus();
      },
      onTapOutside: (event) {
        _searchFocusNode.unfocus();
      },
    ),
  );
}
  Widget _buildTabBar() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 20, 
        vertical: isMobile ? 8 : 10
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF1A1A2E).withOpacity(0.3)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color.fromARGB(255, 55, 55, 55), const Color.fromARGB(255, 81, 86, 96)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: (isMobile ? 12 : 14) * responsiveFontSize
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          fontSize: (isMobile ? 12 : 14) * responsiveFontSize
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Browse'),
          Tab(text: 'Ask Doubt'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildDoubtsList(),
        _buildCreateDoubt(),
      ],
    );
  }

Widget _buildDoubtsList() {
  return Column(
    children: [
      _buildFilters(),
      Expanded(
        child: ValueListenableBuilder<bool>(
          valueListenable: _isInitialLoadingNotifier,
          builder: (context, isLoading, child) {
            if (isLoading) {
              return _buildDoubtsShimmer(); // SHIMMER ALREADY EXISTS
            }

            return ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _allDoubtsNotifier,
              builder: (context, allDoubts, child) {
                final filteredDoubts = _getFilteredDoubts(allDoubts);
                
                if (filteredDoubts.isEmpty) {
                  return _buildEmptyState();
                }

                // ADD SHIMMER FOR LOADING STATES
                return RefreshIndicator(
                  onRefresh: () async {
                    // Add shimmer during refresh
                    _isInitialLoadingNotifier.value = true;
                    await Future.delayed(Duration(milliseconds: 500));
                    await _loadDoubtsOnce();
                  },
                  backgroundColor: const Color(0xFF1A1A2E),
                  color: const Color(0xFF9CA3AF),
                  child: _buildResponsiveList(filteredDoubts.cast<Map<String, dynamic>>()),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

Widget _buildDoubtsShimmer() {
  return ListView.builder(
    padding: responsivePadding,
    itemCount: 5,
    itemBuilder: (context, index) {
      return Container(
        margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
        padding: EdgeInsets.all(isMobile ? 14 : 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(isMobile ? 16 : 20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Shimmer.fromColors(
          baseColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: isMobile ? 40 : 45,
                    height: isMobile ? 40 : 45,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: isMobile ? 10 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(height: 4),
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Container(
                height: 16,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(height: 4),
              Container(
                height: 16,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
Widget _buildResponsiveList(List<Map<String, dynamic>> doubts) {
  if (isDesktop && screenWidth > 1400) {
    // Large Desktop: 3-column grid
    return GridView.builder(
      padding: responsivePadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.1,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: doubts.length,
      itemBuilder: (context, index) => DoubtCard(
        doubt: doubts[index],
        doubtId: doubts[index]['id'],
        currentUsername: widget.username,
        userRole: widget.userRole,
        communityId: widget.communityId,
        userId: widget.userId,
        isCompact: false,
        onAnswerCountUpdate: _updateAnswerCount,
      ),
    );
  } else if (isDesktop) {
    // Desktop: 2-column grid
    return GridView.builder(
      padding: responsivePadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: doubts.length,
      itemBuilder: (context, index) => DoubtCard(
        doubt: doubts[index],
        doubtId: doubts[index]['id'],
        currentUsername: widget.username,
        userRole: widget.userRole,
        communityId: widget.communityId,
        userId: widget.userId,
        isCompact: false,
        onAnswerCountUpdate: _updateAnswerCount,
      ),
    );
  } else if (isTablet && screenWidth > 700) {
    // Large Tablet: 2-column grid
    return GridView.builder(
      padding: responsivePadding,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: doubts.length,
      itemBuilder: (context, index) => DoubtCard(
        doubt: doubts[index],
        doubtId: doubts[index]['id'],
        currentUsername: widget.username,
        userRole: widget.userRole,
        communityId: widget.communityId,
        userId: widget.userId,
        isCompact: true,
        onAnswerCountUpdate: _updateAnswerCount,
      ),
    );
  } else {
    // Mobile/Small Tablet: List layout
    return ListView.builder(
      padding: responsivePadding,
      physics: const BouncingScrollPhysics(),
      itemCount: doubts.length,
      itemBuilder: (context, index) => DoubtCard(
        doubt: doubts[index],
        doubtId: doubts[index]['id'],
        currentUsername: widget.username,
        userRole: widget.userRole,
        communityId: widget.communityId,
        userId: widget.userId,
        isCompact: isMobile || screenWidth < 500,
        onAnswerCountUpdate: _updateAnswerCount,
      ),
    );
  }
}

bool _canUserSeeDoubt(Map<String, dynamic> doubt) {
  // First check visibility permissions
  final visibility = doubt['visibility'] as Map<String, dynamic>?;
  if (visibility == null) return _applyFilters(doubt);
  
  final visibilityType = visibility['type'] as String?;
  if (visibilityType == 'everyone') return _applyFilters(doubt);
  
  final allowedYears = List<String>.from(visibility['allowedYears'] ?? []);
  final allowedBranches = List<String>.from(visibility['allowedBranches'] ?? []);
  
  final userYear = _userProfile?['year']?.toString();
  final userBranch = _userProfile?['branch']?.toString();
  
  bool hasVisibilityAccess = false;
  switch (visibilityType) {
    case 'year':
      hasVisibilityAccess = allowedYears.contains(userYear);
      break;
    case 'branch':
      hasVisibilityAccess = allowedBranches.contains(userBranch);
      break;
    case 'branch_year':
      hasVisibilityAccess = allowedYears.contains(userYear) && allowedBranches.contains(userBranch);
      break;
    default:
      hasVisibilityAccess = true;
  }
  
  return hasVisibilityAccess && _applyFilters(doubt);
}

bool _applyFilters(Map<String, dynamic> doubt) {
  // Apply year filter
  if (_selectedYear != 'all') {
    final doubtYear = doubt['authorYear']?.toString();
    if (doubtYear != _selectedYear) return false;
  }
  
  // Apply branch filter
  if (_selectedBranch != 'all') {
    final doubtBranch = doubt['authorBranch']?.toString();
    if (doubtBranch != _selectedBranch) return false;
  }
  
  return true;
}
  bool _matchesSearch(Map<String, dynamic> doubt) {
    if (_searchQuery.isEmpty) return true;
    
    final question = (doubt['question'] ?? '').toString().toLowerCase();
    final tags = (doubt['tags'] as List<dynamic>?)?.map((tag) => tag.toString().toLowerCase()).toList() ?? [];
    
    return question.contains(_searchQuery) ||
           tags.any((tag) => tag.contains(_searchQuery));
  }

// Stream<QuerySnapshot> _getDoubtsStream() {
//   Query query = FirebaseFirestore.instance
//       .collection('communities')
//       .doc(widget.communityId)
//       .collection('doubts')
//       .orderBy('createdAt', descending: true);

//   return query.snapshots();
// }
Widget _buildFilters() {
  return Container(
    margin: EdgeInsets.symmetric(
      horizontal: isMobile ? 8 : 12, 
      vertical: isMobile ? 4 : 6
    ),
    padding: EdgeInsets.symmetric(
      horizontal: isMobile ? 12 : 16, 
      vertical: isMobile ? 8 : 10
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.08),
          Colors.white.withOpacity(0.04),
        ],
      ),
      borderRadius: BorderRadius.circular(isMobile ? 10 : 14),
      border: Border.all(
        color: Colors.white.withOpacity(0.15),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.filter_list, 
          color: const Color(0xFF9CA3AF), 
          size: (isMobile ? 14 : 16) * responsiveIconSize
        ),
        SizedBox(width: isMobile ? 8 : 10),
        Expanded(
          child: _buildFilterDropdown('Year', _selectedYear, _availableYears, (value) {
            setState(() => _selectedYear = value!);
          }),
        ),
        SizedBox(width: isMobile ? 8 : 12),
        Expanded(
          child: _buildFilterDropdown('Branch', _selectedBranch, _availableBranches, (value) {
            setState(() => _selectedBranch = value!);
          }),
        ),
      ],
    ),
  );
}
 Widget _buildFilterChipsRow() {
  return const SizedBox.shrink(); // Remove filter chips completely
}

  Widget _buildFilterDropdown(
    String label,
    String selectedValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: (isMobile ? 9 : 10) * responsiveFontSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: isMobile ? 28 : 32,
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 6 : 8),
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
                      fontSize: (isMobile ? 9 : 10) * responsiveFontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withOpacity(0.7),
                size: isMobile ? 14 : 16,
              ),
              dropdownColor: const Color(0xFF1A1A2E),
              isDense: true,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: (isMobile ? 9 : 10) * responsiveFontSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: responsivePadding.copyWith(top: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 20 : 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A4A4A), Color(0xFF6B7280)],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.help_outline,
                color: Colors.white,
                size: isMobile ? 32 : 40,
              ),
            ),
            SizedBox(height: isMobile ? 20 : 24),
            Text(
              'No Doubts Found',
              style: GoogleFonts.poppins(
                fontSize: (isMobile ? 16 : 18) * responsiveFontSize,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'Be the first to ask a question or adjust your filters',
              style: GoogleFonts.poppins(
                fontSize: (isMobile ? 12 : 13) * responsiveFontSize,
                color: Colors.white60,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateDoubt() {
  return CreateDoubtPage(
    communityId: widget.communityId,
    userId: widget.userId,
    username: widget.username,
    userRole: widget.userRole,
    userProfile: _userProfile,
    onDoubtCreated: (doubtId, doubtData) {
      _addDoubtToList(doubtId, doubtData);
      _tabController.animateTo(0);
      _showMessage('Doubt posted successfully!');
    },
  );
}

  Widget _buildCreateFAB() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [const Color(0xFF4A4A4A), const Color(0xFF6B7280)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4A4A4A).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _tabController.animateTo(1),
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Text(
          'ask doubt',
          style: GoogleFonts.poppins(
            fontSize: (isMobile ? 12 : 14) * responsiveFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: Icon(
          Icons.add,
          color: Colors.white,
          size: isMobile ? 18 : 20,
        ),
      ),
    );
  }
}

// Doubt Card Widget
// Replace the DoubtCard class in your DoubtsPage with this enhanced version:

class DoubtCard extends StatefulWidget {
  final Map<String, dynamic> doubt;
  final String doubtId;
  final String currentUsername;
  final String userRole;
  final String communityId;
  final String userId;
  final bool isCompact;
  final Function(String, int)? onAnswerCountUpdate;

  const DoubtCard({
    Key? key,
    required this.doubt,
    required this.doubtId,
    required this.currentUsername,
    required this.userRole,
    required this.communityId,
    required this.userId,
    required this.isCompact,
    this.onAnswerCountUpdate,
  }) : super(key: key);

  @override
  State<DoubtCard> createState() => _DoubtCardState();
}

class _DoubtCardState extends State<DoubtCard> with TickerProviderStateMixin {
  // Cache user data to prevent repeated calls
  static final Map<String, Map<String, dynamic>?> _userDataCache = {};
  
  // Animation controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // State management
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;
  bool isExpanded = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadUserData() async {
    final authorUsername = widget.doubt['authorUsername'] as String? ?? '';
    
    if (authorUsername.isEmpty) {
      setState(() {
        _userData = null;
        _isLoadingUserData = false;
      });
      _startAnimations();
      return;
    }
    
    // Check cache first
    if (_userDataCache.containsKey(authorUsername)) {
      setState(() {
        _userData = _userDataCache[authorUsername];
        _isLoadingUserData = false;
      });
      _startAnimations();
      return;
    }

    // Load from database with delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 200));
    
    try {
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: authorUsername)
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        final userData = trioQuery.docs.first.data();
        _userDataCache[authorUsername] = userData;
        if (mounted) {
          setState(() {
            _userData = userData;
            _isLoadingUserData = false;
          });
          _startAnimations();
        }
        return;
      }

      // Check members collection
      final memberQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: authorUsername)
          .limit(1)
          .get();
      
      if (memberQuery.docs.isNotEmpty) {
        final userData = memberQuery.docs.first.data();
        _userDataCache[authorUsername] = userData;
        if (mounted) {
          setState(() {
            _userData = userData;
            _isLoadingUserData = false;
          });
          _startAnimations();
        }
        return;
      }

      // No user data found
      _userDataCache[authorUsername] = null;
      if (mounted) {
        setState(() {
          _userData = null;
          _isLoadingUserData = false;
        });
        _startAnimations();
      }
    } catch (e) {
      print('Error fetching user details for $authorUsername: $e');
      _userDataCache[authorUsername] = null;
      if (mounted) {
        setState(() {
          _userData = null;
          _isLoadingUserData = false;
        });
        _startAnimations();
      }
    }
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String username) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4A4A4A), const Color(0xFF6B7280)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: widget.isCompact ? 16 : 18,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerAvatar() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.2),
      child: Container(
        width: widget.isCompact ? 40 : 45,
        height: widget.isCompact ? 40 : 45,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildShimmerText(double width, double height) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.2),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildShimmerTag(double width) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.2),
      child: Container(
        width: width,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showAnswersModal() async {
    // Prevent keyboard from triggering rebuilds
    FocusScope.of(context).unfocus();
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnswersPage(
          doubtId: widget.doubtId,
          communityId: widget.communityId,
          userId: widget.userId,
          username: widget.currentUsername,
          doubt: widget.doubt,
          onAnswerPosted: () {
            // Update answer count without reload
            if (widget.onAnswerCountUpdate != null) {
              widget.onAnswerCountUpdate!(widget.doubtId, 1);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final doubt = widget.doubt;
    final question = doubt['question'] as String? ?? '';
    final imageUrl = doubt['imageUrl'] as String?;
    final authorUsername = doubt['authorUsername'] as String?;
    final answersCount = doubt['answersCount'] ?? 0;
    final tags = (doubt['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    final createdAt = doubt['createdAt'] as Timestamp?;
    final isAuthor = doubt['authorId'] == widget.userId;

    final displayQuestion = question.length > (widget.isCompact ? 150 : 200) && !isExpanded 
        ? '${question.substring(0, widget.isCompact ? 150 : 200)}...' 
        : question;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: EdgeInsets.only(bottom: widget.isCompact ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF4A4A4A).withOpacity(0.08),
                  const Color(0xFF6B7280).withOpacity(0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(widget.isCompact ? 16 : 20),
              border: Border.all(
                color: const Color(0xFF4A4A4A).withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A4A4A).withOpacity(0.1),
                  blurRadius: widget.isCompact ? 8 : 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.isCompact ? 14 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with smooth loading
                  Row(
                    children: [
                      // Avatar with smooth transition
                      Container(
                        width: widget.isCompact ? 40 : 45,
                        height: widget.isCompact ? 40 : 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF2A1810),
                            width: 2,
                          ),
                        ),
                        child: _isLoadingUserData
                            ? _buildShimmerAvatar()
                            : FadeTransition(
                                opacity: _fadeAnimation,
                                child: GestureDetector(
                                  onTap: () {
                                    if (authorUsername != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserProfileScreen(
                                            username: authorUsername!,
                                            communityId: widget.communityId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: _userData?['profileImageUrl'] != null
                                      ? ClipOval(
                                          child: Image.network(
                                            _userData!['profileImageUrl'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildAvatarFallback(authorUsername ?? 'U'),
                                          ),
                                        )
                                      : _buildAvatarFallback(authorUsername ?? 'U'),
                                ),
                              ),
                      ),
                      SizedBox(width: widget.isCompact ? 10 : 12),
                      Expanded(
                        child: _isLoadingUserData
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildShimmerText(120, 14),
                                            SizedBox(height: 4),
                                            _buildShimmerText(80, 12),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _buildShimmerTag(40),
                                      SizedBox(width: 6),
                                      _buildShimmerTag(50),
                                    ],
                                  ),
                                ],
                              )
                            : FadeTransition(
                                opacity: _fadeAnimation,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: GestureDetector(
                                            onTap: () {
                                              if (authorUsername != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => UserProfileScreen(
                                                      username: authorUsername!,
                                                      communityId: widget.communityId,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _userData != null
                                                      ? '${_userData!['firstName'] ?? ''} ${_userData!['lastName'] ?? ''}'.trim().isNotEmpty
                                                          ? '${_userData!['firstName'] ?? ''} ${_userData!['lastName'] ?? ''}'.trim()
                                                          : 'Unknown User'
                                                      : 'Unknown User',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: widget.isCompact ? 13 : 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                if (authorUsername != null)
                                                  Text(
                                                    '@${authorUsername}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: widget.isCompact ? 11 : 12,
                                                      fontWeight: FontWeight.w400,
                                                      color: Colors.white60,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (isAuthor) ...[
                                          SizedBox(width: widget.isCompact ? 4 : 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: widget.isCompact ? 4 : 6, 
                                              vertical: 2
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
                                              ),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'You',
                                              style: GoogleFonts.poppins(
                                                fontSize: widget.isCompact ? 8 : 9,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (_userData != null && 
                                        (_userData!['year'] != null || _userData!['branch'] != null))
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: [
                                              if (_userData!['year'] != null)
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: widget.isCompact ? 6 : 8, 
                                                    vertical: 3
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        const Color(0xFF2A1810).withOpacity(0.3),
                                                        const Color(0xFF3D2914).withOpacity(0.2),
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
                                                        Icons.school,
                                                        size: widget.isCompact ? 8 : 10,
                                                        color: const Color(0xFFF7B42C),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _userData!['year'].toString(),
                                                        style: GoogleFonts.poppins(
                                                          fontSize: widget.isCompact ? 9 : 10,
                                                          color: const Color(0xFFF7B42C),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              if (_userData!['year'] != null && _userData!['branch'] != null)
                                                const SizedBox(width: 6),
                                              if (_userData!['branch'] != null)
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: widget.isCompact ? 6 : 8, 
                                                    vertical: 3
                                                  ),
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        const Color(0xFF2A1810).withOpacity(0.3),
                                                        const Color(0xFF3D2914).withOpacity(0.2),
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
                                                        size: widget.isCompact ? 8 : 10,
                                                        color: const Color(0xFFF7B42C),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _userData!['branch'].toString(),
                                                        style: GoogleFonts.poppins(
                                                          fontSize: widget.isCompact ? 9 : 10,
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
                                      ),
                                  ],
                                ),
                              ),
                      ),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isCompact ? 6 : 8, 
                            vertical: 4
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatTimestamp(createdAt),
                            style: GoogleFonts.poppins(
                              fontSize: widget.isCompact ? 9 : 10,
                              color: Colors.white60,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: widget.isCompact ? 12 : 16),

                  // Question with fade animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      displayQuestion,
                      style: GoogleFonts.poppins(
                        fontSize: widget.isCompact ? 13 : 14,
                        color: Colors.white,
                        height: 1.6,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  if (question.length > (widget.isCompact ? 150 : 200))
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: GestureDetector(
                        onTap: () => setState(() => isExpanded = !isExpanded),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Text(
                                isExpanded ? 'Show less' : 'Read more',
                                style: GoogleFonts.poppins(
                                  fontSize: widget.isCompact ? 11 : 12,
                                  color: const Color(0xFF4A4A4A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isExpanded ? Icons.expand_less : Icons.expand_more,
                                color: const Color(0xFF4A4A4A),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Image with fade animation
                  if (imageUrl != null) ...[
                    SizedBox(height: widget.isCompact ? 10 : 12),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(context, imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(widget.isCompact ? 10 : 12),
                          child: Image.network(
                            imageUrl,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: widget.isCompact ? 150 : 200,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(widget.isCompact ? 10 : 12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.white60,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // Tags with fade animation
                  if (tags.isNotEmpty) ...[
                    SizedBox(height: widget.isCompact ? 10 : 12),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.take(3).map((tag) => Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isCompact ? 6 : 8, 
                            vertical: 4
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF4A4A4A).withOpacity(0.2),
                                const Color(0xFF6B7280).withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4A4A4A).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            tag,
                            style: GoogleFonts.poppins(
                              fontSize: widget.isCompact ? 9 : 10,
                              color: const Color(0xFF4A4A4A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],

                  SizedBox(height: widget.isCompact ? 12 : 16),

                  // Actions with fade animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _showAnswersModal,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: widget.isCompact ? 10 : 12, 
                              vertical: widget.isCompact ? 6 : 8
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4A4A4A), Color(0xFF6B7280)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4A4A4A).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  color: Colors.white,
                                  size: widget.isCompact ? 14 : 16,
                                ),
                                SizedBox(width: widget.isCompact ? 4 : 6),
                                Text(
                                  answersCount == 0 ? 'Answer' : '$answersCount Answer${answersCount > 1 ? 's' : ''}',
                                  style: GoogleFonts.poppins(
                                    fontSize: widget.isCompact ? 11 : 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isCompact ? 6 : 8, 
                            vertical: 4
                          ),
                          decoration: BoxDecoration(
                            color: answersCount == 0 
                                ? Colors.orange.withOpacity(0.2)
                                : Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                answersCount == 0 ? Icons.help_outline : Icons.check_circle,
                                color: answersCount == 0 ? Colors.orange : Colors.green,
                                size: widget.isCompact ? 12 : 14,
                              ),
                              SizedBox(width: widget.isCompact ? 3 : 4),
                              Text(
                                answersCount == 0 ? 'Unanswered' : 'Answered',
                                style: GoogleFonts.poppins(
                                  fontSize: widget.isCompact ? 9 : 10,
                                  color: answersCount == 0 ? Colors.orange : Colors.green,
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
          ),
        );
      },
    );
  }
}
// Create Doubt Page
class CreateDoubtPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final String userRole;
  final Map<String, dynamic>? userProfile;
  final Function(String, Map<String, dynamic>) onDoubtCreated;

  const CreateDoubtPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
    this.userProfile,
    required this.onDoubtCreated,
  }) : super(key: key);

  @override
  State<CreateDoubtPage> createState() => _CreateDoubtPageState();
}

class _CreateDoubtPageState extends State<CreateDoubtPage> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isPosting = false;
  String _visibility = 'everyone';
  File? _selectedImage;
  String? _imageUrl;
  
  // Responsive helpers
  // Responsive helpers
bool get isMobile => MediaQuery.of(context).size.width < 600;
bool get isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;
bool get isDesktop => MediaQuery.of(context).size.width >= 900;

double get screenWidth => MediaQuery.of(context).size.width;
double get screenHeight => MediaQuery.of(context).size.height;

EdgeInsets get responsivePadding {
  final width = screenWidth;
  final height = screenHeight;
  
  if (width < 360 || height < 640) return const EdgeInsets.all(8);
  if (width < 400) return const EdgeInsets.all(12);
  if (width < 600) return const EdgeInsets.all(16);
  if (width < 900) return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
  return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
}
  

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showMessage('Error picking image: $e', isError: true);
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _imageUrl = null;
    });
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final fileName = 'doubt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('communities')
          .child(widget.communityId)
          .child('doubts')
          .child(fileName);

      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  Future<void> _postDoubt() async {
    final question = _questionController.text.trim();
    if (question.isEmpty && _selectedImage == null) {
      _showMessage('Please write a question or add an image', isError: true);
      return;
    }

    if (question.length > 2000) {
      _showMessage('Question must be 2000 characters or less', isError: true);
      return;
    }

    setState(() => _isPosting = true);

    try {
      String? uploadedImageUrl;
      if (_selectedImage != null) {
        uploadedImageUrl = await _uploadImage();
      }

      final doubtRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('doubts')
          .doc();

      Map<String, dynamic> visibilitySettings = {
        'type': _visibility,
        'allowedYears': _visibility == 'everyone' ? [] : 
                      _visibility.contains('year') ? [widget.userProfile?['year']] : [],
        'allowedBranches': _visibility == 'everyone' ? [] : 
                         _visibility.contains('branch') ? [widget.userProfile?['branch']] : [],
      };
final doubtData = {
  'id': doubtRef.id,
  'question': question,
  'imageUrl': uploadedImageUrl,
  'authorId': widget.userId,
  'authorUsername': widget.username,
  'authorYear': widget.userProfile?['year'],
  'authorBranch': widget.userProfile?['branch'],
  'visibility': visibilitySettings,
  'createdAt': FieldValue.serverTimestamp(),
  'updatedAt': FieldValue.serverTimestamp(),
  'answersCount': 0,
  'tags': _extractTags(question),
};

await doubtRef.set(doubtData);

_questionController.clear();
setState(() {
  _selectedImage = null;
  _imageUrl = null;
});

widget.onDoubtCreated(doubtRef.id, doubtData);
      
    } catch (e) {
      _showMessage('Failed to post doubt: $e', isError: true);
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
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ask your doubt',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Text(
            'get help from your peers with questions and images',
            style: GoogleFonts.poppins(
              fontSize: isMobile ? 11 : 12,
              color: Colors.white60,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          
          // Question input
          Container(
            constraints: BoxConstraints(
              maxHeight: isMobile ? 180 : 220,
              minHeight: isMobile ? 120 : 140,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _questionController,
              maxLines: null,
              maxLength: 2000,
              style: GoogleFonts.poppins(
                color: Colors.white, 
                fontSize: isMobile ? 13 : 14
              ),
              decoration: InputDecoration(
                hintText: 'What\'s your question? Use #tags for better discovery',
                hintStyle: GoogleFonts.poppins(
                  color: Colors.white38, 
                  fontSize: isMobile ? 13 : 14
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(isMobile ? 14 : 16),
                counterStyle: GoogleFonts.poppins(
                  color: Colors.white38, 
                  fontSize: isMobile ? 10 : 11
                ),
              ),
            ),
          ),
          
          SizedBox(height: isMobile ? 16 : 20),

          // Image section
          _buildImageSection(),
          
          SizedBox(height: isMobile ? 16 : 20),

          // Visibility settings
          _buildVisibilitySettings(),
          
          SizedBox(height: isMobile ? 20 : 24),

          // Post button
          _buildPostButton(),
          
          SizedBox(height: isMobile ? 16 : 20),
          
          _buildPostingGuidelines(),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image,
                color: const Color(0xFF9CA3AF),
                size: isMobile ? 16 : 18,
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Text(
                'Add Image (Optional)',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          
          if (_selectedImage != null) ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    width: double.infinity,
                    height: isMobile ? 150 : 200,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: _removeImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: isMobile ? 80 : 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      color: Colors.white60,
                      size: isMobile ? 28 : 32,
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    Text(
                      'Tap to add image',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: isMobile ? 11 : 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisibilitySettings() {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who can see this doubt?',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: isMobile ? 13 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 10 : 12),
          Column(
            children: [
              _buildVisibilityOption('everyone', 'Everyone in the community', Icons.public),
              _buildVisibilityOption('year', 'Only my year (${widget.userProfile?['year'] ?? 'Unknown'})', Icons.school),
              _buildVisibilityOption('branch', 'Only my branch (${widget.userProfile?['branch'] ?? 'Unknown'})', Icons.category),
              _buildVisibilityOption('branch_year', 'My year and branch only', Icons.group),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOption(String value, String label, IconData icon) {
    return GestureDetector(
      onTap: () => setState(() => _visibility = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: _visibility == value 
              ? const Color(0xFF4A4A4A).withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _visibility == value 
                ? const Color(0xFF4A4A4A) 
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: _visibility == value ? const Color(0xFF4A4A4A) : Colors.white70,
              size: isMobile ? 16 : 18,
            ),
            SizedBox(width: isMobile ? 10 : 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: _visibility == value ? Colors.white : Colors.white70,
                  fontSize: isMobile ? 12 : 13,
                  fontWeight: _visibility == value ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            if (_visibility == value)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4A4A4A),
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostButton() {
    return Row(
      children: [
        const Spacer(),
        GestureDetector(
          onTap: _isPosting ? null : _postDoubt,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 28 : 36, 
              vertical: isMobile ? 12 : 14
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A4A4A), Color(0xFF6B7280)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6B7280).withOpacity(0.6),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _isPosting
                ? SizedBox(
                    width: isMobile ? 14 : 16,
                    height: isMobile ? 14 : 16,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'POST DOUBT',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPostingGuidelines() {
    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 16),
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
              Icon(
                Icons.info_outline, 
                color: Colors.orange, 
                size: isMobile ? 14 : 16
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'Posting Guidelines',
                style: GoogleFonts.poppins(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 12 : 14,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            '• Maximum 2000 characters\n'
            '• Be clear and specific with your question\n'
            '• Use #tags for better discoverability\n'
            '• Add images to provide more context',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: isMobile ? 11 : 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// Answers Page Modal
// Replace the AnswersPage class in your DoubtsPage file with this implementation

class AnswersPage extends StatefulWidget {
  final String doubtId;
  final String communityId;
  final String userId;
  final String username;
  final Map<String, dynamic> doubt;
  final VoidCallback? onAnswerPosted;

  const AnswersPage({
    Key? key,
    required this.doubtId,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.doubt,
    this.onAnswerPosted,
    
  }) : super(key: key);
  
  @override
  State<AnswersPage> createState() => _AnswersPageState();
}

class _AnswersPageState extends State<AnswersPage> {
  final TextEditingController _answerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _answerFocusNode = FocusNode();
  
  // Static data - no rebuilds after initial load
  List<Map<String, dynamic>> _answers = [];
  final Map<String, Map<String, dynamic>?> _userCache = {};
  final Map<String, GlobalKey> _answerKeys = {};
  
  // Only for initial loading state
  bool _isInitialLoading = true;
  
  // UI state - minimal updates
  bool _isPosting = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadAnswersOnce(); // Only load once
  }

  @override
  void dispose() {
    _answerController.dispose();
    _scrollController.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _answerFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  // LOAD ANSWERS ONLY ONCE - NO RELOADING
  Future<void> _loadAnswersOnce() async {
  try {
    final answersSnapshot = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('doubts')
        .doc(widget.doubtId)
        .collection('answers')
        .orderBy('createdAt', descending: true) // CHANGED: true instead of false
        .get();

    final answers = <Map<String, dynamic>>[];
    
    for (var doc in answersSnapshot.docs) {
      final data = doc.data();
      final answerData = {
        'id': doc.id,
        ...data,
      };
      answers.add(answerData);
    }
    
    // Set data once and never reload
    if (mounted) {
      setState(() {
        _answers = answers;
        _isInitialLoading = false;
      });
    }
  } catch (e) {
    debugPrint('Error loading answers: $e');
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }
}

Future<void> _createNotification({
  required String recipientUserId,
  required String title,
  required String body,
  required String type,
  String? doubtId,
  String? answerId,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientUserId)
        .collection('notifications')
        .add({
      'type': type, // 'doubt_answer'
      'title': title,
      'message': body,
      'senderName': widget.username,
      'senderId': widget.userId,
      'doubtId': doubtId,
      'answerId': answerId,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    });
  } catch (e) {
    debugPrint('Error creating notification: $e');
  }
}

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showMessage('Error picking image: $e', isError: true);
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final fileName = 'answer_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('communities')
          .child(widget.communityId)
          .child('answers')
          .child(fileName);

      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // POST ANSWER - ADD TO LIST WITHOUT RELOADING
  Future<void> _postAnswer() async {
  final answer = _answerController.text.trim();
  if (answer.isEmpty && _selectedImage == null) {
    _showMessage('Please write an answer or add an image', isError: true);
    return;
  }

  if (answer.length > 1500) {
    _showMessage('Answer must be 1500 characters or less', isError: true);
    return;
  }

  _dismissKeyboard();

  try {
    setState(() => _isPosting = true);

    String? uploadedImageUrl;
    if (_selectedImage != null) {
      uploadedImageUrl = await _uploadImage();
    }

    final answerRef = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('doubts')
        .doc(widget.doubtId)
        .collection('answers')
        .add({
      'content': answer,
      'imageUrl': uploadedImageUrl,
      'authorId': widget.userId,
      'authorUsername': widget.username,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update answers count
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('doubts')
        .doc(widget.doubtId)
        .update({'answersCount': FieldValue.increment(1)});

    // Add notification for doubt author
    await _notifyDoubtAnswer(answerRef.id);

    // Add answer to list in memory - NO RELOAD
    _addAnswerToList(answerRef.id, answer, uploadedImageUrl);

    // Clear form without rebuilding
    _answerController.clear();
    _selectedImage = null;

    // Notify parent about answer posted
    if (widget.onAnswerPosted != null) {
      widget.onAnswerPosted!();
    }

    _showMessage('Answer posted successfully!');
      
  } catch (e) {
    _showMessage('Failed to post answer: $e', isError: true);
  } finally {
    if (mounted) {
      setState(() => _isPosting = false);
    }
  }
}

  // ADD ANSWER TO MEMORY - NO RELOAD
  void _addAnswerToList(String answerId, String content, String? imageUrl) {
  final newAnswer = {
    'id': answerId,
    'content': content,
    'imageUrl': imageUrl,
    'authorUsername': widget.username,
    'createdAt': Timestamp.now(),
  };

  setState(() {
    _answers.insert(0, newAnswer); // CHANGED: insert(0, ...) instead of add()
    // Generate key for the new answer
    _answerKeys[answerId] = GlobalKey();
  });
}

Future<void> _notifyDoubtAnswer(String answerId) async {
  try {
    final doubtAuthorUsername = widget.doubt['authorUsername'];
    if (doubtAuthorUsername == null || doubtAuthorUsername == widget.username) {
      return; // Don't notify if it's the same user
    }

    // Get the doubt author's userId
    final userData = await _getUserDetails(doubtAuthorUsername);
    final authorUserId = userData?['userId'];
    
    if (authorUserId != null) {
      await _createNotification(
        recipientUserId: authorUserId,
        title: 'New answer to your doubt',
        body: '${widget.username} answered your doubt',
        type: 'doubt_answer',
        doubtId: widget.doubtId,
        answerId: answerId,
      );
    }
  } catch (e) {
    debugPrint('Error notifying doubt answer: $e');
  }
}

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
          );
        }
      });
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserDetails(String username) async {
    // Use cache to avoid repeated calls
    if (_userCache.containsKey(username)) {
      return _userCache[username];
    }

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
        final userData = trioQuery.docs.first.data();
        _userCache[username] = userData;
        return userData;
      }

      // Check members collection
      final memberQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      
      if (memberQuery.docs.isNotEmpty) {
        final userData = memberQuery.docs.first.data();
        _userCache[username] = userData;
        return userData;
      }

      _userCache[username] = null;
      return null;
    } catch (e) {
      print('Error fetching user details for $username: $e');
      _userCache[username] = null;
      return null;
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildAvatarFallback(String username) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4A4A4A), const Color(0xFF6B7280)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  bool get isMobile => MediaQuery.of(context).size.width < 600;
  bool get isTablet => MediaQuery.of(context).size.width >= 600 && MediaQuery.of(context).size.width < 900;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: _dismissKeyboard,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1A2E),
                const Color(0xFF16213E),
                const Color(0xFF0F0F23),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Expanded makes everything scrollable
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 80, // Space for input
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Container(
                          padding: EdgeInsets.all(isMobile ? 16 : 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'doubt & answers',
                                    style: GoogleFonts.dmSerifDisplay(
                                      fontSize: isMobile ? 18 : 20,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 1.2
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Icon(
                                      Icons.close, 
                                      color: Colors.white70,
                                      size: isMobile ? 22 : 24,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isMobile ? 12 : 16),
                              // Original doubt
                              Container(
                                padding: EdgeInsets.all(isMobile ? 12 : 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF4A4A4A).withOpacity(0.1),
                                      const Color(0xFF6B7280).withOpacity(0.05),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Enhanced header with full user profile
                                    FutureBuilder<Map<String, dynamic>?>(
                                      future: _getUserDetails(widget.doubt['authorUsername'] ?? ''),
                                      builder: (context, snapshot) {
                                        final userData = snapshot.data;
                                        final profileImageUrl = userData?['profileImageUrl'];
                                        final firstName = userData?['firstName'] ?? '';
                                        final lastName = userData?['lastName'] ?? '';
                                        final fullName = '$firstName $lastName'.trim();
                                        final userYear = userData?['year'];
                                        final userBranch = userData?['branch'];
                                        final authorUsername = userData?['username'];
                                        
                                        return Row(
                                          children: [
                                            // Profile Image
                                            GestureDetector(
                                              onTap: () {
                                                if (authorUsername != null) {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => UserProfileScreen(
                                                        username: authorUsername!,
                                                        communityId: widget.communityId,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                              child: Container(
                                                width: isMobile ? 45 : 50,
                                                height: isMobile ? 45 : 50,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(color: const Color(0xFF2A1810), width: 2),
                                                ),
                                                child: profileImageUrl != null
                                                    ? ClipOval(
                                                        child: Image.network(
                                                          profileImageUrl,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) =>
                                                              _buildAvatarFallback(fullName.isNotEmpty ? fullName : widget.doubt['authorUsername'] ?? 'U'),
                                                        ),
                                                      )
                                                    : _buildAvatarFallback(fullName.isNotEmpty ? fullName : widget.doubt['authorUsername'] ?? 'U'),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    fullName.isNotEmpty ? fullName : 'Unknown User',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: isMobile ? 14 : 16,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  if (widget.doubt['authorUsername'] != null)
                                                    Text(
                                                      '@${widget.doubt['authorUsername']}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: isMobile ? 12 : 13,
                                                        fontWeight: FontWeight.w400,
                                                        color: Colors.white60,
                                                      ),
                                                    ),
                                                  if (userYear != null || userBranch != null)
                                                    Container(
                                                      margin: const EdgeInsets.only(top: 4),
                                                      child: SingleChildScrollView(
                                                        scrollDirection: Axis.horizontal,
                                                        child: Row(
                                                          children: [
                                                            if (userYear != null)
                                                              Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                margin: EdgeInsets.only(right: 6),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [
                                                                      const Color(0xFF2A1810).withOpacity(0.3),
                                                                      const Color(0xFF3D2914).withOpacity(0.2),
                                                                    ],
                                                                  ),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                  border: Border.all(color: const Color(0xFFF7B42C).withOpacity(0.3)),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(Icons.school, size: 10, color: const Color(0xFFF7B42C)),
                                                                    SizedBox(width: 4),
                                                                    Text(
                                                                      userYear.toString(),
                                                                      style: GoogleFonts.poppins(
                                                                        fontSize: 10,
                                                                        color: const Color(0xFFF7B42C),
                                                                        fontWeight: FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            if (userBranch != null)
                                                              Container(
                                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [
                                                                      const Color(0xFF2A1810).withOpacity(0.3),
                                                                      const Color(0xFF3D2914).withOpacity(0.2),
                                                                    ],
                                                                  ),
                                                                  borderRadius: BorderRadius.circular(12),
                                                                  border: Border.all(color: const Color(0xFFF7B42C).withOpacity(0.3)),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    Icon(Icons.category, size: 10, color: const Color(0xFFF7B42C)),
                                                                    SizedBox(width: 4),
                                                                    Text(
                                                                      userBranch.toString(),
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
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _formatTimestamp(widget.doubt['createdAt']),
                                              style: GoogleFonts.poppins(
                                                fontSize: isMobile ? 11 : 12,
                                                color: Colors.white60,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    Text(
                                      widget.doubt['question'] ?? '',
                                      style: GoogleFonts.poppins(
                                        fontSize: isMobile ? 13 : 14,
                                        color: Colors.white,
                                        height: 1.5,
                                      ),
                                    ),
                                    if (widget.doubt['imageUrl'] != null) ...[
                                      SizedBox(height: isMobile ? 12 : 16),
                                      GestureDetector(
                                        onTap: () => _showFullScreenImage(context, widget.doubt['imageUrl']),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.network(
                                            widget.doubt['imageUrl'],
                                            width: double.infinity,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              height: 150,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Center(
                                                child: Icon(Icons.broken_image, color: Colors.white60, size: 40),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Answers Section - NO STREAMBUILDER
                        _buildAnswersList(),
                      ],
                    ),
                  ),
                ),

                // Fixed bottom input
                _buildCommentInput(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswersList() {
    // ONLY show shimmer during initial load
    if (_isInitialLoading) {
      return _buildAnswersShimmer();
    }

    // NO REBUILDS after initial load
    if (_answers.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Center(
          child: Text(
            'No answers yet. Be the first to help!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: isMobile ? 13 : 14,
            ),
          ),
        ),
      );
    }

    // Generate keys only once when answers are first loaded
    for (var answer in _answers) {
      if (!_answerKeys.containsKey(answer['id'])) {
        _answerKeys[answer['id']] = GlobalKey();
      }
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
      child: Column(
        children: _answers.map((answer) {
          final answerKey = _answerKeys[answer['id']]!; // Use existing key
          
          return Container(
            key: answerKey,
            child: AnswerCard(
              key: ValueKey('answer_${answer['id']}'),
              answer: answer,
              isCompact: isMobile,
              communityId: widget.communityId,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnswersShimmer() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 20),
      child: Column(
        children: List.generate(3, (index) => Container(
          margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
          padding: EdgeInsets.all(isMobile ? 14 : 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(0.1),
            highlightColor: Colors.white.withOpacity(0.2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: isMobile ? 40 : 45,
                      height: isMobile ? 40 : 45,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: isMobile ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 12,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  height: 16,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 16,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        )),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: isMobile ? 12 : 16,
        right: isMobile ? 12 : 16,
        top: isMobile ? 8 : 12,
        bottom: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image preview
          if (_selectedImage != null) ...[
            Container(
              height: 80,
              margin: EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: double.infinity,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Image button
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(
                    Icons.image,
                    color: const Color(0xFF9CA3AF),
                    size: isMobile ? 16 : 18,
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              // Text input
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: isMobile ? 100 : 120,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _answerController,
                    focusNode: _answerFocusNode,
                    style: GoogleFonts.poppins(
                      color: Colors.white, 
                      fontSize: isMobile ? 12 : 13
                    ),
                    decoration: InputDecoration(
                      hintText: 'Write your answer...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: isMobile ? 12 : 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 14, 
                        vertical: isMobile ? 8 : 10
                      ),
                      isDense: true,
                    ),
                    maxLines: null,
                    maxLength: 1500,
                    textInputAction: TextInputAction.newline,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  ),
                ),
              ),
              
              SizedBox(width: 8),
              
              // Send button
              GestureDetector(
                onTap: _isPosting ? null : _postAnswer,
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4A4A4A), Color(0xFF6B7280)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: _isPosting
                      ? SizedBox(
                          width: isMobile ? 16 : 18,
                          height: isMobile ? 16 : 18,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: Colors.white,
                          size: isMobile ? 16 : 18,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Answer Card Widget
// Answer Card Widget
class AnswerCard extends StatefulWidget {
  final Map<String, dynamic> answer;
  final bool isCompact;
  final String communityId;

  const AnswerCard({
    Key? key,
    required this.answer,
    required this.isCompact,
    required this.communityId,
  }) : super(key: key);

  @override
  State<AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<AnswerCard> with TickerProviderStateMixin {
  // Cache user data to prevent repeated calls
  static final Map<String, Map<String, dynamic>?> _userDataCache = {};
  
  // Animation controllers for smooth transitions
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // State management
  Map<String, dynamic>? _userData;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserData();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
  }

  Future<void> _loadUserData() async {
    final authorUsername = widget.answer['authorUsername'] as String? ?? 'Unknown';
    
    // Check cache first
    if (_userDataCache.containsKey(authorUsername)) {
      setState(() {
        _userData = _userDataCache[authorUsername];
        _isLoadingUserData = false;
      });
      _startAnimations();
      return;
    }

    // Load from database with delay for smooth transition
    await Future.delayed(const Duration(milliseconds: 200));
    
    try {
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: authorUsername)
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        final userData = trioQuery.docs.first.data();
        _userDataCache[authorUsername] = userData;
        if (mounted) {
          setState(() {
            _userData = userData;
            _isLoadingUserData = false;
          });
          _startAnimations();
        }
        return;
      }

      final memberQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: authorUsername)
          .limit(1)
          .get();
      
      if (memberQuery.docs.isNotEmpty) {
        final userData = memberQuery.docs.first.data();
        _userDataCache[authorUsername] = userData;
        if (mounted) {
          setState(() {
            _userData = userData;
            _isLoadingUserData = false;
          });
          _startAnimations();
        }
        return;
      }

      // No user data found
      _userDataCache[authorUsername] = null;
      if (mounted) {
        setState(() {
          _userData = null;
          _isLoadingUserData = false;
        });
        _startAnimations();
      }
    } catch (e) {
      print('Error fetching user details for $authorUsername: $e');
      _userDataCache[authorUsername] = null;
      if (mounted) {
        setState(() {
          _userData = null;
          _isLoadingUserData = false;
        });
        _startAnimations();
      }
    }
  }

  void _startAnimations() {
    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
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

  Widget _buildAvatarFallback(String username) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF4A4A4A), const Color(0xFF6B7280)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: widget.isCompact ? 14 : 16,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerAvatar() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.2),
      child: Container(
        width: widget.isCompact ? 40 : 45,
        height: widget.isCompact ? 40 : 45,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildShimmerText(double width, double height) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withOpacity(0.1),
      highlightColor: Colors.white.withOpacity(0.2),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.answer['content'] as String? ?? '';
    final imageUrl = widget.answer['imageUrl'] as String?;
    final authorUsername = widget.answer['authorUsername'] as String? ?? 'Unknown';
    final createdAt = widget.answer['createdAt'] as Timestamp?;

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: EdgeInsets.only(bottom: widget.isCompact ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF9CA3AF).withOpacity(0.05),
                  const Color(0xFF6B7280).withOpacity(0.02),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(widget.isCompact ? 16 : 20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.isCompact ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Header with smooth loading
                  Row(
                    children: [
                      // Avatar with smooth transition
                      Container(
                        width: widget.isCompact ? 40 : 45,
                        height: widget.isCompact ? 40 : 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2A1810), width: 2),
                        ),
                        child: _isLoadingUserData
                            ? _buildShimmerAvatar()
                            : FadeTransition(
                                opacity: _fadeAnimation,
                                child: _userData?['profileImageUrl'] != null
                                    ? ClipOval(
                                        child: Image.network(
                                          _userData!['profileImageUrl'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              _buildAvatarFallback(authorUsername),
                                        ),
                                      )
                                    : _buildAvatarFallback(authorUsername),
                              ),
                      ),
                      SizedBox(width: widget.isCompact ? 10 : 12),
                      Expanded(
                        child: _isLoadingUserData
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildShimmerText(120, 14),
                                  const SizedBox(height: 4),
                                  _buildShimmerText(80, 12),
                                ],
                              )
                            : FadeTransition(
                                opacity: _fadeAnimation,
                                child: GestureDetector(
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _userData != null
                                            ? '${_userData!['firstName'] ?? ''} ${_userData!['lastName'] ?? ''}'.trim().isNotEmpty
                                                ? '${_userData!['firstName'] ?? ''} ${_userData!['lastName'] ?? ''}'.trim()
                                                : authorUsername
                                            : authorUsername,
                                        style: GoogleFonts.poppins(
                                          fontSize: widget.isCompact ? 13 : 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        '@$authorUsername',
                                        style: GoogleFonts.poppins(
                                          fontSize: widget.isCompact ? 11 : 12,
                                          fontWeight: FontWeight.w400,
                                          color: Colors.white60,
                                        ),
                                      ),
                                      // Year and Branch tags with smooth transition
                                      if (_userData != null &&
                                          (_userData!['year'] != null || _userData!['branch'] != null))
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                if (_userData!['year'] != null)
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: widget.isCompact ? 6 : 8,
                                                      vertical: 3,
                                                    ),
                                                    margin: EdgeInsets.only(right: 6),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          const Color(0xFF2A1810).withOpacity(0.3),
                                                          const Color(0xFF3D2914).withOpacity(0.2),
                                                        ],
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                          color: const Color(0xFFF7B42C).withOpacity(0.3)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.school,
                                                          size: widget.isCompact ? 8 : 10,
                                                          color: const Color(0xFFF7B42C),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          _userData!['year'].toString(),
                                                          style: GoogleFonts.poppins(
                                                            fontSize: widget.isCompact ? 9 : 10,
                                                            color: const Color(0xFFF7B42C),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (_userData!['branch'] != null)
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: widget.isCompact ? 6 : 8,
                                                      vertical: 3,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          const Color(0xFF2A1810).withOpacity(0.3),
                                                          const Color(0xFF3D2914).withOpacity(0.2),
                                                        ],
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(
                                                          color: const Color(0xFFF7B42C).withOpacity(0.3)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.category,
                                                          size: widget.isCompact ? 8 : 10,
                                                          color: const Color(0xFFF7B42C),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          _userData!['branch'].toString(),
                                                          style: GoogleFonts.poppins(
                                                            fontSize: widget.isCompact ? 9 : 10,
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
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),

                  if (content.isNotEmpty) ...[
                    SizedBox(height: widget.isCompact ? 10 : 12),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        content,
                        style: GoogleFonts.poppins(
                          fontSize: widget.isCompact ? 13 : 14,
                          color: Colors.white,
                          height: 1.5,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],

                  // Full-width Image with increased height
                  if (imageUrl != null) ...[
                    SizedBox(height: widget.isCompact ? 10 : 12),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: GestureDetector(
                        onTap: () => _showFullScreenImage(context, imageUrl),
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: widget.isCompact ? 220 : 320, // INCREASED
                            minHeight: widget.isCompact ? 110 : 200, // INCREASED
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(widget.isCompact ? 10 : 12),
                            child: Image.network(
                              imageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: widget.isCompact ? 200 : 300,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(widget.isCompact ? 10 : 12),
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: const Color(0xFF9CA3AF),
                                      strokeWidth: 2,
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: widget.isCompact ? 200 : 300,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(widget.isCompact ? 10 : 12),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.white60,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: widget.isCompact ? 10 : 12),

                  // Timestamp only
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      children: [
                        Spacer(),
                        Text(
                          _formatTimestamp(createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: widget.isCompact ? 9 : 10,
                            color: Colors.white60,
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
      },
    );
  }
}