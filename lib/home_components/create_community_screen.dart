import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class CreateCommunityScreen extends StatefulWidget {
  final String userId;
  final String firstName;
  final String lastName;
  final String username;  
  final String email;

  const CreateCommunityScreen({
    super.key,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
  });

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  
  List<String> years = [];
  List<String> branches = [];
  bool isCreating = false;
  
  int _descriptionLength = 0;
  final int _maxDescriptionLength = 500;

  // Profile image for creator
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  Alignment _profileImageAlignment = Alignment.center;
  double _profileImageScale = 1.0;

  // Stream subscription for listening to approval status
  StreamSubscription<QuerySnapshot>? _approvalListener;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() {
      setState(() {
        _descriptionLength = _descriptionController.text.length;
      });
    });
    
    // Start listening for approval status changes
    _startListeningForApproval();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _yearController.dispose();
    _branchController.dispose();
    _approvalListener?.cancel();
    super.dispose();
  }

  void _startListeningForApproval() {
    _approvalListener = FirebaseFirestore.instance
        .collection('community_requests')
        .where('createdBy', isEqualTo: widget.userId)
        .where('approved', isEqualTo: true)
        .where('processed', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        // Found an approved but unprocessed community
        final doc = snapshot.docs.first;
        final data = doc.data();
        _processApprovedRequest(data, doc.id);
      }
    });
  }

  // New method to automatically process the approved request
  Future<void> _processApprovedRequest(Map<String, dynamic> data, String requestId) async {
    try {
      // Immediately process this specific community request
      final communityId = await _createCommunityFromRequest(data, requestId);
      
      if (communityId != null) {
        // Show success dialog
        _showApprovalDialog(data, communityId);
      }
    } catch (e) {
      print('Error auto-processing approved community: $e');
      _showSnackBar('Error setting up your community: $e', Colors.red);
    }
  }

  // Extract community creation logic into separate method
  Future<String?> _createCommunityFromRequest(Map<String, dynamic> data, String requestId) async {
    try {
      // Get current user data to handle any username changes
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: data['createdByUsername'])
          .limit(1)
          .get();
      
      if (userQuery.docs.isEmpty) return null;
      
      final currentUserData = userQuery.docs.first.data();
      final currentUsername = currentUserData['username'] ?? data['createdByUsername'];
      final currentFirstName = currentUserData['firstName'] ?? data['createdByFirstName'] ?? '';
      final currentLastName = currentUserData['lastName'] ?? data['createdByLastName'] ?? '';
      final currentEmail = currentUserData['email'] ?? data['createdByEmail'] ?? '';
      
      // Create the community with ALL fields
      final communityRef = await FirebaseFirestore.instance
          .collection('communities')
          .add({
        // Basic community info
        'name': data['name'],
        'description': data['description'],
        'years': data['years'],
        'branches': data['branches'],
        'memberCount': 1, // Start with 1 (the admin)
        'createdAt': FieldValue.serverTimestamp(),
        
        // Creator identification fields
        'createdBy': data['createdBy'],
        'createdByName': data['createdByName'] ?? '$currentFirstName $currentLastName'.trim(),
        'createdByUsername': currentUsername,
        'createdByFirstName': data['createdByFirstName'] ?? currentFirstName,
        'createdByLastName': data['createdByLastName'] ?? currentLastName,
        'createdByEmail': data['createdByEmail'] ?? currentEmail,
        
        // Profile image fields
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'profileImagePositioning': data['profileImagePositioning'] ?? null,
      });
      
      // Create admin user in trio collection with ALL fields from community_requests
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityRef.id)
          .collection('trio')
          .doc(currentUsername)
          .set({
        // User identification
        'userId': data['createdBy'],
        'username': currentUsername,
        'firstName': data['createdByFirstName'] ?? currentFirstName,
        'lastName': data['createdByLastName'] ?? currentLastName,
        'userEmail': data['createdByEmail'] ?? currentEmail,
        
        // Role and status
        'role': 'admin',
        'status': 'active',
        
        // Timestamps
        'joinedAt': FieldValue.serverTimestamp(),
        'assignedAt': FieldValue.serverTimestamp(),
        
        // Profile image fields from community_requests
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'profileImagePositioning': data['profileImagePositioning'] ?? null,
        
        // Creator-specific fields (copy ALL from community_requests)
        'createdByName': data['createdByName'] ?? '$currentFirstName $currentLastName'.trim(),
        'createdByFirstName': data['createdByFirstName'] ?? currentFirstName,
        'createdByLastName': data['createdByLastName'] ?? currentLastName,
        'createdByEmail': data['createdByEmail'] ?? currentEmail,
        
        // Copy any additional fields from community_requests that might exist
        'name': data['name'], // Community name
        'description': data['description'], // Community description
        'years': data['years'], // Available years
        'branches': data['branches'], // Available branches
        'createdAt': data['createdAt'], // Original request creation time
        
        // Academic info (null for admin, can be set later)
        'year': null,
        'branch': null,
      });
      
      // Create entry in global community_members with ALL fields
      await FirebaseFirestore.instance
          .collection('community_members')
          .add({
        // User identification
        'userId': data['createdBy'],
        'username': currentUsername,
        'firstName': data['createdByFirstName'] ?? currentFirstName,
        'lastName': data['createdByLastName'] ?? currentLastName,
        'userEmail': data['createdByEmail'] ?? currentEmail,
        
        // Community info
        'communityId': communityRef.id,
        'role': 'admin',
        'status': 'active',
        
        // Timestamps
        'joinedAt': FieldValue.serverTimestamp(),
        
        // Profile image fields
        'profileImageUrl': data['profileImageUrl'] ?? '',
        'profileImagePositioning': data['profileImagePositioning'] ?? null,
        
        // Creator-specific fields
        'createdByName': data['createdByName'] ?? '$currentFirstName $currentLastName'.trim(),
        'createdByFirstName': data['createdByFirstName'] ?? currentFirstName,
        'createdByLastName': data['createdByLastName'] ?? currentLastName,
        'createdByEmail': data['createdByEmail'] ?? currentEmail,
        
        // Copy additional community request fields
        'name': data['name'],
        'description': data['description'],
        'years': data['years'],
        'branches': data['branches'],
        'originalCreatedAt': data['createdAt'],
        
        // Academic/contact info
        'userPhone': '', // Admins don't need to provide phone initially
        'year': null,
        'branch': null,
      });
      
      // Update user's community mapping
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userQuery.docs.first.id)
          .update({
        'communityId': communityRef.id,
      });
      
      // Mark request as processed with ALL original data preserved
      await FirebaseFirestore.instance
          .collection('community_requests')
          .doc(requestId)
          .update({
        'processed': true,
        'communityId': communityRef.id,
        'processedAt': FieldValue.serverTimestamp(),
        
        // Update with current user data while preserving original
        'currentUsername': currentUsername,
        'currentFirstName': currentFirstName,
        'currentLastName': currentLastName,
        'currentEmail': currentEmail,
        'currentName': '$currentFirstName $currentLastName'.trim(),
      });
      
      return communityRef.id;
      
    } catch (e) {
      print('Error creating community from request: $e');
      rethrow;
    }
  }

  void _showApprovalDialog(Map<String, dynamic> communityData, String communityId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2A1810).withOpacity(0.95),
                const Color(0xFF3D2914).withOpacity(0.95),
                const Color(0xFF4A3218).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFF7B42C).withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF7B42C).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF7B42C).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.celebration,
                  color: Colors.black87,
                  size: 48,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                '🎉 Congratulations! 🎉',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 12),
              
              // Community name
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  communityData['name'] ?? 'Your Community',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Message
              Text(
                'Your community has been approved and is ready! You can now access your community and start building your network.',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // GO Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _navigateToCommunity(communityId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF7B42C).withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.rocket_launch,
                          color: Colors.black87,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'GO TO MY COMMUNITY',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToCommunity(String communityId) {
    Navigator.of(context).pop(); // Close the approval dialog
    
    // Show success message
    _showSnackBar('Welcome to your community! 🎉', Colors.green);
    
    // Navigate to community screen (replace with your actual navigation)
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => CommunityScreen(communityId: communityId),
    //   ),
    // );
    
    // For now, just pop back to previous screen
    Navigator.pop(context);
  }

  Future<String?> _uploadImage(File image, String folder) async {
    try {
      final String fileName = '$folder/${widget.username}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference ref = FirebaseStorage.instance.ref().child(fileName);
      
      final UploadTask uploadTask = ref.putFile(image);
      final TaskSnapshot snapshot = await uploadTask;
      
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  void _addYear() {
    final year = _yearController.text.trim();
    if (year.isNotEmpty && !years.contains(year)) {
      setState(() {
        years.add(year);
        _yearController.clear();
      });
    }
  }

  void _addBranch() {
    final branch = _branchController.text.trim();
    if (branch.isNotEmpty && !branches.contains(branch)) {
      setState(() {
        branches.add(branch);
        _branchController.clear();
      });
    }
  }

  void _removeYear(String year) {
    setState(() {
      years.remove(year);
    });
  }

  void _removeBranch(String branch) {
    setState(() {
      branches.remove(branch);
    });
  }

  // Keep the static method for backwards compatibility or manual processing
  static Future<void> processApprovedCommunities() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('community_requests')
          .where('approved', isEqualTo: true)
          .where('processed', isEqualTo: false)
          .get();
      
      for (final doc in query.docs) {
        final data = doc.data();
        
        // Get current user data to handle username changes
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: data['createdByUsername'])
            .limit(1)
            .get();
        
        if (userQuery.docs.isEmpty) continue;
        
        final currentUserData = userQuery.docs.first.data();
        final currentUsername = currentUserData['username'] ?? data['createdByUsername'];
        final currentFirstName = currentUserData['firstName'] ?? data['createdByFirstName'] ?? '';
        final currentLastName = currentUserData['lastName'] ?? data['createdByLastName'] ?? '';
        final currentEmail = currentUserData['email'] ?? data['createdByEmail'] ?? '';
        
        // Create the community with ALL fields
        final communityRef = await FirebaseFirestore.instance
            .collection('communities')
            .add({
          // Basic community info
          'name': data['name'],
          'description': data['description'],
          'years': data['years'],
          'branches': data['branches'],
          'memberCount': 1,
          'createdAt': FieldValue.serverTimestamp(),
          
          // Creator identification fields
          'createdBy': data['createdBy'],
          'createdByName': data['createdByName'] ?? '$currentFirstName $currentLastName'.trim(),
          'createdByUsername': currentUsername,
          'createdByFirstName': data['createdByFirstName'] ?? currentFirstName,
          'createdByLastName': data['createdByLastName'] ?? currentLastName,
          'createdByEmail': data['createdByEmail'] ?? currentEmail,
          
          // Profile image fields
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'profileImagePositioning': data['profileImagePositioning'] ?? null,
        });
        
        // Create admin user in trio collection with ALL fields
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityRef.id)
            .collection('trio')
            .doc(currentUsername)
            .set({
          // All the fields as in the original method...
          'userId': data['createdBy'],
          'username': currentUsername,
          'firstName': data['createdByFirstName'] ?? currentFirstName,
          'lastName': data['createdByLastName'] ?? currentLastName,
          'userEmail': data['createdByEmail'] ?? currentEmail,
          'role': 'admin',
          'status': 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          'assignedAt': FieldValue.serverTimestamp(),
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'profileImagePositioning': data['profileImagePositioning'] ?? null,
          'createdByName': data['createdByName'] ?? '$currentFirstName $currentLastName'.trim(),
          'createdByFirstName': data['createdByFirstName'] ?? currentFirstName,
          'createdByLastName': data['createdByLastName'] ?? currentLastName,
          'createdByEmail': data['createdByEmail'] ?? currentEmail,
          'year': null,
          'branch': null,
        });
        
        // Continue with community_members creation and other operations...
        await FirebaseFirestore.instance
            .collection('community_members')
            .add({
          'userId': data['createdBy'],
          'username': currentUsername,
          'firstName': data['createdByFirstName'] ?? currentFirstName,
          'lastName': data['createdByLastName'] ?? currentLastName,
          'userEmail': data['createdByEmail'] ?? currentEmail,
          'communityId': communityRef.id,
          'role': 'admin',
          'status': 'active',
          'joinedAt': FieldValue.serverTimestamp(),
          'profileImageUrl': data['profileImageUrl'] ?? '',
          'profileImagePositioning': data['profileImagePositioning'] ?? null,
          'createdByName': data['createdByName'] ?? '$currentFirstName $currentLastName'.trim(),
          'createdByFirstName': data['createdByFirstName'] ?? currentFirstName,
          'createdByLastName': data['createdByLastName'] ?? currentLastName,
          'createdByEmail': data['createdByEmail'] ?? currentEmail,
          'userPhone': '',
          'year': null,
          'branch': null,
        });
        
        // Update user's community mapping
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userQuery.docs.first.id)
            .update({
          'communityId': communityRef.id,
        });
        
        // Mark request as processed
        await FirebaseFirestore.instance
            .collection('community_requests')
            .doc(doc.id)
            .update({
          'processed': true,
          'communityId': communityRef.id,
          'processedAt': FieldValue.serverTimestamp(),
          'currentUsername': currentUsername,
          'currentFirstName': currentFirstName,
          'currentLastName': currentLastName,
          'currentEmail': currentEmail,
          'currentName': '$currentFirstName $currentLastName'.trim(),
        });
      }
    } catch (e) {
      print('Error processing communities: $e');
    }
  }

  Future<void> _createCommunityRequest() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Please enter community name', Colors.red);
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showSnackBar('Please enter community description', Colors.red);
      return;
    }

    if (years.isEmpty) {
      _showSnackBar('Please add at least one year', Colors.red);
      return;
    }

    if (branches.isEmpty) {
      _showSnackBar('Please add at least one branch', Colors.red);
      return;
    }

    setState(() {
      isCreating = true;
    });

    try {
      // Upload profile image if provided
      String? profileImageUrl;
      Map<String, dynamic>? profileImagePositioning;
      
      if (_profileImage != null) {
        profileImageUrl = await _uploadImage(_profileImage!, 'admin_profiles');
        if (profileImageUrl == null) {
          _showSnackBar('Failed to upload profile image', Colors.red);
          setState(() {
            isCreating = false;
          });
          return;
        }
        
        // Store positioning data
        profileImagePositioning = {
          'alignment': {
            'x': _profileImageAlignment.x,
            'y': _profileImageAlignment.y,
          },
          'scale': _profileImageScale,
        };
      }

      await FirebaseFirestore.instance.collection('community_requests').add({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'years': years,
        'branches': branches,
        'createdBy': widget.userId,
        'createdByName': '${widget.firstName} ${widget.lastName}',
        'createdByUsername': widget.username,
        'createdByFirstName': widget.firstName,
        'createdByLastName': widget.lastName,
        'createdByEmail': widget.email,
        'profileImageUrl': profileImageUrl,
        'profileImagePositioning': profileImagePositioning,
        'createdAt': FieldValue.serverTimestamp(),
        'approved': false,
        'processed': false,
      });

      Navigator.pop(context);
      _showSnackBar('Community creation request submitted successfully!', Colors.green);
    } catch (e) {
      _showSnackBar('Error creating request: $e', Colors.red);
    } finally {
      setState(() {
        isCreating = false;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _profileImageAlignment = Alignment.center;
          _profileImageScale = 1.0;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to pick profile image: $e', Colors.red);
    }
  }

  void _showImageEditor() {
    if (_profileImage == null) return;
    
    Alignment tempAlignment = _profileImageAlignment;
    double tempScale = _profileImageScale;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFF7B42C).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Adjust Profile Photo',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Image preview
                Container(
                  height: MediaQuery.of(context).size.width * 0.5,
                  width: MediaQuery.of(context).size.width * 0.5,
                  constraints: const BoxConstraints(
                    maxHeight: 200,
                    maxWidth: 200,
                    minHeight: 150,
                    minWidth: 150,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF7B42C),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: OverflowBox(
                      child: Transform.scale(
                        scale: tempScale,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            alignment: tempAlignment,
                            child: Image.file(_profileImage!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Position controls
                Text(
                  'Position',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      double buttonSize = (constraints.maxWidth - 16) / 3;
                      return Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          _buildAlignmentButton(Alignment.topLeft, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.topCenter, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.topRight, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.centerLeft, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.center, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.centerRight, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.bottomLeft, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.bottomCenter, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                          _buildAlignmentButton(Alignment.bottomRight, tempAlignment, buttonSize, (alignment) {
                            setDialogState(() => tempAlignment = alignment);
                          }),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                
                // Scale control
                Text(
                  'Scale: ${tempScale.toStringAsFixed(1)}x',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFF7B42C),
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: const Color(0xFFF7B42C),
                    overlayColor: const Color(0xFFF7B42C).withOpacity(0.2),
                  ),
                  child: Slider(
                    value: tempScale,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    onChanged: (value) {
                      setDialogState(() => tempScale = value);
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _profileImageAlignment = tempAlignment;
                            _profileImageScale = tempScale;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF7B42C),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlignmentButton(Alignment alignment, Alignment currentAlignment, double size, Function(Alignment) onTap) {
    bool isSelected = alignment == currentAlignment;
    return GestureDetector(
      onTap: () => onTap(alignment),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF7B42C) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFFF7B42C) : Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.circle,
          size: size * 0.3,
          color: isSelected ? Colors.black87 : Colors.white60,
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildProfileImageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Profile Photo',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Colors.green.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                'Optional',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.green.shade300,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            GestureDetector(
              onTap: isCreating ? null : _pickProfileImage,
              child: Container(
                height: MediaQuery.of(context).size.width * 0.5,
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 180,
                  maxHeight: 250,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _profileImage != null
                        ? const Color(0xFFF7B42C)
                        : Colors.white.withOpacity(0.1),
                    width: _profileImage != null ? 2 : 1,
                  ),
                ),
                child: _profileImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: OverflowBox(
                          child: Transform.scale(
                            scale: _profileImageScale,
                            child: Container(
                              width: double.infinity,
                              height: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.cover,
                                alignment: _profileImageAlignment,
                                child: Image.file(_profileImage!),
                              ),
                            ),
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7B42C).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.person,
                              color: const Color(0xFFF7B42C),
                              size: MediaQuery.of(context).size.width * 0.08,
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                          Text(
                            'Upload Profile Photo',
                            style: GoogleFonts.poppins(
                              fontSize: MediaQuery.of(context).size.width * 0.04,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.width * 0.01),
                          Text(
                            'Tap to select from gallery',
                            style: GoogleFonts.poppins(
                              fontSize: MediaQuery.of(context).size.width * 0.03,
                              color: Colors.white60,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            
            // Edit button
            if (_profileImage != null)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: isCreating ? null : _showImageEditor,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFF7B42C),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: Color(0xFFF7B42C),
                      size: 16,
                    ),
                  ),
                ),
              ),
            
            // Remove button
            if (_profileImage != null)
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: isCreating ? null : () {
                    setState(() {
                      _profileImage = null;
                      _profileImageAlignment = Alignment.center;
                      _profileImageScale = 1.0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
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
                    Expanded(
                      child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: Text(
                'create community',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
                    ),
                  ],
                ),
              ),

              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Photo Section
                      _buildProfileImageSelector(),

                      const SizedBox(height: 30),

                      // Community Name
                      _buildSectionTitle('Community Name *'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _nameController,
                        hintText: 'Enter community name',
                        maxLines: 1,
                      ),

                      const SizedBox(height: 24),

                      // Description
                      _buildSectionTitle('Description *'),
                      const SizedBox(height: 4),
                      Text(
                        'Describe your community in detail ($_descriptionLength/$_maxDescriptionLength characters)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _descriptionController,
                        hintText: 'Tell us about your community...',
                        maxLines: 6,
                        maxLength: _maxDescriptionLength,
                      ),

                      const SizedBox(height: 24),

                      // Years Section
                      _buildSectionTitle('Academic Years *'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _yearController,
                              hintText: 'e.g., First Year, FY, etc.',
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildActionButton(
                            onPressed: _addYear,
                            icon: Icons.add,
                            label: 'Add',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildChipList(
                        items: years,
                        onRemove: _removeYear,
                        emptyMessage: 'No years added yet',
                      ),

                      const SizedBox(height: 24),

                      // Branches Section
                      _buildSectionTitle('Branches *'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _branchController,
                              hintText: 'e.g., Computer Science, Mechanical, etc.',
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                          _buildActionButton(
                            onPressed: _addBranch,
                            icon: Icons.add,
                            label: 'Add',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildChipList(
                        items: branches,
                        onRemove: _removeBranch,
                        emptyMessage: 'No branches added yet',
                      ),

                      const SizedBox(height: 40),

                      // Create Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isCreating ? null : _createCommunityRequest,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isCreating
                                  ? LinearGradient(
                                      colors: [
                                        Colors.grey.shade600,
                                        Colors.grey.shade700,
                                      ],
                                    )
                                  : const LinearGradient(
                                      colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: isCreating
                                      ? Colors.grey.withOpacity(0.3)
                                      : const Color(0xFFF7B42C).withOpacity(0.4),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: isCreating
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      'SUBMIT REQUEST',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required int maxLines,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF7B42C).withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFFF7B42C),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          hintText: hintText,
          hintStyle: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFF7B42C),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.all(16),
          counterStyle: GoogleFonts.poppins(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF7B42C),
        foregroundColor: Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipList({
    required List<String> items,
    required Function(String) onRemove,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Center(
          child: Text(
            emptyMessage,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item,
                  style: GoogleFonts.poppins(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => onRemove(item),
                  child: const Icon(
                    Icons.close,
                    color: Colors.black87,
                    size: 16,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}