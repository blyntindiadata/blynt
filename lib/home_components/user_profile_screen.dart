// Updated UserProfileScreen with Instagram-like profile picture viewer

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;
  final String communityId;

  const UserProfileScreen({
    super.key,
    required this.username,
    required this.communityId,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? communityData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Get user data from users collection by username
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        userData = userQuery.docs.first.data();
        final userId = userQuery.docs.first.id;

        // Get community-specific data (year, branch, role, etc.)
        await _loadCommunitySpecificData(userId);
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadCommunitySpecificData(String userId) async {
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
        communityData = trioQuery.docs.first.data();
        return;
      }

      // Check members collection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (membersQuery.docs.isNotEmpty) {
        communityData = membersQuery.docs.first.data();
      }
    } catch (e) {
      print('Error loading community data: $e');
    }
  }

  void _showProfilePictureViewer() {
    final imageUrl = communityData?['profileImageUrl'];
    if (imageUrl == null) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) => 
            ProfilePictureViewer(imageUrl: imageUrl),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

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
            child: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  blendMode: BlendMode.srcIn,
                  child: Text(
                    'about folks',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 28 : 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isTablet ? 56 : 48),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            children: [
              // Header with updated styling
              _buildHeader(),

              // Profile Content
              Expanded(
                child: isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF7B42C),
                        ),
                      )
                    : userData == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.person_off,
                                  color: Colors.white60,
                                  size: 64,
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'User Not Found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    'The user profile could not be loaded or this profile might be deleted',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // Profile Card - Updated to match other cards' width
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
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
                                      color: Colors.white.withOpacity(0.1),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Profile Image - Now clickable
                                      GestureDetector(
                                        onTap: communityData?['profileImageUrl'] != null 
                                            ? _showProfilePictureViewer 
                                            : null,
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFF7B42C),
                                              width: 3,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFF7B42C).withOpacity(0.3),
                                                blurRadius: 20,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: communityData?['profileImageUrl'] != null
                                              ? ClipOval(
                                                  child: Image.network(
                                                    communityData!['profileImageUrl'],
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) =>
                                                        _buildAvatarFallback(),
                                                  ),
                                                )
                                              : _buildAvatarFallback(),
                                        ),
                                      ),

                                      const SizedBox(height: 20),

                                      // Name
                                      Text(
                                        '${userData!['firstName'] ?? ''} ${userData!['lastName'] ?? ''}'.trim(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),

                                      const SizedBox(height: 8),

                                      // Username
                                      Text(
                                        '@${widget.username}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFFF7B42C),
                                        ),
                                      ),

                                      const SizedBox(height: 16),

                                      // Role Badge
                                      if (communityData?['role'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                _getRoleColor(communityData!['role']),
                                                _getRoleColor(communityData!['role']).withOpacity(0.7),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getRoleIcon(communityData!['role']),
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                communityData!['role'].toString().toUpperCase(),
                                                style: GoogleFonts.poppins(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Academic Information (if available)
                                if (communityData?['year'] != null || communityData?['branch'] != null)
                                  _buildInfoCard(
                                    'Academic Information',
                                    [
                                      if (communityData?['year'] != null)
                                        _buildInfoItem(
                                          Icons.school,
                                          'Year',
                                          communityData!['year'],
                                        ),
                                      if (communityData?['branch'] != null)
                                        _buildInfoItem(
                                          Icons.category,
                                          'Branch',
                                          communityData!['branch'],
                                        ),
                                    ],
                                  ),

                                if (communityData?['year'] != null || communityData?['branch'] != null)
                                  const SizedBox(height: 16),

                                // Membership Information
                                _buildInfoCard(
                                  'Membership Information',
                                  [
                                    _buildInfoItem(
                                      Icons.calendar_today,
                                      'Joined',
                                      _formatJoinDate(communityData?['joinedAt'] ?? communityData?['assignedAt']),
                                    ),
                                    _buildInfoItem(
                                      Icons.verified,
                                      'Status',
                                      communityData?['status']?.toString().toUpperCase() ?? 'ACTIVE',
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    final name = '${userData!['firstName'] ?? ''} ${userData!['lastName'] ?? ''}'.trim();
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.poppins(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF7B42C).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFF7B42C),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      final DateTime dateTime = (timestamp as Timestamp).toDate();
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() == 1 ? '' : 's'} ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() == 1 ? '' : 's'} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else {
        return 'Recently';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}

// Profile Picture Viewer Widget
class ProfilePictureViewer extends StatefulWidget {
  final String imageUrl;

  const ProfilePictureViewer({
    super.key,
    required this.imageUrl,
  });

  @override
  State<ProfilePictureViewer> createState() => _ProfilePictureViewerState();
}

class _ProfilePictureViewerState extends State<ProfilePictureViewer>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          color: Colors.black87,
          child: SafeArea(
            child: Stack(
              children: [
                // Main Image
                Center(
                  child: Hero(
                    tag: 'profile_image_${widget.imageUrl}',
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 4.0,
                      onInteractionEnd: (details) {
                        // Reset zoom if scaled too far out
                        if (_transformationController.value.getMaxScaleOnAxis() < 1.0) {
                          _resetZoom();
                        }
                      },
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width,
                          maxHeight: MediaQuery.of(context).size.height * 0.8,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFFF7B42C),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.white60,
                                      size: 48,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Failed to load image',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Close button
                Positioned(
                  top: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

                // Reset zoom button (appears when zoomed)
                ValueListenableBuilder<Matrix4>(
                  valueListenable: _transformationController,
                  builder: (context, matrix, child) {
                    final scale = matrix.getMaxScaleOnAxis();
                    if (scale <= 1.0) return const SizedBox.shrink();
                    
                    return Positioned(
                      bottom: 32,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: _resetZoom,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_out_map,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Reset Zoom',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}