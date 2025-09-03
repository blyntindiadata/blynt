import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup/home_components/notification_service.dart';
import 'package:startup/home_components/user_profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatefulWidget {
  final String userId;
  final String communityId;

  const NotificationsScreen({
    super.key, 
    required this.userId,
    required this.communityId,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // Enhanced zone color mappings
  final Map<String, Map<String, dynamic>> zoneConfigs = {
    'confessions': {
      'name': 'the confession vault',
      'desc': 'we know you cannot face that baddie',
      'colors': [Color(0xFF8B5CF6), Color(0xFFA855F7)],
      'icon': Icons.lock_outline,
      'gradient': LinearGradient(
        colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'shit_i_wish': {
      'name': 'shit i wish i knew',
      'desc': 'do not make the mistake that your parents did',
      'colors': [Color(0xFFF59E0B), Color(0xFFD97706)],
      'icon': Icons.lightbulb_outline,
      'gradient': LinearGradient(
        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'no_limits': {
      'name': 'no limits',
      'desc': 'show your college who is the goat',
      'colors': [Color(0xFFEF4444), Color(0xFFDC2626)],
      'icon': Icons.all_inclusive,
      'gradient': LinearGradient(
        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'doubts': {
      'name': 'doubts',
      'desc': 'we know this is kinda useless',
      'colors': [Color(0xFF4A4A4A), Color(0xFF2C2C2C)],
      'icon': Icons.construction,
      'gradient': LinearGradient(
        colors: [Color(0xFF4A4A4A), Color(0xFF2C2C2C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'chat': {
      'name': 'anonymous chatting',
      'desc': 'where masks hide identities',
      'colors': [Color(0xFF3B82F6), Color(0xFF2563EB)],
      'icon': Icons.people_sharp,
      'gradient': LinearGradient(
        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'shows': {
      'name': 'gaming arena',
      'desc': 'level up your game',
      'colors': [Color(0xFFE91E63), Color(0xFF8B2635)],
      'icon': Icons.theater_comedy,
      'gradient': LinearGradient(
        colors: [Color(0xFFE91E63), Color(0xFF8B2635)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'lost': {
      'name': 'lost it',
      'desc': 'find what you have lost',
      'colors': [Color.fromARGB(255, 102, 75, 63), Color.fromARGB(255, 103, 62, 44)],
      'icon': Icons.search_off,
      'gradient': LinearGradient(
        colors: [Color.fromARGB(255, 102, 75, 63), Color.fromARGB(255, 103, 62, 44)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'barter': {
      'name': 'barter? hell yeah',
      'desc': 'trade your way to success',
      'colors': [Color(0xFF10B981), Color(0xFF059669)],
      'icon': Icons.swap_horiz,
      'gradient': LinearGradient(
        colors: [Color(0xFF10B981), Color(0xFF059669)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'polls': {
      'name': 'the polls',
      'desc': 'democracy in action',
      'colors': [Color(0xFF1976D2), Color(0xFF64B5F6)],
      'icon': Icons.poll_sharp,
      'gradient': LinearGradient(
        colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'neighbourhood': {
      'name': 'your neighbourhood',
      'desc': 'community connections',
      'colors': [Color(0xFF84CC16), Color(0xFF65A30D)],
      'icon': Icons.location_on_outlined,
      'gradient': LinearGradient(
        colors: [Color(0xFF84CC16), Color(0xFF65A30D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
    'committees': {
      'name': 'committees',
      'desc': 'organized excellence',
      'colors': [Color(0xFF0EA5E9), Color(0xFF0284C7)],
      'icon': Icons.groups_outlined,
      'gradient': LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    },
  };

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _markAllAsRead();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _shimmerAnimation = CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    );
    
    _animationController.forward();
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead(widget.userId);
  }

  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  Future<void> _clearAllNotifications() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          title: Text(
            'Clear All Notifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          content: Text(
            'Are you sure you want to delete all notifications? This action cannot be undone.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.white60,
                  fontSize: 13,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Clear All',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await NotificationService.clearAll(widget.userId);
        if (mounted) {
          _showSuccessMessage('All notifications cleared');
        }
      } catch (e) {
        if (mounted) {
          _showErrorMessage('Failed to clear notifications');
        }
      }
    }
  }

  Map<String, dynamic> _getZoneConfig(String? zone, String? type) {
    // First try to match by zone
    if (zone != null && zoneConfigs.containsKey(zone)) {
      return zoneConfigs[zone]!;
    }
    
    // Then try to match by type
    if (type != null && zoneConfigs.containsKey(type)) {
      return zoneConfigs[type]!;
    }
    
    // Fallback for specific notification types
    switch (type) {
      case 'birthday_wish':
        return {
          'name': 'birthday wishes',
          'colors': [Color(0xFF9B5DE5), Color(0xFF7C3AED)],
          'icon': Icons.cake,
          'gradient': LinearGradient(
            colors: [Color(0xFF9B5DE5), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };
      case 'confession_comment':
        return {
          'name': 'confession comment',
          'colors': [Color(0xFF8B5CF6), Color(0xFFA855F7)],
          'icon': Icons.lock_outline,
          'gradient': LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };
      case 'confession_like':
        return {
          'name': 'confession liked',
          'colors': [Color(0xFF8B5CF6), Color(0xFFA855F7)],
          'icon': Icons.lock_outline,
          'gradient': LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };
        case 'meme_reaction':
        return {
          'name': 'reaction on meme',
          'colors': [Color(0xFFEF4444), Color(0xFFDC2626)],
          'icon': Icons.all_inclusive,
          'gradient': LinearGradient(
            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };
        case 'doubt_answer':
        return {
          'name': 'potential answer',
          'colors': [const Color(0xFF4A4A4A), const Color(0xFF2C2C2C)],
          'icon': Icons.construction,
          'gradient': LinearGradient(
            colors: [const Color(0xFF4A4A4A), const Color(0xFF2C2C2C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };

        case 'post_comment':
        return {
          'name': 'someone commented',
          'colors': [Color(0xFFF59E0B), Color(0xFFD97706)],
          'icon': Icons.lightbulb_outline,
          'gradient': LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };

        case 'comment_reply':
        return {
          'name': 'reply to comment',
          'colors': [Color(0xFFF59E0B), Color(0xFFD97706)],
          'icon': Icons.lightbulb_outline,
          'gradient': LinearGradient(
            colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };

        case 'identity_reveal_request':
        return {
          'name': 'the crazy part',
          'colors': [Color(0xFF8B5CF6), Color(0xFFA855F7)],
          'icon': Icons.lock_outline,
          'gradient': LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };
        
        
      default:
        return {
          'name': 'notification',
          'colors': [Color(0xFFF7B42C), Color(0xFFD97706)],
          'icon': Icons.notifications,
          'gradient': LinearGradient(
            colors: [Color(0xFFF7B42C), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        };
    }
  }

  Widget _buildShimmerCard() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.02),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment(-1.0, -0.3),
                end: Alignment(1.0, 0.3),
                colors: const [
                  Colors.transparent,
                  Colors.white24,
                  Colors.transparent,
                ],
                stops: [
                  _shimmerAnimation.value - 0.3,
                  _shimmerAnimation.value,
                  _shimmerAnimation.value + 0.3,
                ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 12,
                        width: MediaQuery.of(context).size.width * 0.7,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 10,
                        width: MediaQuery.of(context).size.width * 0.4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToUserProfile(String? senderName) {
    if (senderName != null && senderName.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            username: senderName,
            communityId: widget.communityId,
          ),
        ),
      );
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height * 0.1,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final horizontalPadding = isTablet ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A2E).withOpacity(0.9),
              const Color(0xFF16213E).withOpacity(0.7),
              const Color(0xFF0F0F23).withOpacity(0.5),
              Colors.black,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Enhanced Header
                _buildHeader(isTablet, horizontalPadding),

                // Notifications List
                Expanded(
                  child: _buildNotificationsList(isTablet, horizontalPadding),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet, double horizontalPadding) {
    return Padding(
      padding: EdgeInsets.all(horizontalPadding),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(isTablet ? 12 : 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFF7B42C).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: const Color(0xFFF7B42C),
                size: isTablet ? 24 : 20,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFF9B233), Color(0xFFFF8008), Color(0xFFB95E00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: Text(
                  'notifications',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 26 : 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: _clearAllNotifications,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 10 : 8,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.red, Color(0xFFDC2626)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Clear All',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isTablet ? 13 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isTablet, double horizontalPadding) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('notifications')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            itemCount: 6,
            itemBuilder: (context, index) => _buildShimmerCard(),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Text(
                    'Error loading notifications',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data?.docs ?? [];

        // Manual sorting by timestamp
        notifications.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['timestamp'] as Timestamp?;
          final bTime = bData['timestamp'] as Timestamp?;
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          return bTime.compareTo(aTime);
        });

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF7B42C).withOpacity(0.2),
                        const Color(0xFFD97706).withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_off_outlined,
                    size: 56,
                    color: Color(0xFFF7B42C),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Notifications Yet',
                  style: GoogleFonts.poppins(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Text(
                    'Updates from zones and community activities will appear here',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white60,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
          physics: const BouncingScrollPhysics(),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            final data = notification.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final isUnread = !(data['read'] ?? false);

            return Dismissible(
              key: Key(notification.id),
              direction: DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Color(0xFFDC2626)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onDismissed: (direction) {
                _deleteNotification(notification.id);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: _buildNotificationCard(data, timestamp, isUnread, isTablet),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(
    Map<String, dynamic> data,
    Timestamp? timestamp,
    bool isUnread,
    bool isTablet,
  ) {
    final type = data['type'] ?? '';
    final zone = data['zone'] ?? '';
    final title = data['title'] ?? '';
    final message = data['message'] ?? '';
    final senderName = data['senderName'] ?? '';
    
    final zoneConfig = _getZoneConfig(zone, type);
    final colors = zoneConfig['colors'] as List<Color>;
    final icon = zoneConfig['icon'] as IconData;
    final zoneName = zoneConfig['name'] as String;
    final gradient = zoneConfig['gradient'] as LinearGradient;

    return GestureDetector(
      onTap: senderName.isNotEmpty ? () => _navigateToUserProfile(senderName) : null,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isUnread
                ? [
                    colors[0].withOpacity(0.15),
                    colors[1].withOpacity(0.10),
                    Colors.white.withOpacity(0.06),
                  ]
                : [
                    Colors.white.withOpacity(0.06),
                    Colors.white.withOpacity(0.03),
                    Colors.transparent,
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUnread
                ? colors[0].withOpacity(0.3)
                : Colors.white.withOpacity(0.08),
            width: isUnread ? 1.5 : 0.8,
          ),
          boxShadow: isUnread ? [
            BoxShadow(
              color: colors[0].withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isTablet ? 18 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zone Icon with enhanced styling
              Container(
                padding: EdgeInsets.all(isTablet ? 12 : 10),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isTablet ? 22 : 18,
                ),
              ),
              
              SizedBox(width: isTablet ? 14 : 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title and time
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 15 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors[0].withOpacity(0.25),
                                      colors[1].withOpacity(0.15),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: colors[0].withOpacity(0.2),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  zoneName,
                                  style: GoogleFonts.poppins(
                                    fontSize: isTablet ? 9 : 8,
                                    fontWeight: FontWeight.w600,
                                    color: colors[0],
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (timestamp != null) ...[
                          SizedBox(width: isTablet ? 10 : 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                timeago.format(timestamp.toDate()),
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 10 : 9,
                                  color: Colors.white60,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isUnread) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: isTablet ? 8 : 6,
                                  height: isTablet ? 8 : 6,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: colors),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors[0].withOpacity(0.5),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                    
                    SizedBox(height: isTablet ? 8 : 6),
                    
                    // Message
                    Text(
                      message,
                      style: GoogleFonts.poppins(
                        fontSize: isTablet ? 13 : 12,
                        color: Colors.white70,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    
                    // Sender info with click functionality
                    if (senderName.isNotEmpty) ...[
                      SizedBox(height: isTablet ? 6 : 4),
                      GestureDetector(
                        onTap: () => _navigateToUserProfile(senderName),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors[0].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors[0].withOpacity(0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: isTablet ? 14 : 12,
                                color: colors[0].withOpacity(0.9),
                              ),
                              SizedBox(width: isTablet ? 4 : 3),
                              Text(
                                '@$senderName',
                                style: GoogleFonts.poppins(
                                  fontSize: isTablet ? 11 : 10,
                                  color: colors[0].withOpacity(0.95),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: isTablet ? 10 : 8,
                                color: colors[0].withOpacity(0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}