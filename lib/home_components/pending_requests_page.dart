import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingRequestsPage extends StatefulWidget {
  final String communityId;
  final VoidCallback onRequestProcessed;

  const PendingRequestsPage({
    super.key,
    required this.communityId,
    required this.onRequestProcessed,
  });

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  bool isProcessing = false;

  Future<void> _processRequest(String requestId, String userId, bool approve, 
      {String? year, String? branch}) async {
    setState(() {
      isProcessing = true;
    });

    try {
      // Get the most current user data using userId
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        throw Exception('User not found');
      }
      
      final userData = userDoc.data() as Map<String, dynamic>;
      final currentUsername = userData['username'] ?? '';
      final currentFirstName = userData['firstName'] ?? '';
      final currentLastName = userData['lastName'] ?? '';
      final currentEmail = userData['email'] ?? '';
      
      final batch = FirebaseFirestore.instance.batch();

      // Get the join request data to extract additional info
      final requestDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('join_requests')
          .doc(requestId)
          .get();

      final requestData = requestDoc.data() ?? {};

      // Update request status
      final requestRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('join_requests')
          .doc(requestId);

      if (approve && year != null && branch != null) {
        batch.update(requestRef, {
          'status': 'approved',
          'processed': true,
          'reviewedAt': FieldValue.serverTimestamp(),
          'year': year,
          'branch': branch,
          // Update with current user data in case username changed
          'username': currentUsername,
          'firstName': currentFirstName,
          'lastName': currentLastName,
          'userEmail': currentEmail,
        });

        // Add user to community_members (global collection) with all data
        // final memberRef = FirebaseFirestore.instance.collection('community_members').doc();
        // batch.set(memberRef, {
        //   'communityId': widget.communityId,
        //   'userId': userId, // Primary identifier
        //   'username': currentUsername, // Current username
        //   'firstName': currentFirstName, // Store separately
        //   'lastName': currentLastName, // Store separately
        //   'role': 'member',
        //   'year': year,
        //   'branch': branch,
        //   'joinedAt': FieldValue.serverTimestamp(),
        //   'status': 'active',
        //   'userEmail': currentEmail,
        //   'userPhone': requestData['userPhone'] ?? '',
        //   'profileImageUrl': requestData['profileImageUrl'] ?? '',
        //   'profileImagePositioning': requestData['profileImagePositioning'] ?? null,
        // });

        // Add user to community's members subcollection with complete data
        final communityMemberRef = FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .doc(currentUsername); // Using current username as document ID

        batch.set(communityMemberRef, {
          'userId': userId, // Primary identifier
          'username': currentUsername, // Current username
          'firstName': currentFirstName, // Store separately
          'lastName': currentLastName, // Store separately
          'role': 'member',
          'year': year,
          'branch': branch,
          'status': 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          'userEmail': currentEmail,
          'userPhone': requestData['userPhone'] ?? '',
          'profileImageUrl': requestData['profileImageUrl'] ?? '',
          'profileImagePositioning': requestData['profileImagePositioning'] ?? null,
        });

        // Update community member count
        final communityRef = FirebaseFirestore.instance.collection('communities').doc(widget.communityId);
        batch.update(communityRef, {
          'memberCount': FieldValue.increment(1),
        });

        // Update user's community mapping with current data
        final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
        batch.update(userRef, {
          'communityId': widget.communityId,
          'year': year,
          'branch': branch,
        });
      } else {
        batch.update(requestRef, {
          'status': 'rejected',
          'processed': true,
          'reviewedAt': FieldValue.serverTimestamp(),
          // Update with current user data in case username changed
          'username': currentUsername,
          'firstName': currentFirstName,
          'lastName': currentLastName,
          'userEmail': currentEmail,
        });
      }

      await batch.commit();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Request approved successfully' : 'Request rejected',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: approve ? Colors.green.shade700 : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      widget.onRequestProcessed();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error processing request: $e',
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

Future<Map<String, List<String>>> _fetchDropdownData() async {
  try {
    final communityDoc = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .get();
    
    if (communityDoc.exists) {
      final data = communityDoc.data() as Map<String, dynamic>;
      final years = List<String>.from(data['years'] ?? []);
      final branches = List<String>.from(data['branches'] ?? []);
      
      return {
        'years': years,
        'branches': branches,
      };
    }
  } catch (e) {
    print('Error fetching dropdown data: $e');
  }
  
  return {
    'years': <String>[],
    'branches': <String>[],
  };
}

  void _showApprovalDialog(String requestId, String userId, String userName) {
    String selectedYear = '';
    String selectedBranch = '';
    List<String> availableYears = [];
    List<String> availableBranches = [];
    bool isLoadingData = true;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Fetch data when dialog opens
            if (isLoadingData) {
              _fetchDropdownData().then((data) {
                setDialogState(() {
                  availableYears = data['years'] ?? [];
                  availableBranches = data['branches'] ?? [];
                  selectedYear = availableYears.isNotEmpty ? availableYears[0] : '';
                  selectedBranch = availableBranches.isNotEmpty ? availableBranches[0] : '';
                  isLoadingData = false;
                });
              });
            }
            
            return AlertDialog(
              backgroundColor: const Color(0xFF2A1810),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Approve Request',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approving request for $userName',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Year Selection
                    Text(
                      'Academic Year',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: isLoadingData 
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFFF7B42C),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedYear.isEmpty ? null : selectedYear,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2A1810),
                              style: GoogleFonts.poppins(color: Colors.white),
                              hint: Text(
                                'Select Year',
                                style: GoogleFonts.poppins(color: Colors.white60),
                              ),
                              items: availableYears.map((String year) {
                                return DropdownMenuItem<String>(
                                  value: year,
                                  child: Text(
                                    year,
                                    style: GoogleFonts.poppins(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setDialogState(() {
                                  selectedYear = newValue ?? '';
                                });
                              },
                            ),
                          ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Branch Selection
                    Text(
                      'Branch',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      child: isLoadingData 
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Color(0xFFF7B42C),
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedBranch.isEmpty ? null : selectedBranch,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF2A1810),
                              style: GoogleFonts.poppins(color: Colors.white),
                              hint: Text(
                                'Select Branch',
                                style: GoogleFonts.poppins(color: Colors.white60),
                              ),
                              items: availableBranches.map((String branch) {
                                return DropdownMenuItem<String>(
                                  value: branch,
                                  child: Text(
                                    branch,
                                    style: GoogleFonts.poppins(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setDialogState(() {
                                  selectedBranch = newValue ?? '';
                                });
                              },
                            ),
                          ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.white60),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoadingData ? null : () {
                    if (selectedYear.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select year')),
                      );
                      return;
                    }
                    if (selectedBranch.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select branch')),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    _processRequest(
                      requestId, 
                      userId, 
                      true, 
                      year: selectedYear, 
                      branch: selectedBranch
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF7B42C),
                    foregroundColor: Colors.black87,
                  ),
                  child: Text(
                    'Approve',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showImageDialog(String imageUrl, String title, {Map<String, dynamic>? positioning}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1810),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    child: _buildPositionedImage(imageUrl, positioning),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPositionedImage(String imageUrl, Map<String, dynamic>? positioning) {
    // If no positioning data, show normal image
    if (positioning == null) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          color: Colors.grey[800],
          child: const Center(
            child: Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
          ),
        ),
      );
    }

    // Extract positioning data
    final alignmentData = positioning['alignment'] as Map<String, dynamic>?;
    final scale = positioning['scale'] as double? ?? 1.0;
    
    Alignment alignment = Alignment.center;
    if (alignmentData != null) {
      alignment = Alignment(
        alignmentData['x'] as double? ?? 0.0,
        alignmentData['y'] as double? ?? 0.0,
      );
    }

    return OverflowBox(
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: alignment,
            child: Image.network(
              imageUrl,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey[800],
                child: const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPhoneNumber(String phone) {
    if (phone.length == 10) {
      return '${phone.substring(0, 5)} ${phone.substring(5)}';
    }
    return phone;
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
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
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
                    Container(
                      margin: const EdgeInsets.only(left: 25),
                      child: ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          'pending requests',
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.055,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Requests List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('communities')
                      .doc(widget.communityId)
                      .collection('join_requests')
                      .where('processed', isEqualTo: false)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFF7B42C),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading requests',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7B42C).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFFF7B42C),
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No Pending Requests',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All caught up! No new join requests to review.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white60,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
                      physics: const BouncingScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        return RequestCard(
                          requestId: doc.id,
                          userId: data['userId'] ?? '',
                          username: data['username'] ?? '',
                          firstName: data['firstName'] ?? '',
                          lastName: data['lastName'] ?? '',
                          userName: data['userName'] ?? 'Unknown User',
                          userEmail: data['userEmail'] ?? '',
                          phoneNumber: data['userPhone'] ?? '',
                          profileImageUrl: data['profileImageUrl'] ?? '',
                          profileImagePositioning: data['profileImagePositioning'],
                          idCardImageUrl: data['idCardImageUrl'] ?? '',
                          requestedAt: data['requestedAt'] as Timestamp?,
                          onApprove: () => _showApprovalDialog(
                            doc.id, 
                            data['userId'] ?? '',
                            data['userName'] ?? 'Unknown User'
                          ),
                          onReject: () => _processRequest(doc.id, data['userId'] ?? '', false),
                          onViewProfileImage: () => _showImageDialog(
                            data['profileImageUrl'] ?? '', 
                            'Profile Photo',
                            positioning: data['profileImagePositioning'],
                          ),
                          onViewIdImage: () => _showImageDialog(
                            data['idCardImageUrl'] ?? '', 
                            'ID Card'
                          ),
                          isProcessing: isProcessing,
                          formatPhoneNumber: _formatPhoneNumber,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RequestCard extends StatelessWidget {
  final String requestId;
  final String userId;
  final String username;
  final String firstName;
  final String lastName;
  final String userName;
  final String userEmail;
  final String phoneNumber;
  final String profileImageUrl;
  final Map<String, dynamic>? profileImagePositioning;
  final String idCardImageUrl;
  final Timestamp? requestedAt;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onViewProfileImage;
  final VoidCallback onViewIdImage;
  final bool isProcessing;
  final String Function(String) formatPhoneNumber;

  const RequestCard({
    super.key,
    required this.requestId,
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.userName,
    required this.userEmail,
    required this.phoneNumber,
    required this.profileImageUrl,
    this.profileImagePositioning,
    required this.idCardImageUrl,
    this.requestedAt,
    required this.onApprove,
    required this.onReject,
    required this.onViewProfileImage,
    required this.onViewIdImage,
    required this.isProcessing,
    required this.formatPhoneNumber,
  });

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildProfileImage(BuildContext context) {
    if (profileImageUrl.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
          ),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            style: GoogleFonts.poppins(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
      );
    }

    // If no positioning data, show normal image
    if (profileImagePositioning == null) {
      return ClipOval(
        child: Image.network(
          profileImageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: GoogleFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Apply positioning for profile image
    final alignmentData = profileImagePositioning!['alignment'] as Map<String, dynamic>?;
    final scale = profileImagePositioning!['scale'] as double? ?? 1.0;
    
    Alignment alignment = Alignment.center;
    if (alignmentData != null) {
      alignment = Alignment(
        alignmentData['x'] as double? ?? 0.0,
        alignmentData['y'] as double? ?? 0.0,
      );
    }

    return ClipOval(
      child: OverflowBox(
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 60,
            height: 60,
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: alignment,
              child: Image.network(
                profileImageUrl,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: GoogleFonts.poppins(
                        color: Colors.black87,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Row with Profile Image
            Row(
              children: [
                GestureDetector(
                  onTap: profileImageUrl.isNotEmpty ? onViewProfileImage : null,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF7B42C),
                        width: 2,
                      ),
                    ),
                    child: _buildProfileImage(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName.isNotEmpty ? userName : 'Unknown User',
                        style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.045,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@$username',
                        style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          color: const Color(0xFFF7B42C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimestamp(requestedAt),
                        style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.03,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'PENDING',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // User Details
            _buildInfoRow(context, Icons.email, 'Email', userEmail.isNotEmpty ? userEmail : 'No email provided'),
            const SizedBox(height: 8),
            _buildInfoRow(context, Icons.phone, 'Phone', phoneNumber.isNotEmpty ? formatPhoneNumber(phoneNumber) : 'No phone provided'),

            const SizedBox(height: 16),

            // Document Views
            Row(
              children: [
                Expanded(
                  child: _buildDocumentButton(
                    context,
                    'View Profile Photo',
                    Icons.person,
                    profileImageUrl.isNotEmpty ? onViewProfileImage : null,
                    profileImageUrl.isNotEmpty,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDocumentButton(
                    context,
                    'View ID Card',
                    Icons.credit_card,
                    idCardImageUrl.isNotEmpty ? onViewIdImage : null,
                    idCardImageUrl.isNotEmpty,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : onReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.red.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      elevation: 0,
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                    ),
                    child: isProcessing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.close,
                                color: Colors.red,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Reject',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing ? null : onApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ).copyWith(
                      backgroundColor: WidgetStateProperty.all(Colors.transparent),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isProcessing
                            ? LinearGradient(
                                colors: [
                                  Colors.grey.shade600,
                                  Colors.grey.shade700,
                                ],
                              )
                            : const LinearGradient(
                                colors: [Colors.green, Colors.lightGreen],
                              ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: isProcessing
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: isProcessing
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Approve',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
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
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentButton(BuildContext context, String title, IconData icon, VoidCallback? onTap, bool isAvailable) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAvailable 
              ? const Color(0xFFF7B42C).withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAvailable 
                ? const Color(0xFFF7B42C).withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isAvailable ? const Color(0xFFF7B42C) : Colors.white30,
              size: 16,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width * 0.03,
                  fontWeight: FontWeight.w600,
                  color: isAvailable ? const Color(0xFFF7B42C) : Colors.white30,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}