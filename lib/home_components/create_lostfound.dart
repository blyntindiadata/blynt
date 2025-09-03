import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:shimmer/shimmer.dart';

class CreateLostFoundPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const CreateLostFoundPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<CreateLostFoundPage> createState() => _CreateLostFoundPageState();
}

class _CreateLostFoundPageState extends State<CreateLostFoundPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  final ValueNotifier<String> _typeNotifier = ValueNotifier('lost');
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<Map<String, String?>> _userDataNotifier = ValueNotifier({});
  final ValueNotifier<File?> _imageNotifier = ValueNotifier(null);

  final ImagePicker _picker = ImagePicker();

  final ValueNotifier<bool> _isLoadingUserData = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
void dispose() {
  _titleController.dispose();
  _descriptionController.dispose();
  _locationController.dispose();
  _typeNotifier.dispose();
  _isLoadingNotifier.dispose();
  _userDataNotifier.dispose();
  _imageNotifier.dispose();
  _isLoadingUserData.dispose(); // Add this line
  super.dispose();
}

Future<void> _loadUserData() async {
  try {
    _isLoadingUserData.value = true; // Add this line
    print('Loading user data for username: ${widget.username}');
    print('Community ID: ${widget.communityId}');
    
    // Try trio collection first
    var trioQuery = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .where('username', isEqualTo: widget.username)
        .limit(1)
        .get();

    DocumentSnapshot? userDoc;
    if (trioQuery.docs.isNotEmpty) {
      userDoc = trioQuery.docs.first;
      print('Found in trio collection: ${userDoc.data()}');
    } else {
      // Try members collection if not found in trio
      var membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();
      
      if (membersQuery.docs.isNotEmpty) {
        userDoc = membersQuery.docs.first;
        print('Found in members collection: ${userDoc.data()}');
      }
    }

    if (userDoc != null && userDoc.exists) {
      final data = userDoc.data()! as Map<String, dynamic>;
      
      // Create the map with explicit nullable String type
      final Map<String, String?> userData = {
        'firstName': data['firstName'] ?? data['first_name'] ?? '',
        'lastName': data['lastName'] ?? data['last_name'] ?? '',
        'email': data['userEmail'] ?? data['email'] ?? '',
        'phone': data['phone'] ?? data['userPhone'] ?? '',
        'branch': data['branch'] ?? '',
        'year': data['year'] ?? '',
        'profileImageUrl': data['profileImageUrl'] ?? '',
      };
      
      print('Processed user data: $userData');
      _userDataNotifier.value = userData;
    } else {
      print('No user document found in either trio or members collection');
    }
  } catch (e) {
    print('Error loading user data: $e');
  } finally {
    _isLoadingUserData.value = false; // Add this line
  }
}
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        _imageNotifier.value = File(image.path);
      }
    } catch (e) {
      _showMessage('Error picking image: $e', isError: true);
    }
  }

Future<String?> _uploadImage(File image) async {
  try {
    final storageRef = FirebaseStorage.instance.ref();
    final imageRef = storageRef.child('lost_found_images/${DateTime.now().millisecondsSinceEpoch}_${widget.username}.jpg');
    
    final uploadTask = imageRef.putFile(image);
    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();
    
    return downloadUrl;
  } catch (e) {
    print('Error uploading image: $e');
    return null;
  }
}

