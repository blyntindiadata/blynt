import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';

class ContactLostFoundPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String communityId;

  const ContactLostFoundPage({
    Key? key,
    required this.item,
    required this.communityId,
  }) : super(key: key);

  @override
  State<ContactLostFoundPage> createState() => _ContactLostFoundPageState();
}

class _ContactLostFoundPageState extends State<ContactLostFoundPage> with TickerProviderStateMixin {
  Map<String, dynamic>? _userDetails;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    try {
      // Try trio collection first
      var trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: widget.item['username'])
          .limit(1)
          .get();
      
      DocumentSnapshot? userDoc;
      if (trioQuery.docs.isNotEmpty) {
        userDoc = trioQuery.docs.first;
      } else {
        // Try members collection if not found in trio
        var membersQuery = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('members')
            .where('username', isEqualTo: widget.item['username'])
            .limit(1)
            .get();
        
        if (membersQuery.docs.isNotEmpty) {
          userDoc = membersQuery.docs.first;
        }
      }
      
      if (userDoc != null && userDoc.exists) {
        setState(() {
          _userDetails = {
            ...userDoc!.data()! as Map<String, dynamic>,
            'branch': (userDoc.data()! as Map<String, dynamic>)['branch'] ?? '',
            'year': (userDoc.data()! as Map<String, dynamic>)['year'] ?? '',
            'userEmail': (userDoc.data()! as Map<String, dynamic>)['userEmail'] ?? '', 
            'userPhone': (userDoc.data()! as Map<String, dynamic>)['userPhone'] ?? '', 
          };
          _isLoadingUser = false;
        });
      } else {
        setState(() {
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      print('Error loading user details: $e');
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _sendWhatsAppMessage(BuildContext context) async {
    final phone = _userDetails?['userPhone']?.toString() ?? '';
    if (phone.isEmpty) {
      _showMessage('Phone number not available', isError: true);
      return;
    }

    // Clean phone number and ensure it starts with country code
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '91${cleanPhone.substring(1)}'; // Assuming Indian numbers
    } else if (!cleanPhone.startsWith('91') && cleanPhone.length == 10) {
      cleanPhone = '91$cleanPhone';
    }

    final itemType = widget.item['type'] == 'lost' ? 'lost' : 'found';
    final message = Uri.encodeComponent(
      'Hi ${widget.item['firstName']},\n\n'
      'I saw your \'$itemType\' item report on blynt.\n\n'
      'You posted: ${widget.item['title']}\n'
      'Location: ${widget.item['location']}\n\n'
      'Let\'s discuss the details.\n'
      'Thanks'
    );

    // Try multiple WhatsApp URL formats
    final whatsappUrls = [
      'https://wa.me/$cleanPhone?text=$message',
      'https://api.whatsapp.com/send?phone=$cleanPhone&text=$message',
      'whatsapp://send?phone=$cleanPhone&text=$message',
    ];

    bool launched = false;
    for (String urlString in whatsappUrls) {
      try {
        final uri = Uri.parse(urlString);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        }
      } catch (e) {
        print('Failed to launch $urlString: $e');
      }
    }

    if (!launched) {
      _showMessage('Could not open WhatsApp. Please make sure WhatsApp is installed.', isError: true);
    }
  }

  Future<void> _launchEmail(BuildContext context) async {
    final email = _userDetails?['userEmail']?.toString() ?? '';
    if (email.isEmpty) {
      _showMessage('Email not available', isError: true);
      return;
    }

    final itemType = widget.item['type'] == 'lost' ? 'lost' : 'found';
    final subject = 'Regarding your $itemType item: ${widget.item['title']}';
    final body = 'Hi ${widget.item['firstName']},\n\n'
      'I saw your \'$itemType\' item report on blynt.\n\n'
      'You posted: ${widget.item['title']}\n'
      'Location: ${widget.item['location']}\n\n'
      'Let\'s discuss the details.\n'
      'Thanks';

    // Try multiple email URL formats
    final emailUrls = [
      'mailto:$email?subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
      'mailto:$email',
    ];

    bool launched = false;
    for (String urlString in emailUrls) {
      try {
        final uri = Uri.parse(urlString);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          launched = true;
          break;
        }
      } catch (e) {
        print('Failed to launch $urlString: $e');
      }
    }

    if (!launched) {
      _showMessage('Could not open email app. Please check if an email app is installed.', isError: true);
    }
  }

