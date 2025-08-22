import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_screen.dart';

class ManageMembersPage extends StatefulWidget {
  final String communityId;
  final String currentUserId;
  final String currentUserRole;

  const ManageMembersPage({
    super.key,
    required this.communityId,
    required this.currentUserId,
    required this.currentUserRole,
  });

  @override
  State<ManageMembersPage> createState() => _ManageMembersPageState();
}

class _ManageMembersPageState extends State<ManageMembersPage> with TickerProviderStateMixin {
  bool isProcessing = false;
  String searchQuery = '';
  
  // Tab controllers for hierarchical filtering
  late TabController _yearTabController;
  late TabController _branchTabController;
  
  // Animation controllers
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  List<String> availableYears = ['All'];
  List<String> availableBranches = ['All'];
  String currentUsername = '';
  
  // Current selections
  String selectedYear = 'All';
  String selectedBranch = 'All';
  
  // Member counts for each filter
  Map<String, int> yearCounts = {};
  Map<String, int> branchCounts = {};

  bool get isAdmin => widget.currentUserRole == 'admin';
  bool get isModerator => widget.currentUserRole == 'moderator';

  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
    _initAnimations();
    _loadAvailableFilters();
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
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
  }

  @override
  void dispose() {
    _yearTabController.dispose();
    _branchTabController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUsername() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUserId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          currentUsername = data['username'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading current username: $e');
    }
  }

  Future<void> _loadAvailableFilters() async {
    try {
      Set<String> years = {};
      Set<String> branches = {};
      Map<String, int> tempYearCounts = {'All': 0};
      Map<String, int> tempBranchCounts = {'All': 0};
      
      // Get unique years and branches from both collections
      final trioSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .get();
      
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .get();

      final allDocs = [...trioSnapshot.docs, ...membersSnapshot.docs];
      
      for (var doc in allDocs) {
        final data = doc.data();
        if (data['year'] != null && data['year'].toString().isNotEmpty) {
          final year = data['year'].toString();
          years.add(year);
          tempYearCounts[year] = (tempYearCounts[year] ?? 0) + 1;
        }
        if (data['branch'] != null && data['branch'].toString().isNotEmpty) {
          final branch = data['branch'].toString();
          branches.add(branch);
          tempBranchCounts[branch] = (tempBranchCounts[branch] ?? 0) + 1;
        }
        tempYearCounts['All'] = (tempYearCounts['All'] ?? 0) + 1;
        tempBranchCounts['All'] = (tempBranchCounts['All'] ?? 0) + 1;
      }

      setState(() {
        availableYears = ['All', ...years.toList()..sort()];
        availableBranches = ['All', ...branches.toList()..sort()];
        yearCounts = tempYearCounts;
        branchCounts = tempBranchCounts;
      });
      
      // Initialize tab controllers after we have the data
      _yearTabController = TabController(length: availableYears.length, vsync: this);
      _branchTabController = TabController(length: availableBranches.length, vsync: this);
      
      // Add listeners for tab changes
      _yearTabController.addListener(_onYearTabChanged);
      _branchTabController.addListener(_onBranchTabChanged);
      
    } catch (e) {
      print('Error loading filters: $e');
    }
  }

  void _onYearTabChanged() {
    if (_yearTabController.indexIsChanging) return;
    
    final newYear = availableYears[_yearTabController.index];
    if (newYear != selectedYear) {
      setState(() {
        selectedYear = newYear;
        selectedBranch = 'All'; // Reset branch when year changes
      });
      _loadBranchesForYear(newYear);
      _branchTabController.animateTo(0); // Reset to "All" branch
      _triggerPulseAnimation();
    }
  }

  void _onBranchTabChanged() {
    if (_branchTabController.indexIsChanging) return;
    
    final newBranch = availableBranches[_branchTabController.index];
    if (newBranch != selectedBranch) {
      setState(() {
        selectedBranch = newBranch;
      });
      _triggerPulseAnimation();
    }
  }

  void _triggerPulseAnimation() {
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }

  Future<void> _loadBranchesForYear(String year) async {
    if (year == 'All') {
      // Load all branches
      _loadAvailableFilters();
      return;
    }
    
    try {
      Set<String> branches = {};
      Map<String, int> tempBranchCounts = {'All': 0};
      
      // Get branches for specific year from both collections
      final trioSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('year', isEqualTo: year)
          .get();
      
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('year', isEqualTo: year)
          .get();

      final allDocs = [...trioSnapshot.docs, ...membersSnapshot.docs];
      
      for (var doc in allDocs) {
        final data = doc.data();
        if (data['branch'] != null && data['branch'].toString().isNotEmpty) {
          final branch = data['branch'].toString();
          branches.add(branch);
          tempBranchCounts[branch] = (tempBranchCounts[branch] ?? 0) + 1;
        }
        tempBranchCounts['All'] = (tempBranchCounts['All'] ?? 0) + 1;
      }

      setState(() {
        availableBranches = ['All', ...branches.toList()..sort()];
        branchCounts = tempBranchCounts;
      });
      
      // Update branch tab controller
      _branchTabController.dispose();
      _branchTabController = TabController(length: availableBranches.length, vsync: this);
      _branchTabController.addListener(_onBranchTabChanged);
      
    } catch (e) {
      print('Error loading branches for year: $e');
    }
  }

  // [Keep all the existing methods like _updateMemberRole, _removeMember, etc. - they remain unchanged]
  Future<void> _updateMemberRole(String memberUsername, String newRole) async {
    setState(() {
      isProcessing = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Find current member document and determine source collection
      DocumentSnapshot? currentDoc;
      String sourceCollection = '';
      
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: memberUsername)
          .limit(1)
          .get();
      
      if (trioQuery.docs.isNotEmpty) {
        currentDoc = trioQuery.docs.first;
        sourceCollection = 'trio';
      } else {
        // Check members collection
        final memberQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .where('username', isEqualTo: memberUsername)
            .limit(1)
            .get();
        
        if (memberQuery.docs.isNotEmpty) {
          currentDoc = memberQuery.docs.first;
          sourceCollection = 'members';
        }
      }

      if (currentDoc == null) {
        throw Exception('Member document not found');
      }

      final currentData = currentDoc.data() as Map<String, dynamic>;
      final currentRole = currentData['role'] as String;
      
      // Determine target collection based on new role
      String targetCollection = (newRole == 'admin' || newRole == 'moderator' || newRole == 'manager') 
          ? 'trio' 
          : 'members';
      
      // If collections are different, we need to transfer data
      if (sourceCollection != targetCollection) {
        // Create new document in target collection using username as ID
        final newDocRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection(targetCollection)
            .doc(memberUsername);
        
        // Prepare updated data
        final updatedData = Map<String, dynamic>.from(currentData);
        updatedData['role'] = newRole;
        updatedData['updatedAt'] = FieldValue.serverTimestamp();
        updatedData['updatedBy'] = currentUsername;
        updatedData['transferredFrom'] = sourceCollection;
        updatedData['transferredAt'] = FieldValue.serverTimestamp();
        
        // Add to target collection
        batch.set(newDocRef, updatedData);
        
        // Delete from source collection
        batch.delete(currentDoc.reference);
        
        // Log the transfer
        final transferLogRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('role_transfers')
            .doc();
        
        batch.set(transferLogRef, {
          'username': memberUsername,
          'fromRole': currentRole,
          'toRole': newRole,
          'fromCollection': sourceCollection,
          'toCollection': targetCollection,
          'transferredBy': currentUsername,
          'transferredAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Same collection, just update role
        batch.update(currentDoc.reference, {
          'role': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUsername,
        });
      }

      // Update global community_members collection
      final globalMemberQuery = await FirebaseFirestore.instance
          .collection('community_members')
          .where('username', isEqualTo: memberUsername)
          .where('communityId', isEqualTo: widget.communityId)
          .get();

      for (var doc in globalMemberQuery.docs) {
        batch.update(doc.reference, {
          'role': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _showSuccessMessage('Member role updated successfully');
    } catch (e) {
      _showErrorMessage('Error updating role: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> _removeMember(String memberUsername, String memberRole) async {
    final confirmed = await _showConfirmationDialog(
      'Remove Member',
      'Are you sure you want to remove this member from the community?',
    );
    
    if (!confirmed) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();

      // Get user ID for the username
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: memberUsername)
          .limit(1)
          .get();

      String userId = '';
      if (userQuery.docs.isNotEmpty) {
        userId = userQuery.docs.first.id;
      }

      // Remove from both possible collections
      // Check and remove from trio
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: memberUsername)
          .get();

      for (var doc in trioQuery.docs) {
        batch.delete(doc.reference);
      }

      // Check and remove from members
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: memberUsername)
          .get();

      for (var doc in membersQuery.docs) {
        batch.delete(doc.reference);
      }

      // Remove from global community_members collection
      final memberQuery = await FirebaseFirestore.instance
          .collection('community_members')
          .where('username', isEqualTo: memberUsername)
          .where('communityId', isEqualTo: widget.communityId)
          .get();

      for (var doc in memberQuery.docs) {
        batch.delete(doc.reference);
      }

      // Update community member count
      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId);
      batch.update(communityRef, {
        'memberCount': FieldValue.increment(-1),
      });

      // Add to removed_members log
      final removedRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('removed_members')
          .doc();
      batch.set(removedRef, {
        'username': memberUsername,
        'removedBy': currentUsername,
        'removedAt': FieldValue.serverTimestamp(),
        'previousRole': memberRole,
        'reason': 'Removed by ${widget.currentUserRole}',
      });

      // Update user's community mapping if we have userId
      if (userId.isNotEmpty) {
        final userRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userId);
        batch.update(userRef, {
          'communityId': FieldValue.delete(),
          'year': FieldValue.delete(),
          'branch': FieldValue.delete(),
        });
      }

      await batch.commit();
      _showSuccessMessage('Member removed successfully');
    } catch (e) {
      _showErrorMessage('Error removing member: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  bool _canManageMember(String memberRole, String memberUsername) {
    // Can't manage yourself
    if (memberUsername == currentUsername) return false;
    
    // Only admin can manage members (ban, remove, etc.)
    if (widget.currentUserRole == 'admin') {
      return memberRole != 'admin';
    }
    
    // Other roles can only view
    return false;
  }

  bool _canChangeRole(String memberRole) {
    // Only admin can change roles
    if (widget.currentUserRole == 'admin') {
      return memberRole != 'admin';
    }
    
    return false;
  }

  Future<bool> _showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A1810),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            content,
            style: GoogleFonts.poppins(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7B42C),
                foregroundColor: Colors.black87,
              ),
              child: Text(
                'Confirm',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    ) ?? false;
  }

  void _showRoleChangeDialog(String memberUsername, String currentRole, String memberName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A1810),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Change Role',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change role for $memberName',
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              if (currentRole == 'member') ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield, color: Color(0xFFF7B42C)),
                  title: Text(
                    'Promote to Moderator',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateMemberRole(memberUsername, 'moderator');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.manage_accounts, color: Colors.purple),
                  title: Text(
                    'Promote to Manager',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateMemberRole(memberUsername, 'manager');
                  },
                ),
              ],
              if (currentRole == 'moderator') ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: Text(
                    'Demote to Member',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateMemberRole(memberUsername, 'member');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.manage_accounts, color: Colors.purple),
                  title: Text(
                    'Change to Manager',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateMemberRole(memberUsername, 'manager');
                  },
                ),
              ],
              if (currentRole == 'manager') ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.shield, color: Color(0xFFF7B42C)),
                  title: Text(
                    'Change to Moderator',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateMemberRole(memberUsername, 'moderator');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person, color: Colors.blue),
                  title: Text(
                    'Demote to Member',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _updateMemberRole(memberUsername, 'member');
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.white60),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showMemberActions(String memberUsername, String memberRole, String memberName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A1810),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage $memberName',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              
              // View Profile
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person, color: Color(0xFFF7B42C)),
                title: Text(
                  'View Profile',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserProfileScreen(
                        username: memberUsername,
                        communityId: widget.communityId,
                      ),
                    ),
                  );
                },
              ),
              
              if (_canChangeRole(memberRole)) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.swap_vert, color: Color(0xFFF7B42C)),
                  title: Text(
                    'Change Role',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showRoleChangeDialog(memberUsername, memberRole, memberName);
                  },
                ),
              ],
              
              if (_canManageMember(memberRole, memberUsername)) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.remove_circle, color: Colors.red),
                  title: Text(
                    'Remove Member',
                    style: GoogleFonts.poppins(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _removeMember(memberUsername, memberRole);
                  },
                ),
              ],
              
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.poppins(color: Colors.white60),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
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

  @override
  Widget build(BuildContext context) {
    // Don't render until tab controllers are initialized
    if (availableYears.length <= 1) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Container(
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
          child: const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF7B42C),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
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
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildYearTabBar(),
                if (selectedYear != 'All') _buildBranchTabBar(),
                Expanded(
                  child: _buildMembersList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFFF7B42C),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            margin: const EdgeInsets.only(left: 65),
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                'the folks',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
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
          onChanged: (value) => setState(() => searchQuery = value),
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500),
          cursorColor: const Color(0xFFF7B42C),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFF7B42C), size: 22),
            hintText: 'search members...',
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
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
    );
  }

  Widget _buildYearTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        final tabCount = availableYears.length;
        final targetVisibleTabs = 4;
        final shouldScroll = tabCount > targetVisibleTabs;
        
        return Container(
          margin: EdgeInsets.all(isCompact ? 16 : 20),
          height: isCompact ? 50 : 55,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: const Color(0xFFF7B42C).withOpacity(0.3)),
          ),
          child: TabBar(
            controller: _yearTabController,
            isScrollable: shouldScroll,
            tabAlignment: shouldScroll ? TabAlignment.start : TabAlignment.fill,
            indicator: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.black87,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, 
              fontSize: isCompact ? 9 : 11
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, 
              fontSize: isCompact ? 9 : 11
            ),
            dividerColor: Colors.transparent,
            tabs: availableYears.asMap().entries.map((entry) {
              final year = entry.value;
              final count = yearCounts[year] ?? 0;
              
              final availableWidth = constraints.maxWidth - (isCompact ? 32 : 40);
              final tabWidth = shouldScroll 
                  ? (availableWidth / targetVisibleTabs) - 8
                  : (availableWidth / tabCount) - 4;
              
              final maxLength = (tabWidth / (isCompact ? 8 : 10)).floor().clamp(6, 15);
              final displayText = year.length > maxLength 
                  ? '${year.substring(0, maxLength)}...' 
                  : year;
              
              return Tab(
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: shouldScroll ? tabWidth : null,
                        constraints: BoxConstraints(
                          minWidth: isCompact ? 70 : 80,
                          maxWidth: shouldScroll ? tabWidth : double.infinity,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                displayText,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 4 : 5, 
                                vertical: 1
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$count',
                                style: GoogleFonts.poppins(
                                  fontSize: isCompact ? 8 : 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildBranchTabBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        final tabCount = availableBranches.length;
        final targetVisibleTabs = 4;
        final shouldScroll = tabCount > targetVisibleTabs;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20).copyWith(bottom: isCompact ? 16 : 20),
          height: isCompact ? 45 : 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TabBar(
            controller: _branchTabController,
            isScrollable: shouldScroll,
            tabAlignment: shouldScroll ? TabAlignment.start : TabAlignment.fill,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.1)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, 
              fontSize: isCompact ? 8 : 10
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, 
              fontSize: isCompact ? 8 : 10
            ),
            dividerColor: Colors.transparent,
            tabs: availableBranches.asMap().entries.map((entry) {
              final branch = entry.value;
              final count = branchCounts[branch] ?? 0;
              
              final availableWidth = constraints.maxWidth - (isCompact ? 32 : 40);
              final tabWidth = shouldScroll 
                  ? (availableWidth / targetVisibleTabs) - 8
                  : (availableWidth / tabCount) - 4;
              
              final maxLength = (tabWidth / (isCompact ? 7 : 9)).floor().clamp(5, 12);
              final displayText = branch.length > maxLength 
                  ? '${branch.substring(0, maxLength)}...' 
                  : branch;
              
              return Tab(
                child: Container(
                  width: shouldScroll ? tabWidth : null,
                  constraints: BoxConstraints(
                    minWidth: isCompact ? 60 : 70,
                    maxWidth: shouldScroll ? tabWidth : double.infinity,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayText,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 3 : 4, 
                          vertical: 1
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 7 : 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildMembersList() {
    return StreamBuilder<List<QuerySnapshot>>(
      stream: Stream.fromFuture(
        Future.wait([
          FirebaseFirestore.instance
              .collection('communities')
              .doc(widget.communityId)
              .collection('trio')
              .get(),
          FirebaseFirestore.instance
              .collection('communities')
              .doc(widget.communityId)
              .collection('members')
              .get(),
        ])
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFFF7B42C),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading members: ${snapshot.error}',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || 
            (snapshot.data![0].docs.isEmpty && snapshot.data![1].docs.isEmpty)) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7B42C).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_outline,
                    color: Color(0xFFF7B42C),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Members Found',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Combine trio and members data
        final List<QueryDocumentSnapshot> allMembers = [];
        allMembers.addAll(snapshot.data![0].docs); // trio members
        allMembers.addAll(snapshot.data![1].docs.where((doc) => 
            doc.id != '_placeholder')); // regular members (excluding placeholder)

        // Sort members: admin, moderator, manager first, then others
        allMembers.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aRole = aData['role'] as String;
          final bRole = bData['role'] as String;
          
          // Define role priority
          int getRolePriority(String role) {
            switch (role.toLowerCase()) {
              case 'admin': return 1;
              case 'moderator': return 2;
              case 'manager': return 3;
              default: return 4;
            }
          }
          
          final aPriority = getRolePriority(aRole);
          final bPriority = getRolePriority(bRole);
          
          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }
          
          // If same role, sort by username
          final aUsername = aData['username'] as String? ?? '';
          final bUsername = bData['username'] as String? ?? '';
          return aUsername.compareTo(bUsername);
        });

        // Filter members based on search, year, and branch
        final members = allMembers.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final username = data['username'] as String? ?? '';
          final year = data['year'] as String? ?? '';
          final branch = data['branch'] as String? ?? '';
          
          // Apply search filter
          if (searchQuery.isNotEmpty && 
              !username.toLowerCase().contains(searchQuery.toLowerCase())) {
            return false;
          }
          
          // Apply year filter
          if (selectedYear != 'All' && year != selectedYear) {
            return false;
          }
          
          // Apply branch filter
          if (selectedBranch != 'All' && branch != selectedBranch) {
            return false;
          }
          
          return true;
        }).toList();

        if (members.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off,
                    color: Colors.blue,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No members found',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  selectedYear != 'All' || selectedBranch != 'All'
                      ? 'Try adjusting your filters'
                      : 'Try a different search term',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final doc = members[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .where('username', isEqualTo: data['username'])
                  .limit(1)
                  .get()
                  .then((query) => query.docs.isNotEmpty ? query.docs.first : throw Exception('User not found')),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox(height: 80);
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                final userName = userData != null 
                    ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim()
                    : 'Unknown User';
                
                return MemberCard(
                  username: data['username'] ?? '',
                  userName: userName,
                  userEmail: userData?['email'] ?? '',
                  role: data['role'] ?? 'member',
                  year: data['year'],
                  branch: data['branch'],
                  status: data['status'] ?? 'active',
                  joinedAt: data['joinedAt'] as Timestamp? ?? data['assignedAt'] as Timestamp?,
                  profileImageUrl: data['profileImageUrl'],
                  isCurrentUser: currentUsername == data['username'],
                  canManage: _canManageMember(data['role'] ?? 'member', data['username'] ?? ''),
                  onManage: () => _showMemberActions(
                    data['username'] ?? '',
                    data['role'] ?? 'member',
                    userName,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class MemberCard extends StatelessWidget {
  final String username;
  final String userName;
  final String userEmail;
  final String role;
  final String? year;
  final String? branch;
  final String status;
  final Timestamp? joinedAt;
  final String? profileImageUrl;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback onManage;

  const MemberCard({
    super.key,
    required this.username,
    required this.userName,
    required this.userEmail,
    required this.role,
    this.year,
    this.branch,
    required this.status,
    this.joinedAt,
    this.profileImageUrl,
    required this.isCurrentUser,
    required this.canManage,
    required this.onManage,
  });

Color _getRoleColor(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return Colors.red;
    case 'moderator':
      return const Color(0xFFF7B42C);
    case 'manager':
      return Colors.purple;
    case 'member':
    default:
      return Colors.blue;
  }
}

IconData _getRoleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'admin':
      return Icons.admin_panel_settings;
    case 'moderator':
      return Icons.shield;
    case 'manager':
      return Icons.manage_accounts;
    case 'member':
    default:
      return Icons.person;
  }
}

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return 'Recently';
    }
  }

@override
Widget build(BuildContext context) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
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
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _getRoleColor(role),
                width: 2,
              ),
            ),
            child: profileImageUrl != null
                ? ClipOval(
                    child: Image.network(
                      profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildAvatarFallback(),
                    ),
                  )
                : _buildAvatarFallback(),
          ),
          
          const SizedBox(width: 12),
          
          // Member Info - Made flexible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name and YOU badge row
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName.isNotEmpty ? userName : 'Unknown User',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7B42C).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'YOU',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFF7B42C),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 3),
                
                // Username
                Text(
                  '@$username',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 6),
                
                // Role and badges row - Made scrollable
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _getRoleColor(role).withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getRoleIcon(role),
                              size: 10,
                              color: _getRoleColor(role),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              role.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: _getRoleColor(role),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Year Badge
                      if (year != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            year!,
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                      
                      // Branch
                      if (branch != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            branch!,
                            style: GoogleFonts.poppins(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // Joined date
                Text(
                  'Joined ${_formatTimestamp(joinedAt)}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Manage Button
          GestureDetector(
            onTap: onManage,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7B42C).withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFF7B42C).withOpacity(0.5),
                ),
              ),
              child: Icon(
                canManage ? Icons.more_vert : Icons.visibility,
                color: const Color(0xFFF7B42C),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildAvatarFallback() {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_getRoleColor(role), _getRoleColor(role).withOpacity(0.7)],
      ),
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(
        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
  );
}
}