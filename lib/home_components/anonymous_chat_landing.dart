// screens/anonymous_chat_landing.dart - COMPLETE PLATFORM-AWARE VERSION

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

class _AnonymousChatLandingState extends State<AnonymousChatLanding>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  
  late AnimationController _floatingController;
  late AnimationController _slideController;
  late Animation<double> _floatingAnimation;
  late Animation<Offset> _slideAnimation;
  
  StreamSubscription<int>? _liveCountSubscription;
  StreamSubscription<LiveZoneUser?>? _userStatusSubscription;
  
  int _liveUsersCount = 0;
  bool _isLoading = false;
  bool _checkingActiveSession = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
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

  void _initAnimations() {
    // Smooth floating animation instead of jarring pulse
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _floatingAnimation = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _slideController.forward();
  }

  Future<void> _checkForActiveSession() async {
    try {
      final activeSession = await _chatService.getActiveSession(widget.communityId, widget.userId);
      
      if (activeSession != null) {
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
            Navigator.pushReplacement(
              context,
              _createPageRoute(ChatScreen(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
                sessionId: userStatus.sessionId!,
                partnerId: userStatus.pairedWith!,
              )),
            );
          }
        }
      },
      onError: (error) {
        debugPrint('Error listening to user status: $error');
      },
    );
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
    _floatingController.dispose();
    _slideController.dispose();
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
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final aspectRatio = screenHeight / screenWidth;
    final isSmallScreen = screenWidth < 360;
    final isTabletLike = aspectRatio < 1.3;
    final isVeryTall = aspectRatio > 2.2;

    if (_checkingActiveSession) {
      return _buildLoadingScreen(isSmallScreen);
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1A2E),
                const Color(0xFF0A0A0A),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            top: true,
            bottom: Platform.isIOS,
            child: Column(
              children: [
                _buildHeader(isSmallScreen),
                Expanded(
                  child: isTabletLike 
                    ? _buildTabletLayout(isSmallScreen)
                    : _buildPhoneLayout(isSmallScreen, isVeryTall),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(bool isSmallScreen) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A2E),
              const Color(0xFF0A0A0A),
              Colors.black,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: const Color(0xFF6C63FF),
                strokeWidth: isSmallScreen ? 2 : 3,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                'Checking for active sessions...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isSmallScreen ? 12 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Platform.isIOS ? Icons.arrow_back_ios : Icons.arrow_back,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                  ).createShader(bounds),
                  child: Text(
                    'Anonymous Chat',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'Connect with strangers anonymously',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: const Color(0xFF6C63FF).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.history,
              color: const Color(0xFF6C63FF),
              size: isSmallScreen ? 20 : 24,
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

  Widget _buildTabletLayout(bool isSmallScreen) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildMainContent(isSmallScreen, false),
        ),
        Container(
          width: 1,
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 20 : 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: isSmallScreen ? 60 : 80,
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
                Text(
                  'Wide Screen Detected',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isSmallScreen ? 18 : 24,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  'Enjoy a comfortable chat experience with optimized layout for your device.',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 12 : 14,
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

  Widget _buildPhoneLayout(bool isSmallScreen, bool isVeryTall) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildMainContent(isSmallScreen, isVeryTall),
      ),
    );
  }

  Widget _buildMainContent(bool isSmallScreen, bool isVeryTall) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: 600, // Prevent content from getting too wide
      ),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: isVeryTall ? 40 : (isSmallScreen ? 20 : 40)),
          
          // Floating anonymous icon
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatingAnimation.value),
                child: Container(
                  width: isSmallScreen ? 100 : 120,
                  height: isSmallScreen ? 100 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                        blurRadius: isSmallScreen ? 15 : 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: isSmallScreen ? 80 : 100,
                        height: isSmallScreen ? 80 : 100,
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
                        Icons.face_retouching_natural,
                        size: isSmallScreen ? 50 : 60,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          SizedBox(height: isSmallScreen ? 30 : 40),

          Text(
            'Ready to Meet Someone New?',
            style: GoogleFonts.dmSerifDisplay(
              fontSize: isSmallScreen ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isSmallScreen ? 12 : 16),

          Text(
            'Connect anonymously with people in your community.\nIdentities revealed only after mutual consent.',
            style: GoogleFonts.poppins(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: isSmallScreen ? 30 : 40),

          // Live users count
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 20 : 24,
              vertical: isSmallScreen ? 12 : 16,
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
                  width: isSmallScreen ? 8 : 12,
                  height: isSmallScreen ? 8 : 12,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 12),
                Text(
                  '$_liveUsersCount users live in the zone',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isSmallScreen ? 40 : 50),

          // Go Live button
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 300),
            height: isSmallScreen ? 50 : 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
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
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      width: isSmallScreen ? 20 : 24,
                      height: isSmallScreen ? 20 : 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: isSmallScreen ? 2 : 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.radio_button_checked,
                          color: Colors.white,
                          size: isSmallScreen ? 20 : 24,
                        ),
                        SizedBox(width: isSmallScreen ? 8 : 12),
                        Text(
                          'Go Live in Zone',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          SizedBox(height: isSmallScreen ? 20 : 30),

          _buildFeaturesList(isSmallScreen),
          
          SizedBox(height: isVeryTall ? 60 : (isSmallScreen ? 30 : 50)),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(bool isSmallScreen) {
    final features = [
      'Completely anonymous chatting',
      'Identity revealed only after 3 days',
      'Secure and private conversations',
      'One-on-one exclusive pairing',
      'Resume chats after closing app',
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3 : 4),
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: const Color(0xFF4CAF50),
                size: isSmallScreen ? 14 : 16,
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Expanded(
                child: Text(
                  feature,
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 11 : 12,
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
}