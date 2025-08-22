import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateTruthLiesPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const CreateTruthLiesPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<CreateTruthLiesPage> createState() => _CreateTruthLiesPageState();
}

class _CreateTruthLiesPageState extends State<CreateTruthLiesPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _statementControllers = List.generate(3, (_) => TextEditingController());
  
  int _truthIndex = 0;
  bool _isAnonymous = false;
  bool _isPermanentMystery = false;
  DateTime? _revealDateTime;
  bool _isSubmitting = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
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

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    for (var controller in _statementControllers) {
      controller.dispose();
    }
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _selectRevealDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF14B8A6),
              onPrimary: Colors.white,
              surface: const Color(0xFF0D9488),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.dark(
                primary: const Color(0xFF14B8A6),
                onPrimary: Colors.white,
                surface: const Color(0xFF0D9488),
                onSurface: Colors.white,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _revealDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Check if reveal time is required but not set
    if (!_isPermanentMystery && _revealDateTime == null) {
      _showMessage('Please set a reveal time or enable permanent mystery', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Get user data for non-anonymous posts
      Map<String, dynamic>? userData;
      if (!_isAnonymous) {
        final userDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .doc(widget.username)
            .get();
        userData = userDoc.data();
      }

      // Create the post
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('truth_lies_posts')
          .add({
        'userId': widget.userId,
        'username': widget.username,
        'isAnonymous': _isAnonymous,
        'firstName': _isAnonymous ? null : userData?['firstName'],
        'lastName': _isAnonymous ? null : userData?['lastName'],
        'statements': _statementControllers.map((c) => c.text.trim()).toList(),
        'truthIndex': _truthIndex,
        'truthRevealed': false,
        'isPermanentMystery': _isPermanentMystery,
        'revealTime': _isPermanentMystery || _revealDateTime == null 
            ? null 
            : Timestamp.fromDate(_revealDateTime!),
        'votes': [0, 0, 0],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context, true);
        _showMessage('Mystery created successfully!');
      }
    } catch (e) {
      _showMessage('Error creating post: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF134E4A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F766E),
              Color(0xFF134E4A),
              Color(0xFF0F172A),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: _buildForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D9488).withOpacity(0.3),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                  ).createShader(bounds),
                  child: Text(
                    'create mystery',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'share your truth and lies',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF14B8A6).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.1),
                  Colors.amber.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade700.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade400, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Write 3 statements: 1 truth and 2 lies. Mark which one is the truth!',
                    style: GoogleFonts.poppins(
                      color: Colors.amber.shade300,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statements
          ...List.generate(3, (index) => _buildStatementField(index)),

          const SizedBox(height: 24),

          // Options Section
          _buildOptionsSection(),

          const SizedBox(height: 32),

          // Submit Button
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildStatementField(int index) {
    final isTruth = _truthIndex == index;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isTruth
                        ? [const Color(0xFF14B8A6), const Color(0xFF0D9488)]
                        : [Colors.grey.shade700, Colors.grey.shade800],
                  ),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Statement ${index + 1}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _truthIndex = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isTruth
                        ? const LinearGradient(
                            colors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
                          )
                        : null,
                    color: isTruth ? null : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isTruth
                          ? const Color(0xFF14B8A6)
                          : Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTruth ? Icons.check_circle : Icons.circle_outlined,
                        color: isTruth ? Colors.white : Colors.white60,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isTruth ? 'TRUTH' : 'LIE',
                        style: GoogleFonts.poppins(
                          color: isTruth ? Colors.white : Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _statementControllers[index],
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            maxLines: 3,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              hintText: isTruth 
                  ? 'Write your truth here...' 
                  : 'Write your lie here...',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF14B8A6).withOpacity(0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF14B8A6).withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF14B8A6)),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a statement';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF14B8A6).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Options',
            style: GoogleFonts.poppins(
              color: const Color(0xFF14B8A6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Anonymous toggle
          _buildToggleOption(
            title: 'Post Anonymously',
            subtitle: 'Hide your identity (but we\'ll know 😉)',
            value: _isAnonymous,
            onChanged: (value) => setState(() => _isAnonymous = value),
            icon: Icons.person_off,
          ),

          const SizedBox(height: 16),

          // Permanent mystery toggle
          _buildToggleOption(
            title: 'Permanent Mystery',
            subtitle: 'Never reveal the truth!',
            value: _isPermanentMystery,
            onChanged: (value) {
              setState(() {
                _isPermanentMystery = value;
                if (value) _revealDateTime = null;
              });
            },
            icon: Icons.lock,
          ),

          if (!_isPermanentMystery) ...[
            const SizedBox(height: 16),
            
            // Reveal time selector
            GestureDetector(
              onTap: _selectRevealDateTime,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _revealDateTime == null 
                        ? Colors.red.withOpacity(0.5)
                        : const Color(0xFF14B8A6).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule, 
                      color: _revealDateTime == null 
                          ? Colors.red.shade400 
                          : const Color(0xFF14B8A6)
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Reveal Time',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_revealDateTime == null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '*Required',
                                  style: GoogleFonts.poppins(
                                    color: Colors.red.shade400,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            _revealDateTime != null
                                ? '${_revealDateTime!.day}/${_revealDateTime!.month}/${_revealDateTime!.year} at ${_revealDateTime!.hour.toString().padLeft(2, '0')}:${_revealDateTime!.minute.toString().padLeft(2, '0')}'
                                : 'Tap to set when truth reveals',
                            style: GoogleFonts.poppins(
                              color: _revealDateTime != null 
                                  ? const Color(0xFF14B8A6)
                                  : Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF14B8A6),
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

  Widget _buildToggleOption({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF0D9488).withOpacity(0.3) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value 
                ? const Color(0xFF14B8A6)
                : const Color(0xFF14B8A6).withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: value ? const Color(0xFF14B8A6) : Colors.white60,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF14B8A6),
              activeTrackColor: const Color(0xFF0D9488),
              inactiveThumbColor: Colors.grey.shade600,
              inactiveTrackColor: Colors.grey.shade800,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _submit,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isSubmitting
                ? [Colors.grey.shade700, Colors.grey.shade800]
                : [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _isSubmitting
                  ? Colors.transparent
                  : const Color(0xFF14B8A6).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.psychology, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Create Mystery',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}