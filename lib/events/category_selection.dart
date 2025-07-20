import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/events/host_eventform.dart';

class HostCategoryScreen extends StatefulWidget {
  final String ?category;
  final String uid;
  final String username;
  final String firstName;
  final String lastName;

  const HostCategoryScreen({super.key,
    this.category,
    required this.uid,
    required this.username,
    required this.firstName,
    required this.lastName,});
  @override
  _HostCategoryScreenState createState() => _HostCategoryScreenState();
}

class _HostCategoryScreenState extends State<HostCategoryScreen> with TickerProviderStateMixin {
  final List<Map<String, dynamic>> categories = [
    
    {
      "title": "Individual",
      "icon": Icons.person_outline_rounded,
      "description": "Personal achievements and showcases",
    },
    {
      "title": "Music",
      "icon": Icons.music_note,
      "description": "Musical performances and concerts",
    },
    {
      "title": "College",
      "icon": Icons.school_outlined,
      "description": "Academic events and seminars",
    },
    {
      "title": "Festival",
      "icon": Icons.celebration_outlined,
      "description": "Cultural celebrations and gatherings",
    },
    {
      "title": "Workshops",
      "icon": Icons.sports_soccer,
      "description": "Athletic competitions and tournaments",
    },
  ];

  // Colors
  static const Color primaryGold = Color(0xFFFFB000);
  static const Color bronzeLight = Color(0xFFCD7F32);
  static const Color amberDeep = Color(0xFFD2691E);
  static const Color goldLight = Color(0xFFFFD700);
  static const Color darkBackground = Color(0xFF0A0A0A);
  static const Color cardBackground = Color(0xFF1C1C1E);
  static const Color selectedCardBackground = Color(0xFF2A2A2C);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFBBBBBB);
  static const Color borderColor = Color(0xFF333333);

  int selectedIndex = -1;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [primaryGold, goldLight, bronzeLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: Text(
              "Create Your Event",
              style: GoogleFonts.poppins(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryGold, goldLight, bronzeLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "Choose the category that best fits your event.",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(int index) {
    final category = categories[index];
    final bool isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });

        Future.delayed(const Duration(milliseconds: 200), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HostEventFormScreen(category: category['title'], uid: widget.uid, username: widget.username, firstName: widget.firstName,lastName: widget.lastName,),
            ),
          );
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isSelected
                ? [selectedCardBackground, Color(0xFF383838)]
                : [cardBackground, Color(0xFF262628)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryGold : borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? primaryGold.withOpacity(0.25)
                  : Colors.black.withOpacity(0.3),
              blurRadius: isSelected ? 16 : 8,
              offset: Offset(0, isSelected ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryGold.withOpacity(0.15),
                    goldLight.withOpacity(0.12),
                    bronzeLight.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                category['icon'],
                size: 28,
                color: isSelected ? Colors.white : primaryGold,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category['title'],
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? primaryGold : textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category['description'],
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.arrow_forward_ios,
              color: isSelected ? Colors.white : textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [primaryGold, goldLight, bronzeLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Text(
            "Host Event",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: categories.length,
                itemBuilder: (_, index) => _buildCategoryCard(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