Future<void> _createItem() async {
  if (!_formKey.currentState!.validate()) return;

  _isLoadingNotifier.value = true;

  try {
    final userData = _userDataNotifier.value;
    String? photoUrl;
    
    // If user selected an image, upload it
    if (_imageNotifier.value != null) {
      photoUrl = await _uploadImage(_imageNotifier.value!);
      if (photoUrl == null) {
        _showMessage('Failed to upload image', isError: true);
        _isLoadingNotifier.value = false;
        return;
      }
    }

    final itemData = {
      'userId': widget.userId,
      'username': widget.username,
      'firstName': userData['firstName'] ?? '',
      'lastName': userData['lastName'] ?? '',
      'email': userData['email'] ?? '',
      'phone': userData['phone'] ?? '',
      'type': _typeNotifier.value,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'photoUrl': photoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    print('Creating item with data: $itemData');

    final docRef = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('lost_found')
        .add(itemData);

    print('Created document with ID: ${docRef.id}');

    if (mounted) {
      _showMessage('${_typeNotifier.value == 'lost' ? 'Lost' : 'Found'} item reported successfully!');
      Navigator.pop(context, true);
    }
  } catch (e) {
    print('Error creating item: $e');
    if (mounted) {
      _showMessage('Error creating item: $e', isError: true);
    }
  } finally {
    _isLoadingNotifier.value = false;
  }
}

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade700 : Colors.brown.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A1810),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF3D2317), // Dark bronze
              const Color(0xFF2A1810), // Medium dark bronze
              const Color(0xFF1A0F08), // Darker bronze
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: ValueListenableBuilder<bool>(
            valueListenable: _isLoadingNotifier,
            builder: (context, isLoading, child) {
              return Stack(
                children: [
                  Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildUserInfoCard(),
                                const SizedBox(height: 24),
                                _buildTypeSelection(),
                                const SizedBox(height: 24),
                                _buildTitleInput(),
                                const SizedBox(height: 24),
                                _buildDescriptionInput(),
                                const SizedBox(height: 24),
                                _buildLocationInput(),
                                const SizedBox(height: 24),
                                _buildPhotoSection(),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _buildCreateButton(),
                    ],
                  ),
                  if (isLoading) _buildLoadingOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

 Widget _buildHeader() {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth > 600;
  
  return Container(
    padding: EdgeInsets.all(isTablet ? 24 : 20),
    // decoration: BoxDecoration(
    //   gradient: LinearGradient(
    //     begin: Alignment.topLeft,
    //     end: Alignment.bottomRight,
    //     colors: [
    //       Colors.brown.shade900.withOpacity(0.3),
    //       Colors.transparent,
    //     ],
    //   ),
    // ),
    child: Row(
      children: [
         GestureDetector(
  onTap: () {
    // _dismissKeyboard();
    Navigator.pop(context);
  },
  child: Container(
    padding: EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.brown.shade600.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.brown.shade600.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      Icons.arrow_back_ios_new,
      color: Colors.brown.shade400,
      size: 18,
    ),
  ),
),
        SizedBox(width: isTablet ? 20 : 16),
        Container(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.brown.shade700, Colors.brown.shade900],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.shade700.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.add_circle_outline, 
            color: Colors.white, 
            size: isTablet ? 28 : 24
          ),
        ),
        SizedBox(width: isTablet ? 20 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [Colors.brown.shade400, Colors.brown.shade700],
                ).createShader(bounds),
                child: Text(
                  'report item',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                'help others find their belongings',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 14 : 12,
                  color: Colors.brown.shade200,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildUserInfoCard() {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth > 600;
  
  return Container(
    padding: EdgeInsets.all(isTablet ? 24 : 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.brown.shade900.withOpacity(0.3),
          Colors.brown.shade800.withOpacity(0.2),
        ],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.brown.shade700.withOpacity(0.4),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.brown.shade900.withOpacity(0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ValueListenableBuilder<Map<String, String?>>(
      valueListenable: _userDataNotifier,
      builder: (context, userData, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isTablet ? 60 : 48,
                  height: isTablet ? 60 : 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.brown.shade600, Colors.brown.shade800],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.brown.shade600.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: userData['profileImageUrl']?.isNotEmpty == true
                        ? Image.network(
                            userData['profileImageUrl']!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                color: Colors.white,
                                size: isTablet ? 30 : 24,
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            color: Colors.white,
                            size: isTablet ? 30 : 24,
                          ),
                  ),
                ),
                SizedBox(width: isTablet ? 20 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Information',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 20 : 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'This will be visible to others',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 14 : 12,
                          color: Colors.brown.shade200,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 24 : 20),
            _buildInfoRow('Username', widget.username),
            _buildInfoRow('Name', '${userData['firstName']} ${userData['lastName']}'),
            _buildInfoRow('Email', userData['email'] ?? 'Not provided'),
            _buildInfoRow('Phone', userData['phone'] ?? 'Not provided'),
            SizedBox(height: isTablet ? 20 : 16),
            Row(
              children: [
                if (userData['branch']?.isNotEmpty == true)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16 : 12, 
                        vertical: isTablet ? 10 : 8
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.brown.shade700, Colors.brown.shade800],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.brown.shade600.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.school, 
                            color: Colors.white, 
                            size: isTablet ? 18 : 16
                          ),
                          SizedBox(width: isTablet ? 8 : 6),
                          Flexible(
                            child: Text(
                              userData['branch']!,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (userData['branch']?.isNotEmpty == true && userData['year']?.isNotEmpty == true)
                  SizedBox(width: isTablet ? 16 : 12),
                if (userData['year']?.isNotEmpty == true)
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16 : 12, 
                        vertical: isTablet ? 10 : 8
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.brown.shade600, Colors.brown.shade700],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.brown.shade600.withOpacity(0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today, 
                            color: Colors.white, 
                            size: isTablet ? 18 : 16
                          ),
                          SizedBox(width: isTablet ? 8 : 6),
                          Flexible(
                            child: Text(
                              '${userData['year']}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isTablet ? 14 : 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

  Widget _buildTypeSelection() {
    return ValueListenableBuilder<String>(
      valueListenable: _typeNotifier,
      builder: (context, currentType, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('What are you reporting?', Icons.help_outline),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTypeCard('lost', 'Lost Item', Icons.search_off)),
                const SizedBox(width: 16),
                Expanded(child: _buildTypeCard('found', 'Found Item', Icons.search)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypeCard(String type, String label, IconData icon) {
    return ValueListenableBuilder<String>(
      valueListenable: _typeNotifier,
      builder: (context, currentType, child) {
        final isSelected = currentType == type;
        final isLost = type == 'lost';
        
        return GestureDetector(
          onTap: () => _typeNotifier.value = type,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected 
                  ? (isLost 
                    ? [Colors.red.shade600, Colors.red.shade800]
                    : [Colors.green.shade600, Colors.green.shade800])
                  : [
                      Colors.brown.shade900.withOpacity(0.2),
                      Colors.brown.shade800.withOpacity(0.1),
                    ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? (isLost ? Colors.red.shade500 : Colors.green.shade500)
                  : Colors.brown.shade700.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: (isLost ? Colors.red.shade600 : Colors.green.shade600).withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ] : [
                BoxShadow(
                  color: Colors.brown.shade900.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Colors.brown.shade400,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.brown.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Item Title', Icons.title),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.brown.shade900.withOpacity(0.2),
                Colors.brown.shade800.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.brown.shade700.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.shade900.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _titleController,
            maxLength: 100,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'e.g., Black iPhone 13, Blue Water Bottle...',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              counterStyle: GoogleFonts.poppins(color: Colors.brown.shade300),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter item title';
              }
              if (value.trim().length < 3) {
                return 'Title must be at least 3 characters';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Description', Icons.description),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.brown.shade900.withOpacity(0.2),
                Colors.brown.shade800.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.brown.shade700.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.shade900.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _descriptionController,
            maxLength: 500,
            maxLines: 4,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Describe the item in detail: color, size, brand, distinguishing features...',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              counterStyle: GoogleFonts.poppins(color: Colors.brown.shade300),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please provide a description';
              }
              if (value.trim().length < 10) {
                return 'Please provide more details (at least 10 characters)';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location', Icons.location_on),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.brown.shade900.withOpacity(0.2),
                Colors.brown.shade800.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.brown.shade700.withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.shade900.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: _locationController,
            maxLength: 50,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Where was it lost/found? e.g., Library, Cafeteria, Main Building...',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              counterStyle: GoogleFonts.poppins(color: Colors.brown.shade300),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please specify the location';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Photo (Optional)', Icons.camera_alt),
        const SizedBox(height: 12),
        ValueListenableBuilder<File?>(
          valueListenable: _imageNotifier,
          builder: (context, image, child) {
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.brown.shade900.withOpacity(0.2),
                    Colors.brown.shade800.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.brown.shade700.withOpacity(0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.shade900.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: image == null
                  ? Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _pickImage,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 150,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                color: Colors.brown.shade400,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tap to add a photo',
                                style: GoogleFonts.poppins(
                                  color: Colors.brown.shade300,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'This helps others identify the item',
                                style: GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.brown.shade700.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              image,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                onPressed: _pickImage,
                                icon: Icon(Icons.edit, color: Colors.brown.shade400),
                                label: Text(
                                  'Change Photo',
                                  style: GoogleFonts.poppins(color: Colors.brown.shade400),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _imageNotifier.value = null,
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: Text(
                                  'Remove',
                                  style: GoogleFonts.poppins(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        ),
      ],
    );
  }

Widget _buildCreateButton() {
  final screenWidth = MediaQuery.of(context).size.width;
  final isTablet = screenWidth > 600;
  
  return Container(
    padding: EdgeInsets.all(isTablet ? 24 : 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.1),
        ],
      ),
    ),
    child: SizedBox(
      width: double.infinity,
      height: isTablet ? 65 : 60,
      child: ElevatedButton(
        onPressed: _createItem,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: EdgeInsets.zero,
        ),
        child: ValueListenableBuilder<String>(
          valueListenable: _typeNotifier,
          builder: (context, type, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.brown.shade600, Colors.brown.shade800],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.shade600.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                  // Subtle glow effect
                  BoxShadow(
                    color: Colors.brown.shade400.withOpacity(0.2),
                    blurRadius: 25,
                    offset: const Offset(0, 0),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Container(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      type == 'lost' ? Icons.search_off : Icons.search,
                      color: Colors.white,
                      size: isTablet ? 28 : 24,
                    ),
                    SizedBox(width: isTablet ? 16 : 12),
                    Text(
                      'REPORT ${type == 'lost' ? 'LOST' : 'FOUND'} ITEM',
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.brown.shade800.withOpacity(0.9),
                Colors.brown.shade900.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.shade600.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.brown.shade400,
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Creating your report...',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.brown.shade600, Colors.brown.shade800],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.shade600.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isLoadingUserData,
      builder: (context, isLoading, child) {
        return Container(
          padding: EdgeInsets.symmetric(
            vertical: MediaQuery.of(context).size.height * 0.01
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.25,
                child: Text(
                  '$label ',
                  style: GoogleFonts.poppins(
                    color: Colors.brown.shade300,
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.brown.shade800.withOpacity(0.3),
                    highlightColor: Colors.brown.shade600.withOpacity(0.5),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.02,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    )
                  : Text(
                      value.isEmpty ? 'Not provided' : value,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width * 0.035,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}