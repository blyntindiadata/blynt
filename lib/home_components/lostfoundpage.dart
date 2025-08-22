import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/contact_lostfound.dart';
// import 'package:startup/home_components/create_lost_found_page.dart';
import 'package:startup/home_components/create_lostfound.dart';
// import 'contact_lost_found.dart';

class LostAndFoundPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const LostAndFoundPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  }) : super(key: key);

  @override
  State<LostAndFoundPage> createState() => _LostAndFoundPageState();
}

class _LostAndFoundPageState extends State<LostAndFoundPage> with TickerProviderStateMixin {
  final ValueNotifier<List<Map<String, dynamic>>> _lostItemsNotifier = ValueNotifier([]);
  final ValueNotifier<List<Map<String, dynamic>>> _foundItemsNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final TextEditingController _searchController = TextEditingController();
  
  late TabController _tabController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isSearching = false;
  String _searchQuery = '';
  
  final Map<String, String?> _userProfileImages = {};

  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadItems();
    _initAnimations();
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
    _lostItemsNotifier.dispose();
    _foundItemsNotifier.dispose();
    _isLoadingNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _tabController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      _isLoadingNotifier.value = true;
      
      print('Loading items from: communities/${widget.communityId}/lost_found');
      
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('lost_found')
          .get();

      print('Found ${snapshot.docs.length} documents in lost_found collection');

      final lostItems = <Map<String, dynamic>>[];
      final foundItems = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('Document ${doc.id}: $data');
        
        final item = {
          'id': doc.id,
          ...data,
        };

