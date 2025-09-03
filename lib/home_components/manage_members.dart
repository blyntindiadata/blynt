import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_profile_screen.dart';
import 'package:flutter/services.dart';

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
  late AnimationController _cardFadeController;
  late Animation<double> _cardFadeAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  
  List<String> availableYears = ['All'];
  List<String> availableBranches = ['All'];
  String currentUsername = '';
  
  // Current selections
  String selectedYear = 'All';
  String selectedBranch = 'All';
  
  // Member counts for each filter
  Map<String, int> yearCounts = {};
  Map<String, int> branchCounts = {};
  
  // Role tracking for restrictions
  bool hasManager = false;
  bool hasModerator = false;

  bool get isAdmin => widget.currentUserRole == 'admin';
  bool get isModerator => widget.currentUserRole == 'moderator';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
    _setSystemUIOverlay();
    _loadCurrentUsername();
    _initAnimations();
    _loadAvailableFilters();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _cardFadeController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _cardFadeAnimation = CurvedAnimation(
      parent: _cardFadeController,
      curve: Curves.easeInOut,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );
    
    _fadeController.forward();
    _cardFadeController.forward();
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _yearTabController.dispose();
    _branchTabController.dispose();
    _fadeController.dispose();
    _pulseController.dispose();
    _cardFadeController.dispose();
    _shimmerController.dispose();
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

  Future<void> _checkExistingRoles() async {
    try {
      // Check trio collection for existing manager/moderator
      final trioSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .get();
      
      bool tempHasManager = false;
      bool tempHasModerator = false;
      
      for (var doc in trioSnapshot.docs) {
        final data = doc.data();
        final role = data['role'] as String? ?? '';
        
        if (role == 'manager') tempHasManager = true;
        if (role == 'moderator') tempHasModerator = true;
      }
      
      setState(() {
        hasManager = tempHasManager;
        hasModerator = tempHasModerator;
      });
    } catch (e) {
      print('Error checking existing roles: $e');
    }
  }

  Future<void> _loadAvailableFilters() async {
      if (!mounted) return;
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
      
      // Check existing roles after loading data
      await _checkExistingRoles();
      
    } catch (e) {
      print('Error loading filters: $e');
    }
  }

  void _onYearTabChanged() {
    if (_yearTabController.indexIsChanging) return;
    
    final newYear = availableYears[_yearTabController.index];
    if (newYear != selectedYear) {
      // Trigger fast fade out
      _cardFadeController.reverse().then((_) {
        setState(() {
          selectedYear = newYear;
          selectedBranch = 'All';
        });
        _loadBranchesForYear(newYear);
        _branchTabController.animateTo(0);
        _triggerPulseAnimation();
        // Fast fade back in
        _cardFadeController.forward();
      });
    }
  }

  void _onBranchTabChanged() {
    if (_branchTabController.indexIsChanging) return;
    
    final newBranch = availableBranches[_branchTabController.index];
    if (newBranch != selectedBranch) {
      // Trigger fast fade out
      _cardFadeController.reverse().then((_) {
        setState(() {
          selectedBranch = newBranch;
        });
        _triggerPulseAnimation();
        // Fast fade back in
        _cardFadeController.forward();
      });
    }
  }

  void _triggerPulseAnimation() {
    _pulseController.forward().then((_) {
      _pulseController.reverse();
    });
  }

  Future<void> _loadBranchesForYear(String year) async {
    if (year == 'All') {
      _loadAvailableFilters();
      return;
    }
    
    try {
      Set<String> branches = {};
      Map<String, int> tempBranchCounts = {'All': 0};
      
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
      
      _branchTabController.dispose();
      _branchTabController = TabController(length: availableBranches.length, vsync: this);
      _branchTabController.addListener(_onBranchTabChanged);
      
    } catch (e) {
      print('Error loading branches for year: $e');
    }
  }

  Future<void> _updateMemberRole(String memberUsername, String newRole) async {
    // Role validation - prevent multiple managers/moderators
    if (newRole == 'manager' && hasManager) {
      _showErrorMessage('A manager already exists in this community');
      return;
    }
    
    if (newRole == 'moderator' && hasModerator) {
      _showErrorMessage('A moderator already exists in this community');
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Find current member document and determine source collection
      DocumentSnapshot? currentDoc;
      String sourceCollection = '';
      
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
      
      String targetCollection = (newRole == 'admin' || newRole == 'moderator' || newRole == 'manager') 
          ? 'trio' 
          : 'members';
      
      if (sourceCollection != targetCollection) {
        final newDocRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection(targetCollection)
            .doc(memberUsername);
        
        final updatedData = Map<String, dynamic>.from(currentData);
        updatedData['role'] = newRole;
        updatedData['updatedAt'] = FieldValue.serverTimestamp();
        updatedData['updatedBy'] = currentUsername;
        updatedData['transferredFrom'] = sourceCollection;
        updatedData['transferredAt'] = FieldValue.serverTimestamp();
        
        batch.set(newDocRef, updatedData);
        batch.delete(currentDoc.reference);
        
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
        batch.update(currentDoc.reference, {
          'role': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUsername,
        });
      }

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
      
      // Update role tracking
      if (newRole == 'manager') hasManager = true;
      if (newRole == 'moderator') hasModerator = true;
      if (currentRole == 'manager') hasManager = false;
      if (currentRole == 'moderator') hasModerator = false;
      
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

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: memberUsername)
          .limit(1)
          .get();

      String userId = '';
      if (userQuery.docs.isNotEmpty) {
        userId = userQuery.docs.first.id;
      }

      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: memberUsername)
          .get();

      for (var doc in trioQuery.docs) {
        batch.delete(doc.reference);
      }

      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: memberUsername)
          .get();

      for (var doc in membersQuery.docs) {
        batch.delete(doc.reference);
      }

      final memberQuery = await FirebaseFirestore.instance
          .collection('community_members')
          .where('username', isEqualTo: memberUsername)
          .where('communityId', isEqualTo: widget.communityId)
          .get();

      for (var doc in memberQuery.docs) {
        batch.delete(doc.reference);
      }

      final communityRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId);
      batch.update(communityRef, {
        'memberCount': FieldValue.increment(-1),
      });

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
      
      // Update role tracking if removed member was manager/moderator
      if (memberRole == 'manager') hasManager = false;
      if (memberRole == 'moderator') hasModerator = false;
      
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
    if (memberUsername == currentUsername) return false;
    
    if (widget.currentUserRole == 'admin') {
      return memberRole != 'admin';
    }
    
    return false;
  }

  bool _canChangeRole(String memberRole) {
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
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 0,
  ).copyWith(
    backgroundColor: MaterialStateProperty.all(Colors.transparent),
    shadowColor: MaterialStateProperty.all(Colors.transparent),
  ),
  child: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      'Confirm',
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
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
                // Only show if no moderator exists
                if (!hasModerator)
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
                // Only show if no manager exists
                if (!hasManager)
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
                // Show disabled options with explanation
                if (hasModerator)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shield, color: Colors.grey.shade600),
                    title: Text(
                      'Promote to Moderator',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                    subtitle: Text(
                      'Moderator already exists',
                      style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
                if (hasManager)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.manage_accounts, color: Colors.grey.shade600),
                    title: Text(
                      'Promote to Manager',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                    subtitle: Text(
                      'Manager already exists',
                      style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 12),
                    ),
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
                // Only allow change to manager if no manager exists
                if (!hasManager)
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
                if (hasManager)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.manage_accounts, color: Colors.grey.shade600),
                    title: Text(
                      'Change to Manager',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                    subtitle: Text(
                      'Manager already exists',
                      style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 12),
                    ),
                  ),
              ],
              if (currentRole == 'manager') ...[
                // Only allow change to moderator if no moderator exists
                if (!hasModerator)
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
                if (hasModerator)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shield, color: Colors.grey.shade600),
                    title: Text(
                      'Change to Moderator',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600),
                    ),
                    subtitle: Text(
                      'Moderator already exists',
                      style: GoogleFonts.poppins(color: Colors.grey.shade700, fontSize: 12),
                    ),
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

  void _showMemberActions(String memberUsername, String memberRole, String memberName, String? memberYear, String? memberBranch) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A1810),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
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

                if (isAdmin) ...[
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.school, color: Color(0xFFF7B42C)),
      title: Text(
        'Update Year & Branch',
        style: GoogleFonts.poppins(color: Colors.white),
      ),
      onTap: () {
        Navigator.of(context).pop();
        _showYearBranchChangeDialog(memberUsername, memberYear ?? '', memberBranch ?? '', memberName);
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
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.poppins(color: Colors.white60),
                    ),
                  ),
                ),
              ],
            ),
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
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
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
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  Future<void> _updateMemberYearBranch(String memberUsername, String? newYear, String? newBranch) async {
  setState(() {
    isProcessing = true;
  });

  try {
    final batch = FirebaseFirestore.instance.batch();
    
    // Find current member document
    DocumentSnapshot? currentDoc;
    String sourceCollection = '';
    
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

    // Update the document
    Map<String, dynamic> updateData = {
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': currentUsername,
    };
    
    if (newYear != null) updateData['year'] = newYear;
    if (newBranch != null) updateData['branch'] = newBranch;
    
    batch.update(currentDoc.reference, updateData);

    // Update global community_members collection
    final globalMemberQuery = await FirebaseFirestore.instance
        .collection('community_members')
        .where('username', isEqualTo: memberUsername)
        .where('communityId', isEqualTo: widget.communityId)
        .get();

    for (var doc in globalMemberQuery.docs) {
      batch.update(doc.reference, updateData);
    }

    // Update user document
    final userQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: memberUsername)
        .limit(1)
        .get();

    if (userQuery.docs.isNotEmpty) {
      batch.update(userQuery.docs.first.reference, updateData);
    }

    await batch.commit();
    
    // Refresh filters after update
    await _loadAvailableFilters();
    
    _showSuccessMessage('Member year/branch updated successfully');
  } catch (e) {
    _showErrorMessage('Error updating year/branch: $e');
  } finally {
    setState(() {
      isProcessing = false;
    });
  }
}

