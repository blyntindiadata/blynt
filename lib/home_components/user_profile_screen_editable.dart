import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditableUserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String? communityId;

  const EditableUserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
    this.communityId,
  });

  @override
  State<EditableUserProfileScreen> createState() => _EditableUserProfileScreenState();
}

class _EditableUserProfileScreenState extends State<EditableUserProfileScreen> {
  Map<String, dynamic>? userData;
  Map<String, dynamic>? communityData;
  bool isLoading = true;
  bool isUploadingImage = false;
  bool canChangeImage = false;
  DateTime? lastImageChange;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Get user data from users collection
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        userData = userDoc.data();

        // Get community-specific data if communityId is available
        if (widget.communityId != null) {
          await _loadCommunitySpecificData();
        }
        
        // Check if user can change profile image
        await _checkImageChangeEligibility();
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadCommunitySpecificData() async {
    try {
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId!)
          .collection('trio')
          .where('userId', isEqualTo: widget.userId)
          .limit(1)
          .get();

      if (trioQuery.docs.isNotEmpty) {
        communityData = trioQuery.docs.first.data();
        return;
      }

      // Check members collection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId!)
          .collection('members')
          .where('userId', isEqualTo: widget.userId)
          .limit(1)
          .get();

      if (membersQuery.docs.isNotEmpty) {
        communityData = membersQuery.docs.first.data();
      }
    } catch (e) {
      print('Error loading community data: $e');
    }
  }

  Future<void> _checkImageChangeEligibility() async {
    if (communityData?['lastImageChange'] != null) {
      lastImageChange = (communityData!['lastImageChange'] as Timestamp).toDate();
      final now = DateTime.now();
      final daysSinceLastChange = now.difference(lastImageChange!).inDays;
      
      setState(() {
        canChangeImage = daysSinceLastChange >= 30; // Can change after 30 days
      });
    } else {
      setState(() {
        canChangeImage = true; // First time, can change
      });
    }
  }

  Future<void> _changeProfileImage() async {
    if (!canChangeImage || isUploadingImage) return;

    try {
      // Show image source selection
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1D),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Select Image Source',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.camera_alt, color: Color(0xFFF7B42C)),
                  title: Text('Camera', style: GoogleFonts.poppins(color: Colors.white)),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.photo_library, color: Color(0xFFF7B42C)),
                  title: Text('Gallery', style: GoogleFonts.poppins(color: Colors.white)),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
          );
        },
      );

      if (source == null) return;

      // Pick image
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        isUploadingImage = true;
      });

      // Upload image to Firebase Storage
      final String fileName = 'profile_images/${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
      
      final UploadTask uploadTask = storageRef.putFile(File(image.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update profile image in Firestore
      await _updateProfileImage(downloadUrl);

      _showSuccessMessage('Profile image updated successfully!');
      
    } catch (e) {
      _showErrorMessage('Failed to update profile image: $e');
      print('Error updating profile image: $e');
    } finally {
      setState(() {
        isUploadingImage = false;
      });
    }
  }

  Future<void> _updateProfileImage(String imageUrl) async {
    final batch = FirebaseFirestore.instance.batch();
    final now = Timestamp.now();

    // Update in community collection if user is part of a community
    if (widget.communityId != null && communityData != null) {
      // Determine which collection (trio or members)
      final isInTrio = communityData!.containsKey('role') && 
                      ['admin', 'moderator', 'manager'].contains(communityData!['role']);
      
      final collection = isInTrio ? 'trio' : 'members';
      
      // Find and update the user's document
      final query = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId!)
          .collection(collection)
          .where('userId', isEqualTo: widget.userId)
          .limit(1)
          .get();
      
      if (query.docs.isNotEmpty) {
        batch.update(query.docs.first.reference, {
          'profileImageUrl': imageUrl,
          'lastImageChange': now,
          'updatedAt': now,
        });
      }
    }

    // Commit the batch
    await batch.commit();

    // Update local state
    setState(() {
      if (communityData != null) {
        communityData!['profileImageUrl'] = imageUrl;
        communityData!['lastImageChange'] = now;
      }
      canChangeImage = false;
      lastImageChange = now.toDate();
    });
  }

  void _showImageChangeDialog() {
    final daysLeft = lastImageChange != null 
        ? 30 - DateTime.now().difference(lastImageChange!).inDays
        : 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info, color: Color(0xFFF7B42C), size: 22),
              SizedBox(width: 8),
              Text(
                'Image Change Limit',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Text(
            'You can only change your profile image once every 30 days.\n\nNext change available in $daysLeft day${daysLeft == 1 ? '' : 's'}.',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7B42C),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Got it',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              message,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
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
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Color(0xFFF7B42C),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'My Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

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
                                  'Profile Not Found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Your profile could not be loaded.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                // Profile Card
                               Container(
  width: double.infinity, // Add this line to match other cards
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withOpacity(0.12),
        Colors.white.withOpacity(0.06),
      ],
    ),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: const Color(0xFFF7B42C).withOpacity(0.3),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFFF7B42C).withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Column(
    children: [
      // Profile Image with Edit Button
      Stack(
        children: [
          Container(
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
            child: isUploadingImage
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFF7B42C),
                    ),
                  )
                : communityData?['profileImageUrl'] != null
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
          
          // Edit Button
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: canChangeImage ? _changeProfileImage : _showImageChangeDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: canChangeImage 
                      ? const Color(0xFFF7B42C)
                      : Colors.grey.shade600,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.black,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  canChangeImage ? Icons.camera_alt : Icons.schedule,
                  color: Colors.black87,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
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

                                // Information Cards
                                _buildInfoCard(
                                  'Contact Information',
                                  [
                                    _buildInfoItem(
                                      Icons.email,
                                      'Email',
                                      userData!['email'] ?? 'Not provided',
                                    ),
                                    if (communityData?['userPhone'] != null)
                                      _buildInfoItem(
                                        Icons.phone,
                                        'Phone',
                                        communityData!['userPhone'],
                                      ),
                                  ],
                                ),

                                const SizedBox(height: 16),

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
                                    if (lastImageChange != null)
                                      _buildInfoItem(
                                        Icons.image,
                                        'Last Image Change',
                                        _formatJoinDate(Timestamp.fromDate(lastImageChange!)),
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