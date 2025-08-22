import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

// Indian phone number formatter - defined outside the class
class IndianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String newText = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    if (newText.length > 10) {
      newText = newText.substring(0, 10);
    }
    
    String formattedText = '';
    for (int i = 0; i < newText.length; i++) {
      if (i == 5) {
        formattedText += ' ';
      }
      formattedText += newText[i];
    }
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}

class JoinRequestPage extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String userId;
  final String username;
  final VoidCallback onRequestSubmitted;

  const JoinRequestPage({
    super.key,
    required this.communityId,
    required this.communityName,
    required this.userId,
    required this.username,
    required this.onRequestSubmitted,
  });

  @override
  State<JoinRequestPage> createState() => _JoinRequestPageState();
}

class _JoinRequestPageState extends State<JoinRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  
  File? _profileImage;
  File? _idCardImage;
  bool _isSubmitting = false;
  final ImagePicker _picker = ImagePicker();
  
  String userName = '';
  String userEmail = '';
  String firstName = '';
  String lastName = '';
  
  // Image positioning variables
  Alignment _profileImageAlignment = Alignment.center;
  double _profileImageScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          firstName = data['firstName'] ?? '';
          lastName = data['lastName'] ?? '';
          userName = '${firstName} ${lastName}'.trim();
          userEmail = data['email'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Validate Indian phone number
  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    
    String cleanNumber = value.replaceAll(RegExp(r'\D'), '');
    
    if (cleanNumber.length != 10) {
      return 'Please enter a valid 10-digit phone number';
    }
    
    // Check if starts with valid Indian mobile prefixes
    List<String> validPrefixes = ['6', '7', '8', '9'];
    if (!validPrefixes.contains(cleanNumber[0])) {
      return 'Please enter a valid Indian mobile number';
    }
    
    return null;
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
          // Reset positioning when new image is selected
          _profileImageAlignment = Alignment.center;
          _profileImageScale = 1.0;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick profile image: $e');
    }
  }

  Future<void> _pickIdCardImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _idCardImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to pick ID card image: $e');
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
            // maxWidth: 400,
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
                
                // Responsive image preview
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

  Future<void> _submitJoinRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idCardImage == null) {
      _showErrorSnackBar('Please select your ID card image');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get the most current user data to handle username changes
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      
      if (!currentUserDoc.exists) {
        _showErrorSnackBar('User not found');
        return;
      }
      
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      final currentUsername = currentUserData['username'] ?? widget.username;
      final currentFirstName = currentUserData['firstName'] ?? '';
      final currentLastName = currentUserData['lastName'] ?? '';
      final currentEmail = currentUserData['email'] ?? '';

      // Check if user already has a pending request for this community (using current username)
      final existingRequest = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('join_requests')
          .where('userId', isEqualTo: widget.userId) // Use userId instead of username
          .where('processed', isEqualTo: false)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        _showErrorSnackBar('You already have a pending request for this community');
        return;
      }

      // Check if user is already a member of any community (using userId)
      final existingMember = await FirebaseFirestore.instance
          .collection('community_members')
          .where('userId', isEqualTo: widget.userId) // Use userId instead of username
          .where('status', isEqualTo: 'active')
          .get();

      if (existingMember.docs.isNotEmpty) {
        _showErrorSnackBar('You are already a member of another community');
        return;
      }

      // Upload images (profile image is optional)
      String? profileImageUrl;
      if (_profileImage != null) {
        profileImageUrl = await _uploadImage(_profileImage!, 'profile_photos');
        if (profileImageUrl == null) {
          _showErrorSnackBar('Failed to upload profile image');
          return;
        }
      }
      
      final String? idCardImageUrl = await _uploadImage(_idCardImage!, 'id_cards');
      if (idCardImageUrl == null) {
        _showErrorSnackBar('Failed to upload ID card image');
        return;
      }

      // Store positioning data as map for profile image
      Map<String, dynamic>? profileImagePositioning;
      if (profileImageUrl != null) {
        profileImagePositioning = {
          'alignment': {
            'x': _profileImageAlignment.x,
            'y': _profileImageAlignment.y,
          },
          'scale': _profileImageScale,
        };
      }

      // Create join request in community subcollection with current user data
      await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('join_requests')
          .add({
        'userId': widget.userId, // Primary identifier
        'username': currentUsername, // Current username
        'firstName': currentFirstName, // Store separately
        'lastName': currentLastName, // Store separately
        'communityId': widget.communityId,
        'userName': '$currentFirstName $currentLastName'.trim(),
        'userEmail': currentEmail,
        'userPhone': _phoneController.text.replaceAll(RegExp(r'\D'), ''), // Store clean number
        'profileImageUrl': profileImageUrl,
        'profileImagePositioning': profileImagePositioning,
        'idCardImageUrl': idCardImageUrl,
        'requestedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'processed': false,
        // These will be filled by admin/moderator
        'year': null,
        'branch': null,
      });

      // Show success dialog
      _showSuccessDialog();
    } catch (e) {
      _showErrorSnackBar('Failed to submit request: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFF7B42C).withOpacity(0.3),
              width: 1,
            ),
          ),
          content: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.black87,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Request Submitted!',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your join request has been sent to the community moderators. You will be notified once it\'s reviewed.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      widget.onRequestSubmitted(); // Navigate back to home
                    },
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'OK',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildImageSelector({
    required String title,
    required File? selectedImage,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    bool isProfilePhoto = title.contains('Profile Photo');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (isProfilePhoto) ...[
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
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            GestureDetector(
              onTap: _isSubmitting ? null : onTap,
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
                    color: selectedImage != null
                        ? const Color(0xFFF7B42C)
                        : Colors.white.withOpacity(0.1),
                    width: selectedImage != null ? 2 : 1,
                  ),
                ),
                child: selectedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: isProfilePhoto
                            ? OverflowBox(
                                child: Transform.scale(
                                  scale: _profileImageScale,
                                  child: Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      alignment: _profileImageAlignment,
                                      child: Image.file(selectedImage),
                                    ),
                                  ),
                                ),
                              )
                            : Image.file(
                                selectedImage,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
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
                              icon,
                              color: const Color(0xFFF7B42C),
                              size: MediaQuery.of(context).size.width * 0.08,
                            ),
                          ),
                          SizedBox(height: MediaQuery.of(context).size.width * 0.04),
                          Text(
                            'Upload $title',
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
            
            // Edit button for profile photo
            if (selectedImage != null && isProfilePhoto)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: _isSubmitting ? null : _showImageEditor,
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
            if (selectedImage != null)
              Positioned(
                top: 8,
                left: 8,
                child: GestureDetector(
                  onTap: _isSubmitting ? null : () {
                    setState(() {
                      if (isProfilePhoto) {
                        _profileImage = null;
                        _profileImageAlignment = Alignment.center;
                        _profileImageScale = 1.0;
                      } else {
                        _idCardImage = null;
                      }
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
              // Responsive Header
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Profile & Join',
                            style: GoogleFonts.poppins(
                              fontSize: MediaQuery.of(context).size.width * 0.055,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            widget.communityName,
                            style: GoogleFonts.poppins(
                              fontSize: MediaQuery.of(context).size.width * 0.035,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFFF7B42C),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width * 0.05),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Complete your profile to join the community. All information will be reviewed by moderators.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: Colors.blue.shade300,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Name Field (Read-only)
                        Text(
                          'Full Name',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Color(0xFFF7B42C),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                userName.isNotEmpty ? userName : 'Loading...',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Username Field (Read-only)
                        Text(
                          'Username',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alternate_email,
                                color: Color(0xFFF7B42C),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '@${widget.username}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Phone Number Field with Indian formatting
                        Text(
                          'Phone Number',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            IndianPhoneFormatter(),
                          ],
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                          cursorColor: const Color(0xFFF7B42C),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.08),
                            prefixIcon: const Icon(
                              Icons.phone,
                              color: Color(0xFFF7B42C),
                              size: 20,
                            ),
                            hintText: '98765 43210',
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
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: _validatePhoneNumber,
                        ),

                        const SizedBox(height: 30),

                        // Profile Photo Upload
                        _buildImageSelector(
                          title: 'Profile Photo',
                          selectedImage: _profileImage,
                          onTap: _pickProfileImage,
                          icon: Icons.person,
                        ),

                        const SizedBox(height: 30),

                        // ID Card Upload
                        _buildImageSelector(
                          title: 'ID Card Image',
                          selectedImage: _idCardImage,
                          onTap: _pickIdCardImage,
                          icon: Icons.credit_card,
                        ),

                        const SizedBox(height: 40),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitJoinRequest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ).copyWith(
                              backgroundColor: WidgetStateProperty.all(Colors.transparent),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: _isSubmitting
                                    ? LinearGradient(
                                        colors: [
                                          Colors.grey.shade600,
                                          Colors.grey.shade700,
                                        ],
                                      )
                                    : const LinearGradient(
                                        colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                                      ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isSubmitting
                                        ? Colors.grey.withOpacity(0.3)
                                        : const Color(0xFFF7B42C).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: _isSubmitting
                                  ? Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Submitting...',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.send,
                                          color: Colors.black87,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Submit Request',
                                          style: GoogleFonts.poppins(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
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
}