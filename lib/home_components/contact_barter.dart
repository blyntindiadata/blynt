import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactBarterPage extends StatefulWidget {
  final Map<String, dynamic> barter;
  final String communityId;

  const ContactBarterPage({
    Key? key,
    required this.barter,
    required this.communityId
  }) : super(key: key);

  @override
  State<ContactBarterPage> createState() => _ContactBarterPageState();
}

class _ContactBarterPageState extends State<ContactBarterPage> with TickerProviderStateMixin {

  Map<String, dynamic>? _userDetails;
  bool _isLoadingUser = true;
  final ValueNotifier<bool> _isLoadingUserData = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    try {
      DocumentSnapshot? userDoc;
      
      // Check trio collection first
      final trioQuery = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('trio')
          .where('username', isEqualTo: widget.barter['username'])
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
            .where('username', isEqualTo: widget.barter['username'])
            .limit(1)
            .get();
        
        if (membersQuery.docs.isNotEmpty) {
          userDoc = membersQuery.docs.first;
        }
      }
      
      if (userDoc != null && userDoc.exists) {
        setState(() {
          _userDetails = {
            ...userDoc!.data() as Map<String, dynamic>,
            'branch': (userDoc.data() as Map<String, dynamic>)['branch'] ?? '',
            'year': (userDoc.data() as Map<String, dynamic>)['year'] ?? '',
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

    final firstName = _userDetails?['firstName'] ?? widget.barter['firstName'] ?? '';
    final lastName = _userDetails?['lastName'] ?? widget.barter['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    final message = Uri.encodeComponent(
      'Hey ${fullName.isNotEmpty ? firstName : widget.barter['username']},\n\n'
      'I saw your barter request on blynt and I\'m interested in helping out!\n\n'
      'You requested for: ${widget.barter['request']}\n\n'
      'Let\'s discuss the details.\n'
      'Regards'
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

    final firstName = _userDetails?['firstName'] ?? widget.barter['firstName'] ?? '';
    final lastName = _userDetails?['lastName'] ?? widget.barter['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();

    final subject = 'Regarding your barter request';
    final body = 'Hey ${fullName.isNotEmpty ? firstName : widget.barter['username']},\n\n'
      'I saw your barter request on blynt and I\'m interested in helping out!\n\n'
      'You requested for: ${widget.barter['request']}\n\n'
      'Let\'s discuss the details.\n'
      'Regards';
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
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deadline = widget.barter['deadline'] != null 
        ? (widget.barter['deadline'] as Timestamp).toDate() 
        : DateTime.now().add(const Duration(days: 30));
    final daysLeft = deadline.difference(DateTime.now()).inDays;

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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserInfoCard(),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                      _buildContactInfoCard(),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                      _buildBarterDetailsCard(deadline, daysLeft),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                      // _buildContactActionsCard(),
                      // SizedBox(height: MediaQuery.of(context).size.height * 0.025),
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
      //       Colors.green.shade900.withOpacity(0.3),
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
                    colors: [Colors.green.shade400, Colors.green.shade700],
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
                  'reach out & collaborate',
                  style: GoogleFonts.poppins(
                    fontSize: MediaQuery.of(context).size.width * 0.028,
                    color: Colors.green.shade200,
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
    final firstName = _userDetails?['firstName'] ?? widget.barter['firstName'] ?? '';
    final lastName = _userDetails?['lastName'] ?? widget.barter['lastName'] ?? '';
    final username = widget.barter['username'] ?? 'Unknown';
    final fullName = '$firstName $lastName'.trim();

    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
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
                colors: [Colors.green.shade600, Colors.green.shade800],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.shade600.withOpacity(0.4),
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
                        baseColor: Colors.green.shade800.withOpacity(0.3),
                        highlightColor: Colors.green.shade600.withOpacity(0.5),
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
                      colors: [Colors.green.shade700, Colors.green.shade800],
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
                      colors: [Colors.green.shade600, Colors.green.shade700],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      // Subtle glow effect
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
                        // WhatsApp Icon using a simple alternative
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
                      // Subtle glow effect
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
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    final firstName = _userDetails?['firstName'] ?? widget.barter['firstName'] ?? '';
    final displayName = firstName.isNotEmpty ? firstName : widget.barter['username'] ?? 'this user';

    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.2),
            Colors.green.shade800.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.shade700.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade800],
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
              'Choose your preferred method to contact $displayName about their barter request.',
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

  Widget _buildContactRow(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
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
            color: onTap != null 
                ? Colors.green.shade600.withOpacity(0.4)
                : Colors.green.shade700.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: onTap != null
                      ? [Colors.green.shade600, Colors.green.shade800]
                      : [Colors.grey.shade600, Colors.grey.shade800],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon, 
                color: Colors.white, 
                size: MediaQuery.of(context).size.width * 0.045
              ),
            ),
            SizedBox(width: MediaQuery.of(context).size.width * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: MediaQuery.of(context).size.width * 0.03,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.003),
                  _isLoadingUser
                    ? Shimmer.fromColors(
                        baseColor: Colors.green.shade800.withOpacity(0.3),
                        highlightColor: Colors.green.shade600.withOpacity(0.5),
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.02,
                          width: MediaQuery.of(context).size.width * 0.3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: GoogleFonts.poppins(
                          color: onTap != null ? Colors.green.shade300 : Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                ],
              ),
            ),
            if (onTap != null && !_isLoadingUser)
              Icon(
                Icons.launch,
                color: Colors.green.shade400,
                size: MediaQuery.of(context).size.width * 0.045,
              ),
          ],
        ),
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

  Widget _buildBarterDetailsCard(DateTime deadline, int daysLeft) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.06),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  Icons.description, 
                  color: Colors.white, 
                  size: MediaQuery.of(context).size.width * 0.05
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.04),
              Text(
                'Barter Details',
                style: GoogleFonts.poppins(
                  fontSize: MediaQuery.of(context).size.width * 0.04,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.025),
          
          // Request - Full width
          _buildDetailSection(
            'What they need:',
            widget.barter['request'] ?? '',
            Colors.green.shade400,
          ),
          
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          // Offer - Full width
          _buildDetailSection(
            'What they offer:',
            widget.barter['offerType'] == 'money'
                ? '₹${widget.barter['moneyAmount']?.toString() ?? '0'}'
                : widget.barter['serviceOffer'] ?? '',
            Colors.amber.shade400,
          ),
          
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          
          // Deadline
          Container(
            width: double.infinity,
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
                color: daysLeft <= 2 
                    ? Colors.red.shade500.withOpacity(0.5)
                    : Colors.green.shade700.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule,
                  color: daysLeft <= 2 ? Colors.red.shade400 : Colors.green.shade400,
                  size: MediaQuery.of(context).size.width * 0.06,
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deadline',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.002),
                      Text(
                        '${deadline.day}/${deadline.month}/${deadline.year}',
                        style: GoogleFonts.poppins(
                          color: daysLeft <= 2 ? Colors.red.shade400 : Colors.white,
                          fontSize: MediaQuery.of(context).size.width * 0.04,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.03,
                    vertical: MediaQuery.of(context).size.height * 0.008,
                  ),
                  decoration: BoxDecoration(
                    color: daysLeft <= 2 
                        ? Colors.red.shade500.withOpacity(0.2)
                        : Colors.green.shade500.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$daysLeft days left',
                    style: GoogleFonts.poppins(
                      color: daysLeft <= 2 ? Colors.red.shade300 : Colors.green.shade300,
                      fontSize: MediaQuery.of(context).size.width * 0.03,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  }
