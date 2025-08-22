import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateConfessionPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final String userRole;

  const CreateConfessionPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
  }) : super(key: key);

  @override
  State<CreateConfessionPage> createState() => _CreateConfessionPageState();
}

class _CreateConfessionPageState extends State<CreateConfessionPage> with TickerProviderStateMixin {
  final TextEditingController _contentController = TextEditingController();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isAnonymous = true;
  String _visibilityType = 'everyone';
  List<String> _selectedYears = [];
  List<String> _selectedBranches = [];
  
  List<String> _availableYears = [];
  List<String> _availableBranches = [];
  
  int get _remainingChars => 1000 - _contentController.text.length;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadAvailableOptions();
    _contentController.addListener(() => setState(() {}));
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
    _contentController.dispose();
    _isLoadingNotifier.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableOptions() async {
    try {
      Set<String> years = {};
      Set<String> branches = {};
      
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
          years.add(data['year'].toString());
        }
        if (data['branch'] != null && data['branch'].toString().isNotEmpty) {
          branches.add(data['branch'].toString());
        }
      }

      setState(() {
        _availableYears = years.toList()..sort();
        _availableBranches = branches.toList()..sort();
      });
    } catch (e) {
      print('Error loading options: $e');
    }
  }

  Future<void> _submitConfession() async {
    if (_contentController.text.trim().isEmpty) {
      _showMessage('Please write your confession', isError: true);
      return;
    }

    if (_contentController.text.length > 1000) {
      _showMessage('Confession must be under 1000 characters', isError: true);
      return;
    }

    if (_visibilityType == 'year' && _selectedYears.isEmpty) {
      _showMessage('Please select at least one year', isError: true);
      return;
    }

    if (_visibilityType == 'branch' && _selectedBranches.isEmpty) {
      _showMessage('Please select at least one branch', isError: true);
      return;
    }

    if (_visibilityType == 'branch_year' && (_selectedYears.isEmpty || _selectedBranches.isEmpty)) {
      _showMessage('Please select both year and branch', isError: true);
      return;
    }

    _isLoadingNotifier.value = true;

    try {
      final confessionRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('confessions')
          .doc();

      Map<String, dynamic> visibilityData = {'type': _visibilityType};
      if (_visibilityType == 'year' || _visibilityType == 'branch_year') {
        visibilityData['allowedYears'] = _selectedYears;
      }
      if (_visibilityType == 'branch' || _visibilityType == 'branch_year') {
        visibilityData['allowedBranches'] = _selectedBranches;
      }

      await confessionRef.set({
        'content': _contentController.text.trim(),
        'authorUsername': widget.username,
        'authorId': widget.userId,
        'isAnonymous': _isAnonymous,
        'visibility': visibilityData,
        'status': 'pending', // Needs admin approval
        'likes': [],
        'dislikes': [],
        'likesCount': 0,
        'dislikesCount': 0,
        'reactions': {},
        'createdAt': FieldValue.serverTimestamp(),
        'submittedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Confession submitted for review');
      Navigator.pop(context, true);
    } catch (e) {
      _showMessage('Error submitting confession: $e', isError: true);
    } finally {
      _isLoadingNotifier.value = false;
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
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8B5CF6).withOpacity(0.1),
              const Color(0xFFA855F7).withOpacity(0.05),
              const Color(0xFF0D1B2A),
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContentSection(),
                        const SizedBox(height: 24),
                        _buildAnonymitySection(),
                        const SizedBox(height: 24),
                        _buildVisibilitySection(),
                        const SizedBox(height: 32),
                        _buildSubmitButton(),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8B5CF6).withOpacity(0.2),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.psychology, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                  ).createShader(bounds),
                  child: Text(
                    'new confession',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
                Text(
                  'share your thoughts safely',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Confession',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _contentController,
            maxLines: 8,
            maxLength: 1000,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'What\'s on your mind? Share your thoughts, experiences, or secrets...',
              hintStyle: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterText: '',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Characters remaining: $_remainingChars',
              style: GoogleFonts.poppins(
                color: _remainingChars < 100 ? Colors.orange : Colors.white60,
                fontSize: 12,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_contentController.text.length}/1000',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnonymitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Identity',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.04),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isAnonymous = true),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: _isAnonymous
                        ? LinearGradient(
                            colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                          )
                        : null,
                    color: _isAnonymous ? null : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isAnonymous 
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.privacy_tip,
                        color: _isAnonymous ? Colors.white : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Anonymous',
                              style: GoogleFonts.poppins(
                                color: _isAnonymous ? Colors.white : Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Your identity will be hidden from others',
                              style: GoogleFonts.poppins(
                                color: _isAnonymous ? Colors.white70 : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAnonymous)
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => setState(() => _isAnonymous = false),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: !_isAnonymous
                        ? LinearGradient(
                            colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                          )
                        : null,
                    color: !_isAnonymous ? null : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_isAnonymous 
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person,
                        color: !_isAnonymous ? Colors.white : Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Show Identity',
                              style: GoogleFonts.poppins(
                                color: !_isAnonymous ? Colors.white : Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Your name and profile will be visible',
                              style: GoogleFonts.poppins(
                                color: !_isAnonymous ? Colors.white70 : Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isAnonymous)
                        const Icon(Icons.check_circle, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVisibilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Visibility',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        _buildVisibilityOption('everyone', 'Everyone', 'All community members can see'),
        const SizedBox(height: 8),
        _buildVisibilityOption('year', 'Specific Year', 'Only selected year students can see'),
        if (_visibilityType == 'year') ...[
          const SizedBox(height: 12),
          _buildYearSelector(),
        ],
        const SizedBox(height: 8),
        _buildVisibilityOption('branch', 'Specific Branch', 'Only selected branch students can see'),
        if (_visibilityType == 'branch') ...[
          const SizedBox(height: 12),
          _buildBranchSelector(),
        ],
        const SizedBox(height: 8),
        _buildVisibilityOption('branch_year', 'Branch + Year', 'Only selected branch and year students can see'),
        if (_visibilityType == 'branch_year') ...[
          const SizedBox(height: 12),
          _buildYearSelector(),
          const SizedBox(height: 8),
          _buildBranchSelector(),
        ],
      ],
    );
  }

  Widget _buildVisibilityOption(String value, String title, String description) {
    final isSelected = _visibilityType == value;
    
    return GestureDetector(
      onTap: () => setState(() {
        _visibilityType = value;
        if (value != 'year' && value != 'branch_year') _selectedYears.clear();
        if (value != 'branch' && value != 'branch_year') _selectedBranches.clear();
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                )
              : null,
          color: isSelected ? null : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF8B5CF6)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _getVisibilityIcon(value),
              color: isSelected ? Colors.white : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white70 : Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  IconData _getVisibilityIcon(String type) {
    switch (type) {
      case 'everyone':
        return Icons.public;
      case 'year':
        return Icons.school;
      case 'branch':
        return Icons.category;
      case 'branch_year':
        return Icons.group;
      default:
        return Icons.visibility;
    }
  }

  Widget _buildYearSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Years',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableYears.map((year) {
              final isSelected = _selectedYears.contains(year);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedYears.remove(year);
                  } else {
                    _selectedYears.add(year);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    year,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Branches',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableBranches.map((branch) {
              final isSelected = _selectedBranches.contains(branch);
              return GestureDetector(
                onTap: () => setState(() {
                  if (isSelected) {
                    _selectedBranches.remove(branch);
                  } else {
                    _selectedBranches.add(branch);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
                          )
                        : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected 
                          ? const Color(0xFF8B5CF6)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    branch,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        return SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF8B5CF6), const Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : _submitConfession,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Submit for Review',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}