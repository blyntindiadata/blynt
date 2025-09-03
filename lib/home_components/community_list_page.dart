import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'join_request_page.dart';

class CommunityListPage extends StatefulWidget {
  final String userId;
  final String username;
  final VoidCallback onCommunityJoined;

  const CommunityListPage({
    super.key,
    required this.userId,
    required this.username,
    required this.onCommunityJoined,
  });

  @override
  State<CommunityListPage> createState() => _CommunityListPageState();
}

class _CommunityListPageState extends State<CommunityListPage> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
final screenWidth = screenSize.width;
final screenHeight = screenSize.height;
final isTablet = screenWidth > 768;
final isLargePhone = screenWidth > 414;
final isSmallScreen = screenHeight < 700;
final horizontalPadding = isTablet ? 32.0 : (isLargePhone ? 20.0 : 16.0);
final verticalPadding = isTablet ? 24.0 : (isSmallScreen ? 16.0 : 20.0);
    
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
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
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
                          Icons.arrow_back_ios_new,
                          color: const Color(0xFFF7B42C),
                          size: isTablet ? 24 : 20,
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
                'browse communities',
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 28 : 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
                    ),
                  ],
                ),
              ),

              // Search Bar
            // Search Bar - matching Home.dart style
Padding(
    padding: EdgeInsets.symmetric(horizontal: horizontalPadding),

  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.white.withOpacity(0.1),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFF7B42C).withOpacity(0.1),
          blurRadius: 16,
          spreadRadius: 1,
        ),
      ],
    ),
    child: TextField(
      controller: _searchController,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontWeight: FontWeight.w500,
        fontSize: isTablet ? 18 : 16,
      ),
      cursorColor: const Color(0xFFF7B42C),
      onChanged: (value) {
        setState(() {
          searchQuery = value.toLowerCase();
        });
      },
      decoration: InputDecoration(
        border: InputBorder.none,
        prefixIcon: Icon(
          Icons.search_rounded,
          color: const Color(0xFFF7B42C),
          size: isTablet ? 24 : 20,
        ),
        hintText: 'search communities',
        hintStyle: GoogleFonts.poppins(
          color: Colors.white70,
          fontSize: isTablet ? 18 : 16,
          fontWeight: FontWeight.w400,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: isTablet ? 16 : 12,
        ),
      ),
    ),
  ),
),
              const SizedBox(height: 20),

              // Communities List
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('communities')
                      .where('isActive', isEqualTo: true)
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
                            Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: isTablet ? 64 : 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading communities',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isTablet ? 18 : 16,
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
                            Icon(
                              Icons.groups_outlined,
                              color: Colors.white60,
                              size: isTablet ? 80 : 64,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'No Communities Available',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 24 : 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to create a community!',
                              style: GoogleFonts.poppins(
                                fontSize: isTablet ? 16 : 14,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Filter communities
                    final filteredDocs = snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = (data['name'] ?? '').toString().toLowerCase();
                      final description = (data['description'] ?? '').toString().toLowerCase();
                      return searchQuery.isEmpty ||
                          name.contains(searchQuery) ||
                          description.contains(searchQuery);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              color: Colors.white60,
                              size: isTablet ? 64 : 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No communities found',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: isTablet ? 18 : 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Use ListView for all devices - simpler and more reliable
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        return CommunityCard(
                          key: ValueKey(doc.id),
                          communityId: doc.id,
                          name: data['name'] ?? '',
                          description: data['description'] ?? '',
                          memberCount: data['memberCount'] ?? 0,
                          coverImage: data['coverImage'],
                            createdAt: data['createdAt'] as Timestamp?, 
                          userId: widget.userId,
                          username: widget.username,
                          isTablet: isTablet,
                          isSmallScreen: isSmallScreen,
                          onJoinPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => JoinRequestPage(
                                  communityId: doc.id,
                                  communityName: data['name'] ?? '',
                                  userId: widget.userId,
                                  username: widget.username,
                                  onRequestSubmitted: () {
                                    Navigator.pop(context);
                                    Navigator.pop(context);
                                    widget.onCommunityJoined();
                                  },
                                ),
                              ),
                            );
                          },
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

