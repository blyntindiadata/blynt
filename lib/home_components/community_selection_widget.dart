import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'community_list_page.dart';

class CommunitySelectionWidget extends StatelessWidget {
  final String userId;
  final String username;
  final VoidCallback onCommunityJoined;

  const CommunitySelectionWidget({
    super.key,
    required this.userId,
    required this.username,
    required this.onCommunityJoined,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isSmallScreen = screenSize.height < 700;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Community Icon
          Container(
            padding: EdgeInsets.all(isTablet ? 28 : isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF7B42C).withOpacity(0.3),
                  blurRadius: isTablet ? 25 : 20,
                  spreadRadius: isTablet ? 3 : 2,
                ),
              ],
            ),
            child: Icon(
              Icons.groups,
              size: isTablet ? 64 : isSmallScreen ? 40 : 50,
              color: Colors.black87,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 20 : 30),
          
          // Title
          Text(
            'Join Your Community',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 34 : isSmallScreen ? 24 : 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isSmallScreen ? 10 : 15),
          
          // Subtitle
          Text(
            'Connect with your college community\nand discover amazing experiences together',
            style: GoogleFonts.poppins(
              fontSize: isTablet ? 18 : isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w400,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isSmallScreen ? 30 : 50),
          
          // Join Community Button - Styled like create group button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CommunityListPage(
                      userId: userId,
                      username: username,
                      onCommunityJoined: onCommunityJoined,
                    ),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 18 : isSmallScreen ? 14 : 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFB77200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amberAccent.withOpacity(0.6),
                      blurRadius: 18,
                      spreadRadius: 1,
                      offset: const Offset(0, 0),
                    ),
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.2),
                      blurRadius: 4,
                      spreadRadius: 1,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_add,
                      color: Colors.black87,
                      size: isTablet ? 28 : isSmallScreen ? 20 : 24,
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF101010), Color(0xFF222222)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      blendMode: BlendMode.srcIn,
                      child: Text(
                        'JOIN COMMUNITY',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 16 : isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 15 : 20),
          
          // Info Cards
          Container(
            padding: EdgeInsets.all(isTablet ? 24 : isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7B42C).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: const Color(0xFFF7B42C),
                        size: isTablet ? 24 : isSmallScreen ? 18 : 20,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Expanded(
                      child: Text(
                        'One Community Per Person',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 16 : isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  'You can only be part of one community at a time. Choose your college community to connect with fellow students.',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 15 : isSmallScreen ? 11 : 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                    height: 1.4,
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