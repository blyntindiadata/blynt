import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePollPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final String userRole;

  const CreatePollPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
  }) : super(key: key);

  @override
  State<CreatePollPage> createState() => _CreatePollPageState();
}

class _CreatePollPageState extends State<CreatePollPage> with TickerProviderStateMixin {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  
  final ValueNotifier<bool> _isCreatingNotifier = ValueNotifier(false);
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final ScrollController _scrollController = ScrollController();

  // Visibility settings
  String _visibility = 'everyone';
  String _selectedYear = 'all';
  String _selectedBranch = 'all';
  Map<String, dynamic>? _userProfile;
  List<String> _availableYears = ['all'];
  List<String> _availableBranches = ['all'];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadUserProfile();
    _loadFilterOptions();
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
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    _isCreatingNotifier.dispose();
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (trioQuery.docs.isNotEmpty) {
        final data = trioQuery.docs.first.data();
        final profile = Map<String, dynamic>.from(data);
        if (profile['year'] != null) {
          profile['year'] = profile['year'].toString();
        }
        if (profile['branch'] != null) {
          profile['branch'] = profile['branch'].toString();
        }
        
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _selectedYear = profile['year'] ?? 'all';
            _selectedBranch = profile['branch'] ?? 'all';
          });
        }
        return;
      }

      // Check members collection
      final memberQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (memberQuery.docs.isNotEmpty) {
        final data = memberQuery.docs.first.data();
        final profile = Map<String, dynamic>.from(data);
        if (profile['year'] != null) {
          profile['year'] = profile['year'].toString();
        }
        if (profile['branch'] != null) {
          profile['branch'] = profile['branch'].toString();
        }
        
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _selectedYear = profile['year'] ?? 'all';
            _selectedBranch = profile['branch'] ?? 'all';
          });
        }
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      // Try loading from community document first
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
      } else {
        // Fallback to loading from members
        await _loadFilterOptionsFromMembers();
      }
    } catch (e) {
      print('Error loading filter options: $e');
      await _loadFilterOptionsFromMembers();
    }
  }

  Future<void> _loadFilterOptionsFromMembers() async {
    try {
      final membersSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .get();

      final trioSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .get();

      final years = <String>{'all'};
      final branches = <String>{'all'};

      for (var doc in [...membersSnapshot.docs, ...trioSnapshot.docs]) {
        final data = doc.data();
        if (data['year'] != null) years.add(data['year'].toString());
        if (data['branch'] != null) branches.add(data['branch'].toString());
      }

      if (mounted) {
        setState(() {
          _availableYears = years.toList()..sort();
          _availableBranches = branches.toList()..sort();
        });
      }
    } catch (e) {
      print('Error loading filter options from members: $e');
    }
  }

  void _addOption() {
    if (_optionControllers.length < 8) {
      setState(() {
        _optionControllers.add(TextEditingController());
      });
    }
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _createPoll() async {
    if (_questionController.text.trim().isEmpty) {
      _showMessage('Please enter a question', isError: true);
      return;
    }

    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    if (options.length < 2) {
      _showMessage('Please provide at least 2 options', isError: true);
      return;
    }

    try {
      _isCreatingNotifier.value = true;

      // Determine visibility settings
      Map<String, dynamic> visibilitySettings = {
        'type': _visibility,
      };

      final isPrivilegedUser = widget.userRole == 'admin' || 
                              widget.userRole == 'manager' || 
                              widget.userRole == 'moderator';

      if (_visibility == 'everyone') {
        visibilitySettings['allowedYears'] = <String>[];
        visibilitySettings['allowedBranches'] = <String>[];
      } else if (_visibility == 'year') {
        visibilitySettings['allowedYears'] = [_userProfile?['year']];
        visibilitySettings['allowedBranches'] = <String>[];
      } else if (_visibility == 'branch') {
        visibilitySettings['allowedYears'] = <String>[];
        visibilitySettings['allowedBranches'] = [_userProfile?['branch']];
      } else if (_visibility == 'branch_year') {
        visibilitySettings['allowedYears'] = [_userProfile?['year']];
        visibilitySettings['allowedBranches'] = [_userProfile?['branch']];
      } else if (_visibility == 'custom') {
        visibilitySettings['allowedYears'] = _selectedYear != 'all' ? [_selectedYear] : <String>[];
        visibilitySettings['allowedBranches'] = _selectedBranch != 'all' ? [_selectedBranch] : <String>[];
      }

      final pollData = {
        'question': _questionController.text.trim(),
        'options': options,
        'optionCounts': List.filled(options.length, 0),
        'votes': <String, List<String>>{},
        'voteTimestamps': <String, dynamic>{},
        'totalVotes': 0,
        'creatorId': widget.userId,
        'creatorUsername': widget.username,
        'creatorRole': widget.userRole,
        'communityId': widget.communityId,
        'visibility': visibilitySettings,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('polls')
          .add(pollData);

      if (mounted) {
        _showMessage('Poll created successfully!');
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showMessage('Error creating poll: $e', isError: true);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isCompact = screenWidth < 350;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1B263B),
              const Color(0xFF0D1B2A),
              const Color(0xFF041426),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                _buildHeader(screenWidth, isTablet, isCompact),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.all(isTablet ? 24 : (isCompact ? 16 : 20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuestionSection(screenWidth, isTablet, isCompact),
                        SizedBox(height: isTablet ? 32 : 24),
                        _buildOptionsSection(screenWidth, isTablet, isCompact),
                        SizedBox(height: isTablet ? 32 : 24),
                        _buildVisibilitySection(screenWidth, isTablet, isCompact),
                        SizedBox(height: isTablet ? 40 : 32),
                        _buildCreateButton(screenWidth, isTablet, isCompact),
                      ],
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

  Widget _buildHeader(double screenWidth, bool isTablet, bool isCompact) {
  return Container(
    padding: EdgeInsets.all(isTablet ? 24 : (isCompact ? 16 : 20)),
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
          margin: EdgeInsets.only(left: 15),
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
            Icons.add_circle,
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
                  'create poll',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isTablet ? 28 : (isCompact ? 18 : 22),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'ask the community',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : (isCompact ? 10 : 12),
                  color: const Color(0xFF64B5F6),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildQuestionSection(double screenWidth, bool isTablet, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64B5F6),
          ),
        ),
        SizedBox(height: isTablet ? 12 : 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1B263B).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: _questionController,
            maxLines: 3,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              hintText: 'What would you like to ask the community?',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
              ),
              contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection(double screenWidth, bool isTablet, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Options',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 18 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64B5F6),
              ),
            ),
            const Spacer(),
            Text(
              '${_optionControllers.length}/8',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 14 : 12,
                color: Colors.white60,
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 16 : 12),
        
        ..._optionControllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;
          
          return Container(
            margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1B263B).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.08),
                        hintText: 'Option ${index + 1}',
                        hintStyle: GoogleFonts.poppins(color: Colors.white38),
                        prefixIcon: Container(
                          margin: EdgeInsets.all(isTablet ? 10 : 8),
                          width: isTablet ? 28 : (isCompact ? 20 : 24),
                          height: isTablet ? 28 : (isCompact ? 20 : 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1976D2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isTablet ? 14 : (isCompact ? 10 : 12),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                          borderSide: const BorderSide(color: Color(0xFF64B5F6), width: 2),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : (isCompact ? 12 : 16),
                          vertical: isTablet ? 16 : (isCompact ? 10 : 12),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_optionControllers.length > 2) ...[
                  SizedBox(width: isTablet ? 12 : 8),
                  GestureDetector(
                    onTap: () => _removeOption(index),
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 10 : (isCompact ? 6 : 8)),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.5)),
                      ),
                      child: Icon(
                        Icons.remove,
                        color: Colors.red,
                        size: isTablet ? 20 : (isCompact ? 14 : 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        
        if (_optionControllers.length < 8) ...[
          SizedBox(height: isTablet ? 12 : 8),
          GestureDetector(
            onTap: _addOption,
            child: Container(
              padding: EdgeInsets.all(isTablet ? 16 : (isCompact ? 10 : 12)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
                border: Border.all(
                  color: const Color(0xFF64B5F6).withOpacity(0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add,
                    color: const Color(0xFF64B5F6),
                    size: isTablet ? 24 : (isCompact ? 16 : 20),
                  ),
                  SizedBox(width: isTablet ? 12 : 8),
                  Text(
                    'Add Option',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64B5F6),
                      fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVisibilitySection(double screenWidth, bool isTablet, bool isCompact) {
    final isPrivilegedUser = widget.userRole == 'admin' || 
                            widget.userRole == 'manager' || 
                            widget.userRole == 'moderator';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who can see this poll?',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64B5F6),
          ),
        ),
        SizedBox(height: isTablet ? 16 : 12),
        
        // Everyone option - available to all users
        _buildVisibilityOption(
          'everyone',
          'Everyone',
          'All community members can see and vote',
          Icons.public,
          screenWidth,
          isTablet,
          isCompact,
        ),
        
        if (isPrivilegedUser) ...[
          // For privileged users: Only Everyone and Custom Selection
          _buildVisibilityOption(
            'custom',
            'Custom Selection',
            'Choose specific years and branches',
            Icons.tune,
            screenWidth,
            isTablet,
            isCompact,
          ),
        ] else ...[
          // For regular members: Show all specific options based on their profile
          if (_userProfile?['year'] != null)
            _buildVisibilityOption(
              'year',
              'My Year Only',
              'Only Year ${_userProfile?['year']} students',
              Icons.school,
              screenWidth,
              isTablet,
              isCompact,
            ),
          
          if (_userProfile?['branch'] != null)
            _buildVisibilityOption(
              'branch',
              'My Branch Only',
              'Only ${_userProfile?['branch']} students',
              Icons.account_tree,
              screenWidth,
              isTablet,
              isCompact,
            ),
          
          if (_userProfile?['year'] != null && _userProfile?['branch'] != null)
            _buildVisibilityOption(
              'branch_year',
              'My Branch & Year',
              '${_userProfile?['branch']} Year ${_userProfile?['year']} only',
              Icons.group,
              screenWidth,
              isTablet,
              isCompact,
            ),
        ],
        
        // Show custom settings panel when custom is selected
        if (_visibility == 'custom') ...[
          SizedBox(height: isTablet ? 16 : 12),
          _buildCustomVisibilityOptions(screenWidth, isTablet, isCompact),
        ],
      ],
    );
  }

Widget _buildVisibilityOption(String value, String title, String subtitle, IconData icon, double screenWidth, bool isTablet, bool isCompact) {
  final isSelected = _visibility == value;
  
  return Container(
    margin: EdgeInsets.only(bottom: isTablet ? 12 : 8),
    child: InkWell(
      onTap: () async {
        final previousVisibility = _visibility;
        
        // Handle auto-scroll when switching from custom to other options
        if (previousVisibility == 'custom' && value != 'custom') {
          // Start the scroll immediately, before setState
          final currentOffset = _scrollController.offset;
          final scrollAdjustment = isTablet ? 220.0 : 180.0;
          final targetOffset = (currentOffset - scrollAdjustment).clamp(0.0, _scrollController.position.maxScrollExtent);
          
          // Update state and scroll simultaneously
          setState(() => _visibility = value);
          
          if (currentOffset > 0) {
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
            );
          }
        }
        // Handle auto-scroll when switching to custom
        else if (previousVisibility != 'custom' && value == 'custom') {
          setState(() => _visibility = value);
          
          // Small delay to let custom panel start appearing
          await Future.delayed(const Duration(milliseconds: 50));
          
          _scrollController.animateTo(
            _scrollController.offset + (isTablet ? 80.0 : 60.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
        else {
          // Simple state change for other transitions
          setState(() => _visibility = value);
        }
      },
      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(isTablet ? 20 : (isCompact ? 12 : 16)),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF64B5F6)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: EdgeInsets.all(isTablet ? 12 : (isCompact ? 8 : 10)),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: isTablet ? 24 : (isCompact ? 16 : 20),
              ),
            ),
            SizedBox(width: isTablet ? 16 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 17 : (isCompact ? 13 : 15),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isTablet ? 4 : 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 14 : (isCompact ? 10 : 12),
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedScale(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              scale: isSelected ? 1.0 : 0.0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                opacity: isSelected ? 1.0 : 0.0,
                child: Icon(
                  Icons.check_circle,
                  color: const Color(0xFF64B5F6),
                  size: isTablet ? 26 : (isCompact ? 18 : 22),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// Update the custom visibility options section to animate smoothly
Widget _buildCustomVisibilityOptions(double screenWidth, bool isTablet, bool isCompact) {
  final isPrivilegedUser = widget.userRole == 'admin' || 
                          widget.userRole == 'manager' || 
                          widget.userRole == 'moderator';
  
  return AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    padding: EdgeInsets.all(isTablet ? 20 : (isCompact ? 12 : 16)),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Custom Settings',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 17 : (isCompact ? 13 : 15),
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64B5F6),
              ),
            ),
            const Spacer(),
            if (isPrivilegedUser)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 8 : (isCompact ? 4 : 6),
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade600, Colors.orange.shade600],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.userRole.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 9 : (isCompact ? 7 : 8),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: isTablet ? 16 : 12),
        
        // Year selection
        Row(
          children: [
            Expanded(
              child: Text(
                'Year:',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
                  color: Colors.white70,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : (isCompact ? 8 : 12),
                vertical: isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedYear,
                items: _availableYears.map((year) {
                  return DropdownMenuItem(
                    value: year,
                    child: Text(
                      year == 'all' ? 'All Years' : '$year',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isTablet ? 15 : (isCompact ? 11 : 13),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedYear = value!),
                dropdownColor: const Color(0xFF1B263B),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: isTablet ? 12 : 8),
        
        // Branch selection
        Row(
          children: [
            Expanded(
              child: Text(
                'Branch:',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 16 : (isCompact ? 12 : 14),
                  color: Colors.white70,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : (isCompact ? 8 : 12),
                vertical: isTablet ? 8 : 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                value: _selectedBranch,
                items: _availableBranches.map((branch) {
                  return DropdownMenuItem(
                    value: branch,
                    child: Text(
                      branch == 'all' ? 'All Branches' : branch,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isTablet ? 15 : (isCompact ? 11 : 13),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedBranch = value!),
                dropdownColor: const Color(0xFF1B263B),
                underline: const SizedBox(),
                icon: Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white,
                  size: isTablet ? 24 : 20,
                ),
              ),
            ),
          ],
        ),
        
        SizedBox(height: isTablet ? 16 : 12),
        
        // Help text based on user role
        Container(
          padding: EdgeInsets.all(isTablet ? 14 : (isCompact ? 8 : 10)),
          decoration: BoxDecoration(
            color: isPrivilegedUser 
                ? Colors.amber.shade900.withOpacity(0.2)
                : const Color(0xFF1976D2).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPrivilegedUser 
                  ? Colors.amber.shade700.withOpacity(0.3)
                  : const Color(0xFF64B5F6).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isPrivilegedUser ? Icons.admin_panel_settings : Icons.info_outline,
                color: isPrivilegedUser ? Colors.amber.shade400 : const Color(0xFF64B5F6),
                size: isTablet ? 18 : (isCompact ? 14 : 16),
              ),
              SizedBox(width: isTablet ? 12 : 8),
              Expanded(
                child: Text(
                  isPrivilegedUser 
                      ? 'As ${widget.userRole}, you can create polls for any combination of years and branches in the community.'
                      : 'Select "All" to include everyone in that category, or choose specific options to limit visibility.',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 12 : (isCompact ? 9 : 10),
                    color: isPrivilegedUser ? Colors.amber.shade400 : const Color(0xFF64B5F6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildCreateButton(double screenWidth, bool isTablet, bool isCompact) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isCreatingNotifier,
      builder: (context, isCreating, child) {
        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1976D2),
                const Color(0xFF64B5F6),
              ],
            ),
            borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: isCreating ? null : _createPoll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 20 : (isCompact ? 14 : 16),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
              ),
            ),
            child: isCreating
                ? SizedBox(
                    height: isTablet ? 24 : (isCompact ? 16 : 20),
                    width: isTablet ? 24 : (isCompact ? 16 : 20),
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: isTablet ? 3 : 2,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: isTablet ? 26 : (isCompact ? 18 : 22),
                      ),
                      SizedBox(width: isTablet ? 12 : 8),
                      Text(
                        'Create Poll',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 18 : (isCompact ? 14 : 16),
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}