        // Check if item is active (not deleted)
        if (data['isActive'] == true || data['isActive'] == null) {
          if (data['type'] == 'lost') {
            lostItems.add(item);
          } else if (data['type'] == 'found') {
            foundItems.add(item);
          }
        }
      }

      // Sort by creation date (most recent first)
      lostItems.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        } else if (aTime != null) {
          return -1;
        } else if (bTime != null) {
          return 1;
        }
        return 0;
      });

      foundItems.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        
        if (aTime != null && bTime != null) {
          return bTime.compareTo(aTime);
        } else if (aTime != null) {
          return -1;
        } else if (bTime != null) {
          return 1;
        }
        return 0;
      });

      print('Loaded ${lostItems.length} lost items and ${foundItems.length} found items');
      _lostItemsNotifier.value = lostItems;
      _foundItemsNotifier.value = foundItems;
    } catch (e) {
      print('Error loading items: $e');
      if (mounted) {
        _showMessage('Error loading items: $e', isError: true);
      }
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

Future<String?> _getUserProfileImage(String username) async {
  if (_userProfileImages.containsKey(username)) {
    return _userProfileImages[username];
  }

  try {
    // Try trio collection first
    var trioQuery = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    
    DocumentSnapshot? userDoc;
    if (trioQuery.docs.isNotEmpty) {
      userDoc = trioQuery.docs.first;
    } else {
      // Try members collection if not found in trio
      var membersQuery = await FirebaseFirestore.instance
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
        ? (userDoc!.data()! as Map<String, dynamic>)['profileImageUrl'] as String?
        : null;
    _userProfileImages[username] = profileImageUrl;
    return profileImageUrl;
  } catch (e) {
    print('Error fetching profile image for $username: $e');
    _userProfileImages[username] = null;
    return null;
  }
}

  Future<void> _deleteItem(String itemId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('lost_found')
          .doc(itemId)
          .delete();

      _loadItems();
      
      if (mounted) {
        _showMessage('Item deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error deleting item: $e', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : Colors.brown.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
  void _dismissKeyboard() {
  _searchFocusNode.unfocus();
  FocusScope.of(context).unfocus();
}

@override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth > 600;
  
  return GestureDetector(
    onTap: _dismissKeyboard,
    child: Scaffold(
      backgroundColor: const Color(0xFF4A1A00), // Keep your brown theme
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF5A2D00),
              const Color(0xFF4A1A00),
              const Color(0xFF2A0D00),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isTablet), // Pass isTablet parameter
              _buildTabBar(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildItemsList(_lostItemsNotifier, 'lost', isTablet),
                      _buildItemsList(_foundItemsNotifier, 'found', isTablet),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildCreateFAB(isTablet), // Pass isTablet parameter
    ),
  );
}
  

  Widget _buildHeader(bool isTablet) {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth > 600;
  
  return Container(
    padding: EdgeInsets.fromLTRB(
      isTablet ? 32 : 20, 
      isTablet ? 24 : 20, 
      isTablet ? 32 : 20, 
      isTablet ? 20 : 16
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.brown.shade900.withOpacity(0.3),
          Colors.transparent,
        ],
      ),
    ),
    child: Column(
      children: [
        Row(
          children: [
            // Back button - styled like NoLimits
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(isTablet ? 10 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                  border: Border.all(
                    color: Colors.brown.shade600.withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.shade600.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.brown.shade400,
                  size: isTablet ? 22 : 18,
                ),
              ),
            ),
            SizedBox(width: isTablet ? 20 : 16),
            Container(
              padding: EdgeInsets.all(isTablet ? 16 : 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.brown.shade700, Colors.brown.shade900],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.shade700.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.find_replace, 
                color: Colors.white, 
                size: isTablet ? 28 : 24
              ),
            ),
            SizedBox(width: isTablet ? 20 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [Colors.brown.shade400, Colors.brown.shade700],
                    ).createShader(bounds),
                    child: Text(
                      'lost & found',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: isTablet ? 28 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5
                      ),
                    ),
                  ),
                  Text(
                    'helping each other find what matters',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : 12,
                      color: Colors.brown.shade200,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.refresh, 
                color: Colors.brown.shade300,
                size: isTablet ? 28 : 24,
              ),
              onPressed: _loadItems,
            ),
          ],
        ),
        SizedBox(height: isTablet ? 20 : 16),
        _buildSearchBar(isTablet),
      ],
    ),
  );
}

  Widget _buildSearchBar(bool isTablet) {
  // final screenWidth = MediaQuery.of(context).size.width;
  // final isTablet = screenWidth > 600;
  
  return Container(
    height: isTablet ? 55 : 45,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: Colors.brown.shade800.withOpacity(0.3)),
    ),
    child: TextField(
      controller: _searchController,
      focusNode: _searchFocusNode, // Add this line
      style: GoogleFonts.poppins(
        color: Colors.white, 
        fontSize: isTablet ? 16 : 14
      ),
      decoration: InputDecoration(
        hintText: 'Search lost or found items...',
        hintStyle: GoogleFonts.poppins(color: Colors.white38),
        prefixIcon: Icon(
          Icons.search, 
          color: Colors.brown.shade300, 
          size: isTablet ? 24 : 20
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 24 : 20, 
          vertical: isTablet ? 16 : 12
        ),
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value.toLowerCase();
          _isSearching = value.isNotEmpty;
        });
      },
    ),
  );
}
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.brown.shade900.withOpacity(0.3),
            Colors.brown.shade800.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.brown.shade700.withOpacity(0.3)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.brown.shade600, Colors.brown.shade800],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.shade600.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.brown.shade300,
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 18),
                SizedBox(width: 8),
                Text('Lost'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 18),
                SizedBox(width: 8),
                Text('Found'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList(ValueNotifier<List<Map<String, dynamic>>> itemsNotifier, String type, bool isTablet) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(color: Colors.brown.shade600),
          );
        }

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: itemsNotifier,
          builder: (context, items, child) {
            var visibleItems = items;

            if (_isSearching) {
              visibleItems = items.where((item) {
                final title = (item['title'] ?? '').toString().toLowerCase();
                final description = (item['description'] ?? '').toString().toLowerCase();
                final username = (item['username'] ?? '').toString().toLowerCase();
                final location = (item['location'] ?? '').toString().toLowerCase();
                
                return title.contains(_searchQuery) ||
                       description.contains(_searchQuery) ||
                       username.contains(_searchQuery) ||
                       location.contains(_searchQuery);
              }).toList();
            }

            if (visibleItems.isEmpty) {
              return _buildEmptyState(type);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleItems.length,
              itemBuilder: (context, index) {
                final item = visibleItems[index];
                print('Rendering item $index: ${item['title']} (${item['type']})');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LostFoundCard(
                    item: item,
                    currentUserId: widget.userId,
                    currentUserRole: widget.userRole,
                    onDelete: () => _deleteItem(item['id']),
                    communityId: widget.communityId,
                    getUserProfileImage: _getUserProfileImage,
                    onNavigateToContact: _dismissKeyboard,
                    isTablet: isTablet, 
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            type == 'lost' ? Icons.search_off : Icons.search,
            color: Colors.brown.shade300,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${type} items',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            type == 'lost' 
              ? 'Be the first to report a lost item!'
              : 'Be the first to report a found item!',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white60),
          ),
          const SizedBox(height: 20),
          // Debug button - remove this after testing
          ElevatedButton(
            onPressed: () {
              print('Debug: Forcing reload...');
              _loadItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.brown.shade600,
            ),
            child: Text(
              'Debug: Reload Data',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateFAB(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [Colors.brown.shade600, Colors.brown.shade800],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade600.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () async {
          _dismissKeyboard();
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateLostFoundPage(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
          if (result == true) {
            _loadItems();
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Text(
          'report item',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }
}

class LostFoundCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback onDelete;
  final String communityId;
  final Future<String?> Function(String username) getUserProfileImage;
  final VoidCallback onNavigateToContact;
  final bool isTablet; 

  const LostFoundCard({
    Key? key,
    required this.item,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onDelete,
    required this.communityId,
    required this.getUserProfileImage,
    required this.onNavigateToContact,
    required this.isTablet,
  }) : super(key: key);

  bool get _canDelete {
    return item['userId'] == currentUserId || 
           ['admin', 'manager', 'moderator'].contains(currentUserRole);
  }

  @override
  Widget build(BuildContext context) {
    final isLost = item['type'] == 'lost';
    final createdAt = item['createdAt'] != null 
        ? (item['createdAt'] as Timestamp).toDate() 
        : DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.brown.shade900.withOpacity(0.2),
              Colors.brown.shade800.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLost 
              ? Colors.red.shade500.withOpacity(0.3)
              : Colors.green.shade500.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and type
Row(
  children: [
    Expanded(
      child: Row(
        children: [
          FutureBuilder<String?>(
            future: getUserProfileImage(item['username'] ?? ''),
            builder: (context, snapshot) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isTablet = screenWidth > 600;
              final avatarSize = isTablet ? 24.0 : 20.0;
              
              if (snapshot.hasData && snapshot.data != null) {
                return CircleAvatar(
                  radius: avatarSize,
                  backgroundImage: NetworkImage(snapshot.data!),
                  backgroundColor: Colors.brown.shade600,
                  onBackgroundImageError: (exception, stackTrace) {},
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? SizedBox(
                          width: isTablet ? 20 : 16,
                          height: isTablet ? 20 : 16,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : null,
                );
              } else {
                return CircleAvatar(
                  radius: avatarSize,
                  backgroundColor: Colors.brown.shade600,
                  child: Text(
                    item['username']?.toString().substring(0, 1).toUpperCase() ?? 'U',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                );
              }
            },
          ),
          SizedBox(width: MediaQuery.of(context).size.width > 600 ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Changed: firstName, lastName with username styling (primary)
                Text(
                  '${item['firstName'] ?? ''} ${item['lastName'] ?? ''}'.trim(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                // Changed: username with firstName, lastName styling and @ prefix (secondary)
                Text(
                  '@${item['username'] ?? 'Unknown'}',
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: MediaQuery.of(context).size.width > 600 ? 14 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width > 600 ? 12 : 8),
          // Branch and Year badges - horizontal layout with the updated FutureBuilder above
          FutureBuilder<DocumentSnapshot?>(
            future: FirebaseFirestore.instance
                .collection('communities')
                .doc(communityId)
                .collection('trio')
                .where('username', isEqualTo: item['username'])
                .limit(1)
                .get()
                .then((query) async {
                  if (query.docs.isNotEmpty) return query.docs.first;
                  final membersQuery = await FirebaseFirestore.instance
                      .collection('communities')
                      .doc(communityId)
                      .collection('members')
                      .where('username', isEqualTo: item['username'])
                      .limit(1)
                      .get();
                  return membersQuery.docs.isNotEmpty ? membersQuery.docs.first : null;
                }),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                final screenWidth = MediaQuery.of(context).size.width;
                final isTablet = screenWidth > 600;
                
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (userData['branch']?.toString().isNotEmpty == true)
                      Container(
                        margin: EdgeInsets.only(right: isTablet ? 6 : 4),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : 6, 
                          vertical: isTablet ? 3 : 2
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.brown.shade700, Colors.brown.shade800],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.school, 
                              color: Colors.white, 
                              size: isTablet ? 12 : 10
                            ),
                            SizedBox(width: isTablet ? 4 : 3),
                            Text(
                              userData['branch'].toString(),
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 11 : 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (userData['year']?.toString().isNotEmpty == true)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : 6, 
                          vertical: isTablet ? 3 : 2
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.brown.shade600, Colors.brown.shade700],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today, 
                              color: Colors.white, 
                              size: isTablet ? 12 : 10
                            ),
                            SizedBox(width: isTablet ? 4 : 3),
                            Text(
                              '${userData['year']}',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 11 : 9,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    ),
    // Better positioned Lost/Found tag and menu
    Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.width > 600 ? 8 : 6),
          padding: EdgeInsets.symmetric(
            horizontal: MediaQuery.of(context).size.width > 600 ? 10 : 8, 
            vertical: MediaQuery.of(context).size.width > 600 ? 5 : 4
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isLost 
                ? [Colors.red.shade600, Colors.red.shade800]
                : [Colors.green.shade600, Colors.green.shade800],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: (isLost ? Colors.red.shade600 : Colors.green.shade600).withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLost ? Icons.search_off : Icons.search,
                color: Colors.white,
                size: MediaQuery.of(context).size.width > 600 ? 14 : 12,
              ),
              SizedBox(width: MediaQuery.of(context).size.width > 600 ? 5 : 4),
              Text(
                isLost ? 'LOST' : 'FOUND',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width > 600 ? 12 : 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        if (_canDelete)
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert, 
              color: Colors.white60,
              size: MediaQuery.of(context).size.width > 600 ? 24 : 20,
            ),
            color: const Color(0xFF1A0F08),
            onSelected: (value) {
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete, 
                      color: Colors.red, 
                      size: MediaQuery.of(context).size.width > 600 ? 20 : 18
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width > 600 ? 10 : 8),
                    Text(
                      'Delete', 
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14,
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    ),
  ],
),

            const SizedBox(height: 16),

            // Title
            Text(
              item['title'] ?? '',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            if (item['description'] != null && item['description'].toString().isNotEmpty)
              Container(
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
                  border: Border.all(color: Colors.brown.shade700.withOpacity(0.2)),
                ),
                child: Text(
                  item['description'],
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Photo if available
            if (item['photoUrl'] != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.brown.shade700.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    item['photoUrl'],
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.brown.shade900.withOpacity(0.2),
                        child: Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.brown.shade400,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            
            // Location and date
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.brown.shade700.withOpacity(0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.brown.shade400,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Location:',
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['location'] ?? 'Not specified',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.brown.shade700.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.brown.shade400,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Posted:',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Contact button
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  onNavigateToContact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ContactLostFoundPage(
                        item: item,
                        communityId: communityId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.brown.shade600, Colors.brown.shade800],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.shade600.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.contact_phone, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Contact ${item['firstName'] ?? 'User'}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}