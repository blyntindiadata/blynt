import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class NoticesCarousel extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;
  final VoidCallback? onManageNotices;

  const NoticesCarousel({
    super.key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
    this.onManageNotices,
  });

  @override
  State<NoticesCarousel> createState() => _NoticesCarouselState();
}

class _NoticesCarouselState extends State<NoticesCarousel> {
  PageController? _pageController;
  Timer? _timer;
  int _currentPage = 0;
  List<Map<String, dynamic>> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  Future<void> _loadNotices() async {
    try {
      final noticesSnapshot = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('notices')
          .where('isActive', isEqualTo: true)
          .limit(3)
          .get();

      final notices = noticesSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });

        // Initialize PageController after notices are loaded
        if (_notices.isNotEmpty) {
          _pageController = PageController(
            initialPage: _notices.length > 1 ? 1000 * _notices.length : 0,
          );
          
          // Start auto-scrolling if there are multiple notices
          if (_notices.length > 1) {
            _startAutoScroll();
          }
        }
      }
    } catch (e) {
      print('Error loading notices: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || _notices.length <= 1 || _pageController == null) {
        timer.cancel();
        return;
      }

      if (_pageController!.hasClients) {
        try {
          final currentPage = _pageController!.page ?? 0;
          final nextPage = currentPage.round() + 1;
          _pageController!.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
          );
        } catch (e) {
          print('Auto-scroll error: $e');
          timer.cancel();
        }
      }
    });
  }

  void _onPageChanged(int page) {
    if (_notices.isNotEmpty && mounted) {
      setState(() {
        _currentPage = page % _notices.length;
      });
    }
  }

  bool _canManageNotices() {
    return widget.userRole == 'admin' || 
           widget.userRole == 'moderator' || 
           widget.userRole == 'manager';
  }

  void _showFullNoticeDialog(Map<String, dynamic> notice) {
    final createdAt = notice['createdAt'] as Timestamp?;
    final createdDate = createdAt?.toDate();
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final isTablet = screenSize.width > 600;
        
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenSize.width * 0.08,
            vertical: screenSize.height * 0.1,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.8,
              maxWidth: 600,
              minWidth: 300,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFF7B42C).withOpacity(0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isTablet ? 28 : 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF7B42C).withOpacity(0.2),
                          const Color(0xFFF7B42C).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 12 : 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7B42C),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF7B42C).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.campaign,
                            color: Colors.black87,
                            size: isTablet ? 26 : 24,
                          ),
                        ),
                        SizedBox(width: isTablet ? 20 : 16),
                        Expanded(
                          child: Text(
                            notice['heading'] ?? 'Notice',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 22 : 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: isTablet ? 12 : 8),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            padding: EdgeInsets.all(isTablet ? 10 : 8),
                          ),
                          icon: Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: isTablet ? 26 : 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Scrollable Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isTablet ? 28 : 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Content
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isTablet ? 28 : 24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              notice['content'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 17 : 16,
                                color: Colors.white70,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          
                          SizedBox(height: isTablet ? 28 : 24),
                          
                          // Footer
                          IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 14 : 12,
                                    vertical: isTablet ? 8 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRoleColor(notice['createdByRole']).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _getRoleColor(notice['createdByRole']).withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    notice['createdByRole']?.toString().toUpperCase() ?? 'ADMIN',
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 12 : 11,
                                      fontWeight: FontWeight.w700,
                                      color: _getRoleColor(notice['createdByRole']),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                SizedBox(width: isTablet ? 16 : 12),
                                Expanded(
                                  child: Text(
                                    notice['createdByUsername'] ?? 'Admin',
                                    style: GoogleFonts.poppins(
                                      fontSize: isTablet ? 16 : 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                if (createdDate != null)
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 14 : 12, 
                                      vertical: isTablet ? 8 : 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _formatFullDate(createdDate),
                                      style: GoogleFonts.poppins(
                                        fontSize: isTablet ? 13 : 12,
                                        color: Colors.white60,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
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

  @override
  Widget build(BuildContext context) {
    // Don't show anything if loading
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final screenSize = MediaQuery.of(context).size;
        final isTablet = screenSize.width > 600;
        final isLandscape = screenSize.width > screenSize.height;
        
        // Calculate responsive dimensions
        final horizontalPadding = availableWidth * 0.02;
        final noticeHeight = isTablet 
            ? (isLandscape ? 140.0 : 170.0)
            : (isLandscape ? 120.0 : 150.0);

        // Show empty state with create button for authorized users
        if (_notices.isEmpty) {
          if (_canManageNotices()) {
            return Container(
              width: availableWidth,
              margin: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 12,
              ),
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF7B42C).withOpacity(0.15),
                    const Color(0xFFF7B42C).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFF7B42C).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7B42C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.campaign_outlined,
                      color: const Color(0xFFF7B42C),
                      size: isTablet ? 24 : 20,
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Active Notices',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isTablet ? 6 : 4),
                        Text(
                          'Keep your community informed',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 13,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isTablet ? 16 : 12),
                  TextButton(
                    onPressed: widget.onManageNotices,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF7B42C),
                      foregroundColor: Colors.black87,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 12 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Create Notice',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 14 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }

        // Main notices carousel
        return Container(
          width: availableWidth,
          margin: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with manage button
              if (_canManageNotices())
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
                  child: Row(
                    children: [
                      Text(
                        'Community Notices',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onManageNotices,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 16 : 12,
                            vertical: isTablet ? 8 : 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Manage',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : 12,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFF7B42C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Notices carousel
              Container(
                width: double.infinity,
                height: noticeHeight,
                child: Stack(
                  children: [
                    if (_pageController != null)
                      PageView.builder(
                        controller: _pageController!,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          if (_notices.isEmpty) return const SizedBox();
                          final actualIndex = index % _notices.length;
                          final notice = _notices[actualIndex];
                          return _buildNoticeCard(notice, isTablet, availableWidth);
                        },
                      ),

                    // Page indicators (only show if multiple notices)
                    if (_notices.length > 1)
                      Positioned(
                        bottom: 16,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _notices.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: EdgeInsets.symmetric(
                                horizontal: isTablet ? 4 : 3,
                              ),
                              width: _currentPage == index ? 
                                  (isTablet ? 24 : 20) : 
                                  (isTablet ? 8 : 6),
                              height: isTablet ? 8 : 6,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: _currentPage == index
                                    ? const Color(0xFFF7B42C)
                                    : Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Tap hint
              SizedBox(height: isTablet ? 12 : 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app,
                    size: isTablet ? 16 : 14,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  SizedBox(width: isTablet ? 6 : 4),
                  Text(
                    'Tap notice to read full content',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 12 : 11,
                      color: Colors.white.withOpacity(0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> notice, bool isTablet, double availableWidth) {
    final createdAt = notice['createdAt'] as Timestamp?;
    final createdDate = createdAt?.toDate();
    final isLandscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

    return GestureDetector(
      onTap: () => _showFullNoticeDialog(notice),
      onLongPress: () => _showFullNoticeDialog(notice),
      child: Container(
        width: availableWidth,
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 8 : 6,
        ),
        padding: EdgeInsets.all(isTablet ? 28 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFF7B42C).withOpacity(0.22),
              const Color(0xFFF7B42C).withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF7B42C).withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF7B42C).withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7B42C),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF7B42C).withOpacity(0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.campaign,
                    color: Colors.black87,
                    size: isTablet ? 20 : 18,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: Text(
                    notice['heading'] ?? 'Notice',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (createdDate != null)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 10 : 8, 
                      vertical: isTablet ? 4 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _formatDate(createdDate),
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 11 : 10,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: isTablet ? 16 : 12),

            // Content with more lines visible
            Flexible(
              child: Text(
                notice['content'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 15 : 14,
                  color: Colors.white70,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: isTablet 
                    ? (isLandscape ? 3 : 4) 
                    : (isLandscape ? 2 : 3),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            SizedBox(height: isTablet ? 14 : 12),

            // Footer with read more hint
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12 : 10,
                    vertical: isTablet ? 6 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(notice['createdByRole']).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getRoleColor(notice['createdByRole']).withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    notice['createdByRole']?.toString().toUpperCase() ?? 'ADMIN',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 10 : 9,
                      fontWeight: FontWeight.w700,
                      color: _getRoleColor(notice['createdByRole']),
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                SizedBox(width: isTablet ? 12 : 8),
                Expanded(
                  child: Text(
                    notice['createdByUsername'] ?? 'Admin',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 13 : 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Read more indicator
                if ((notice['content'] ?? '').length > 120)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12 : 10,
                      vertical: isTablet ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7B42C).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Tap to read more',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 10 : 9,
                        color: const Color(0xFFF7B42C),
                        fontWeight: FontWeight.w600,
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

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return const Color(0xFFF7B42C);
      case 'moderator':
        return const Color(0xFF3B82F6);
      case 'manager':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF7B42C);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}