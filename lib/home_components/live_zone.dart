// screens/live_zone_screen.dart - COMPLETE PLATFORM-AWARE VERSION

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/home_components/chat_models.dart';
import 'package:startup/home_components/chat_service.dart';
import 'chat_screen.dart';

class LiveZoneScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;

  const LiveZoneScreen({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  State<LiveZoneScreen> createState() => _LiveZoneScreenState();
}

class _LiveZoneScreenState extends State<LiveZoneScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _waveAnimation;
  
  StreamSubscription<LiveZoneUser?>? _userStatusSubscription;
  StreamSubscription<int>? _liveCountSubscription;
  
  int _liveUsersCount = 0;
  String _currentStatus = 'waiting';
  int _waitingSeconds = 0;
  Timer? _waitingTimer;
  
  final List<String> _waitingMessages = [
    'Looking for someone amazing...',
    'Finding your perfect match...',
    'Connecting you with someone cool...',
    'Almost there, hang tight...',
    'Searching for your chat buddy...',
  ];
  
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _setSystemUI();
    _initAnimations();
    _setupListeners();
    _startWaitingTimer();
    _startMessageRotation();
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
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _waveController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(_rotationController);

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(_waveController);
  }

  void _setupListeners() {
    _userStatusSubscription = _chatService.listenToUserStatus(widget.communityId, widget.userId).listen(
      (userStatus) {
        if (mounted && userStatus != null) {
          setState(() {
            _currentStatus = userStatus.status;
          });

          if (userStatus.status == 'paired' && userStatus.sessionId != null) {
            _navigateToChat(userStatus.sessionId!, userStatus.pairedWith!);
          }
        }
      },
      onError: (error) {
        debugPrint('Error listening to user status: $error');
        _showErrorAndGoBack('Connection error. Please try again.');
      },
    );

    _liveCountSubscription = _chatService.getLiveZoneCount(widget.communityId).listen(
      (count) {
        if (mounted) {
          setState(() {
            _liveUsersCount = count;
          });
        }
      },
    );
  }

  void _startWaitingTimer() {
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _waitingSeconds++;
        });
      }
    });
  }

  void _startMessageRotation() {
    _messageTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _currentStatus == 'waiting') {
        setState(() {
          _currentMessageIndex = (_currentMessageIndex + 1) % _waitingMessages.length;
        });
      }
    });
  }

  void _navigateToChat(String sessionId, String partnerId) {
    // Enhanced haptic feedback for successful pairing
    if (Platform.isIOS) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.vibrate();
    }

    _chatService.startChat(sessionId, partnerId);
    
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
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      );
    } else {
      return PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      );
    }
  }

  Future<void> _leaveLiveZone() async {
    // Platform-specific haptic feedback
    if (Platform.isIOS) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.vibrate();
    }

    try {
      await _chatService.leaveLiveZone(widget.communityId, widget.userId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorMessage('Failed to leave live zone');
    }
  }

  void _showErrorAndGoBack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    _userStatusSubscription?.cancel();
    _liveCountSubscription?.cancel();
    _waitingTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final aspectRatio = screenHeight / screenWidth;
    final isSmallScreen = screenWidth < 360;
    final isTabletLike = aspectRatio < 1.3;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _leaveLiveZone();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                      : _buildPhoneLayout(isSmallScreen),
                  ),
                ],
              ),
            ),
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
            onPressed: _leaveLiveZone,
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 8 : 12,
                      height: isSmallScreen ? 8 : 12,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Text(
                      'Live Zone',
                      style: GoogleFonts.dmSerifDisplay(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$_liveUsersCount users online',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: const Color(0xFF6C63FF).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          // Waiting time indicator
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              '${_waitingSeconds}s',
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 10 : 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
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
          child: _buildMainContent(isSmallScreen),
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
                  Icons.search,
                  size: isSmallScreen ? 60 : 80,
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
                Text(
                  'Finding Your Match',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isSmallScreen ? 18 : 24,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  'Our intelligent matching system is working to pair you with the perfect conversation partner.',
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

  Widget _buildPhoneLayout(bool isSmallScreen) {
    return _buildMainContent(isSmallScreen);
  }

  Widget _buildMainContent(bool isSmallScreen) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      padding: EdgeInsets.all(isSmallScreen ? 20 : 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated searching indicator
          _buildSearchingAnimation(isSmallScreen),
          
          SizedBox(height: isSmallScreen ? 30 : 50),
          
          // Status message
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              _waitingMessages[_currentMessageIndex],
              key: ValueKey(_currentMessageIndex),
              style: GoogleFonts.dmSerifDisplay(
                fontSize: isSmallScreen ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 20),
          
          Text(
            'We\'re finding someone perfect for you to chat with.\nThis usually takes just a few seconds.',
            style: GoogleFonts.poppins(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.white70,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          
          SizedBox(height: isSmallScreen ? 40 : 60),
          
          // Cancel button
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 300),
            height: isSmallScreen ? 45 : 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.5),
              ),
            ),
            child: ElevatedButton(
              onPressed: _leaveLiveZone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Leave Live Zone',
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingAnimation(bool isSmallScreen) {
    final size = isSmallScreen ? 150.0 : 200.0;
    final outerSize = isSmallScreen ? 130.0 : 180.0;
    final middleSize = isSmallScreen ? 90.0 : 120.0;
    final centerSize = isSmallScreen ? 60.0 : 80.0;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          AnimatedBuilder(
            animation: _rotationAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotationAnimation.value,
                child: Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                      width: isSmallScreen ? 1.5 : 2,
                    ),
                  ),
                  child: CustomPaint(
                    painter: DotPainter(
                      color: const Color(0xFF6C63FF),
                      animation: _waveAnimation,
                      isSmallScreen: isSmallScreen,
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Middle pulsing circle
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: middleSize,
                  height: middleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF6C63FF).withOpacity(0.3),
                        const Color(0xFF9C88FF).withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Center icon
          Container(
            width: centerSize,
            height: centerSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: Icon(
              Icons.search,
              size: isSmallScreen ? 30 : 40,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for animated dots around the circle
class DotPainter extends CustomPainter {
  final Color color;
  final Animation<double> animation;
  final bool isSmallScreen;
  
  DotPainter({
    required this.color, 
    required this.animation,
    this.isSmallScreen = false,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - (isSmallScreen ? 8 : 10);
    final dotSize = isSmallScreen ? 3.0 : 4.0;
    
    for (int i = 0; i < 8; i++) {
      final angle = (i * pi / 4) + (animation.value * 2 * pi / 8);
      final dotX = center.dx + radius * cos(angle);
      final dotY = center.dy + radius * sin(angle);
      
      final opacity = (sin(animation.value * 2 * pi + i * pi / 4) + 1) / 2;
      paint.color = color.withOpacity(opacity * 0.8);
      
      canvas.drawCircle(Offset(dotX, dotY), dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(DotPainter oldDelegate) {
    return oldDelegate.animation != animation ||
           oldDelegate.isSmallScreen != isSmallScreen;
  }
}