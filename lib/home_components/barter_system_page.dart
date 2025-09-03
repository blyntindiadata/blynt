import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/create_barter_page.dart';
import 'contact_barter.dart';

class BarterSystemPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const BarterSystemPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  }) : super(key: key);

  @override
  State<BarterSystemPage> createState() => _BarterSystemPageState();
}

class _BarterSystemPageState extends State<BarterSystemPage> with TickerProviderStateMixin {
  final ValueNotifier<List<Map<String, dynamic>>> _bartersNotifier = ValueNotifier([]);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(true);
  final ValueNotifier<Set<String>> _removedBartersNotifier = ValueNotifier({});
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isSearching = false;
  String _searchQuery = '';

  final Map<String, String?> _userProfileImages = {};

  @override
  void initState() {
    super.initState();
    _loadBarters();
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
    _bartersNotifier.dispose();
    _isLoadingNotifier.dispose();
    _removedBartersNotifier.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    _searchFocusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Future<void> _approvePriority(String barterId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update the barter
      final barterRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('barters')
          .doc(barterId);
      
      batch.update(barterRef, {
        'priorityApproved': true,
        'isPriority': true,
      });

      // Update the priority request if it exists
      final priorityQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('priority_requests')
          .where('barterId', isEqualTo: barterId)
          .where('processed', isEqualTo: false)
          .get();

      for (var doc in priorityQuery.docs) {
        batch.update(doc.reference, {
          'processed': true,
          'approved': true,
          'processedBy': widget.userId,
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _loadBarters(); // Refresh the list

      if (mounted) {
        _showMessage('Priority approved successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error approving priority: $e', isError: true);
      }
    }
  }

  Future<void> _rejectPriority(String barterId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Update the barter (keep as normal barter)
      final barterRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('barters')
          .doc(barterId);
      
      batch.update(barterRef, {
        'isPriority': false,
        'priorityApproved': false,
      });

      // Update the priority request if it exists
      final priorityQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('priority_requests')
          .where('barterId', isEqualTo: barterId)
          .where('processed', isEqualTo: false)
          .get();

      for (var doc in priorityQuery.docs) {
        batch.update(doc.reference, {
          'processed': true,
          'approved': false,
          'processedBy': widget.userId,
          'processedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _loadBarters(); // Refresh the list

      if (mounted) {
        _showMessage('Priority request rejected');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error rejecting priority: $e', isError: true);
      }
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
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  Future<void> _loadBarters() async {
    try {
      _isLoadingNotifier.value = true;
      
      // Simplified query - only order by createdAt for now
      // We'll sort priority and pinned items in code
      final snapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('barters')
          .orderBy('createdAt', descending: true)
          .get();

      final barters = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Debug print to see what data we're getting
        print('Barter data: $data');
        
        // Check if deadline exists and is valid
        if (data['deadline'] != null) {
          try {
            final deadline = (data['deadline'] as Timestamp).toDate();
            
            // Only include barters that haven't expired (with some buffer)
            if (deadline.isAfter(now.subtract(const Duration(hours: 1)))) {
              barters.add({
                'id': doc.id,
                ...data,
              });
            }
          } catch (e) {
            print('Error parsing deadline for barter ${doc.id}: $e');
            // Include barter even if deadline parsing fails
            barters.add({
              'id': doc.id,
              ...data,
            });
          }
        } else {
          // Include barters without deadline
          barters.add({
            'id': doc.id,
            ...data,
          });
        }
      }

      // Sort in memory: Priority first, then Pinned, then by creation date
     barters.sort((a, b) {
  // First, check priority status
  final aPriority = (a['isPriority'] == true && a['priorityApproved'] == true) ? 1 : 0;
  final bPriority = (b['isPriority'] == true && b['priorityApproved'] == true) ? 1 : 0;
  
  if (aPriority != bPriority) {
    return bPriority.compareTo(aPriority); // Priority items first
  }
  
  // Then check pinned status
  final aPinned = (a['isPinned'] == true) ? 1 : 0;
  final bPinned = (b['isPinned'] == true) ? 1 : 0;
  
  if (aPinned != bPinned) {
    return bPinned.compareTo(aPinned); // Pinned items first
  }
  
  // Then sort by time remaining (urgent deadlines first)
  final aDeadline = a['deadline'] != null ? (a['deadline'] as Timestamp).toDate() : null;
  final bDeadline = b['deadline'] != null ? (b['deadline'] as Timestamp).toDate() : null;
  
  // If both have deadlines, sort by deadline (earliest first)
  if (aDeadline != null && bDeadline != null) {
    return aDeadline.compareTo(bDeadline); // Earliest deadline first
  }
  
  // If only one has deadline, prioritize the one with deadline
  if (aDeadline != null && bDeadline == null) {
    return -1; // a comes first (has deadline)
  }
  if (aDeadline == null && bDeadline != null) {
    return 1; // b comes first (has deadline)
  }
  
  // Finally, if neither has deadline, sort by creation date (most recent first)
  final aTime = a['createdAt'] as Timestamp?;
  final bTime = b['createdAt'] as Timestamp?;
  
  if (aTime != null && bTime != null) {
    return bTime.compareTo(aTime); // Most recent first
  }
  
  return 0;
});

      print('Loaded ${barters.length} barters');
      _bartersNotifier.value = barters;
    } catch (e) {
      print('Error loading barters: $e');
      // Show error message to user
      if (mounted) {
        _showMessage('Error loading barters: $e', isError: true);
      }
    } finally {
      _isLoadingNotifier.value = false;
    }
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
      _userProfileImages[username] = profileImageUrl; // Cache it
      return profileImageUrl;
    } catch (e) {
      print('Error fetching profile image for $username: $e');
      _userProfileImages[username] = null; // Cache null result
      return null;
    }
  }

  Future<void> _deleteBarter(String barterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('barters')
          .doc(barterId)
          .delete();

      _loadBarters();
      
      if (mounted) {
        _showMessage('Barter deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error deleting barter: $e', isError: true);
      }
    }
  }

  Future<void> _togglePinBarter(String barterId, bool currentPinStatus) async {
  try {
    // If trying to pin a barter, check current pin count
    if (!currentPinStatus) {
      final pinnedCount = _bartersNotifier.value
          .where((barter) => barter['isPinned'] == true)
          .length;
      
      if (pinnedCount >= 3) {
        _showMessage('Maximum 3 barters can be pinned at a time', isError: true);
        return;
      }
    }
    
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('barters')
        .doc(barterId)
        .update({'isPinned': !currentPinStatus});

    _loadBarters();
  } catch (e) {
    print('Error toggling pin: $e');
  }
}

  // Fixed remove method - now permanently deletes from database
  Future<void> _removeBarter(String barterId) async {
    try {
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('barters')
          .doc(barterId)
          .delete();

      _loadBarters();
      
      if (mounted) {
        _showMessage('Barter removed successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Error removing barter: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A4A00), // Green base like NoLimits
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2D5A00), // Dark green
                const Color(0xFF1A4A00), // Medium green
                const Color(0xFF0D2A00), // Darker green
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildHeader(isTablet),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildBartersList(isTablet),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: _buildCreateFAB(isTablet),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 32 : 20, 
        isTablet ? 24 : 20, 
        isTablet ? 32 : 20, 
        isTablet ? 20 : 16
      ),
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //     colors: [
      //       Colors.green.shade900.withOpacity(0.3),
      //       Colors.transparent,
      //     ],
      //   ),
      // ),
      child: Column(
        children: [
          Row(
            children: [
              // Better back button for iOS/Android
            GestureDetector(
  onTap: () {
    _dismissKeyboard();
    Navigator.pop(context);
  },
  child: Container(
    padding: EdgeInsets.all(isTablet ? 10 : 8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
      border: Border.all(
        color: Colors.green.shade600.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.green.shade600.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      Icons.arrow_back_ios_new,
      color: Colors.green.shade400,
      size: isTablet ? 22 : 18,
    ),
  ),
),
              SizedBox(width: isTablet ? 20 : 16),
              Container(
                padding: EdgeInsets.all(isTablet ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade700, Colors.green.shade900],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade700.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.swap_horiz, 
                  color: Colors.white, 
                  size: isTablet ? 28 : 24
                ),
              ),
              SizedBox(width: isTablet ? 20 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.green.shade400, Colors.green.shade700],
                      ).createShader(bounds),
                      child: Text(
                        'barter? hell yeah',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: isTablet ? 28 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                    Text(
                      'back to the ancient times',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 14 : 12,
                        color: Colors.green.shade200,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      _dismissKeyboard();
                      _loadBarters();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.refresh, 
                        color: Colors.green.shade300,
                        size: isTablet ? 28 : 24,
                      ),
                    ),
                  ),
                ),
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
    return Container(
      height: isTablet ? 55 : 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.green.shade800.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: GoogleFonts.poppins(
          color: Colors.white, 
          fontSize: isTablet ? 16 : 14
        ),
        decoration: InputDecoration(
          hintText: 'search...',
          hintStyle: GoogleFonts.poppins(color: Colors.white38),
          prefixIcon: Icon(
            Icons.search, 
            color: Colors.green.shade300, 
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

  Widget _buildBartersList(bool isTablet) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        if (isLoading) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.green.shade600,
              strokeWidth: isTablet ? 4 : 3,
            ),
          );
        }

        return ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: _bartersNotifier,
          builder: (context, barters, child) {
            return ValueListenableBuilder<Set<String>>(
              valueListenable: _removedBartersNotifier,
              builder: (context, removedBarters, child) {
                var visibleBarters = barters.where((barter) => 
                  !removedBarters.contains(barter['id'])).toList();

                if (_isSearching) {
                  visibleBarters = visibleBarters.where((barter) {
                    final request = (barter['request'] ?? '').toString().toLowerCase();
                    final username = (barter['username'] ?? '').toString().toLowerCase();
                    final offer = (barter['serviceOffer'] ?? '').toString().toLowerCase();
                    
                    return request.contains(_searchQuery) ||
                           username.contains(_searchQuery) ||
                           offer.contains(_searchQuery);
                  }).toList();
                }

                if (visibleBarters.isEmpty) {
                  return _buildEmptyState(isTablet);
                }

                return ListView.builder(
                  padding: EdgeInsets.all(isTablet ? 24 : 16),
                  itemCount: visibleBarters.length,
                  itemBuilder: (context, index) {
                    final barter = visibleBarters[index];
                    return BarterCard(
                      barter: barter,
                      currentUserId: widget.userId,
                      currentUserRole: widget.userRole,
                      onRemove: () => _removeBarter(barter['id']),
                      onDelete: () => _deleteBarter(barter['id']),
                      onPin: () => _togglePinBarter(barter['id'], barter['isPinned'] ?? false),
                      onApprovePriority: () => _approvePriority(barter['id']),
                      onRejectPriority: () => _rejectPriority(barter['id']),
                      communityId: widget.communityId,
                      getUserProfileImage: _getUserProfileImage,
                      isTablet: isTablet,
                      onNavigateToContact: _dismissKeyboard,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool isTablet) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
      final availableHeight = constraints.maxHeight;
      
      // Adaptive sizing for landscape mode
      final iconSize = isLandscape 
          ? (isTablet ? 48.0 : 40.0)
          : (isTablet ? 80.0 : 64.0);
      final spacing = isLandscape 
          ? (isTablet ? 12.0 : 10.0) 
          : (isTablet ? 20.0 : 16.0);
      final titleSize = isLandscape 
          ? (isTablet ? 18.0 : 16.0) 
          : (isTablet ? 22.0 : 18.0);
      final subtitleSize = isLandscape 
          ? (isTablet ? 12.0 : 10.0) 
          : (isTablet ? 16.0 : 14.0);
      
      return Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: availableHeight > 200 ? 150 : availableHeight * 0.8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz, 
                  color: Colors.green.shade300, 
                  size: iconSize
                ),
                SizedBox(height: spacing),
                Text(
                  'No barters available',
                  style: GoogleFonts.poppins(
                    fontSize: titleSize,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: spacing / 2),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
                  child: Text(
                    'Be the first to create a barter!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: subtitleSize, 
                      color: Colors.white60
                    ),
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

  Widget _buildCreateFAB(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade800],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade600.withOpacity(0.4),
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
              builder: (context) => CreateBarterPage(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
          if (result == true) {
            _loadBarters();
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Text(
          'create barter',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: Icon(
          Icons.add,
          color: Colors.white,
          size: isTablet ? 24 : 20,
        ),
      ),
    );
  }
}

class BarterCard extends StatelessWidget {
  final Map<String, dynamic> barter;
  final String currentUserId;
  final String currentUserRole;
  final VoidCallback onRemove;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onApprovePriority;
  final VoidCallback onRejectPriority;
  final String communityId;
  final Future<String?> Function(String username) getUserProfileImage;
  final bool isTablet;
  final VoidCallback onNavigateToContact;

  const BarterCard({
    Key? key,
    required this.barter,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onRemove,
    required this.onDelete,
    required this.onPin,
    required this.onApprovePriority,
    required this.onRejectPriority,
    required this.communityId,
    required this.getUserProfileImage,
    required this.isTablet,
    required this.onNavigateToContact,
  }) : super(key: key);

  bool get _canDelete {
    return barter['userId'] == currentUserId || 
           ['admin', 'manager', 'moderator'].contains(currentUserRole);
  }

  bool get _canPin {
    return ['admin', 'manager', 'moderator'].contains(currentUserRole);
  }

  bool get _canApprovePriority {
    return ['admin', 'manager', 'moderator'].contains(currentUserRole);
  }

  @override
  Widget build(BuildContext context) {
    final isPriority = barter['isPriority'] == true && barter['priorityApproved'] == true;
    final isPendingPriority = barter['isPriority'] == true && barter['priorityApproved'] != true;
    final isPinned = barter['isPinned'] == true;
    final deadline = barter['deadline'] != null ? (barter['deadline'] as Timestamp).toDate() : null;
    final daysLeft = deadline?.difference(DateTime.now()).inDays ?? 0;

    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 20 : 16),
      child: Stack(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.green.shade900.withOpacity(0.2),
                  Colors.green.shade800.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPinned
                  ? Colors.blue.shade500.withOpacity(0.5)
                  : isPendingPriority
                    ? Colors.orange.shade500.withOpacity(0.5)
                    : Colors.green.shade700.withOpacity(0.3),
                width: isPinned || isPendingPriority ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isPinned
                    ? Colors.blue.shade500.withOpacity(0.2)
                    : isPendingPriority
                      ? Colors.orange.shade500.withOpacity(0.2)
                      : Colors.black26,
                  blurRadius: isPinned || isPendingPriority ? 12 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with user info and tags
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          FutureBuilder<String?>(
                            future: getUserProfileImage(barter['username'] ?? ''),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return CircleAvatar(
                                  radius: isTablet ? 24 : 20,
                                  backgroundImage: NetworkImage(snapshot.data!),
                                  backgroundColor: Colors.green.shade600,
                                  onBackgroundImageError: (exception, stackTrace) {
                                    // Handle image load error - will show fallback
                                  },
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
                                // Fallback to text avatar
                                return CircleAvatar(
                                  radius: isTablet ? 24 : 20,
                                  backgroundColor: Colors.green.shade600,
                                  child: Text(
                                    barter['username']?.toString().substring(0, 1).toUpperCase() ?? 'U',
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
                          SizedBox(width: isTablet ? 16 : 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Changed: firstName, lastName with username styling
                                Text(
                                  '${barter['firstName'] ?? ''} ${barter['lastName'] ?? ''}'.trim(),
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    fontSize: isTablet ? 18 : 16,
                                  ),
                                ),
                                // Changed: username with firstName, lastName styling and @ prefix
                                Text(
                                  '@${barter['username'] ?? 'Unknown'}',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white60,
                                    fontSize: isTablet ? 14 : 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: isTablet ? 12 : 8),
                          FutureBuilder<DocumentSnapshot?>(
                            future: () async {
                              try {
                                // Check trio collection first
                                final trioQuery = await FirebaseFirestore.instance
                                    .collection('communities')
                                    .doc(communityId)
                                    .collection('trio')
                                    .where('username', isEqualTo: barter['username'])
                                    .limit(1)
                                    .get();
                                
                                if (trioQuery.docs.isNotEmpty) {
                                  return trioQuery.docs.first;
                                }
                                
                                // Check members collection
                                final membersQuery = await FirebaseFirestore.instance
                                    .collection('communities')
                                    .doc(communityId)
                                    .collection('members')
                                    .where('username', isEqualTo: barter['username'])
                                    .limit(1)
                                    .get();
                                
                                if (membersQuery.docs.isNotEmpty) {
                                  return membersQuery.docs.first;
                                }
                                
                                return null;
                              } catch (e) {
                                print('Error fetching user data: $e');
                                return null;
                              }
                            }(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data!.exists) {
                                final userData = snapshot.data!.data() as Map<String, dynamic>;
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Changed: Made branch and year horizontal
                                    if (userData['branch']?.toString().isNotEmpty == true)
                                      Container(
                                        margin: EdgeInsets.only(right: isTablet ? 6 : 4),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isTablet ? 8 : 6, 
                                          vertical: isTablet ? 3 : 2
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.green.shade700, Colors.green.shade800],
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
                                            colors: [Colors.green.shade600, Colors.green.shade700],
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
                    // Fixed alignment - wrapped in Column to maintain consistent alignment
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // if (isPinned)
                            //   Container(
                            //     margin: EdgeInsets.only(right: isTablet ? 10 : 8),
                            //     padding: EdgeInsets.symmetric(
                            //       horizontal: isTablet ? 10 : 8, 
                            //       vertical: isTablet ? 5 : 4
                            //     ),
                            //     decoration: BoxDecoration(
                            //       gradient: const LinearGradient(
                            //         colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                            //       ),
                            //       borderRadius: BorderRadius.circular(8),
                            //     ),
                            //     child: Row(
                            //       mainAxisSize: MainAxisSize.min,
                            //       children: [
                            //         Icon(
                            //           Icons.push_pin, 
                            //           color: Colors.white, 
                            //           size: isTablet ? 14 : 12
                            //         ),
                            //         SizedBox(width: isTablet ? 5 : 4),
                            //         Text(
                            //           'PINNED',
                            //           style: GoogleFonts.poppins(
                            //             fontSize: isTablet ? 12 : 10,
                            //             fontWeight: FontWeight.w700,
                            //             color: Colors.white,
                            //             letterSpacing: 0.5,
                            //           ),
                            //         ),
                            //       ],
                            //     ),
                            //   ),
                            if (isPendingPriority)
                              Container(
                                margin: EdgeInsets.only(right: isTablet ? 10 : 8),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 10 : 8, 
                                  vertical: isTablet ? 5 : 4
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.orange, Colors.deepOrange],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pending, 
                                      color: Colors.white, 
                                      size: isTablet ? 14 : 12
                                    ),
                                    SizedBox(width: isTablet ? 5 : 4),
                                    Text(
                                      'PENDING',
                                      style: GoogleFonts.poppins(
                                        fontSize: isTablet ? 12 : 10,
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
                                  size: isTablet ? 24 : 20,
                                ),
                                color: const Color(0xFF2A4A00),
                                onSelected: (value) {
                                  if (value == 'delete') onDelete();
                                  // if (value == 'pin') onPin();
                                },
                                itemBuilder: (context) => [
                                  if (_canDelete)
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete, 
                                            color: Colors.red, 
                                            size: isTablet ? 20 : 18
                                          ),
                                          SizedBox(width: isTablet ? 10 : 8),
                                          Text(
                                            'Delete', 
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: isTablet ? 16 : 14,
                                            )
                                          ),
                                        ],
                                      ),
                                    ),
                                  // if (_canPin)
                                  //   PopupMenuItem(
                                  //     value: 'pin',
                                  //     child: Row(
                                  //       // children: [
                                  //       //   Icon(
                                  //       //     isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                  //       //     color: Colors.green.shade400,
                                  //       //     size: isTablet ? 20 : 18,
                                  //       //   ),
                                  //       //   SizedBox(width: isTablet ? 10 : 8),
                                  //       //   Text(
                                  //       //     isPinned ? 'Unpin' : 'Pin',
                                  //       //     style: GoogleFonts.poppins(
                                  //       //       color: Colors.white,
                                  //       //       fontSize: isTablet ? 16 : 14,
                                  //       //     ),
                                  //       //   ),
                                  //       // ],
                                  //     ),
                                  //   ),
                                ],
                              ),
                          ],
                        ),
                        if (_canApprovePriority && isPendingPriority)
                          Container(
                            margin: EdgeInsets.only(top: isTablet ? 10 : 8),
                            child: PopupMenuButton<String>(
                              icon: Container(
                                padding: EdgeInsets.all(isTablet ? 6 : 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.pending, 
                                  color: Colors.orange, 
                                  size: isTablet ? 18 : 16
                                ),
                              ),
                              color: const Color(0xFF2A4A00),
                              onSelected: (value) {
                                if (value == 'approve') {
                                  onApprovePriority();
                                } else if (value == 'reject') {
                                  onRejectPriority();
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'approve',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle, 
                                        color: Colors.green, 
                                        size: isTablet ? 20 : 18
                                      ),
                                      SizedBox(width: isTablet ? 10 : 8),
                                      Text(
                                        'Approve Priority', 
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: isTablet ? 16 : 14,
                                        )
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'reject',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cancel, 
                                        color: Colors.red, 
                                        size: isTablet ? 20 : 18
                                      ),
                                      SizedBox(width: isTablet ? 10 : 8),
                                      Text(
                                        'Reject Priority', 
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: isTablet ? 16 : 14,
                                        )
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
                ),

                SizedBox(height: isTablet ? 20 : 16),

                // Request description
                Text(
                  'Needs:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade400,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade700.withOpacity(0.2)),
                  ),
                  child: Text(
                    barter['request'] ?? '',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: isTablet ? 16 : 14,
                      height: 1.4,
                    ),
                  ),
                ),

                SizedBox(height: isTablet ? 16 : 12),

                // Offer description - Changed colors
                Text(
                  'Offers:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color.fromARGB(255, 128, 188, 71), // Changed from amber to purple
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withOpacity(0.08), // Changed from amber to purple
                        Colors.purple.withOpacity(0.05), // Changed from amber to purple
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade700.withOpacity(0.2)), // Changed from amber to purple
                  ),
                  child: barter['offerType'] == 'money'
                    ? Row(
                        children: [
                          Icon(
                            Icons.currency_rupee, 
                            color: const Color.fromARGB(255, 128, 188, 71),// Changed from amber to purple
                            size: isTablet ? 20 : 18
                          ),
                          Text(
                            barter['moneyAmount']?.toString() ?? '0',
                            style: GoogleFonts.poppins(
                              color: const Color.fromARGB(255, 128, 188, 71), // Changed from amber to purple
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        barter['serviceOffer'] ?? '',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: isTablet ? 16 : 14,
                          height: 1.4,
                        ),
                      ),
                ),

                SizedBox(height: isTablet ? 20 : 16),

                // Deadline and action buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.shade700.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule,
                                  color: deadline != null && daysLeft <= 2 ? Colors.red.shade400 : Colors.green.shade400,
                                  size: isTablet ? 18 : 16,
                                ),
                                SizedBox(width: isTablet ? 8 : 6),
                                Text(
                                  'Deadline:',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: isTablet ? 14 : 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isTablet ? 6 : 4),
                            Text(
                              deadline != null 
                                  ? '${deadline.day}/${deadline.month}/${deadline.year}'
                                  : 'No deadline',
                              style: GoogleFonts.poppins(
                                color: deadline != null && daysLeft <= 2 ? Colors.red.shade400 : Colors.white,
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (deadline != null && daysLeft >= 0)
                              Container(
                                margin: EdgeInsets.only(top: isTablet ? 6 : 4),
                                padding: EdgeInsets.symmetric(
                                  horizontal: isTablet ? 8 : 6, 
                                  vertical: isTablet ? 3 : 2
                                ),
                                decoration: BoxDecoration(
                                  color: daysLeft <= 2 
                                    ? Colors.red.shade500.withOpacity(0.2) 
                                    : Colors.green.shade500.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$daysLeft days left',
                                  style: GoogleFonts.poppins(
                                    color: daysLeft <= 2 ? Colors.red.shade300 : Colors.green.shade300,
                                    fontSize: isTablet ? 12 : 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Column(
                      children: [
                        GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 20 : 16, 
                              vertical: isTablet ? 12 : 10
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.red.withOpacity(0.8), Colors.red.withOpacity(0.6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.remove_circle_outline, 
                                  color: Colors.white, 
                                  size: isTablet ? 18 : 16
                                ),
                                SizedBox(width: isTablet ? 8 : 6),
                                Text(
                                  'Remove',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: isTablet ? 14 : 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: isTablet ? 10 : 8),
                        GestureDetector(
                          onTap: () {
                            onNavigateToContact(); // Dismiss keyboard before navigation
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContactBarterPage(
                                  barter: barter,
                                  communityId: communityId
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 20 : 16, 
                              vertical: isTablet ? 12 : 10
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green.shade600, Colors.green.shade800],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.shade600.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.contact_phone, 
                                  color: Colors.white, 
                                  size: isTablet ? 18 : 16
                                ),
                                SizedBox(width: isTablet ? 8 : 6),
                                Text(
                                  'Contact',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: isTablet ? 14 : 12,
                                    fontWeight: FontWeight.w600,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String getDisplayName(Map<String, dynamic>? userData) {
  if (userData == null) return 'Unknown User';
  
  final bool isDeleted = userData['accountDeleted'] == true;
  if (isDeleted) return 'Deleted Account';
  
  final firstName = userData['firstName'] ?? '';
  final lastName = userData['lastName'] ?? '';
  
  if (firstName.isEmpty && lastName.isEmpty) return 'Unknown User';
  return '$firstName $lastName'.trim();
}

String getDisplayUsername(Map<String, dynamic>? userData) {
  if (userData == null) return 'unknown';
  
  final bool isDeleted = userData['accountDeleted'] == true;
  if (isDeleted) return 'deleted_account';
  
  return userData['username'] ?? 'unknown';
}

Widget buildUserAvatar(Map<String, dynamic>? userData, {double size = 40}) {
  final bool isDeleted = userData?['accountDeleted'] == true;
  
  if (isDeleted) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade600,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_off,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }
  
  // Your existing avatar logic
  final profileUrl = userData?['profileImageUrl'];
  final name = getDisplayName(userData);
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
  
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFFF7B42C), width: 1),
    ),
    child: profileUrl != null
        ? ClipOval(
            child: Image.network(
              profileUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildInitialAvatar(initial, size),
            ),
          )
        : _buildInitialAvatar(initial, size),
  );
}

Widget _buildInitialAvatar(String initial, double size) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFF7B42C), Color(0xFFFFD700)]),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.4,
        ),
      ),
    ),
  );
}