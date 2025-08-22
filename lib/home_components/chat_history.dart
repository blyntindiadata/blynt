// screens/chat_history_screen.dart - COMPLETE PLATFORM-AWARE VERSION

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/home_components/chat_models.dart';
import 'package:startup/home_components/chat_service.dart';

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
    final isSmallScreen = screenWidth < 360;
    final isTabletLike = aspectRatio < 1.3;

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
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: isTabletLike 
                      ? _buildTabletLayout(isSmallScreen)
                      : _buildPhoneLayout(isSmallScreen),
                  ),
                ),
              ],
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
                    'Chat History',
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  'Your past anonymous conversations',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 10 : 12,
                    color: const Color(0xFF6C63FF).withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 4 : 6,
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
    if (_isLoading) {
      return _buildLoadingState(isSmallScreen);
    }

    if (_chatHistory.isEmpty) {
      return _buildEmptyState(isSmallScreen);
    }

    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildHistoryList(isSmallScreen),
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
                  Icons.history,
                  size: isSmallScreen ? 60 : 80,
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
                SizedBox(height: isSmallScreen ? 16 : 24),
                Text(
                  'Chat History',
                  style: GoogleFonts.dmSerifDisplay(
                    fontSize: isSmallScreen ? 18 : 24,
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  'View your conversation details and statistics on this wide-screen optimized layout.',
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
    if (_isLoading) {
      return _buildLoadingState(isSmallScreen);
    }

    if (_chatHistory.isEmpty) {
      return _buildEmptyState(isSmallScreen);
    }

    return _buildHistoryList(isSmallScreen);
  }

  Widget _buildLoadingState(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: const Color(0xFF6C63FF),
            strokeWidth: isSmallScreen ? 2 : 3,
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Text(
            'Loading chat history...',
            style: GoogleFonts.poppins(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(bool isSmallScreen) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ListView.builder(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        itemCount: _chatHistory.length,
        itemBuilder: (context, index) {
          final history = _chatHistory[index];
          return _buildHistoryCard(history, index, isSmallScreen);
        },
      ),
    );
  }

  Widget _buildHistoryCard(ChatHistory history, int index, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.1),
            const Color(0xFF9C88FF).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: isSmallScreen ? 40 : 50,
                height: isSmallScreen ? 40 : 50,
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
                          width: isSmallScreen ? 40 : 50,
                          height: isSmallScreen ? 40 : 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              color: Colors.white,
                              size: isSmallScreen ? 20 : 24,
                            );
                          },
                        ),
                      )
                    : Icon(
                        history.identityRevealed ? Icons.person : Icons.face_retouching_natural,
                        color: Colors.white,
                        size: isSmallScreen ? 20 : 24,
                      ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
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
                              fontSize: isSmallScreen ? 14 : 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 6 : 8,
                            vertical: isSmallScreen ? 2 : 4,
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
                              fontSize: isSmallScreen ? 8 : 10,
                              color: history.identityRevealed
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF6C63FF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    if (history.identityRevealed && history.partnerData != null)
                      Text(
                        '${history.partnerData!.branch} • ${history.partnerData!.year}',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 10 : 12,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Chat stats - Make them wrap on small screens
          Wrap(
            spacing: isSmallScreen ? 12 : 20,
            runSpacing: isSmallScreen ? 8 : 0,
            children: [
              _buildStatItem(Icons.message, '${history.totalMessages}', 'Messages', isSmallScreen),
              _buildStatItem(Icons.access_time, history.sessionDuration, 'Duration', isSmallScreen),
              _buildStatItem(Icons.calendar_today, _formatDate(history.startedAt), 'Started', isSmallScreen),
            ],
          ),
          
          if (history.identityRevealed && history.endedAt != null) ...[
            SizedBox(height: isSmallScreen ? 8 : 12),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
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
                    size: isSmallScreen ? 14 : 16,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'Identities were revealed on ${_formatDate(history.endedAt!)}',
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 9 : 11,
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

  Widget _buildStatItem(IconData icon, String value, String label, bool isSmallScreen) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: isSmallScreen ? 12 : 14,
          color: const Color(0xFF6C63FF),
        ),
        SizedBox(width: isSmallScreen ? 3 : 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 10 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 8 : 10,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isSmallScreen) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isSmallScreen ? 60 : 80,
              height: isSmallScreen ? 60 : 80,
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
                size: isSmallScreen ? 30 : 40,
                color: const Color(0xFF6C63FF),
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            Text(
              'No Chat History Yet',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Start chatting anonymously to see\nyour conversation history here',
              style: GoogleFonts.poppins(
                fontSize: isSmallScreen ? 12 : 14,
                color: Colors.white60,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Platform-specific haptic feedback
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
                    horizontal: isSmallScreen ? 24 : 32,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                ),
                child: Text(
                  'Start Chatting',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 12 : 14,
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