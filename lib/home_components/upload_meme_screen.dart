import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class UploadMemeScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final Map<String, dynamic>? userProfile;

  const UploadMemeScreen({
    super.key,
    required this.communityId,
    required this.userId,
    required this.username,
    this.userProfile,
  });

  @override
  State<UploadMemeScreen> createState() => _UploadMemeScreenState();
}

class _UploadMemeScreenState extends State<UploadMemeScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  bool _postAnonymously = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _uploadMeme() async {
    if (_selectedImage == null) return;
    
    setState(() => _isUploading = true);

    try {
      final fileName = 'meme_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('communities')
          .child(widget.communityId)
          .child('memes')
          .child(fileName);
      
      await ref.putFile(_selectedImage!);
      final imageUrl = await ref.getDownloadURL();

      final memeRef = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('memes')
          .doc();

      await memeRef.set({
        'id': memeRef.id,
        'imageUrl': imageUrl,
        'caption': _captionController.text.trim(),
        'authorId': _postAnonymously ? 'anonymous' : widget.userId,
        'authorUsername': _postAnonymously ? 'Anonymous' : widget.username,
        'authorFirstName': _postAnonymously ? '' : (widget.userProfile?['firstName'] ?? ''),
        'authorLastName': _postAnonymously ? '' : (widget.userProfile?['lastName'] ?? ''),
        'authorYear': _postAnonymously ? '' : (widget.userProfile?['year'] ?? ''),
        'authorBranch': _postAnonymously ? '' : (widget.userProfile?['branch'] ?? ''),
        'isAnonymous': _postAnonymously,
        'createdAt': FieldValue.serverTimestamp(),
        'reactions': {},
        'commentsCount': 0,
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload: $e'),
          backgroundColor: Colors.red.shade800,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0000),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF3D0000),
              const Color(0xFF2A0000),
              const Color(0xFF1A0000),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
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
                        child: Icon(
                          Icons.close,
                          color: Colors.red.shade300,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [Colors.red.shade400, Colors.red.shade700],
                      ).createShader(bounds),
                      child: Text(
                        'post meme',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Image picker
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 300,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.red.shade900.withOpacity(0.2),
                                Colors.red.shade800.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.red.shade700.withOpacity(0.3),
                              width: 2,
                              style: _selectedImage == null ? BorderStyle.solid : BorderStyle.none,
                            ),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Colors.red.shade600, Colors.red.shade800],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_photo_alternate,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tap to select meme',
                                      style: GoogleFonts.poppins(
                                        color: Colors.red.shade300,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Choose from your gallery',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Caption input
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.red.shade700.withOpacity(0.3),
                          ),
                        ),
                        child: TextField(
                          controller: _captionController,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'ladies & gentlemen, this is your caption speaking...',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.white38,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Anonymous toggle
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _postAnonymously = !_postAnonymously;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.08),
                                Colors.white.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _postAnonymously 
                                  ? Colors.red.shade500 
                                  : Colors.red.shade700.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: _postAnonymously
                                      ? LinearGradient(
                                          colors: [Colors.red.shade600, Colors.red.shade800],
                                        )
                                      : null,
                                  border: Border.all(
                                    color: _postAnonymously 
                                        ? Colors.red.shade500 
                                        : Colors.red.shade700,
                                    width: 2,
                                  ),
                                ),
                                child: _postAnonymously
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 16,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12,),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Post anonymously',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Center(
  child: Text(
    'we got you',
    textAlign: TextAlign.center,
    style: GoogleFonts.poppins(
      color: Colors.white60,
      fontSize: 12,
    ),
  ),
),

                                ],
                              ),
                              const Spacer(),
                              Icon(
                                Icons.masks,
                                color: _postAnonymously 
                                    ? Colors.red.shade400 
                                    : Colors.red.shade700,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Upload button
              Container(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedImage != null && !_isUploading 
                        ? _uploadMeme 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _selectedImage != null
                              ? [Colors.red.shade600, Colors.red.shade800]
                              : [Colors.grey.shade800, Colors.grey.shade900],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _selectedImage != null
                            ? [
                                BoxShadow(
                                  color: Colors.red.shade600.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: _isUploading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Uploading...',
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
                                    Icons.upload_rounded,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Upload Meme',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
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