  Future<void> _launchPhone(BuildContext context) async {
    final phone = _userDetails?['userPhone']?.toString() ?? '';
    if (phone.isEmpty) {
      _showMessage('Phone number not available', isError: true);
      return;
    }

    // Try multiple phone URL formats
    final phoneUrls = [
      'tel:$phone',
      'tel://$phone',
    ];

    bool launched = false;
    for (String urlString in phoneUrls) {
      try {
        final uri = Uri.parse(urlString);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          launched = true;
          break;
        }
      } catch (e) {
        print('Failed to launch $urlString: $e');
      }
    }

    if (!launched) {
      _showMessage('Could not open phone app', isError: true);
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

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.1),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade900.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            color: Colors.brown.shade400,
                            size: MediaQuery.of(context).size.width * 0.15,
                          ),
                          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                          Text(
                            'Could not load image',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: MediaQuery.of(context).size.width * 0.04,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLost = widget.item['type'] == 'lost';
    final createdAt = widget.item['createdAt'] != null 
        ? (widget.item['createdAt'] as Timestamp).toDate() 
        : DateTime.now();

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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserInfoCard(isLost),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                      _buildContactInfoCard(),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                      _buildItemDetailsCard(createdAt),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                      _buildInfoNote(),
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

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
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
          SizedBox(width: MediaQuery.of(context).size.width * 0.04),
          Container(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
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
              Icons.contact_phone, 
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
                    colors: [Colors.brown.shade400, Colors.brown.shade700],
                  ).createShader(bounds),
                  child: Text(
                    'contact details',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: MediaQuery.of(context).size.width * 0.055,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'reach out & help',
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width * 0.028,
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

  Widget _buildUserInfoCard(bool isLost) {
    final firstName = _userDetails?['firstName'] ?? widget.item['firstName'] ?? '';
    final lastName = _userDetails?['lastName'] ?? widget.item['lastName'] ?? '';
    final username = widget.item['username'] ?? 'Unknown';
    final fullName = '$firstName $lastName'.trim();

    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.brown.shade800.withOpacity(0.3),
            Colors.brown.shade900.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.brown.shade600.withOpacity(0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade600.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.18,
            height: MediaQuery.of(context).size.width * 0.18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.brown.shade600, Colors.brown.shade800],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.shade600.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _userDetails?['profileImageUrl'] != null
                ? CircleAvatar(
                    radius: MediaQuery.of(context).size.width * 0.09,
                    backgroundImage: NetworkImage(_userDetails!['profileImageUrl']),
                    backgroundColor: Colors.transparent,
                  )
                : Center(
                    child: Text(
                      username.substring(0, 1).toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: MediaQuery.of(context).size.width * 0.055,
                      ),
                    ),
                  ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * 0.05),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: MediaQuery.of(context).size.width * 0.045,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                if (fullName.isNotEmpty || !_isLoadingUser)
                  _isLoadingUser
                    ? Shimmer.fromColors(
                        baseColor: Colors.brown.shade800.withOpacity(0.3),
                        highlightColor: Colors.brown.shade600.withOpacity(0.5),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.02,
                          width: MediaQuery.of(context).size.width * 0.25,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )
                    : Text(
                        fullName,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ],
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * 0.03),
          Column(
            children: [
              if (_userDetails?['branch']?.toString().isNotEmpty == true)
                Container(
                  margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.005),
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.02,
                    vertical: MediaQuery.of(context).size.height * 0.005,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.brown.shade700, Colors.brown.shade800],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.school, 
                        color: Colors.white, 
                        size: MediaQuery.of(context).size.width * 0.03
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                      Text(
                        _userDetails!['branch'].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.025,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_userDetails?['year']?.toString().isNotEmpty == true)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.02,
                    vertical: MediaQuery.of(context).size.height * 0.005,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.brown.shade600, Colors.brown.shade700],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today, 
                        color: Colors.white, 
                        size: MediaQuery.of(context).size.width * 0.03
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                      Text(
                        '${_userDetails!['year']}',
                        style: GoogleFonts.poppins(
                          fontSize: MediaQuery.of(context).size.width * 0.025,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactInfoCard() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
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
                child: Icon(
                  Icons.contact_mail, 
                  color: Colors.white, 
                  size: MediaQuery.of(context).size.width * 0.05
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.04),
              Text(
                'Contact Options',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.025),
          
          // WhatsApp Button
          if (_userDetails?['userPhone'] != null && _userDetails!['userPhone'].toString().isNotEmpty)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.02),
              child: ElevatedButton(
                onPressed: () => _sendWhatsAppMessage(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF25D366), Color(0xFF1EA952)], // WhatsApp green
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: const Color(0xFF25D366).withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 0),
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.of(context).size.height * 0.022,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.008),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.chat_bubble,
                            color: Colors.white,
                            size: MediaQuery.of(context).size.width * 0.055,
                          ),
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                        Text(
                          'Send WhatsApp Message',
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.035,
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

          // Email Button
          if (_userDetails?['userEmail'] != null && _userDetails!['userEmail'].toString().isNotEmpty)
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _launchEmail(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade600.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.blue.shade600.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 0),
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.of(context).size.height * 0.022,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.email,
                          color: Colors.white,
                          size: MediaQuery.of(context).size.width * 0.055,
                        ),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                        Text(
                          'Send Email',
                          style: GoogleFonts.poppins(
                            fontSize: MediaQuery.of(context).size.width * 0.035,
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

          // No contact info available message
          if ((_userDetails?['userPhone'] == null || _userDetails!['userPhone'].toString().isEmpty) &&
              (_userDetails?['userEmail'] == null || _userDetails!['userEmail'].toString().isEmpty))
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.shade800.withOpacity(0.2),
                    Colors.orange.shade900.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.orange.shade700.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.shade600, Colors.orange.shade800],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.warning_outlined, 
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
                          'Contact Info Unavailable',
                          style: GoogleFonts.poppins(
                            color: Colors.orange.shade300,
                            fontSize: MediaQuery.of(context).size.width * 0.035,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                        Text(
                          'This user hasn\'t provided contact information yet.',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: MediaQuery.of(context).size.width * 0.03,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemDetailsCard(DateTime createdAt) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
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
                child: Icon(
                  Icons.description, 
                  color: Colors.white, 
                  size: MediaQuery.of(context).size.width * 0.05
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.04),
              Text(
                'Item Details',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.025),
          
          // Title - Full width
          _buildDetailSection(
            'Item:',
            widget.item['title'] ?? '',
            Colors.brown.shade400,
          ),
          
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          // Description - Full width
          _buildDetailSection(
            'Description:',
            widget.item['description'] ?? '',
            Colors.brown.shade300,
          ),
          
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          // Location and Date Row - Perfectly aligned
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.brown.shade700.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.brown.shade400,
                            size: MediaQuery.of(context).size.width * 0.045,
                          ),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.015),
                          Text(
                            'Location',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: MediaQuery.of(context).size.width * 0.03,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                      Text(
                        widget.item['location'] ?? 'Not specified',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.03),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.brown.shade700.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.brown.shade400,
                            size: MediaQuery.of(context).size.width * 0.045,
                          ),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.015),
                          Text(
                            'Posted',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: MediaQuery.of(context).size.width * 0.03,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                      Text(
                        '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Photo if available - Clickable for full view
          if (widget.item['photoUrl'] != null) ...[
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            GestureDetector(
              onTap: () => _showImageDialog(widget.item['photoUrl']),
              child: Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.25,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.brown.shade700.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Image.network(
                        widget.item['photoUrl'],
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.brown.shade900.withOpacity(0.2),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    color: Colors.brown.shade400,
                                    size: MediaQuery.of(context).size.width * 0.12,
                                  ),
                                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                                  Text(
                                    'Image not available',
                                    style: GoogleFonts.poppins(
                                      color: Colors.brown.shade400,
                                      fontSize: MediaQuery.of(context).size.width * 0.035,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Tap indicator overlay
                      Positioned(
                        top: MediaQuery.of(context).size.width * 0.02,
                        right: MediaQuery.of(context).size.width * 0.02,
                        child: Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: MediaQuery.of(context).size.width * 0.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.brown.shade900.withOpacity(0.2),
            Colors.brown.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.brown.shade700.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.brown.shade600, Colors.brown.shade800],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.info_outline, 
              color: Colors.white, 
              size: MediaQuery.of(context).size.width * 0.05
            ),
          ),
          SizedBox(width: MediaQuery.of(context).size.width * 0.04),
          Expanded(
            child: Text(
              'Contact ${widget.item['firstName']} to coordinate about this ${widget.item['type']} item.',
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: MediaQuery.of(context).size.width * 0.035,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, String content, Color color) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: MediaQuery.of(context).size.width * 0.035,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
          Text(
            content,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: MediaQuery.of(context).size.width * 0.035,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  
  }
}