Future<void> _bulkUpdateYear(String fromYear, String toYear) async {
  final confirmed = await _showConfirmationDialog(
    'Bulk Year Update',
    'Are you sure you want to promote all students from $fromYear to $toYear? This action cannot be undone.',
  );
  
  if (!confirmed) return;

  setState(() {
    isProcessing = true;
  });

  try {
    final batch = FirebaseFirestore.instance.batch();
    int updateCount = 0;

    // Update trio collection
    final trioQuery = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .where('year', isEqualTo: fromYear)
        .get();

    for (var doc in trioQuery.docs) {
      final data = doc.data();
      // Only update members and moderators, not admins
      if (data['role'] == 'member' || data['role'] == 'moderator' || data['role'] == 'manager') {
        batch.update(doc.reference, {
          'year': toYear,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': currentUsername,
          'bulkUpdated': true,
          'previousYear': fromYear,
        });
        updateCount++;
      }
    }

    // Update members collection
    final membersQuery = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('members')
        .where('year', isEqualTo: fromYear)
        .get();

    for (var doc in membersQuery.docs) {
      batch.update(doc.reference, {
        'year': toYear,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUsername,
        'bulkUpdated': true,
        'previousYear': fromYear,
      });
      updateCount++;
    }

    // Update global community_members collection
    final globalQuery = await FirebaseFirestore.instance
        .collection('community_members')
        .where('communityId', isEqualTo: widget.communityId)
        .where('year', isEqualTo: fromYear)
        .get();

    for (var doc in globalQuery.docs) {
      batch.update(doc.reference, {
        'year': toYear,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Update users collection
    final usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('communityId', isEqualTo: widget.communityId)
        .where('year', isEqualTo: fromYear)
        .get();

    for (var doc in usersQuery.docs) {
      batch.update(doc.reference, {
        'year': toYear,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    
    // Log the bulk update
    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('bulk_updates')
        .add({
      'type': 'year_progression',
      'fromYear': fromYear,
      'toYear': toYear,
      'updatedCount': updateCount,
      'updatedBy': currentUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    // Refresh filters
    await _loadAvailableFilters();
    
    _showSuccessMessage('Successfully updated $updateCount students from $fromYear to $toYear');
  } catch (e) {
    _showErrorMessage('Error in bulk update: $e');
  } finally {
    setState(() {
      isProcessing = false;
    });
  }
}

void _showYearBranchChangeDialog(String memberUsername, String currentYear, String currentBranch, String memberName) {
  String? selectedYear = currentYear;
  String? selectedBranch = currentBranch;
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A1810),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Update Year & Branch',
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
                  'Update year and branch for $memberName',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Year Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedYear,
                    decoration: InputDecoration(
                      labelText: 'Year',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    dropdownColor: const Color(0xFF2A1810),
                    style: GoogleFonts.poppins(color: Colors.white),
                    items: availableYears.where((year) => year != 'All').map((String year) {
                      return DropdownMenuItem<String>(
                        value: year,
                        child: Text(year),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedYear = newValue;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Branch Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedBranch,
                    decoration: InputDecoration(
                      labelText: 'Branch',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    dropdownColor: const Color(0xFF2A1810),
                    style: GoogleFonts.poppins(color: Colors.white),
                    items: availableBranches.where((branch) => branch != 'All').map((String branch) {
                      return DropdownMenuItem<String>(
                        value: branch,
                        child: Text(branch),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedBranch = newValue;
                      });
                    },
                  ),
                ),
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
             ElevatedButton(
  onPressed: () {
    Navigator.of(context).pop();
    _updateMemberYearBranch(memberUsername, selectedYear, selectedBranch);
  },
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 0,
  ).copyWith(
    backgroundColor: MaterialStateProperty.all(Colors.transparent),
    shadowColor: MaterialStateProperty.all(Colors.transparent),
  ),
  child: Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      'Update',
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    ),
  ),
),
            ],
          );
        },
      );
    },
  );
}

void _showBulkYearUpdateDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      String? selectedFromYear;
      String? selectedToYear;
      
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF2A1810),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Bulk Year Progression',
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
                  'Promote all students from one year to the next',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 20),
                
                // From Year Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedFromYear,
                    decoration: InputDecoration(
                      labelText: 'From Year',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    dropdownColor: const Color(0xFF2A1810),
                    style: GoogleFonts.poppins(color: Colors.white),
                    items: availableYears.where((year) => year != 'All').map((String year) {
                      final count = yearCounts[year] ?? 0;
                      return DropdownMenuItem<String>(
                        value: year,
                        child: Text('$year ($count students)'),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedFromYear = newValue;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // To Year Dropdown
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedToYear,
                    decoration: InputDecoration(
                      labelText: 'To Year',
                      labelStyle: GoogleFonts.poppins(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    dropdownColor: const Color(0xFF2A1810),
                    style: GoogleFonts.poppins(color: Colors.white),
                    items: availableYears.where((year) => year != 'All').map((String year) {
                      return DropdownMenuItem<String>(
                        value: year,
                        child: Text(year),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedToYear = newValue;
                      });
                    },
                  ),
                ),
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
             ElevatedButton(
  onPressed: selectedFromYear != null && selectedToYear != null && selectedFromYear != selectedToYear
      ? () {
          Navigator.of(context).pop();
          _bulkUpdateYear(selectedFromYear!, selectedToYear!);
        }
      : null,
  style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 0,
  ).copyWith(
    backgroundColor: MaterialStateProperty.all(Colors.transparent),
    shadowColor: MaterialStateProperty.all(Colors.transparent),
  ),
  child: Container(
    decoration: BoxDecoration(
      gradient: selectedFromYear != null && selectedToYear != null && selectedFromYear != selectedToYear
          ? const LinearGradient(
              colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : LinearGradient(
              colors: [Colors.grey.shade600, Colors.grey.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Text(
      'Update All',
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: selectedFromYear != null && selectedToYear != null && selectedFromYear != selectedToYear
            ? Colors.black87
            : Colors.white60,
      ),
    ),
  ),
),
            ],
          );
        },
      );
    },
  );
}

