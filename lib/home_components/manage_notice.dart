import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/create_notice.dart';

class ManageNoticesScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final String userRole;
  final String username;

  const ManageNoticesScreen({
    super.key,
    required this.communityId,
    required this.userId,
    required this.userRole,
    required this.username,
  });

  @override
  State<ManageNoticesScreen> createState() => _ManageNoticesScreenState();
}

class _ManageNoticesScreenState extends State<ManageNoticesScreen> {
  bool _isLoading = false;

  Future<void> _deleteNotice(String noticeId, String heading) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Colors.red.withOpacity(0.3),
              width: 1,
            ),
          ),
          title: Text(
            'Delete Notice',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Are you sure you want to delete the notice "$heading"? This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('notices')
            .doc(noticeId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Notice deleted successfully',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete notice: $e',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToCreateNotice() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateNoticeScreen(
          communityId: widget.communityId,
          userId: widget.userId,
          userRole: widget.userRole,
          username: widget.username,
        ),
      ),
    );

    // Refresh the list if a notice was created
    if (result == true) {
      setState(() {});
    }
  }

  bool _canManageNotices() {
  return widget.userRole == 'admin' || 
         widget.userRole == 'moderator' || 
         widget.userRole == 'manager';
}

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
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
        title: ShaderMask(
           shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child:Text(
  _canManageNotices() ? 'manage notices' : 'community notices',
  style: GoogleFonts.poppins(
    fontSize: isTablet ? 24 : 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  ),
  ),
),
        centerTitle: true,
      actions: [
  if (_canManageNotices())
    IconButton(
      onPressed: _navigateToCreateNotice,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7B42C).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFF7B42C).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.add,
          color: Color(0xFFF7B42C),
          size: 20,
        ),
      ),
    ),
  const SizedBox(width: 8),
],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('notices')
            .where('isActive', isEqualTo: true)
            // .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notices',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please try again later',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFF7B42C),
              ),
            );
          }

          final notices = snapshot.data?.docs ?? [];

          if (notices.isEmpty) {
  return Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              size: 64,
              color: Color(0xFFF7B42C),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Notices',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _canManageNotices() 
                ? 'Create your first notice to keep your community informed about important updates.'
                : 'No announcements at the moment. Check back later for important updates from your community administrators.',
              style: GoogleFonts.poppins(
                fontSize: isTablet ? 16 : 14,
                color: Colors.white60,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          if (_canManageNotices())
            SizedBox(
              width: isTablet ? 300 : double.infinity,
              height: isTablet ? 56 : 48,
              child: ElevatedButton.icon(
                onPressed: _navigateToCreateNotice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF7B42C),
                  foregroundColor: Colors.black87,
                  elevation: 8,
                  shadowColor: const Color(0xFFF7B42C).withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add, size: 20),
                label: Text(
                  'Create First Notice',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                // Replace the existing header info container with this:
if (_canManageNotices()) ...[
  // Header Info
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
            Icons.campaign,
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
                'Active Notices: ${notices.length}/3',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                notices.length >= 3
                    ? 'Maximum limit reached. Delete existing notices to create new ones.'
                    : 'You can create ${3 - notices.length} more notice${3 - notices.length == 1 ? '' : 's'}.',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 13 : 12,
                  color: notices.length >= 3 
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

  const SizedBox(height: 24),
] else ...[
  // Info for regular members
  Container(
    width: double.infinity,
    padding: EdgeInsets.all(isTablet ? 20 : 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          const Color(0xFF6366F1).withOpacity(0.2),
          const Color(0xFF8B5CF6).withOpacity(0.1),
        ],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: const Color(0xFF6366F1).withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.info_outline,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Community Notices',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stay updated with important community announcements',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 13 : 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),

  const SizedBox(height: 24),
],

                const SizedBox(height: 24),

                // Notices List
                Text(
                  'Current Notices',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 20 : 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                ...notices.asMap().entries.map((entry) {
                  final index = entry.key;
                  final doc = entry.value;
                  final notice = doc.data() as Map<String, dynamic>;
                  final createdAt = notice['createdAt'] as Timestamp?;
                  final createdDate = createdAt?.toDate();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(isTablet ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with delete button
                      // Update the notices list item header section:
Row(
  children: [
    Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7B42C).withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${index + 1}',
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFF7B42C),
        ),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: Text(
        notice['heading'] ?? 'No Heading',
        style: GoogleFonts.poppins(
          fontSize: isTablet ? 18 : 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(width: 8),
    // Only show delete button for authorized users
    if (_canManageNotices())
      IconButton(
        onPressed: () => _deleteNotice(
          doc.id,
          notice['heading'] ?? 'Untitled Notice',
        ),
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: Colors.red,
            size: 18,
          ),
        ),
      ),
  ],
),
                        const SizedBox(height: 12),
                        
                        // Content
                        Text(
                          notice['content'] ?? 'No content',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 15 : 14,
                            color: Colors.white70,
                            height: 1.5,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Footer info
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getRoleColor(notice['createdByRole']).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getRoleColor(notice['createdByRole']).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                notice['createdByRole']?.toString().toUpperCase() ?? 'UNKNOWN',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getRoleColor(notice['createdByRole']),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notice['createdByUsername'] ?? 'Unknown User',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white60,
                              ),
                            ),
                            const Spacer(),
                            if (createdDate != null)
                              Text(
                                _formatDate(createdDate),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white54,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    
    );
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin':
        return const Color(0xFFF7B42C);
      case 'moderator':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}