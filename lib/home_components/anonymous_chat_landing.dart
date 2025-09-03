// screens/anonymous_chat_landing.dart - RESPONSIVE & ADAPTIVE VERSION

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/home_components/chat_history.dart';
import 'package:startup/home_components/chat_models.dart';
import 'package:startup/home_components/chat_service.dart';
import 'package:startup/home_components/live_zone.dart';
import 'package:startup/home_components/chat_screen.dart';

class AnonymousChatLanding extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const AnonymousChatLanding({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<AnonymousChatLanding> createState() => _AnonymousChatLandingState();
}

class _AnonymousChatLandingState extends State<AnonymousChatLanding> {
  final ChatService _chatService = ChatService();
  
  StreamSubscription<int>? _liveCountSubscription;
  StreamSubscription<LiveZoneUser?>? _userStatusSubscription;
  
  int _liveUsersCount = 0;
  bool _isLoading = false;
  bool _checkingActiveSession = true;

  @override
  void initState() {
    super.initState();
    _checkForActiveSession();
    _setSystemUI();
  }

  void _setSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Platform.isIOS ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: const Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  Future<void> _checkForActiveSession() async {
    try {
      final activeSession = await _chatService.getActiveSession(widget.communityId, widget.userId);
      
      if (activeSession != null) {
        // If identity is revealed or session ended, don't redirect to chat
        if (activeSession.identityRevealed || activeSession.status == 'ended') {
          // Session exists but is ended/revealed, continue to show landing page
          debugPrint('Found ended/revealed session, staying on landing page');
        } else {
          // Active session exists, redirect to chat
          final partnerId = activeSession.getPartnerId(widget.userId);
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              _createPageRoute(ChatScreen(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
                sessionId: activeSession.sessionId,
                partnerId: partnerId,
              )),
            );
            return;
          }
        }
      }

      _setupListeners();
    } catch (e) {
      debugPrint('Error checking active session: $e');
      _setupListeners();
    } finally {
      if (mounted) {
        setState(() {
          _checkingActiveSession = false;
        });
      }
    }
  }

  void _setupListeners() {
    _liveCountSubscription = _chatService.getLiveZoneCount(widget.communityId).listen(
      (count) {
        if (mounted) {
          setState(() {
            _liveUsersCount = count;
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to live count: $error');
      },
    );

    _userStatusSubscription = _chatService.listenToUserStatus(widget.communityId, widget.userId).listen(
      (userStatus) {
        if (mounted && userStatus != null) {
          if (userStatus.status == 'paired' && userStatus.sessionId != null) {
            // Only navigate if we don't already know this is an ended session
            _checkSessionBeforeNavigation(userStatus.sessionId!, userStatus.pairedWith!);
          }
        }
      },
      onError: (error) {
        debugPrint('Error listening to user status: $error');
      },
    );
  }

  Future<void> _checkSessionBeforeNavigation(String sessionId, String partnerId) async {
    try {
      final session = await _chatService.getActiveSession(widget.communityId, widget.userId);
      
      if (session != null && !session.identityRevealed && session.status == 'active') {
        Navigator.pushReplacement(
          context,
          _createPageRoute(ChatScreen(
            communityId: widget.communityId,
            userId: widget.userId,
            username: widget.username,
            sessionId: sessionId,
            partnerId: partnerId,
          )),
        );
      } else {
        debugPrint('Session is ended or identity revealed, not navigating to chat');
      }
    } catch (e) {
      debugPrint('Error validating session: $e');
    }
  }

  PageRoute _createPageRoute(Widget page) {
    if (Platform.isIOS) {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeInOut)),
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      );
    } else {
      return MaterialPageRoute(builder: (context) => page);
    }
  }

  @override
  void dispose() {
    _liveCountSubscription?.cancel();
    _userStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _goLive() async {
    if (_isLoading) return;

    // Platform-specific haptic feedback
    if (Platform.isIOS) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _chatService.joinLiveZone(widget.communityId, widget.userId, widget.username);
      
      if (mounted) {
        Navigator.push(
          context,
          _createPageRoute(LiveZoneScreen(
            communityId: widget.communityId,
            userId: widget.userId,
            username: widget.username,
          )),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('ACTIVE_SESSION_EXISTS')) {
          _showResumeSessionDialog();
        } else {
          _showErrorMessage(e.toString());
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showResumeSessionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Active Session Found',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'You have an active chat session. Would you like to resume it?',
          style: GoogleFonts.poppins(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkForActiveSession();
            },
            child: Text(
              'Resume Chat',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingActiveSession) {
      return _buildLoadingScreen();
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Platform.isIOS ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: const Color(0xFF0A0A0A),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1A1A2E),
                Color(0xFF0A0A0A),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    _buildHeader(constraints),
                    Expanded(
                      child: _buildResponsiveBody(constraints),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A2E),
              Color(0xFF0A0A0A),
              Colors.black,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF6C63FF),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Checking for active sessions...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BoxConstraints constraints) {
    final isCompact = constraints.maxHeight < 600;
    final isSmallWidth = constraints.maxWidth < 360;
    
    return Container(
      padding: EdgeInsets.all(isSmallWidth ? 12 : 16),
      child: Row(
        children: [
      GestureDetector(
  onTap: () => Navigator.pop(context),
  child: Container(
    padding: EdgeInsets.all(isSmallWidth ? 10 : 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0A0A).withOpacity(0.8),
      borderRadius: BorderRadius.circular(isSmallWidth ? 12 : 16),
      border: Border.all(
        color: const Color(0xFF6C63FF).withOpacity(0.2),
      ),
    ),
    child: Icon(
      Platform.isIOS ? Icons.arrow_back_ios_new : Icons.arrow_back,
      color: Colors.white,
      size: isSmallWidth ? 16 : 20,
    ),
  ),
),
          SizedBox(width: isSmallWidth ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                  ).createShader(bounds),
                  child: Text(
                    'anonymous chat',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: _getResponsiveFontSize(constraints, 20, 16, 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (!isCompact) ...[
                  SizedBox(height: 2),
                  Text(
                    'go live and talk to an absolutely anonymous person-completely secured',
                    style: GoogleFonts.poppins(
                      fontSize: _getResponsiveFontSize(constraints, 12, 10, 14),
                      color: const Color(0xFF6C63FF).withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.history,
              color: const Color(0xFF6C63FF),
              size: isSmallWidth ? 20 : 24,
            ),
            onPressed: () {
              Navigator.push(
                context,
                _createPageRoute(ChatHistoryScreen(
                  communityId: widget.communityId,
                  userId: widget.userId,
                )),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveBody(BoxConstraints constraints) {
    final isWideScreen = constraints.maxWidth > 800;
    final isTablet = constraints.maxWidth > 600 && constraints.maxWidth <= 800;
    
    if (isWideScreen) {
      return _buildWideScreenLayout(constraints);
    } else if (isTablet) {
      return _buildTabletLayout(constraints);
    } else {
      return _buildPhoneLayout(constraints);
    }
  }

  Widget _buildWideScreenLayout(BoxConstraints constraints) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildMainContent(constraints),
        ),
        Container(
          width: 1,
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  'Wide Screen Experience',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: 24,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Optimized layout for your larger screen with enhanced chat experience.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white60,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(BoxConstraints constraints) {
    final double maxWidth = constraints.maxWidth > 700 ? 600.0 : constraints.maxWidth * 0.9;
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
        ),
        child: _buildMainContent(constraints),
      ),
    );
  }

  Widget _buildPhoneLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        constraints: BoxConstraints(
          minHeight: constraints.maxHeight,
        ),
        child: _buildMainContent(constraints),
      ),
    );
  }

  Widget _buildMainContent(BoxConstraints constraints) {
    final isCompact = constraints.maxHeight < 600;
    final padding = _getResponsivePadding(constraints);
    
    return Container(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!isCompact) SizedBox(height: _getVerticalSpacing(constraints, 20)),
          
          // Replace: Anonymous icon with chat bubbles icon
          _buildChatIcon(constraints),

          SizedBox(height: _getVerticalSpacing(constraints, 40)),

          // Title
          Text(
            'ready to meet someone new?',
            style: GoogleFonts.poppins(
              fontSize: _getResponsiveFontSize(constraints, 28, 22, 32),
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: _getVerticalSpacing(constraints, 16)),

          // Subtitle
          Text(
            'Connect anonymously with people in your community.\nIdentities revealed only after mutual consent.',
            style: GoogleFonts.poppins(
              fontSize: _getResponsiveFontSize(constraints, 14, 12, 16),
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: _getVerticalSpacing(constraints, 40)),

          // Live users count
          _buildLiveUsersCount(constraints),

          SizedBox(height: _getVerticalSpacing(constraints, 50)),

          // Go Live button
          _buildGoLiveButton(constraints),

          SizedBox(height: _getVerticalSpacing(constraints, 30)),

          // Features list
          _buildFeaturesList(constraints),
          
          if (!isCompact) SizedBox(height: _getVerticalSpacing(constraints, 50)),
        ],
      ),
    );
  }

  // Replace: Anonymous icon with chat bubbles icon
  Widget _buildChatIcon(BoxConstraints constraints) {
    final iconSize = _getResponsiveIconSize(constraints);
    
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: iconSize * 0.8,
            height: iconSize * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.4),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Icon(
            Icons.chat_bubble_outline,
            size: iconSize * 0.5,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUsersCount(BoxConstraints constraints) {
    final fontSize = _getResponsiveFontSize(constraints, 16, 14, 18);
    final padding = _getResponsivePadding(constraints);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.75,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.2),
            const Color(0xFF9C88FF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: fontSize * 0.75,
            height: fontSize * 0.75,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4CAF50),
            ),
          ),
          SizedBox(width: padding * 0.5),
          Text(
            '$_liveUsersCount users live in the zone',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoLiveButton(BoxConstraints constraints) {
    final buttonHeight = _getResponsiveButtonHeight(constraints);
    final fontSize = _getResponsiveFontSize(constraints, 18, 16, 20);
    final iconSize = fontSize + 4;
    final maxWidth = constraints.maxWidth > 400 ? 350 : constraints.maxWidth * 0.85;
    
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxWidth: maxWidth.toDouble()),
      height: buttonHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(buttonHeight / 2),
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _goLive,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonHeight / 2),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: Colors.white,
                    size: iconSize,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Go Live in Zone',
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFeaturesList(BoxConstraints constraints) {
    final features = [
      'Completely anonymous chatting',
      'Identity revealed only after 3 days',
      'Secure and private conversations',
      'One-on-one exclusive pairing',
      'Resume chats after closing app',
    ];

    final fontSize = _getResponsiveFontSize(constraints, 12, 11, 14);
    final iconSize = fontSize + 2;
    final spacing = _getVerticalSpacing(constraints, 4);

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: spacing),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: const Color(0xFF4CAF50),
                size: iconSize,
              ),
              SizedBox(width: _getResponsivePadding(constraints) * 0.75),
              Expanded(
                child: Text(
                  feature,
                  style: GoogleFonts.poppins(
                    fontSize: fontSize,
                    color: Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Helper methods for responsive design
  double _getResponsiveFontSize(BoxConstraints constraints, double base, double small, double large) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    
    // Ultra small devices (width < 320)
    if (width < 320) return small * 0.9;
    
    // Small devices (width < 360)
    if (width < 360) return small;
    
    // Large tablets and desktops (width > 800)
    if (width > 800) return large;
    
    // Regular tablets (width > 600)
    if (width > 600) return large * 0.9;
    
    // Adjust for very tall narrow screens
    if (height / width > 2.2) return small * 1.1;
    
    // Adjust for very short wide screens
    if (height / width < 1.3) return base * 0.9;
    
    return base;
  }

  double _getResponsivePadding(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    
    if (width < 320) return 10;
    if (width < 360) return 12;
    if (width > 800) return 32;
    if (width > 600) return 24;
    return 16;
  }

  double _getVerticalSpacing(BoxConstraints constraints, double base) {
    final height = constraints.maxHeight;
    final width = constraints.maxWidth;
    
    // Very small screens
    if (height < 600) return base * 0.6;
    
    // Very large screens
    if (height > 900) return base * 1.3;
    
    // Ultra wide tablets in landscape
    if (width > 800 && height / width < 0.7) return base * 0.8;
    
    // Very tall screens
    if (height / width > 2.2) return base * 1.1;
    
    return base;
  }

  double _getResponsiveIconSize(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    
    if (width < 320) return 80;
    if (width < 360) return 90;
    if (width > 800) return 160;
    if (width > 600) return 140;
    if (height < 600) return 100;
    return 120;
  }

  double _getResponsiveButtonHeight(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    
    if (width < 320) return 45;
    if (width < 360) return 50;
    if (width > 800) return 75;
    if (width > 600) return 70;
    if (height < 600) return 55;
    return 60;
  }
}