// Simplified CommunityCard
class CommunityCard extends StatelessWidget {
  final String communityId;
  final String name;
  final String description;
  final int memberCount;
  final String? coverImage;
  final String userId;
  final String username;
  final bool isTablet;
  final bool isSmallScreen;
  final VoidCallback onJoinPressed;
  final Timestamp? createdAt;

  const CommunityCard({
    super.key,
    required this.communityId,
    required this.name,
    required this.description,
    required this.memberCount,
    this.coverImage,
    required this.userId,
    required this.username,
    required this.isTablet,
    required this.isSmallScreen,
    required this.onJoinPressed,
    this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargePhone = screenWidth > 414;
    final cardPadding = isTablet ? 24.0 : (isLargePhone ? 20.0 : 18.0);
    
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 24 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with community info
            Row(
              children: [
                // Community icon with gradient background
                Container(
                  width: isTablet ? 56 : (isLargePhone ? 48 : 44),
                  height: isTablet ? 56 : (isLargePhone ? 48 : 44),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFF7B42C),
                        const Color(0xFFFFD700),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF7B42C).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    size: isTablet ? 28 : (isLargePhone ? 24 : 22),
                    color: Colors.black87,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Community name and status
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 22 : (isLargePhone ? 20 : 18),
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active Community',
                            style: GoogleFonts.poppins(
                              fontSize: isTablet ? 12 : (isLargePhone ? 11 : 10),
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade300,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Member count badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 14 : (isLargePhone ? 12 : 10),
                    vertical: isTablet ? 8 : 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF7B42C), Color(0xFFFFD700)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF7B42C).withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: isTablet ? 18 : (isLargePhone ? 16 : 14),
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$memberCount',
                        style: GoogleFonts.poppins(
                          fontSize: isTablet ? 14 : (isLargePhone ? 13 : 12),
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 16 : 14),
            
            // Description with better styling
            Container(
              width: double.infinity, // Add this line
  height: isTablet ? 80 : (isLargePhone ? 70 : 60),
              padding: EdgeInsets.all(isTablet ? 16 : 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
              ),
            

            child: Align( // Add this wrapper
    alignment: Alignment.topLeft,
              child: Text(
                description,
                style: GoogleFonts.poppins(
                  fontSize: isTablet ? 16 : (isLargePhone ? 15 : 14),
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  height: 1.5,
                ),
                maxLines: isTablet ? 4 : 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ),
            
            SizedBox(height: isTablet ? 18 : 16),
            
            // Community stats row
            Row(
              children: [
               _buildStatItem(
  Icons.calendar_today_rounded,
  'est. ${_formatCreationDate(createdAt)}',
  isTablet,
  isLargePhone,
),
                const SizedBox(width: 16),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 10 : 8,
                    vertical: isTablet ? 4 : 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7B42C).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Open to Join',
                    style: GoogleFonts.poppins(
                      fontSize: isTablet ? 11 : (isLargePhone ? 10 : 9),
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF7B42C),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 20 : 18),
            
            // Join Button with enhanced styling
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: onJoinPressed,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : (isLargePhone ? 14 : 12),
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFB77200)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amberAccent.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.2),
                        blurRadius: 4,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login_rounded,
                        color: Colors.black87,
                        size: isTablet ? 22 : (isLargePhone ? 20 : 18),
                      ),
                      const SizedBox(width: 10),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF101010), Color(0xFF333333)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        blendMode: BlendMode.srcIn,
                        child: Text(
                          'JOIN COMMUNITY',
                          style: GoogleFonts.poppins(
                            fontSize: isTablet ? 14 : (isLargePhone ? 13 : 12),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
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
    );
  }

  Widget _buildStatItem(IconData icon, String text, bool isTablet, bool isLargePhone) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isTablet ? 16 : (isLargePhone ? 14 : 13),
          color: const Color(0xFFF7B42C).withOpacity(0.8),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: isTablet ? 12 : (isLargePhone ? 11 : 10),
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
String _formatCreationDate(Timestamp? timestamp) {
  if (timestamp == null) return 'Unknown';
  
  final date = timestamp.toDate();
  final now = DateTime.now();
  final difference = now.difference(date);
  
  if (difference.inDays < 30) {
    return '${difference.inDays} days ago';
  } else if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return '$months month${months == 1 ? '' : 's'} ago';
  } else {
    final years = (difference.inDays / 365).floor();
    return '$years year${years == 1 ? '' : 's'} ago';
  }
}