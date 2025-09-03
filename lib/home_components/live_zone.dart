// screens/live_zone_screen.dart - FULLY RESPONSIVE & ADAPTIVE VERSION

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:math' as math;
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
  bool _explicitlyLeft = false;
  
  final List<String> _waitingMessages = [
    'finding someone...',
    'almost there...',
    'seems like everyone is attending lecs right now...',
    'hell nah man who got them so busy...',
    
  ];
  
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setSystemUI();
    _initAnimations();
    _setupListeners();
    _startWaitingTimer();
    _startMessageRotation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't leave live zone on app lifecycle changes - keep user in pairing queue
    // Only leave when user explicitly taps the leave button
    super.didChangeAppLifecycleState(state);
  }

  void _setSystemUI() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark, // For iOS
      systemNavigationBarColor: Color(0xFF0A0A0A),
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
    _explicitlyLeft = true;
    
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
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _rotationController.dispose();
    _waveController.dispose();
    _userStatusSubscription?.cancel();
    _liveCountSubscription?.cancel();
    _waitingTimer?.cancel();
    _messageTimer?.cancel();
    
    // Only leave live zone if user explicitly left
    if (_explicitlyLeft) {
      _chatService.leaveLiveZone(widget.communityId, widget.userId);
    }
    
    super.dispose();
  }

  // Enhanced responsive calculations with device detection
  DeviceConfig _getDeviceConfig(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final aspectRatio = height / width;
    final shortestSide = math.min(width, height);
    final longestSide = math.max(width, height);

    // Device type detection
    DeviceType deviceType;
    if (width >= 1200) {
      deviceType = DeviceType.desktop;
    } else if (width >= 900) {
      deviceType = DeviceType.largeTablet;
    } else if (width >= 600) {
      deviceType = DeviceType.tablet;
    } else if (shortestSide >= 600) {
      deviceType = DeviceType.tablet;
    } else if (aspectRatio < 1.3) {
      deviceType = DeviceType.tabletLandscape;
    } else if (width < 320) {
      deviceType = DeviceType.verySmallPhone;
    } else if (width < 375) {
      deviceType = DeviceType.smallPhone;
    } else {
      deviceType = DeviceType.phone;
    }

    // Screen density considerations
    bool isCompactHeight = height < 600;
    bool isVeryCompactHeight = height < 500;
    bool isTallScreen = aspectRatio > 2.1;
    bool isWideScreen = aspectRatio < 1.3;

    return DeviceConfig(
      deviceType: deviceType,
      width: width,
      height: height,
      aspectRatio: aspectRatio,
      isCompactHeight: isCompactHeight,
      isVeryCompactHeight: isVeryCompactHeight,
      isTallScreen: isTallScreen,
      isWideScreen: isWideScreen,
    );
  }

  ResponsiveValues _getResponsiveValues(DeviceConfig config) {
    switch (config.deviceType) {
      case DeviceType.desktop:
        return ResponsiveValues(
          padding: 40.0,
          titleSize: 32.0,
          subtitleSize: 16.0,
          bodySize: 16.0,
          iconSize: 200.0,
          buttonHeight: 75.0,
          spacing: 60.0,
          borderRadius: 24.0,
          useWideLayout: true,
          headerPadding: 32.0,
          animationSize: 300.0,
          iconPadding: 20.0,
        );
      case DeviceType.largeTablet:
        return ResponsiveValues(
          padding: 32.0,
          titleSize: 28.0,
          subtitleSize: 15.0,
          bodySize: 15.0,
          iconSize: 180.0,
          buttonHeight: 70.0,
          spacing: 50.0,
          borderRadius: 20.0,
          useWideLayout: true,
          headerPadding: 28.0,
          animationSize: 260.0,
          iconPadding: 18.0,
        );
      case DeviceType.tablet:
        bool useWide = config.isWideScreen || config.width > config.height;
        return ResponsiveValues(
          padding: 24.0,
          titleSize: useWide ? 26.0 : 24.0,
          subtitleSize: 14.0,
          bodySize: 14.0,
          iconSize: useWide ? 160.0 : 150.0,
          buttonHeight: 65.0,
          spacing: useWide ? 45.0 : 40.0,
          borderRadius: 18.0,
          useWideLayout: useWide,
          headerPadding: 24.0,
          animationSize: useWide ? 220.0 : 200.0,
          iconPadding: 16.0,
        );
      case DeviceType.tabletLandscape:
        return ResponsiveValues(
          padding: 20.0,
          titleSize: 22.0,
          subtitleSize: 13.0,
          bodySize: 13.0,
          iconSize: 140.0,
          buttonHeight: 60.0,
          spacing: 35.0,
          borderRadius: 16.0,
          useWideLayout: true,
          headerPadding: 20.0,
          animationSize: 180.0,
          iconPadding: 14.0,
        );
      case DeviceType.verySmallPhone:
        return ResponsiveValues(
          padding: 10.0,
          titleSize: config.isTallScreen ? 20.0 : 18.0,
          subtitleSize: 10.0,
          bodySize: 11.0,
          iconSize: config.isVeryCompactHeight ? 80.0 : 95.0,
          buttonHeight: config.isVeryCompactHeight ? 40.0 : 45.0,
          spacing: config.isVeryCompactHeight ? 15.0 : 20.0,
          borderRadius: 12.0,
          useWideLayout: false,
          headerPadding: 10.0,
          animationSize: config.isVeryCompactHeight ? 120.0 : 140.0,
          iconPadding: 8.0,
        );
      case DeviceType.smallPhone:
        return ResponsiveValues(
          padding: 12.0,
          titleSize: config.isTallScreen ? 22.0 : 20.0,
          subtitleSize: 11.0,
          bodySize: 12.0,
          iconSize: config.isVeryCompactHeight ? 95.0 : 110.0,
          buttonHeight: config.isVeryCompactHeight ? 45.0 : 50.0,
          spacing: config.isVeryCompactHeight ? 18.0 : 25.0,
          borderRadius: 14.0,
          useWideLayout: false,
          headerPadding: 12.0,
          animationSize: config.isVeryCompactHeight ? 140.0 : 160.0,
          iconPadding: 10.0,
        );
      case DeviceType.phone:
      default:
        return ResponsiveValues(
          padding: 16.0,
          titleSize: config.isTallScreen ? 28.0 : (config.isCompactHeight ? 22.0 : 26.0),
          subtitleSize: 12.0,
          bodySize: 13.0,
          iconSize: config.isCompactHeight ? 120.0 : 140.0,
          buttonHeight: config.isCompactHeight ? 50.0 : 60.0,
          spacing: config.isCompactHeight ? 25.0 : 35.0,
          borderRadius: 16.0,
          useWideLayout: false,
          headerPadding: 16.0,
          animationSize: config.isCompactHeight ? 160.0 : 180.0,
          iconPadding: 12.0,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceConfig = _getDeviceConfig(constraints);
        final responsive = _getResponsiveValues(deviceConfig);
        
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
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(deviceConfig, responsive),
                  Expanded(
                    child: responsive.useWideLayout 
                      ? _buildWideScreenLayout(deviceConfig, responsive)
                      : _buildPhoneLayout(deviceConfig, responsive),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(DeviceConfig config, ResponsiveValues responsive) {
    return Container(
      padding: EdgeInsets.all(responsive.headerPadding),
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     begin: Alignment.topLeft,
      //     end: Alignment.bottomRight,
      //     colors: [
      //       const Color(0xFF1A1A2E).withOpacity(0.3),
      //       Colors.transparent,
      //     ],
      //   ),
      // ),
      child: Row(
        children: [
          // Back button styled like polls screen but with purple colors
          GestureDetector(
            onTap: _leaveLiveZone,
            child: Container(
              padding: EdgeInsets.all(responsive.iconPadding),
           decoration: BoxDecoration(
  color: const Color(0xFF0A0A0A).withOpacity(0.8),
  borderRadius: BorderRadius.circular(responsive.borderRadius * 0.8),
  border: Border.all(
    color: const Color(0xFF6C63FF).withOpacity(0.2),
  ),
),
              child: Icon(
                Platform.isIOS ? Icons.arrow_back_ios_new : Icons.arrow_back,
                color: Colors.white,
                size: responsive.titleSize * 0.8,
              ),
            ),
          ),

          // Live zone icon container
          Container(
            margin: EdgeInsets.only(left: responsive.padding * 0.75),
            padding: EdgeInsets.all(responsive.iconPadding),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
              borderRadius: BorderRadius.circular(responsive.borderRadius * 0.8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.radio_button_checked,
              color: Colors.white,
              size: responsive.titleSize,
            ),
          ),

          SizedBox(width: responsive.padding),

          // Title section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: responsive.subtitleSize * 0.8,
                      height: responsive.subtitleSize * 0.8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                    SizedBox(width: responsive.padding * 0.4),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                      ).createShader(bounds),
                      child: Text(
                        'live zone',
                        style: GoogleFonts.dmSerifDisplay(
                          fontSize: responsive.titleSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!config.isVeryCompactHeight) ...[
                  SizedBox(height: 2),
                  Text(
                    '$_liveUsersCount users online',
                    style: GoogleFonts.poppins(
                      fontSize: responsive.subtitleSize,
                      color: const Color(0xFF6C63FF).withOpacity(0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Timer display
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: responsive.padding * 0.75,
              vertical: responsive.padding * 0.3,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6C63FF).withOpacity(0.2),
                  const Color(0xFF9C88FF).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(responsive.borderRadius * 0.8),
              border: Border.all(
                color: const Color(0xFF6C63FF).withOpacity(0.3),
              ),
            ),
            child: Text(
              '${_waitingSeconds}s',
              style: GoogleFonts.poppins(
                fontSize: responsive.subtitleSize,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideScreenLayout(DeviceConfig config, ResponsiveValues responsive) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildMainContent(config, responsive),
        ),
        Container(
          width: 1,
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
        Expanded(
          flex: 2,
          child: Container(
            padding: EdgeInsets.all(responsive.padding * 1.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search,
                  size: responsive.iconSize * 0.7,
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
                SizedBox(height: responsive.spacing * 0.6),
                Text(
                  'finding your match',
                  style: GoogleFonts.poppins(
                    fontSize: responsive.titleSize * 0.9,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: responsive.spacing * 0.3),
                Text(
                  'we are working to pair you with the perfect conversation partner.',
                  style: GoogleFonts.poppins(
                    fontSize: responsive.bodySize,
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

  Widget _buildPhoneLayout(DeviceConfig config, ResponsiveValues responsive) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Container(
        constraints: BoxConstraints(
          minHeight: config.height - (responsive.headerPadding * 6) - responsive.titleSize * 4,
        ),
        child: _buildMainContent(config, responsive),
      ),
    );
  }

  Widget _buildMainContent(DeviceConfig config, ResponsiveValues responsive) {
    final maxWidth = config.width > 700 ? 600.0 : config.width * 0.9;
    
    return Center(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth.isFinite ? maxWidth : double.infinity,
        ),
        padding: EdgeInsets.all(responsive.padding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Searching animation
            _buildSearchingAnimation(config, responsive),
            
            SizedBox(height: responsive.spacing),
            
            // Animated message
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _waitingMessages[_currentMessageIndex],
                key: ValueKey(_currentMessageIndex),
                style: GoogleFonts.poppins(
                  fontSize: responsive.titleSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            SizedBox(height: responsive.spacing * 2),
            
            // Description
            Text(
              'We\'re finding someone perfect for you to chat with.\nThis usually takes just a few seconds.',
              style: GoogleFonts.poppins(
                fontSize: responsive.bodySize,
                color: Colors.white70,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: responsive.spacing * 1.2),
            
            // Leave button
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: math.min(350, config.width * 0.8),
              ),
              height: responsive.buttonHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(responsive.buttonHeight / 2),
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
                    borderRadius: BorderRadius.circular(responsive.buttonHeight / 2),
                  ),
                ),
                child: Text(
                  'Leave Live Zone',
                  style: GoogleFonts.poppins(
                    fontSize: responsive.bodySize + 2,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6C63FF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchingAnimation(DeviceConfig config, ResponsiveValues responsive) {
    final size = responsive.animationSize;
    final outerSize = size * 0.85;
    final middleSize = size * 0.6;
    final centerSize = size * 0.4;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring with dots
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
                      width: config.deviceType == DeviceType.verySmallPhone ? 1.5 : 2,
                    ),
                  ),
                  child: CustomPaint(
                    painter: DotPainter(
                      color: const Color(0xFF6C63FF),
                      animation: _waveAnimation,
                      dotSize: config.deviceType == DeviceType.verySmallPhone ? 3.0 : 4.0,
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
          
          // Center search icon
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
              size: centerSize * 0.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced DotPainter with responsive sizing
class DotPainter extends CustomPainter {
  final Color color;
  final Animation<double> animation;
  final double dotSize;
  
  DotPainter({
    required this.color, 
    required this.animation,
    this.dotSize = 4.0,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - (dotSize * 2);
    
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
    return oldDelegate.animation != animation || oldDelegate.dotSize != dotSize;
  }
}

// Device type enumeration
enum DeviceType {
  verySmallPhone,
  smallPhone,
  phone,
  tabletLandscape,
  tablet,
  largeTablet,
  desktop,
}

// Device configuration class
class DeviceConfig {
  final DeviceType deviceType;
  final double width;
  final double height;
  final double aspectRatio;
  final bool isCompactHeight;
  final bool isVeryCompactHeight;
  final bool isTallScreen;
  final bool isWideScreen;

  DeviceConfig({
    required this.deviceType,
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.isCompactHeight,
    required this.isVeryCompactHeight,
    required this.isTallScreen,
    required this.isWideScreen,
  });
}

// Responsive values configuration
class ResponsiveValues {
  final double padding;
  final double titleSize;
  final double subtitleSize;
  final double bodySize;
  final double iconSize;
  final double buttonHeight;
  final double spacing;
  final double borderRadius;
  final bool useWideLayout;
  final double headerPadding;
  final double animationSize;
  final double iconPadding;

  ResponsiveValues({
    required this.padding,
    required this.titleSize,
    required this.subtitleSize,
    required this.bodySize,
    required this.iconSize,
    required this.buttonHeight,
    required this.spacing,
    required this.borderRadius,
    required this.useWideLayout,
    required this.headerPadding,
    required this.animationSize,
    required this.iconPadding,
  });
}