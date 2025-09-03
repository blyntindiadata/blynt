import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateNoticeScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const CreateNoticeScreen({
    super.key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  });

  @override
  State<CreateNoticeScreen> createState() => _CreateNoticeScreenState();
}

class _CreateNoticeScreenState extends State<CreateNoticeScreen> {
  final TextEditingController _headingController = TextEditingController();
  final TextEditingController _noticeController = TextEditingController();
  final FocusNode _headingFocusNode = FocusNode();
  final FocusNode _noticeFocusNode = FocusNode();
  
  bool _isLoading = false;
  int _currentNoticeCount = 0;
  bool _isLoadingCount = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentNoticeCount();
  }

  @override
  void dispose() {
    _headingController.dispose();
    _noticeController.dispose();
    _headingFocusNode.dispose();
    _noticeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentNoticeCount() async {
    try {
      final noticesQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('notices')
          .where('isActive', isEqualTo: true)
          .get();
      
      setState(() {
        _currentNoticeCount = noticesQuery.docs.length;
        _isLoadingCount = false;
      });
    } catch (e) {
      print('Error loading notice count: $e');
      setState(() {
        _isLoadingCount = false;
      });
    }
  }

  Future<void> _createNotice() async {
    if (_headingController.text.trim().isEmpty) {
      _showSnackBar('Please enter a heading for the notice', Colors.red);
      return;
    }

    if (_noticeController.text.trim().isEmpty) {
      _showSnackBar('Please enter the notice content', Colors.red);
      return;
    }

    if (_currentNoticeCount >= 3) {
      _showSnackBar('Maximum 3 active notices allowed. Please delete an existing notice first.', Colors.orange);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Create notice document
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('notices')
          .add({
        'heading': _headingController.text.trim(),
        'content': _noticeController.text.trim(),
        'createdBy': widget.userId,
        'createdByUsername': widget.username,
        'createdByRole': widget.userRole,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'priority': _currentNoticeCount + 1, // For ordering
      });

      _showSnackBar('Notice created successfully!', Colors.green);
      
      // Clear form
      _headingController.clear();
      _noticeController.clear();
      
      // Navigate back
      Navigator.of(context).pop(true); // Return true to indicate success
      
    } catch (e) {
      print('Error creating notice: $e');
      _showSnackBar('Failed to create notice: $e', Colors.red);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? screenWidth * 0.1 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Create Notice',
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 24 : 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoadingCount
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF7B42C),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notice Count Info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF7B42C).withOpacity(0.2),
                          const Color(0xFFF7B42C).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF7B42C).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7B42C),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.black87,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active Notices: $_currentNoticeCount/3',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 16 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentNoticeCount >= 3
                                    ? 'Maximum limit reached. Delete existing notices to create new ones.'
                                    : 'You can create ${3 - _currentNoticeCount} more notice${3 - _currentNoticeCount == 1 ? '' : 's'}.',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 13 : 12,
                                  color: _currentNoticeCount >= 3 
                                      ? Colors.orange.shade300 
                                      : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Heading Field
                  Text(
                    'Notice Heading',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _headingController,
                      focusNode: _headingFocusNode,
                      maxLength: 50,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter notice heading (max 50 characters)',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: isTablet ? 16 : 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
                        counterStyle: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) {
                        FocusScope.of(context).requestFocus(_noticeFocusNode);
                      },
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Notice Content Field
                  Text(
                    'Notice Content',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _noticeController,
                      focusNode: _noticeFocusNode,
                      maxLines: isTablet ? 8 : 6,
                      maxLength: 300,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: isTablet ? 16 : 14,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter notice content (max 300 characters)',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: isTablet ? 16 : 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(isTablet ? 20 : 16),
                        counterStyle: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.05),

                  // Create Button
                  SizedBox(
                    width: double.infinity,
                    height: isTablet ? 60 : 52,
                    child: ElevatedButton(
                      onPressed: _currentNoticeCount >= 3 || _isLoading
                          ? null
                          : _createNotice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentNoticeCount >= 3 
                            ? Colors.grey.shade700 
                            : const Color(0xFFF7B42C),
                        foregroundColor: Colors.black87,
                        elevation: _currentNoticeCount >= 3 ? 0 : 8,
                        shadowColor: _currentNoticeCount >= 3 
                            ? Colors.transparent 
                            : const Color(0xFFF7B42C).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        disabledBackgroundColor: Colors.grey.shade700,
                        disabledForegroundColor: Colors.white60,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _currentNoticeCount >= 3 
                                      ? Colors.white60 
                                      : Colors.black87,
                                ),
                              ),
                            )
                          : Text(
                              _currentNoticeCount >= 3 
                                  ? 'Maximum Notices Reached' 
                                  : 'Create Notice',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.w600,
                                color: _currentNoticeCount >= 3 
                                    ? Colors.white60 
                                    : Colors.black87,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Guidelines
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Guidelines',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 16 : 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...const [
                          '• Maximum 3 active notices allowed at once',
                          '• Heading: Maximum 50 characters',
                          '• Content: Maximum 300 characters',
                          '• Notices will be displayed in auto-scrolling format',
                          '• Only admins, moderators can create notices',
                        ].map((guideline) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            guideline,
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 13 : 12,
                              color: Colors.blue.shade300,
                              height: 1.4,
                            ),
                          ),
                        )).toList(),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.05),
                ],
              ),
            ),
    );
  }
}