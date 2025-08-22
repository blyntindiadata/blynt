import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateCommitteeRequestPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final String userRole;

  const CreateCommitteeRequestPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
  }) : super(key: key);

  @override
  State<CreateCommitteeRequestPage> createState() => _CreateCommitteeRequestPageState();
}

class _CreateCommitteeRequestPageState extends State<CreateCommitteeRequestPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final ValueNotifier<bool> _isCreatingNotifier = ValueNotifier(false);
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _overallLeaderTermController = TextEditingController();
  final List<TextEditingController> _departmentControllers = [];
  final List<TextEditingController> _departmentLeaderTermControllers = [];
  
  // Selected members for each department
  Map<int, List<Map<String, dynamic>>> _departmentMembers = {};
  
  // Available community members
  List<Map<String, dynamic>> _availableMembers = [];
  
  // Achievements
  final List<TextEditingController> _achievementControllers = [];
  
  int _currentPage = 0;
  final int _totalPages = 4;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadAvailableMembers();
    _addDepartment(); // Add first department
    _addAchievement(); // Add first achievement
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
    _nameController.dispose();
    _descriptionController.dispose();
    _overallLeaderTermController.dispose();
    for (var controller in _departmentControllers) {
      controller.dispose();
    }
    for (var controller in _departmentLeaderTermControllers) {
      controller.dispose();
    }
    for (var controller in _achievementControllers) {
      controller.dispose();
    }
    _isCreatingNotifier.dispose();
    _fadeController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableMembers() async {
    try {
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

      final members = <Map<String, dynamic>>[];
      
      for (var doc in [...trioSnapshot.docs, ...membersSnapshot.docs]) {
        final data = doc.data();
        if (data['username'] != null && data['username'] != widget.username) {
          members.add({
            'username': data['username'],
            'name': '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim(),
            'role': data['role'] ?? 'member',
            'year': data['year']?.toString() ?? '',
            'branch': data['branch']?.toString() ?? '',
          });
        }
      }

      setState(() {
        _availableMembers = members;
      });
    } catch (e) {
      print('Error loading members: $e');
    }
  }

  void _addDepartment() {
    setState(() {
      _departmentControllers.add(TextEditingController());
      _departmentLeaderTermControllers.add(TextEditingController());
      _departmentMembers[_departmentControllers.length - 1] = [];
    });
  }

  void _removeDepartment(int index) {
    if (_departmentControllers.length > 1) {
      setState(() {
        _departmentControllers[index].dispose();
        _departmentLeaderTermControllers[index].dispose();
        _departmentControllers.removeAt(index);
        _departmentLeaderTermControllers.removeAt(index);
        
        // Reindex department members
        final newDepartmentMembers = <int, List<Map<String, dynamic>>>{};
        int newIndex = 0;
        for (int i = 0; i < _departmentMembers.length; i++) {
          if (i != index) {
            newDepartmentMembers[newIndex] = _departmentMembers[i] ?? [];
            newIndex++;
          }
        }
        _departmentMembers = newDepartmentMembers;
      });
    }
  }

  void _addAchievement() {
    setState(() {
      _achievementControllers.add(TextEditingController());
    });
  }

  void _removeAchievement(int index) {
    if (_achievementControllers.length > 1) {
      setState(() {
        _achievementControllers[index].dispose();
        _achievementControllers.removeAt(index);
      });
    }
  }

  void _showMemberSelection(int departmentIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A1628),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => MemberSelectionSheet(
          availableMembers: _availableMembers,
          selectedMembers: _departmentMembers[departmentIndex] ?? [],
          departmentName: _departmentControllers[departmentIndex].text,
          onMembersSelected: (members) {
            setState(() {
              _departmentMembers[departmentIndex] = members;
            });
          },
          scrollController: scrollController,
        ),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceedFromCurrentPage() {
    switch (_currentPage) {
      case 0: // Basic Info
        return _nameController.text.trim().isNotEmpty &&
               _descriptionController.text.trim().isNotEmpty;
      case 1: // Departments & Terms
        return _departmentControllers.every((controller) => 
               controller.text.trim().isNotEmpty) &&
               _departmentLeaderTermControllers.every((controller) => 
               controller.text.trim().isNotEmpty) &&
               _overallLeaderTermController.text.trim().isNotEmpty;
      case 2: // Members (optional)
        return true;
      case 3: // Achievements (optional)
        return true;
      default:
        return false;
    }
  }

  Future<void> _submitRequest() async {
    if (!_canProceedFromCurrentPage()) return;

    try {
      _isCreatingNotifier.value = true;

      final departments = _departmentControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final departmentLeaderTerms = _departmentLeaderTermControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      final achievements = _achievementControllers
          .map((controller) => controller.text.trim())
          .where((text) => text.isNotEmpty)
          .toList();

      // Prepare department members data
      final departmentMembersData = <String, List<Map<String, dynamic>>>{};
      for (int i = 0; i < departments.length; i++) {
        departmentMembersData[departments[i]] = _departmentMembers[i] ?? [];
      }

      final requestData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'departments': departments,
        'departmentLeaderTerms': departmentLeaderTerms,
        'overallLeaderTerm': _overallLeaderTermController.text.trim(),
        'departmentMembers': departmentMembersData,
        'achievements': achievements,
        'creatorId': widget.userId,
        'creatorUsername': widget.username,
        'creatorRole': widget.userRole,
        'communityId': widget.communityId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('committee_requests')
          .add(requestData);

      if (mounted) {
        _showMessage('Committee request submitted successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMessage('Error submitting request: $e', isError: true);
    } finally {
      _isCreatingNotifier.value = false;
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1E3A5F),
              const Color(0xFF0A1628),
              const Color(0xFF041018),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(),
                _buildProgressIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      _buildBasicInfoPage(),
                      _buildDepartmentsPage(),
                      _buildMembersPage(),
                      _buildAchievementsPage(),
                    ],
                  ),
                ),
                _buildNavigationButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.3),
                Colors.transparent,
              ],
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Container(
                padding: EdgeInsets.all(isCompact ? 10 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF1E3A5F), const Color(0xFF0A1628)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A5F).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_circle, 
                  color: Colors.white, 
                  size: isCompact ? 20 : 24
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [const Color(0xFF4FC3F7), const Color(0xFF29B6F6)],
                      ).createShader(bounds),
                      child: Text(
                        'create committee',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: isCompact ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                      ),
                    ),
                    Text(
                      'request new committee',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 10 : 12,
                        color: const Color(0xFF4FC3F7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressIndicator() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          margin: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
          padding: EdgeInsets.all(isCompact ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: List.generate(_totalPages, (index) {
                  final isActive = index <= _currentPage;
                  final isCurrent = index == _currentPage;
                  
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: isCompact ? 2 : 4),
                      height: isCompact ? 4 : 6,
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? LinearGradient(
                                colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                              )
                            : null,
                        color: isActive ? null : Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(isCompact ? 2 : 3),
                        boxShadow: isCurrent ? [
                          BoxShadow(
                            color: const Color(0xFF4FC3F7).withOpacity(0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
                      ),
                    ),
                  );
                }),
              ),
              SizedBox(height: isCompact ? 8 : 12),
              Text(
                _getPageTitle(_currentPage),
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getPageTitle(int page) {
    switch (page) {
      case 0: return 'Basic Information';
      case 1: return 'Departments & Terms';
      case 2: return 'Add Members (Optional)';
      case 3: return 'Achievements (Optional)';
      default: return '';
    }
  }

  Widget _buildBasicInfoPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Committee Name',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A5F).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _nameController,
                  style: GoogleFonts.poppins(
                    color: Colors.white, 
                    fontSize: isCompact ? 12 : 14
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    hintText: 'Enter committee name...',
                    hintStyle: GoogleFonts.poppins(color: Colors.white38),
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
                      borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),

              SizedBox(height: isCompact ? 20 : 24),

              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A5F).withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: GoogleFonts.poppins(
                    color: Colors.white, 
                    fontSize: isCompact ? 12 : 14
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    hintText: 'Describe the purpose and goals of your committee...',
                    hintStyle: GoogleFonts.poppins(color: Colors.white38),
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
                      borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDepartmentsPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall Leader Term
              Text(
                'Overall Committee Leader Term',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A5F).withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _overallLeaderTermController,
                  style: GoogleFonts.poppins(
                    color: Colors.white, 
                    fontSize: isCompact ? 12 : 14
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    hintText: 'e.g., President, Chairperson, Head...',
                    hintStyle: GoogleFonts.poppins(color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 12 : 16, 
                      vertical: isCompact ? 10 : 12
                    ),
                  ),
                ),
              ),

              SizedBox(height: isCompact ? 20 : 24),

              // Departments
              Row(
                children: [
                  Text(
                    'Departments',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4FC3F7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_departmentControllers.length}/10',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ..._departmentControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final deptController = entry.value;
                final termController = _departmentLeaderTermControllers[index];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isCompact ? 6 : 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isCompact ? 10 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Department ${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 13 : 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_departmentControllers.length > 1)
                            GestureDetector(
                              onTap: () => _removeDepartment(index),
                              child: Container(
                                padding: EdgeInsets.all(isCompact ? 4 : 6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.remove,
                                  color: Colors.red,
                                  size: isCompact ? 14 : 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Department Name
                      TextField(
                        controller: deptController,
                        style: GoogleFonts.poppins(
                          color: Colors.white, 
                          fontSize: isCompact ? 11 : 13
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          hintText: 'Department name...',
                          hintStyle: GoogleFonts.poppins(color: Colors.white38),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 10 : 12, 
                            vertical: isCompact ? 8 : 10
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Department Leader Term
                      TextField(
                        controller: termController,
                        style: GoogleFonts.poppins(
                          color: Colors.white, 
                          fontSize: isCompact ? 11 : 13
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.08),
                          hintText: 'Leader title (e.g., Head, Manager, Lead)...',
                          hintStyle: GoogleFonts.poppins(color: Colors.white38),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 10 : 12, 
                            vertical: isCompact ? 8 : 10
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              if (_departmentControllers.length < 10) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _addDepartment,
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4FC3F7).withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add,
                          color: const Color(0xFF4FC3F7),
                          size: isCompact ? 16 : 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Department',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF4FC3F7),
                            fontSize: isCompact ? 12 : 14,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }

  Widget _buildMembersPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4FC3F7).withOpacity(0.1),
                      const Color(0xFF29B6F6).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4FC3F7).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF4FC3F7),
                      size: isCompact ? 16 : 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Adding members is optional. You can add them later after approval.',
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 11 : 13,
                          color: const Color(0xFF4FC3F7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isCompact ? 16 : 20),

              Text(
                'Department Members',
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF4FC3F7),
                ),
              ),
              const SizedBox(height: 12),

              ..._departmentControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final deptName = entry.value.text.trim();
                final members = _departmentMembers[index] ?? [];
                
                if (deptName.isEmpty) return const SizedBox.shrink();
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: EdgeInsets.all(isCompact ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              deptName,
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 13 : 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showMemberSelection(index),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 8 : 12,
                                vertical: isCompact ? 4 : 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                members.isEmpty ? 'Add Members' : 'Edit Members',
                                style: GoogleFonts.poppins(
                                  fontSize: isCompact ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      if (members.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${members.length} member${members.length != 1 ? 's' : ''} added',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 11 : 13,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: members.take(3).map((member) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 6 : 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4FC3F7).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '@${member['username']}',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 9 : 10,
                                color: const Color(0xFF4FC3F7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )).toList(),
                        ),
                        if (members.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '+${members.length - 3} more',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 9 : 10,
                                color: Colors.white60,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAchievementsPage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 12 : 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4FC3F7).withOpacity(0.1),
                      const Color(0xFF29B6F6).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4FC3F7).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF4FC3F7),
                      size: isCompact ? 16 : 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Add achievements to showcase your committee\'s past successes.',
                        style: GoogleFonts.poppins(
                          fontSize: isCompact ? 11 : 13,
                          color: const Color(0xFF4FC3F7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: isCompact ? 16 : 20),

              Row(
                children: [
                  Text(
                    'Achievements',
                    style: GoogleFonts.poppins(
                      fontSize: isCompact ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4FC3F7),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_achievementControllers.length}/10',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ..._achievementControllers.asMap().entries.map((entry) {
                final index = entry.key;
                final controller = entry.value;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A5F).withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: controller,
                            maxLines: 2,
                            style: GoogleFonts.poppins(
                              color: Colors.white, 
                              fontSize: isCompact ? 12 : 14
                            ),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.08),
                              hintText: 'Achievement ${index + 1}...',
                              hintStyle: GoogleFonts.poppins(color: Colors.white38),
                              prefixIcon: Container(
                                margin: const EdgeInsets.all(8),
                                width: isCompact ? 20 : 24,
                                height: isCompact ? 20 : 24,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF29B6F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: isCompact ? 10 : 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 12 : 16, 
                                vertical: isCompact ? 10 : 12
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_achievementControllers.length > 1) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _removeAchievement(index),
                          child: Container(
                            padding: EdgeInsets.all(isCompact ? 6 : 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.5)),
                            ),
                            child: Icon(
                              Icons.remove,
                              color: Colors.red,
                              size: isCompact ? 14 : 16,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),

              if (_achievementControllers.length < 10) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _addAchievement,
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4FC3F7).withOpacity(0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add,
                          color: const Color(0xFF4FC3F7),
                          size: isCompact ? 16 : 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add Achievement',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF4FC3F7),
                            fontSize: isCompact ? 12 : 14,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }

  Widget _buildNavigationButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Row(
            children: [
              if (_currentPage > 0) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previousPage,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
                      side: BorderSide(color: const Color(0xFF4FC3F7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Previous',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 12 : 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4FC3F7),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: _currentPage == 0 ? 1 : 1,
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isCreatingNotifier,
                  builder: (context, isCreating, child) {
                    final isLastPage = _currentPage == _totalPages - 1;
                    final canProceed = _canProceedFromCurrentPage();
                    
                    return Container(
                      decoration: BoxDecoration(
                        gradient: canProceed 
                            ? LinearGradient(
                                colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                              )
                            : null,
                        color: canProceed ? null : Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: canProceed ? [
                          BoxShadow(
                            color: const Color(0xFF29B6F6).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: ElevatedButton(
                        onPressed: canProceed && !isCreating
                            ? (isLastPage ? _submitRequest : _nextPage)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isCreating
                            ? SizedBox(
                                height: isCompact ? 16 : 20,
                                width: isCompact ? 16 : 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isLastPage ? 'Submit Request' : 'Next',
                                style: GoogleFonts.poppins(
                                  fontSize: isCompact ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: canProceed ? Colors.white : Colors.grey,
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class MemberSelectionSheet extends StatefulWidget {
  final List<Map<String, dynamic>> availableMembers;
  final List<Map<String, dynamic>> selectedMembers;
  final String departmentName;
  final Function(List<Map<String, dynamic>>) onMembersSelected;
  final ScrollController scrollController;

  const MemberSelectionSheet({
    Key? key,
    required this.availableMembers,
    required this.selectedMembers,
    required this.departmentName,
    required this.onMembersSelected,
    required this.scrollController,
  }) : super(key: key);

  @override
  State<MemberSelectionSheet> createState() => _MemberSelectionSheetState();
}

class _MemberSelectionSheetState extends State<MemberSelectionSheet> {
  late List<Map<String, dynamic>> _selectedMembers;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final List<String> _roles = ['Member', 'Co-Lead', 'Lead', 'Assistant'];
  Map<String, String> _memberRoles = {};

  @override
  void initState() {
    super.initState();
    _selectedMembers = List.from(widget.selectedMembers);
    // Initialize roles for selected members
    for (var member in _selectedMembers) {
      _memberRoles[member['username']] = member['role'] ?? 'Member';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleMember(Map<String, dynamic> member) {
    setState(() {
      final index = _selectedMembers.indexWhere(
        (m) => m['username'] == member['username']
      );
      if (index >= 0) {
        _selectedMembers.removeAt(index);
        _memberRoles.remove(member['username']);
      } else {
        final memberWithRole = Map<String, dynamic>.from(member);
        memberWithRole['role'] = _memberRoles[member['username']] ?? 'Member';
        _selectedMembers.add(memberWithRole);
        _memberRoles[member['username']] = 'Member';
      }
    });
  }

  void _updateMemberRole(String username, String role) {
    setState(() {
      _memberRoles[username] = role;
      // Update the role in selected members list
      final index = _selectedMembers.indexWhere((m) => m['username'] == username);
      if (index >= 0) {
        _selectedMembers[index]['role'] = role;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredMembers = widget.availableMembers.where((member) {
      if (_searchQuery.isEmpty) return true;
      final username = member['username'].toString().toLowerCase();
      final name = member['name'].toString().toLowerCase();
      return username.contains(_searchQuery.toLowerCase()) ||
             name.contains(_searchQuery.toLowerCase());
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E3A5F),
                const Color(0xFF0A1628),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.all(isCompact ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Members to ${widget.departmentName}',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_selectedMembers.length} selected',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 12 : 14,
                        color: const Color(0xFF4FC3F7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Search
                    TextField(
                      controller: _searchController,
                      style: GoogleFonts.poppins(
                        color: Colors.white, 
                        fontSize: isCompact ? 12 : 14
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        hintText: 'Search members...',
                        hintStyle: GoogleFonts.poppins(color: Colors.white38),
                        prefixIcon: Icon(
                          Icons.search,
                          color: const Color(0xFF4FC3F7),
                          size: isCompact ? 18 : 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF4FC3F7), width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 12 : 16,
                          vertical: isCompact ? 8 : 10,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Members list
              Expanded(
                child: ListView.builder(
                  controller: widget.scrollController,
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 20),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    final isSelected = _selectedMembers.any(
                      (m) => m['username'] == member['username']
                    );
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? const Color(0xFF4FC3F7).withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected 
                              ? const Color(0xFF4FC3F7)
                              : Colors.white.withOpacity(0.1),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 12 : 16,
                              vertical: isCompact ? 4 : 8,
                            ),
                            leading: Container(
                              width: isCompact ? 36 : 40,
                              height: isCompact ? 36 : 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  member['username'][0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: isCompact ? 12 : 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              '@${member['username']}',
                              style: GoogleFonts.poppins(
                                fontSize: isCompact ? 13 : 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (member['name'].isNotEmpty)
                                  Text(
                                    member['name'],
                                    style: GoogleFonts.poppins(
                                      fontSize: isCompact ? 11 : 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                if (member['year'].isNotEmpty || member['branch'].isNotEmpty)
                                  Row(
                                    children: [
                                      if (member['branch'].isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4FC3F7).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            member['branch'],
                                            style: GoogleFonts.poppins(
                                              fontSize: isCompact ? 8 : 9,
                                              color: const Color(0xFF4FC3F7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (member['year'].isNotEmpty) const SizedBox(width: 4),
                                      ],
                                      if (member['year'].isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Year ${member['year']}',
                                            style: GoogleFonts.poppins(
                                              fontSize: isCompact ? 8 : 9,
                                              color: Colors.green,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                            trailing: Container(
                              width: isCompact ? 20 : 24,
                              height: isCompact ? 20 : 24,
                              decoration: BoxDecoration(
                                gradient: isSelected 
                                    ? LinearGradient(
                                        colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                                      )
                                    : null,
                                color: isSelected ? null : Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isSelected 
                                      ? Colors.transparent
                                      : Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: isCompact ? 14 : 16,
                                    )
                                  : null,
                            ),
                            onTap: () => _toggleMember(member),
                          ),
                          
                          // Role selector for selected members
                          if (isSelected) ...[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                isCompact ? 12 : 16,
                                0,
                                isCompact ? 12 : 16,
                                isCompact ? 8 : 12,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Role:',
                                    style: GoogleFonts.poppins(
                                      fontSize: isCompact ? 11 : 13,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: DropdownButton<String>(
                                        value: _memberRoles[member['username']] ?? 'Member',
                                        items: _roles.map((role) {
                                          return DropdownMenuItem(
                                            value: role,
                                            child: Text(
                                              role,
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontSize: isCompact ? 11 : 13,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (value) => _updateMemberRole(member['username'], value!),
                                        dropdownColor: const Color(0xFF1E3A5F),
                                        underline: const SizedBox(),
                                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                                        isExpanded: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Footer
              Container(
                padding: EdgeInsets.all(isCompact ? 16 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
                          side: BorderSide(color: Colors.white.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: isCompact ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [const Color(0xFF29B6F6), const Color(0xFF4FC3F7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            widget.onMembersSelected(_selectedMembers);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Done (${_selectedMembers.length})',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}