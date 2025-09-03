// screens/chat_history_screen.dart - COMPLETE FIXED VERSION

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/home_components/chat_models.dart';
import 'package:startup/home_components/chat_service.dart';
import 'package:startup/home_components/user_profile_screen.dart';

class ChatHistoryScreen extends StatefulWidget {
  final String communityId;
  final String userId;

  const ChatHistoryScreen({
    Key? key,
    required this.communityId,
    required this.userId,
  }) : super(key: key);

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen>
    with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  StreamSubscription<List<ChatHistory>>? _historySubscription;
  List<ChatHistory> _chatHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setSystemUI();
    _initAnimations();
    _setupListeners();
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
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    
    _fadeController.forward();
  }

  void _setupListeners() {
    _historySubscription = _chatService.getChatHistory(widget.communityId, widget.userId).listen(
      (history) {
        if (mounted) {
          setState(() {
            _chatHistory = history;
            _isLoading = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Error loading chat history: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
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
              Tween(begin: const Offset(-1.0, 0.0), end: Offset.zero)
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
    _fadeController.dispose();
    _historySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final aspectRatio = screenHeight / screenWidth;
    
    // FIX 2: Improved responsive breakpoints for all devices
    final isVerySmallScreen = screenWidth < 320; // Very small phones
    final isSmallScreen = screenWidth < 375; // Small phones like iPhone SE
    final isMediumScreen = screenWidth >= 375 && screenWidth < 414; // Standard phones
    final isLargeScreen = screenWidth >= 414 && screenWidth < 768; // Large phones/phablets
    final isTablet = screenWidth >= 768; // Tablets
    final isTabletLike = aspectRatio < 1.3 || isTablet;
    final isLandscape = screenWidth > screenHeight;

    // Dynamic sizing based on screen size
    final headerPadding = isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0);
    final cardPadding = isVerySmallScreen ? 12.0 : (isSmallScreen ? 16.0 : 20.0);
    final avatarSize = isVerySmallScreen ? 35.0 : (isSmallScreen ? 40.0 : 50.0);
    final titleFontSize = isVerySmallScreen ? 18.0 : (isSmallScreen ? 20.0 : 24.0);
    final contentPadding = isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 16.0);

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
                _buildHeader(headerPadding, titleFontSize, isVerySmallScreen),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: (isTabletLike && !isLandscape)
                      ? _buildTabletLayout(contentPadding, avatarSize, isVerySmallScreen)
                      : _buildPhoneLayout(contentPadding, avatarSize, cardPadding, isVerySmallScreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double padding, double titleFontSize, bool isVerySmallScreen) {
    return Container(
      padding: EdgeInsets.all(padding),
      child: Row(
        children: [
       GestureDetector(
  onTap: () => Navigator.pop(context),
  child: Container(
    padding: EdgeInsets.all(isVerySmallScreen ? 8 : 12),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0A0A).withOpacity(0.8),
      borderRadius: BorderRadius.circular(isVerySmallScreen ? 12 : 16),
      border: Border.all(
        color: const Color(0xFF6C63FF).withOpacity(0.2),
      ),
    ),
    child: Icon(
      Platform.isIOS ? Icons.arrow_back_ios_new : Icons.arrow_back,
      color: Colors.white,
      size: isVerySmallScreen ? 14 : 20,
    ),
  ),
),
          SizedBox(width: padding * 0.8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                  ).createShader(bounds),
                  child: Text(
                    'chat history',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'Your past anonymous conversations',
                  style: GoogleFonts.poppins(
                    fontSize: isVerySmallScreen ? 9 : 12,
                    color: const Color(0xFF6C63FF).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isVerySmallScreen ? 6 : 12,
              vertical: isVerySmallScreen ? 3 : 6,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              '${_chatHistory.length}',
              style: GoogleFonts.poppins(
                fontSize: isVerySmallScreen ? 9 : 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(double contentPadding, double avatarSize, bool isVerySmallScreen) {
    if (_isLoading) {
      return _buildLoadingState(isVerySmallScreen);
    }

    if (_chatHistory.isEmpty) {
      return _buildEmptyState(isVerySmallScreen);
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildHistoryList(contentPadding, avatarSize, isVerySmallScreen),
        ),
        Container(
          width: 1,
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: EdgeInsets.all(contentPadding * 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: isVerySmallScreen ? 50 : 80,
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
                SizedBox(height: contentPadding),
                Text(
                  'Chat History',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isVerySmallScreen ? 16 : 24,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: contentPadding * 0.5),
                Text(
                  'View your conversation details and statistics on this wide-screen optimized layout.',
                  style: GoogleFonts.poppins(
                    fontSize: isVerySmallScreen ? 11 : 14,
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

  Widget _buildPhoneLayout(double contentPadding, double avatarSize, double cardPadding, bool isVerySmallScreen) {
    if (_isLoading) {
      return _buildLoadingState(isVerySmallScreen);
    }

    if (_chatHistory.isEmpty) {
      return _buildEmptyState(isVerySmallScreen);
    }

    return _buildHistoryList(contentPadding, avatarSize, isVerySmallScreen);
  }

  Widget _buildLoadingState(bool isVerySmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF6C63FF),
            strokeWidth: isVerySmallScreen ? 2 : 3,
          ),
          SizedBox(height: isVerySmallScreen ? 10 : 16),
          Text(
            'Loading chat history...',
            style: GoogleFonts.poppins(
              fontSize: isVerySmallScreen ? 11 : 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(double contentPadding, double avatarSize, bool isVerySmallScreen) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView.builder(
        padding: EdgeInsets.all(contentPadding),
        itemCount: _chatHistory.length,
        itemBuilder: (context, index) {
          final history = _chatHistory[index];
          return _buildHistoryCard(history, index, contentPadding, avatarSize, isVerySmallScreen);
        },
      ),
    );
  }

  Widget _buildHistoryCard(ChatHistory history, int index, double contentPadding, double avatarSize, bool isVerySmallScreen) {
    // FIX 3: Display actual message count (divide by 2 to prevent doubling)
    final actualMessageCount = (history.totalMessages / 2).round();
    
    return Container(
      margin: EdgeInsets.only(bottom: contentPadding),
      padding: EdgeInsets.all(contentPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.1),
            const Color(0xFF9C88FF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(contentPadding * 0.8),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
             Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: history.identityRevealed
                        ? const LinearGradient(
                            colors: [Color(0xFF4CAF50), Color(0xFF8BC34A)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                          ),
                  ),
                  child: history.identityRevealed && history.partnerData?.profileImageUrl != null
                      ? ClipOval(
                          child: Image.network(
                            history.partnerData!.profileImageUrl!,
                            width: avatarSize,
                            height: avatarSize,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                color: Colors.white,
                                size: avatarSize * 0.5,
                              );
                            },
                          ),
                        )
                      : Icon(
                          history.identityRevealed ? Icons.person : Icons.face_retouching_natural,
                          color: Colors.white,
                          size: avatarSize * 0.5,
                        ),
                ),
              
              SizedBox(width: contentPadding),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                         
                            child: Text(
                              history.displayName,
                              style: GoogleFonts.poppins(
                                fontSize: isVerySmallScreen ? 12 : 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isVerySmallScreen ? 4 : 8,
                            vertical: isVerySmallScreen ? 1 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: history.identityRevealed
                                ? const Color(0xFF4CAF50).withOpacity(0.2)
                                : const Color(0xFF6C63FF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            history.identityRevealed ? 'Revealed' : 'Anonymous',
                            style: GoogleFonts.poppins(
                              fontSize: isVerySmallScreen ? 7 : 10,
                              color: history.identityRevealed
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF6C63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isVerySmallScreen ? 1 : 4),
                    if (history.identityRevealed && history.partnerData != null)
                      Text(
                        '${history.partnerData!.branch} • ${history.partnerData!.year}',
                        style: GoogleFonts.poppins(
                          fontSize: isVerySmallScreen ? 9 : 12,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: contentPadding),
          
          // Chat stats - Improved responsive wrapping
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 300;
              return Wrap(
                spacing: isNarrow ? 8 : 20,
                runSpacing: isNarrow ? 6 : 8,
                children: [
                  _buildStatItem(Icons.message, '$actualMessageCount', 'Messages', isVerySmallScreen),
                  _buildStatItem(Icons.access_time, history.sessionDuration, 'Duration', isVerySmallScreen),
                  _buildStatItem(Icons.calendar_today, _formatDate(history.startedAt), 'Started', isVerySmallScreen),
                ],
              );
            },
          ),
          
          if (history.identityRevealed && history.endedAt != null) ...[
            SizedBox(height: contentPadding * 0.7),
            Container(
              padding: EdgeInsets.all(contentPadding * 0.6),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility,
                    color: const Color(0xFF4CAF50),
                    size: isVerySmallScreen ? 12 : 16,
                  ),
                  SizedBox(width: contentPadding * 0.5),
                  Expanded(
                    child: Text(
                      'Identities were revealed on ${_formatDate(history.endedAt!)}',
                      style: GoogleFonts.poppins(
                        fontSize: isVerySmallScreen ? 8 : 11,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, bool isVerySmallScreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isVerySmallScreen ? 10 : 14,
          color: const Color(0xFF6C63FF),
        ),
        SizedBox(width: isVerySmallScreen ? 2 : 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isVerySmallScreen ? 9 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isVerySmallScreen ? 7 : 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isVerySmallScreen) {
    final iconSize = isVerySmallScreen ? 50.0 : 80.0;
    final titleSize = isVerySmallScreen ? 16.0 : 20.0;
    final bodySize = isVerySmallScreen ? 11.0 : 14.0;
    final buttonSize = isVerySmallScreen ? 11.0 : 14.0;
    
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 12 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.3),
                    const Color(0xFF9C88FF).withOpacity(0.1),
                  ],
                ),
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: iconSize * 0.5,
                color: const Color(0xFF6C63FF),
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 12 : 24),
            Text(
              'No Chat History Yet',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: titleSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: isVerySmallScreen ? 4 : 8),
            Text(
              'Start chatting anonymously to see\nyour conversation history here',
              style: GoogleFonts.poppins(
                fontSize: bodySize,
                color: Colors.white60,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isVerySmallScreen ? 16 : 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (Platform.isIOS) {
                    HapticFeedback.lightImpact();
                  } else {
                    HapticFeedback.vibrate();
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallScreen ? 20 : 32,
                    vertical: isVerySmallScreen ? 8 : 12,
                  ),
                ),
                child: Text(
                  'Start Chatting',
                  style: GoogleFonts.poppins(
                    fontSize: buttonSize,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}