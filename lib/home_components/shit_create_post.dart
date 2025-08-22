import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePostPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final String userRole;

  const CreatePostPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.userRole,
  }) : super(key: key);

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> with TickerProviderStateMixin {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _customTagController = TextEditingController();
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  static const int maxPredefinedTags = 3;
  static const int maxCustomTags = 1;
  
  final Set<String> _selectedTags = {};
  final Set<String> _customTags = {};
  final List<String> _predefinedTags = [
    'social',
    'travel buddy',
    'roommates',
    'seniors advice',
    'suggestions',
    'faculty gossip',
    'college trips',
    'academics',
    'placements',
    'internships',
    'food spots',
    'events',
  ];

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
    _fadeController.forward();
  }

  @override
  void dispose() {
    _contentController.dispose();
    _customTagController.dispose();
    _isLoadingNotifier.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    final content = _contentController.text.trim();
    
    if (content.isEmpty) {
      _showMessage('Please enter some content', isError: true);
      return;
    }

    if (content.length > 1000) {
      _showMessage('Content must be less than 1000 characters', isError: true);
      return;
    }

    if (_selectedTags.isEmpty) {
      _showMessage('Please select at least one tag', isError: true);
      return;
    }

    try {
      _isLoadingNotifier.value = true;

      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('shitIWishIKnew')
          .add({
        'content': content,
        'authorUsername': widget.username,
        'authorId': widget.userId,
        'authorRole': widget.userRole,
        'tags': _selectedTags.toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'isDeleted': false,
      });

      if (mounted) {
        Navigator.pop(context, true);
        _showMessage('Post created successfully!');
      }
    } catch (e) {
      _showMessage('Error creating post: $e', isError: true);
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  void _addCustomTag() {
  final customTag = _customTagController.text.trim().toLowerCase();
  
  if (customTag.isEmpty) {
    _showMessage('Please enter a custom tag', isError: true);
    return;
  }

  if (customTag.length > 20) {
    _showMessage('Tag must be less than 20 characters', isError: true);
    return;
  }

  if (_customTags.length >= maxCustomTags) {
    _showMessage('You can only add $maxCustomTags custom tag', isError: true);
    return;
  }

  if (_selectedTags.contains(customTag)) {
    _showMessage('Tag already selected', isError: true);
    return;
  }

  if (_predefinedTags.contains(customTag)) {
    _showMessage('This tag already exists in predefined tags', isError: true);
    return;
  }

  setState(() {
    _selectedTags.add(customTag);
    _customTags.add(customTag);
    _customTagController.clear();
  });
}

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade800 : const Color(0xFFF59E0B),
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
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildContentInput(),
                        const SizedBox(height: 24),
                        _buildTagsSection(),
                        const SizedBox(height: 24),
                        _buildCustomTagInput(),
                        const SizedBox(height: 32),
                        _buildCreateButton(),
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
    padding: EdgeInsets.fromLTRB(
      ScreenUtil.responsiveWidth(context, 0.05),
      MediaQuery.of(context).padding.top + 8,
      ScreenUtil.responsiveWidth(context, 0.05),
      16,
    ),
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
            onTap: () {
              // _dismissKeyboard();
              Navigator.pop(context);
            },
            child: Container(
              padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 10 : 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(ScreenUtil.isTablet(context) ? 14 : 12),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: ScreenUtil.isTablet(context) ? 22 : 18,
              ),
            ),
          ),
        Container(
          margin: EdgeInsets.only(left:15),
          padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 12 : 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.edit, 
            color: Colors.white, 
            size: ScreenUtil.isTablet(context) ? 24 : 20,
          ),
        ),
        SizedBox(width: ScreenUtil.isTablet(context) ? 16 : 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                ).createShader(bounds),
                child: Text(
                  'create post',
                  style: GoogleFonts.dmSerifDisplay(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5
                        ),
                ),
              ),
              Text(
                'share your wisdom',
                style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFFF59E0B),
                      ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildContentInput() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 400;
        
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1B263B).withOpacity(0.2),
                const Color(0xFF0D1B2A).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF1B263B).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 20, 
                  isCompact ? 16 : 20, 
                  isCompact ? 16 : 20, 
                  isCompact ? 8 : 12
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: const Color(0xFFF59E0B),
                      size: isCompact ? 18 : 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'share it!',
                      style: GoogleFonts.poppins(
                        fontSize: isCompact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isCompact ? 16 : 20, 
                  0, 
                  isCompact ? 16 : 20, 
                  isCompact ? 16 : 20
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _contentController,
                      maxLines: isCompact ? 8 : 10,
                      maxLength: 1000,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isCompact ? 13 : 15,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Share your thoughts, experiences, tips, or any advice that could help fellow students...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: isCompact ? 13 : 15,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: const Color(0xFFF59E0B),
                            width: 2,
                          ),
                        ),
                        counterStyle: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: isCompact ? 10 : 12,
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

  Widget _buildTagsSection() {
  final selectedPredefinedCount = _selectedTags.where((tag) => _predefinedTags.contains(tag)).length;
  
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1B263B).withOpacity(0.2),
          const Color(0xFF0D1B2A).withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF1B263B).withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_offer_outlined,
                color: const Color(0xFFF59E0B),
                size: ScreenUtil.isTablet(context) ? 20 : 18,
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
              Text(
                'Select Tags',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveFonts.body(context),
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              Text(
                ' ($selectedPredefinedCount/$maxPredefinedTags)',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveFonts.caption(context),
                  color: const Color(0xFFF59E0B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Wrap(
  spacing: ScreenUtil.isTablet(context) ? 8 : 6,
  runSpacing: ScreenUtil.isTablet(context) ? 8 : 6,
  children: _predefinedTags.map((tag) {
    final isSelected = _selectedTags.contains(tag);
    final canSelect = selectedPredefinedCount < maxPredefinedTags || isSelected;
    
    return FilterChip(
      label: Text(
        tag,
        style: GoogleFonts.poppins(
          fontSize: ResponsiveFonts.caption(context) - 1,
          fontWeight: FontWeight.w500,
          color: isSelected 
              ? Colors.white 
              : canSelect 
                  ? Colors.white70
                  : const Color.fromARGB(255, 79, 79, 79), // Changed to golden color for disabled tags
        ),
      ),
      selected: isSelected,
      onSelected: canSelect ? (selected) {
        setState(() {
          if (selected) {
            _selectedTags.add(tag);
          } else {
            _selectedTags.remove(tag);
          }
        });
      } : null,
      backgroundColor: canSelect 
          ? Colors.grey[900] 
          : const Color.fromARGB(255, 79, 79, 79),  // Dark brownish background for disabled
      selectedColor: const Color(0xFFF59E0B),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected 
            ? const Color(0xFFF59E0B) 
            : canSelect
                ? Colors.white24
                : const Color.fromARGB(255, 79, 79, 79),  // Golden border for disabled
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }).toList(),
),
          
          // Selected custom tags
          if (_customTags.isNotEmpty) ...[
            SizedBox(height: ScreenUtil.isTablet(context) ? 16 : 12),
            Text(
              'Custom Tag:',
              style: GoogleFonts.poppins(
                fontSize: ResponsiveFonts.caption(context),
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: ScreenUtil.isTablet(context) ? 8 : 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _customTags.map((tag) => Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ScreenUtil.isTablet(context) ? 10 : 8, 
                  vertical: ScreenUtil.isTablet(context) ? 6 : 4
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$tag',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveFonts.caption(context) - 1,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: ScreenUtil.isTablet(context) ? 6 : 4),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTags.remove(tag);
                          _customTags.remove(tag);
                        });
                      },
                      child: Icon(
                        Icons.close,
                        size: ScreenUtil.isTablet(context) ? 14 : 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _buildCustomTagInput() {
  final canAddCustom = _customTags.length < maxCustomTags;
  
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1B263B).withOpacity(0.2),
          const Color(0xFF0D1B2A).withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF1B263B).withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Padding(
      padding: EdgeInsets.all(ScreenUtil.isTablet(context) ? 20 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_circle_outline,
                color: canAddCustom ? const Color(0xFFF59E0B) : Colors.grey,
                size: ScreenUtil.isTablet(context) ? 20 : 18,
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 8 : 6),
              Text(
                'Add Custom Tag',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveFonts.body(context),
                  fontWeight: FontWeight.w600,
                  color: canAddCustom ? Colors.white : Colors.grey,
                ),
              ),
              Text(
                ' (${_customTags.length}/$maxCustomTags)',
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveFonts.caption(context),
                  color: canAddCustom ? const Color(0xFFF59E0B) : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          SizedBox(height: ScreenUtil.isTablet(context) ? 12 : 8),
          
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  enabled: canAddCustom,
                  maxLength: 20,
                  style: GoogleFonts.poppins(
                    color: canAddCustom ? Colors.white : Colors.grey,
                    fontSize: ResponsiveFonts.body(context),
                  ),
                  decoration: InputDecoration(
                    hintText: canAddCustom ? 'Enter custom tag...' : 'Maximum custom tags reached',
                    hintStyle: GoogleFonts.poppins(
                      color: canAddCustom ? Colors.white38 : Colors.grey,
                      fontSize: ResponsiveFonts.body(context),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(canAddCustom ? 0.05 : 0.02),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFFF59E0B),
                        width: 2,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.withOpacity(0.3),
                      ),
                    ),
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ScreenUtil.isTablet(context) ? 16 : 12,
                      vertical: ScreenUtil.isTablet(context) ? 12 : 10,
                    ),
                  ),
                  onSubmitted: canAddCustom ? (_) => _addCustomTag() : null,
                ),
              ),
              SizedBox(width: ScreenUtil.isTablet(context) ? 12 : 8),
              Container(
                decoration: BoxDecoration(
                  gradient: canAddCustom 
                      ? LinearGradient(
                          colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                        )
                      : LinearGradient(
                          colors: [Colors.grey, Colors.grey],
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: canAddCustom ? _addCustomTag : null,
                  icon: Icon(
                    Icons.add,
                    color: Colors.white,
                    size: ScreenUtil.isTablet(context) ? 20 : 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildCreateButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingNotifier,
      builder: (context, isLoading, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 400;
            
            return Container(
              width: double.infinity,
              height: isCompact ? 50 : 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: isLoading ? null : _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isLoading
                    ? SizedBox(
                        width: isCompact ? 20 : 24,
                        height: isCompact ? 20 : 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.publish,
                            color: Colors.white,
                            size: isCompact ? 18 : 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'create post',
                            style: GoogleFonts.poppins(
                              fontSize: isCompact ? 14 : 16,
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
      },
    );
  }
}

class ScreenUtil {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
  
  static bool isTablet(BuildContext context) => screenWidth(context) > 600;
  static bool isDesktop(BuildContext context) => screenWidth(context) > 1200;
  
  static double responsiveWidth(BuildContext context, double fraction) {
    return screenWidth(context) * fraction;
  }
}

class ResponsiveFonts {
  static double title(BuildContext context) {
    if (ScreenUtil.isTablet(context)) return 28;
    return 24;
  }
  
  static double body(BuildContext context) {
    if (ScreenUtil.isTablet(context)) return 16;
    return 14;
  }
  
  static double caption(BuildContext context) {
    if (ScreenUtil.isTablet(context)) return 14;
    return 12;
  }
}