void _setSystemUIOverlay() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );
}

  Widget _buildShimmerEffect() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0, -0.3),
              end: Alignment(1.0, 0.3),
              colors: const [
                Colors.transparent,
                Colors.white24,
                Colors.transparent,
              ],
              stops: [
                _shimmerAnimation.value - 0.3,
                _shimmerAnimation.value,
                _shimmerAnimation.value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child!,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: isTablet ? 100 : 80,
      child: _buildShimmerEffect(),
    );
  }

  @override
  Widget build(BuildContext context) {

    // Get screen dimensions for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;
    
    // Don't render until tab controllers are initialized
  

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
                _buildSearchBar(horizontalPadding),
                _buildYearTabBar(horizontalPadding),
                if (selectedYear != 'All') _buildBranchTabBar(horizontalPadding),
                Expanded(
                  child: _buildMembersList(horizontalPadding),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
  final screenSize = MediaQuery.of(context).size;
  final isTablet = screenSize.width > 600;
  final horizontalPadding = isTablet ? 32.0 : 20.0;
  
  return Padding(
    padding: EdgeInsets.all(horizontalPadding),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 12 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: const Color(0xFFF7B42C),
              size: isTablet ? 24 : 20,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                'the folks',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 28 : 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        // Add bulk actions button for admins
     // Add bulk actions button for admins
if (isAdmin) ...[
  GestureDetector(
    onTap: _showBulkYearUpdateDialog,
    child: Container(
      padding: EdgeInsets.all(isTablet ? 12 : 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.purple, Color(0xFF8E24AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.group_work,
        color: Colors.white,
        size: isTablet ? 24 : 20,
      ),
    ),
  ),
] else ...[
  SizedBox(width: isTablet ? 56 : 48),
],
      ],
    ),
  );
}

  Widget _buildSearchBar(double horizontalPadding) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: isTablet ? 18 : 16,
          ),
          cursorColor: const Color(0xFFF7B42C),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.08),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: const Color(0xFFF7B42C),
              size: isTablet ? 26 : 22,
            ),
            hintText: 'search members...',
            hintStyle: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: isTablet ? 18 : 16,
            ),
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
            contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
          ),
        ),
      ),
    );
  }

  Widget _buildYearTabBar(double horizontalPadding) {
    // Show loading state if tab controller not ready
  if (availableYears.length <= 1 || _yearTabController.length == 0) {
    return Container(
      margin: EdgeInsets.all(horizontalPadding),
      height: 55,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: const Color(0xFFF7B42C),
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;
        final isTablet = screenSize.width > 600;
        final isCompact = constraints.maxWidth < 400;
        final tabCount = availableYears.length;
        final targetVisibleTabs = isTablet ? 6 : 4;
        final shouldScroll = tabCount > targetVisibleTabs;
        
        return Container(
          margin: EdgeInsets.all(horizontalPadding),
          height: isTablet ? 65 : (isCompact ? 50 : 55),
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
              fontSize: isTablet ? 14 : (isCompact ? 9 : 11)
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, 
              fontSize: isTablet ? 14 : (isCompact ? 9 : 11)
            ),
            dividerColor: Colors.transparent,
            tabs: availableYears.asMap().entries.map((entry) {
              final year = entry.value;
              final count = yearCounts[year] ?? 0;
              
              final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
              final tabWidth = shouldScroll 
                  ? (availableWidth / targetVisibleTabs) - 8
                  : (availableWidth / tabCount) - 4;
              
              final maxLength = isTablet 
                  ? 20 
                  : (tabWidth / (isCompact ? 8 : 10)).floor().clamp(6, 15);
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
                          minWidth: isTablet ? 100 : (isCompact ? 70 : 80),
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
                            SizedBox(height: isTablet ? 4 : 2),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 8 : (isCompact ? 4 : 5), 
                                vertical: isTablet ? 2 : 1
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$count',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 12 : (isCompact ? 8 : 9),
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

  Widget _buildBranchTabBar(double horizontalPadding) {
    // Show loading state if tab controller not ready
  if (availableBranches.length <= 1 || _branchTabController.length == 0) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalPadding)
          .copyWith(bottom: horizontalPadding),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            color: Colors.white60,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenSize = MediaQuery.of(context).size;
        final isTablet = screenSize.width > 600;
        final isCompact = constraints.maxWidth < 400;
        final tabCount = availableBranches.length;
        final targetVisibleTabs = isTablet ? 6 : 4;
        final shouldScroll = tabCount > targetVisibleTabs;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalPadding)
              .copyWith(bottom: horizontalPadding),
          height: isTablet ? 60 : (isCompact ? 45 : 50),
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
              fontSize: isTablet ? 12 : (isCompact ? 8 : 10)
            ),
            unselectedLabelStyle: GoogleFonts.poppins(
              fontWeight: FontWeight.w500, 
              fontSize: isTablet ? 12 : (isCompact ? 8 : 10)
            ),
            dividerColor: Colors.transparent,
            tabs: availableBranches.asMap().entries.map((entry) {
              final branch = entry.value;
              final count = branchCounts[branch] ?? 0;
              
              final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
              final tabWidth = shouldScroll 
                  ? (availableWidth / targetVisibleTabs) - 8
                  : (availableWidth / tabCount) - 4;
              
              final maxLength = isTablet 
                  ? 15 
                  : (tabWidth / (isCompact ? 7 : 9)).floor().clamp(5, 12);
              final displayText = branch.length > maxLength 
                  ? '${branch.substring(0, maxLength)}...' 
                  : branch;
              
              return Tab(
                child: Container(
                  width: shouldScroll ? tabWidth : null,
                  constraints: BoxConstraints(
                    minWidth: isTablet ? 90 : (isCompact ? 60 : 70),
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
                      SizedBox(height: isTablet ? 3 : 2),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 6 : (isCompact ? 3 : 4), 
                          vertical: isTablet ? 2 : 1
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 10 : (isCompact ? 7 : 8),
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

  Widget _buildMembersList(double horizontalPadding) {
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
          return FadeTransition(
            opacity: _cardFadeAnimation,
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: 8,
              itemBuilder: (context, index) => _buildShimmerCard(),
            ),
          );
        }

        if (snapshot.hasError) {
          return FadeTransition(
            opacity: _cardFadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Text(
                      'Error loading members: ${snapshot.error}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || 
            (snapshot.data![0].docs.isEmpty && snapshot.data![1].docs.isEmpty)) {
          return FadeTransition(
            opacity: _cardFadeAnimation,
            child: Center(
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
          return FadeTransition(
            opacity: _cardFadeAnimation,
            child: Center(
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
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                    child: Text(
                      selectedYear != 'All' || selectedBranch != 'All'
                          ? 'Try adjusting your filters'
                          : 'Try a different search term',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return FadeTransition(
          opacity: _cardFadeAnimation,
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                    return AnimatedOpacity(
                      opacity: 0.6,
                      duration: const Duration(milliseconds: 200),
                      child: _buildShimmerCard(),
                    );
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                  final userName = userData != null 
                      ? '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim()
                      : 'Unknown User';
                  
                  return AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: MemberCard(
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
  data['year']?.toString(),
  data['branch']?.toString(),
                      ),
                    ),
                  );
                },
              );
            },
          ),
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
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    
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
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: isTablet ? 60 : 50,
              height: isTablet ? 60 : 50,
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
                            _buildAvatarFallback(isTablet),
                      ),
                    )
                  : _buildAvatarFallback(isTablet),
            ),
            
            SizedBox(width: isTablet ? 16 : 12),
            
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
                            fontSize: isTablet ? 18 : 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        SizedBox(width: isTablet ? 8 : 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 6, 
                            vertical: isTablet ? 3 : 2
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7B42C).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'YOU',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 11 : 9,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF7B42C),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  SizedBox(height: isTablet ? 4 : 3),
                  
                  // Username
                  Text(
                    '@$username',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 13 : 11,
                      color: Colors.white60,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  SizedBox(height: isTablet ? 8 : 6),
                  
                  // Role and badges row - Made scrollable
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // Role Badge
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 8 : 6, 
                            vertical: isTablet ? 4 : 3
                          ),
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
                                size: isTablet ? 12 : 10,
                                color: _getRoleColor(role),
                              ),
                              SizedBox(width: isTablet ? 4 : 3),
                              Text(
                                role.toUpperCase(),
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 10 : 8,
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
                          SizedBox(width: isTablet ? 8 : 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 6 : 5, 
                              vertical: isTablet ? 3 : 2
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              year!,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 10 : 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                        
                        // Branch
                        if (branch != null) ...[
                          SizedBox(width: isTablet ? 8 : 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 6 : 5, 
                              vertical: isTablet ? 3 : 2
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              branch!,
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 10 : 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  SizedBox(height: isTablet ? 6 : 4),
                  
                  // Joined date
                  Text(
                    'Joined ${_formatTimestamp(joinedAt)}',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 12 : 10,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(width: isTablet ? 12 : 8),
            
            // Manage Button
            // Manage Button
GestureDetector(
  onTap: onManage,
  child: Container(
    padding: EdgeInsets.all(isTablet ? 10 : 6),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFFF7B42C).withOpacity(0.8),
          const Color(0xFFFFD700).withOpacity(0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFF7B42C).withOpacity(0.3),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      canManage ? Icons.more_vert : Icons.visibility,
      color: Colors.black87,
      size: isTablet ? 20 : 16,
    ),
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(bool isTablet) {
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
            fontSize: isTablet ? 20 : 16,
          ),
        ),
      ),
    );
  }
}

