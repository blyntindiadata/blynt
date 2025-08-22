import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';

class CreateBarterPage extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const CreateBarterPage({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<CreateBarterPage> createState() => _CreateBarterPageState();
}

class _CreateBarterPageState extends State<CreateBarterPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _requestController = TextEditingController();
  final TextEditingController _serviceOfferController = TextEditingController();
  final TextEditingController _moneyAmountController = TextEditingController();
  
  final ValueNotifier<String> _offerTypeNotifier = ValueNotifier('service');
  final ValueNotifier<DateTime?> _deadlineNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isLoadingNotifier = ValueNotifier(false);
  final ValueNotifier<Map<String, String?>> _userDataNotifier = ValueNotifier({});
  final ValueNotifier<bool> _isPriorityNotifier = ValueNotifier(false);

  final ValueNotifier<bool> _isLoadingUserData = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _requestController.dispose();
    _serviceOfferController.dispose();
    _moneyAmountController.dispose();
    _offerTypeNotifier.dispose();
    _deadlineNotifier.dispose();
    _isLoadingNotifier.dispose();
    _userDataNotifier.dispose();
    _isPriorityNotifier.dispose();
    _isLoadingUserData.dispose();
    super.dispose();
  }

Future<void> _loadUserData() async {
  try {
    DocumentSnapshot? userDoc;
    _isLoadingUserData.value = true;
    
    // Check trio collection first
    final trioQuery = await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('trio')
        .where('username', isEqualTo: widget.username)
        .limit(1)
        .get();
    
    if (trioQuery.docs.isNotEmpty) {
      userDoc = trioQuery.docs.first;
    } else {
      // Check members collection
      final membersQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('members')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();
      
      if (membersQuery.docs.isNotEmpty) {
        userDoc = membersQuery.docs.first;
      }
    }

    if (userDoc != null && userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      _userDataNotifier.value = {
        'firstName': data['firstName'] ?? data['first_name'] ?? '',
        'lastName': data['lastName'] ?? data['last_name'] ?? '',
        'email': data['userEmail'] ?? '',
        'phone': data['userPhone'] ?? '',
        'branch': data['branch'] ?? '',
        'year': data['year'] ?? '',
        'profileImageUrl': data['profileImageUrl'] ?? '',
      };
    }
  } catch (e) {
    print('Error loading user data: $e');
  }
  finally {
    _isLoadingUserData.value = false;
  }
}

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.green.shade600,
              onPrimary: Colors.white,
              surface: const Color(0xFF1A4A00),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _deadlineNotifier.value = picked;
    }
  }

  Future<void> _createBarter() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deadlineNotifier.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a deadline', style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    _isLoadingNotifier.value = true;

    try {
      final barterData = {
        'userId': widget.userId,
        'username': widget.username,
        'firstName': _userDataNotifier.value['firstName'],
        'lastName': _userDataNotifier.value['lastName'],
        'email': _userDataNotifier.value['email'],
        'phone': _userDataNotifier.value['phone'],
        'request': _requestController.text.trim(),
        'offerType': _offerTypeNotifier.value,
        'serviceOffer': _offerTypeNotifier.value == 'service' ? _serviceOfferController.text.trim() : null,
        'moneyAmount': _offerTypeNotifier.value == 'money' ? int.tryParse(_moneyAmountController.text) : null,
        'deadline': Timestamp.fromDate(_deadlineNotifier.value!),
        'createdAt': FieldValue.serverTimestamp(),
        'isPinned': false,
        'isActive': true,
        'isPriority': _isPriorityNotifier.value,
        'priorityApproved': false,
      };

      final barterRef = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('barters')
          .add(barterData);

      // If priority is requested, create a priority request
      if (_isPriorityNotifier.value) {
        await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('priority_requests')
            .add({
          'barterId': barterRef.id,
          'userId': widget.userId,
          'username': widget.username,
          'requestedAt': FieldValue.serverTimestamp(),
          'processed': false,
          'approved': false,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isPriorityNotifier.value 
                  ? 'Barter created! Priority request sent for approval.'
                  : 'Barter created successfully!',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating barter: $e', style: GoogleFonts.poppins(color: Colors.white)),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      _isLoadingNotifier.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A4A00),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2D5A00), // Dark green
              const Color(0xFF1A4A00), // Medium green
              const Color(0xFF0D2A00), // Darker green
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
                      // Header
                      Container(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.green.shade900.withOpacity(0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
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
        color: Colors.green.shade600.withOpacity(0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.green.shade600.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Icon(
      Icons.arrow_back_ios_new,
      color: Colors.green.shade400,
      size: 18,
    ),
  ),
),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                            Container(
                              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.green.shade700, Colors.green.shade900],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.shade700.withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add_circle_outline, 
                                color: Colors.white, 
                                size: MediaQuery.of(context).size.width * 0.06
                              ),
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [Colors.green.shade400, Colors.green.shade700],
                                    ).createShader(bounds),
                                    child: Text(
                                      'create barter',
                                      style: GoogleFonts.dmSerifDisplay(
                                        fontSize: MediaQuery.of(context).size.width * 0.06,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'trade skills & services',
                                    style: GoogleFonts.poppins(
                                      fontSize: MediaQuery.of(context).size.width * 0.03,
                                      color: Colors.green.shade200,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // User Info Section
                                _buildUserInfoCard(),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                                // What you need
                                _buildSectionTitle('What do you need?', Icons.help_outline),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                                _buildRequestInput(),

                                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                                // What you offer
                                _buildSectionTitle('What do you offer?', Icons.handshake),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                                _buildOfferSection(),

                                SizedBox(height: MediaQuery.of(context).size.height * 0.03),

                                // Deadline selection
                                _buildSectionTitle('Deadline', Icons.calendar_today),
                                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                                _buildDeadlineSelector(),

                                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Create button
                      _buildCreateButton(),
                    ],
                  ),

                  // Loading overlay
                  if (isLoading) _buildLoadingOverlay(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.3),
            Colors.green.shade800.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.2),
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
                    width: MediaQuery.of(context).size.width * 0.12,
                    height: MediaQuery.of(context).size.width * 0.12,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade800],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade600.withOpacity(0.3),
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
                                  size: MediaQuery.of(context).size.width * 0.06,
                                );
                              },
                            )
                          : Icon(
                              Icons.person,
                              color: Colors.white,
                              size: MediaQuery.of(context).size.width * 0.06,
                            ),
                    ),
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Information',
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.045,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'This will be visible to others',
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            color: Colors.green.shade200,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.025),
              _buildInfoRow('Username', widget.username),
              _buildInfoRow('Name', '${userData['firstName']} ${userData['lastName']}'),
              _buildInfoRow('Email', userData['email'] ?? 'Not provided'),
              _buildInfoRow('Phone', userData['phone'] ?? 'Not provided'),
              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
              Row(
                children: [
                  if (userData['branch']?.isNotEmpty == true)
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.03,
                          vertical: MediaQuery.of(context).size.height * 0.01,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade700, Colors.green.shade800],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade600.withOpacity(0.3),
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
                              size: MediaQuery.of(context).size.width * 0.04
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.015),
                            Flexible(
                              child: Text(
                                userData['branch']!,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: MediaQuery.of(context).size.width * 0.03,
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
                    SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  if (userData['year']?.isNotEmpty == true)
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.03,
                          vertical: MediaQuery.of(context).size.height * 0.01,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade600, Colors.green.shade700],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade600.withOpacity(0.3),
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
                              size: MediaQuery.of(context).size.width * 0.04
                            ),
                            SizedBox(width: MediaQuery.of(context).size.width * 0.015),
                            Flexible(
                              child: Text(
                                '${userData['year']}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: MediaQuery.of(context).size.width * 0.03,
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

  Widget _buildRequestInput() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.2),
            Colors.green.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _requestController,
        maxLength: 800,
        maxLines: 4,
        style: GoogleFonts.poppins(
          color: Colors.white, 
          fontSize: MediaQuery.of(context).size.width * 0.035
        ),
        decoration: InputDecoration(
          hintText: 'Describe what you need help with in detail...',
          hintStyle: GoogleFonts.poppins(color: Colors.white38),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
          counterStyle: GoogleFonts.poppins(color: Colors.green.shade300),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please describe what you need';
          }
          if (value.trim().length < 10) {
            return 'Please provide more details (at least 10 characters)';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildOfferSection() {
    return ValueListenableBuilder<String>(
      valueListenable: _offerTypeNotifier,
      builder: (context, offerType, child) {
        return Column(
          children: [
            // Offer type selection
            Row(
              children: [
                Expanded(child: _buildOfferTypeCard('service', 'Service/Skill', Icons.work_history)),
                SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                Expanded(child: _buildOfferTypeCard('money', 'Money', Icons.currency_rupee)),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            // Offer details input
            _buildOfferDetailsInput(offerType),
          ],
        );
      },
    );
  }

  Widget _buildOfferTypeCard(String type, String label, IconData icon) {
    return ValueListenableBuilder<String>(
      valueListenable: _offerTypeNotifier,
      builder: (context, currentType, child) {
        final isSelected = currentType == type;
        return GestureDetector(
          onTap: () => _offerTypeNotifier.value = type,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected 
                  ? [Colors.green.shade600, Colors.green.shade800]
                  : [
                      Colors.green.shade900.withOpacity(0.2),
                      Colors.green.shade800.withOpacity(0.1),
                    ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected 
                  ? Colors.green.shade500
                  : Colors.green.shade700.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: Colors.green.shade600.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ] : [],
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.green.shade400,
                  size: MediaQuery.of(context).size.width * 0.08,
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : Colors.green.shade400,
                    fontWeight: FontWeight.w600,
                    fontSize: MediaQuery.of(context).size.width * 0.035,
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

  Widget _buildOfferDetailsInput(String offerType) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.2),
            Colors.green.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.shade900.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: offerType == 'service'
        ? TextFormField(
            controller: _serviceOfferController,
            maxLength: 800,
            maxLines: 3,
            style: GoogleFonts.poppins(
              color: Colors.white, 
              fontSize: MediaQuery.of(context).size.width * 0.035
            ),
            decoration: InputDecoration(
              hintText: 'Describe what service/skill you can provide...',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
              counterStyle: GoogleFonts.poppins(color: Colors.green.shade300),
            ),
            validator: (value) {
              if (offerType == 'service' && (value == null || value.trim().isEmpty)) {
                return 'Please describe your service offer';
              }
              return null;
            },
          )
        : TextFormField(
            controller: _moneyAmountController,
            keyboardType: TextInputType.number,
            maxLength: 4, // Limit to 4 digits
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,

              LengthLimitingTextInputFormatter(4),
            ],
            style: GoogleFonts.poppins(
              color: Colors.white, 
              fontSize: MediaQuery.of(context).size.width * 0.04
            ),
            decoration: InputDecoration(
              hintText: 'Enter amount in ₹ (max 4 digits)',
              hintStyle: GoogleFonts.poppins(color: Colors.white38),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
              prefixIcon: Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                child: Icon(
                  Icons.currency_rupee, 
                  color: Colors.green.shade400, 
                  size: MediaQuery.of(context).size.width * 0.05
                ),
              ),
              counterStyle: GoogleFonts.poppins(color: Colors.green.shade300),
            ),
            validator: (value) {
              if (offerType == 'money') {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the amount';
                }
                if (int.tryParse(value) == null || int.parse(value) <= 0) {
                  return 'Please enter a valid amount';
                }
                if (value.length > 4) {
                  return 'Amount cannot exceed 4 digits';
                }
              }
              return null;
            },
          ),
    );
  }

  Widget _buildDeadlineSelector() {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _deadlineNotifier,
      builder: (context, deadline, child) {
        return GestureDetector(
          onTap: _selectDate,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green.shade900.withOpacity(0.2),
                  Colors.green.shade800.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.green.shade700.withOpacity(0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade900.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade800],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade600.withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.calendar_today, 
                    color: Colors.white, 
                    size: MediaQuery.of(context).size.width * 0.05
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deadline != null 
                          ? '${deadline.day}/${deadline.month}/${deadline.year}'
                          : 'Select deadline date',
                        style: GoogleFonts.poppins(
                          color: deadline != null ? Colors.white : Colors.white60,
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (deadline != null)
                        Text(
                          'Tap to change',
                          style: GoogleFonts.poppins(
                            color: Colors.green.shade300,
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios, 
                  color: Colors.green.shade400, 
                  size: MediaQuery.of(context).size.width * 0.04,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateButton() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
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
        height: MediaQuery.of(context).size.height * 0.065,
        child: ElevatedButton(
          onPressed: _createBarter,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade600.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
                // Subtle glow effect
                BoxShadow(
                  color: Colors.green.shade400.withOpacity(0.2),
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
                    Icons.add_circle,
                    color: Colors.white,
                    size: MediaQuery.of(context).size.width * 0.06,
                  ),
                  SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                  Text(
                    'CREATE BARTER',
                    style: GoogleFonts.poppins(
                      fontSize: MediaQuery.of(context).size.width * 0.045,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
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
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.green.shade800.withOpacity(0.9),
                Colors.green.shade900.withOpacity(0.9),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade600.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Colors.green.shade400,
                strokeWidth: 3,
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.025),
              Text(
                'Creating your barter...',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: MediaQuery.of(context).size.width * 0.04,
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
          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade600, Colors.green.shade800],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.green.shade600.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon, 
            color: Colors.white, 
            size: MediaQuery.of(context).size.width * 0.05
          ),
        ),
        SizedBox(width: MediaQuery.of(context).size.width * 0.04),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: MediaQuery.of(context).size.width * 0.045,
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
                    color: Colors.green.shade300,
                    fontSize: MediaQuery.of(context).size.width * 0.035,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(
                child: isLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.green.shade800.withOpacity(0.3),
                      highlightColor: Colors.green.shade600.withOpacity(0.5),
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