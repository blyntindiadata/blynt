// screens/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/home_components/chat_models.dart';
import 'package:startup/home_components/chat_service.dart';
// import 'package:startup/services/chat_service.dart';
import 'package:startup/home_components/live_zone.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChatScreen extends StatefulWidget {
  final String communityId;
  final String userId;
  final String username;
  final String sessionId;
  final String partnerId;

  const ChatScreen({
    Key? key,
    required this.communityId,
    required this.userId,
    required this.username,
    required this.sessionId,
    required this.partnerId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  final Connectivity _connectivity = Connectivity();
  
  late AnimationController _typingController;
  late Animation<double> _typingAnimation;
  
  StreamSubscription<List<ChatMessage>>? _messagesSubscription;
  StreamSubscription<ChatSession?>? _sessionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<bool>? _partnerTypingSubscription;
  StreamSubscription<bool>? _partnerOnlineSubscription;
  
  List<ChatMessage> _messages = [];
  ChatSession? _currentSession;
  bool _isTyping = false;
  bool _partnerIsTyping = false;
  bool _partnerIsOnline = false;
  bool _isOnline = true;
  bool _canRevealIdentity = false;
  bool _hasRequestedReveal = false;
  bool _partnerRequestedReveal = false;
  Timer? _typingTimer;
  bool _isSessionEnded = false;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupListeners();
    _setupConnectivity();
    _messageFocusNode.requestFocus();
    
    // Set chat service state
    _chatService.startChat(widget.sessionId, widget.partnerId);
    _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, true);
  }

  void _initAnimations() {
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _typingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_typingController);
  }

// Fixed _setupConnectivity method in ChatScreen
void _setupConnectivity() {
  // Check initial connectivity
  _checkInitialConnectivity();
  
  // Listen to connectivity changes
  _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
    (List<ConnectivityResult> results) {
      // Check if any of the results indicate connectivity
      final isOnline = results.any((result) => 
          result == ConnectivityResult.wifi || 
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet);
      
      if (_isOnline != isOnline) {
        setState(() {
          _isOnline = isOnline;
        });
        
        debugPrint('Connectivity changed: $isOnline'); // Debug log
        
        // Update online status in Firebase
        _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, isOnline);
        
        // Show connectivity status to user
        if (isOnline) {
          _showSuccessMessage('Connection restored');
        } else {
          _showErrorMessage('Connection lost');
        }
      }
    },
  );
}

// Add this method to check initial connectivity
Future<void> _checkInitialConnectivity() async {
  try {
    final connectivityResults = await _connectivity.checkConnectivity();
    final isOnline = connectivityResults.any((result) => 
        result == ConnectivityResult.wifi || 
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);
    
    setState(() {
      _isOnline = isOnline;
    });
    
    debugPrint('Initial connectivity: $isOnline'); // Debug log
    
    // Set initial online status
    _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, isOnline);
  } catch (e) {
    debugPrint('Error checking initial connectivity: $e');
    // Assume online if we can't check
    setState(() {
      _isOnline = true;
    });
  }
}

  void _setupListeners() {
    // Listen to messages - with proper ordering
    _messagesSubscription = _chatService.listenToMessages(widget.communityId, widget.sessionId).listen(
      (messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
          });
          _scrollToBottom();
          _markMessagesAsRead();
        }
      },
      onError: (error) {
        debugPrint('Error listening to messages: $error');
      },
    );

    // Listen to session status
    _sessionSubscription = _chatService.listenToSession(widget.communityId, widget.sessionId).listen(
      (session) {
        if (mounted && session != null) {
          setState(() {
            _currentSession = session;
            _canRevealIdentity = session.canRevealIdentity();
            _hasRequestedReveal = session.revealRequests[widget.userId] ?? false;
            _partnerRequestedReveal = session.revealRequests[widget.partnerId] ?? false;
            _isSessionEnded = session.status == 'ended';
            _partnerIsOnline = session.isUserOnline(widget.partnerId);
          });

          // Check if both users requested reveal
          if (_hasRequestedReveal && _partnerRequestedReveal && !session.identityRevealed) {
            _processIdentityReveal();
          }

          // Handle session end - navigate to live zone
          if (session.status == 'ended' && !_isSessionEnded) {
            _handleSessionEnd();
          }
        }
      },
      onError: (error) {
        debugPrint('Error listening to session: $error');
      },
    );

    // Listen to partner typing status
    _partnerTypingSubscription = _chatService.listenToUserTyping(
      widget.communityId, 
      widget.sessionId, 
      widget.partnerId
    ).listen(
      (isTyping) {
        if (mounted) {
          setState(() {
            _partnerIsTyping = isTyping;
          });
        }
      },
    );

    // Listen to partner online status
    _partnerOnlineSubscription = _chatService.listenToUserOnline(
      widget.communityId, 
      widget.sessionId, 
      widget.partnerId
    ).listen(
      (isOnline) {
        if (mounted) {
          setState(() {
            _partnerIsOnline = isOnline;
          });
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_isSessionEnded) {
      _showErrorMessage('This chat session has ended');
      return;
    }

    if (!_isOnline) {
      _showErrorMessage('No internet connection');
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Clear input immediately for better UX
    _messageController.clear();
    _stopTyping();
    
    try {
      await _chatService.sendMessage(
        widget.communityId, 
        widget.sessionId, 
        widget.userId, 
        message,
        sequenceNumber: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      _showErrorMessage('Failed to send message');
    }
  }

  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    
    if (isCurrentlyTyping && !_isTyping) {
      _startTyping();
    } else if (!isCurrentlyTyping && _isTyping) {
      _stopTyping();
    }
    
    // Reset typing timer - stop typing after 2 seconds of inactivity
    _typingTimer?.cancel();
    if (isCurrentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _stopTyping();
        }
      });
    }
  }

  void _startTyping() {
    if (!_isTyping && _isOnline) {
      setState(() {
        _isTyping = true;
      });
      _chatService.setUserTyping(widget.communityId, widget.sessionId, widget.userId, true);
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      setState(() {
        _isTyping = false;
      });
      _chatService.setUserTyping(widget.communityId, widget.sessionId, widget.userId, false);
    }
  }

  void _markMessagesAsRead() {
    if (_messages.isNotEmpty && _isOnline) {
      final unreadMessages = _messages.where(
        (msg) => !msg.isSentByMe(widget.userId) && 
                 !msg.isReadBy(widget.userId)
      ).toList();
      
      for (final message in unreadMessages) {
        _chatService.markMessageAsRead(
          widget.communityId, 
          widget.sessionId, 
          message.messageId, 
          widget.userId
        );
      }
    }
  }

  Future<void> _requestIdentityReveal() async {
    if (!_canRevealIdentity) {
      _showErrorMessage('Identity can only be revealed after 3 days');
      return;
    }

    try {
      await _chatService.requestIdentityReveal(widget.communityId, widget.sessionId, widget.userId);
      _showSuccessMessage('Identity reveal request sent!');
    } catch (e) {
      _showErrorMessage('Failed to request identity reveal');
    }
  }

  Future<void> _processIdentityReveal() async {
    if (_currentSession == null) return;

    try {
      await _chatService.processIdentityReveal(
        widget.communityId,
        widget.sessionId,
        _currentSession!.participants,
      );
    } catch (e) {
      _showErrorMessage('Failed to process identity reveal');
    }
  }

  void _handleSessionEnd() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => LiveZoneScreen(
              communityId: widget.communityId,
              userId: widget.userId,
              username: widget.username,
            ),
          ),
        );
      }
    });
  }

  Future<void> _endChat() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'End Chat?',
          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to end this chat session? This will close the chat for both participants.',
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: const Color(0xFF6C63FF)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'End Chat',
              style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (shouldEnd == true) {
      try {
        await _chatService.endChat(widget.communityId, widget.sessionId, widget.userId);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LiveZoneScreen(
                communityId: widget.communityId,
                userId: widget.userId,
                username: widget.username,
              ),
            ),
          );
        }
      } catch (e) {
        _showErrorMessage('Failed to end chat');
      }
    }
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

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up before disposing
    _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, false);
    _stopTyping();
    
    _typingController.dispose();
    _messagesSubscription?.cancel();
    _sessionSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _partnerTypingSubscription?.cancel();
    _partnerOnlineSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Set user offline when leaving
        _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, false);
        _stopTyping();
        Navigator.pop(context);
        return false;
      },
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
            child: Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildMessagesList()),
                if (_partnerIsTyping) _buildTypingIndicator(),
                if (!_isSessionEnded) _buildMessageInput(),
                if (_isSessionEnded) _buildSessionEndedIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _typingAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'typing',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    SizedBox(width: 4),
                    ...List.generate(3, (index) {
                      return Container(
                        margin: EdgeInsets.symmetric(horizontal: 1),
                        child: AnimatedOpacity(
                          opacity: ((_typingAnimation.value + index * 0.3) % 1.0) > 0.5 ? 1.0 : 0.3,
                          duration: Duration(milliseconds: 100),
                          child: Text(
                            '.',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF6C63FF),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionEndedIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        border: Border(top: BorderSide(color: Colors.red.withOpacity(0.3))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text(
            'This chat session has ended',
            style: GoogleFonts.poppins(
              color: Colors.red,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF6C63FF).withOpacity(0.1),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF6C63FF).withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          // Anonymous avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentSession?.identityRevealed == true ? 'Identity Revealed' : 'Anonymous User',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSessionEnded 
                            ? Colors.grey 
                            : _partnerIsOnline 
                                ? const Color(0xFF4CAF50)
                                : Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSessionEnded 
                          ? 'Chat Ended' 
                          : _partnerIsOnline 
                              ? 'Online'
                              : 'Offline',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: _isSessionEnded 
                            ? Colors.grey 
                            : _partnerIsOnline 
                                ? const Color(0xFF4CAF50)
                                : Colors.orange,
                      ),
                    ),
                    if (_canRevealIdentity && !_isSessionEnded) ...[
                      const SizedBox(width: 12),
                      Text(
                        '• Can reveal identity',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xFF6C63FF),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Network status indicator
          if (!_isOnline)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.wifi_off,
                color: Colors.red,
                size: 16,
              ),
            ),
          
          // Reveal identity button
          if (_canRevealIdentity && !_hasRequestedReveal && !_isSessionEnded)
            IconButton(
              icon: const Icon(Icons.visibility, color: Color(0xFF6C63FF)),
              onPressed: _requestIdentityReveal,
              tooltip: 'Reveal Identity',
            ),
          
          // Show reveal status
          if ((_hasRequestedReveal || _partnerRequestedReveal) && !_isSessionEnded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _hasRequestedReveal && _partnerRequestedReveal
                    ? 'Revealing...'
                    : _hasRequestedReveal
                        ? 'Requested'
                        : 'Partner wants to reveal',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: const Color(0xFF6C63FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          
          // More options
          if (!_isSessionEnded)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white60),
              color: const Color(0xFF1A1A1A),
              onSelected: (value) {
                if (value == 'end') _endChat();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'end',
                  child: Row(
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Text('End Chat', style: GoogleFonts.poppins(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6C63FF).withOpacity(0.3),
                    const Color(0xFF9C88FF).withOpacity(0.1),
                  ],
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: Color(0xFF6C63FF),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Start the conversation!',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say hello to your anonymous chat partner',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white60,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.isSentByMe(widget.userId);
        final showTimestamp = _shouldShowTimestamp(index);
        final showDateSeparator = _shouldShowDateSeparator(index);
        
        return Column(
          children: [
            if (showDateSeparator) _buildDateSeparator(message.timestamp),
            if (showTimestamp) _buildTimestamp(message.timestamp),
            message.isSystemMessage 
              ? _buildSystemMessage(message)
              : _buildMessageBubble(message, isMe),
          ],
        );
      },
    );
  }

  Widget _buildSystemMessage(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF6C63FF).withOpacity(0.3),
            ),
          ),
          child: Text(
            message.message,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6C63FF),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    
    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];
    
    // Show timestamp if more than 5 minutes apart
    return currentMessage.timestamp.difference(previousMessage.timestamp).inMinutes >= 5;
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    
    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];
    
    // Show date separator if messages are on different days
    return !_isSameDay(currentMessage.timestamp, previousMessage.timestamp);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  Widget _buildDateSeparator(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.white24)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _formatDate(timestamp),
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.white24)),
        ],
      ),
    );
  }

  Widget _buildTimestamp(DateTime timestamp) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _formatTime(timestamp),
        style: GoogleFonts.poppins(
          fontSize: 10,
          color: Colors.white38,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // Widget _buildMessageBubble(ChatMessage message, bool isMe) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(vertical: 2),
  //     child: Row(
  //       mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
  //       crossAxisAlignment: CrossAxisAlignment.end,
  //       children: [
  //         if (!isMe) ...[
  //           Container(
  //             width: 30,
  //             height: 30,
  //             decoration: BoxDecoration(
  //               shape: BoxShape.circle,
  //               gradient: const LinearGradient(
  //                 colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
  //               ),
  //             ),
  //             child: const Icon(
  //               Icons.face_retouching_natural,
  //               color: Colors.white,
  //               size: 16,
  //             ),
  //           ),
  //           const SizedBox(width: 8),
  //         ],
          
  //         Flexible(
  //           child: Container(
  //             constraints: BoxConstraints(
  //               maxWidth: MediaQuery.of(context).size.width * 0.75,
  //             ),
  //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //             decoration: BoxDecoration(
  //               gradient: isMe
  //                   ? const LinearGradient(
  //                       colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
  //                     )
  //                   : LinearGradient(
  //                       colors: [
  //                         Colors.white.withOpacity(0.1),
  //                         Colors.white.withOpacity(0.05),
  //                       ],
  //                     ),
  //               borderRadius: BorderRadius.only(
  //                 topLeft: const Radius.circular(20),
  //                 topRight: const Radius.circular(20),
  //                 bottomLeft: Radius.circular(isMe ? 20 : 4),
  //                 bottomRight: Radius.circular(isMe ? 4 : 20),
  //               ),
  //               border: !isMe
  //                   ? Border.all(
  //                       color: const Color(0xFF6C63FF).withOpacity(0.2),
  //                     )
  //                   : null,
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   message.message,
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 14,
  //                     color: Colors.white,
  //                     height: 1.3,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 4),
  //                 Row(
  //                   mainAxisSize: MainAxisSize.min,
  //                   mainAxisAlignment: MainAxisAlignment.end,
  //                   children: [
  //                     Text(
  //                       _formatMessageTime(message.timestamp),
  //                       style: GoogleFonts.poppins(
  //                         fontSize: 10,
  //                         color: isMe ? Colors.white70 : Colors.white54,
  //                       ),
  //                     ),
  //                     if (isMe) ...[
  //                       const SizedBox(width: 4),
  //                       _buildMessageStatus(message),
  //                     ],
  //                   ],
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
          
  //         if (isMe) ...[
  //           const SizedBox(width: 8),
  //           Container(
  //             width: 30,
  //             height: 30,
  //             decoration: BoxDecoration(
  //               shape: BoxShape.circle,
  //               gradient: const LinearGradient(
  //                 colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
  //               ),
  //             ),
  //             child: const Icon(
  //               Icons.person,
  //               color: Colors.white,
  //               size: 16,
  //             ),
  //           ),
  //         ],
  //       ],
  //     ),
  //   );
  // }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
  final screenWidth = MediaQuery.of(context).size.width;
  final maxWidth = screenWidth < 360 ? screenWidth * 0.8 : screenWidth * 0.75;
  final isSmallScreen = screenWidth < 360;
  
  return Container(
    margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 1 : 2),
    child: Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          Container(
            width: isSmallScreen ? 25 : 30,
            height: isSmallScreen ? 25 : 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: isSmallScreen ? 12 : 16,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
        ],
        
        Flexible(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isSmallScreen ? 16 : 20),
                topRight: Radius.circular(isSmallScreen ? 16 : 20),
                bottomLeft: Radius.circular(isMe ? (isSmallScreen ? 16 : 20) : 4),
                bottomRight: Radius.circular(isMe ? 4 : (isSmallScreen ? 16 : 20)),
              ),
              border: !isMe
                  ? Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.2),
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 13 : 14,
                    color: Colors.white,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 2 : 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 9 : 10,
                        color: isMe ? Colors.white70 : Colors.white54,
                      ),
                    ),
                    if (isMe) ...[
                      SizedBox(width: isSmallScreen ? 3 : 4),
                      _buildMessageStatus(message),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        
        if (isMe) ...[
          SizedBox(width: isSmallScreen ? 6 : 8),
          Container(
            width: isSmallScreen ? 25 : 30,
            height: isSmallScreen ? 25 : 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: isSmallScreen ? 12 : 16,
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildMessageStatus(ChatMessage message) {
    // Check if message is read by partner
    bool isRead = message.readBy != null && 
                  message.readBy!.contains(widget.partnerId);
    
    // Check if message is delivered (exists in Firestore)
    bool isDelivered = message.messageId.isNotEmpty && message.status != 'sent';
    
    if (isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 12,
            color: const Color(0xFF4CAF50), // Green for read
          ),
          const SizedBox(width: 2),
          Text(
            'Read',
            style: GoogleFonts.poppins(
              fontSize: 8,
              color: const Color(0xFF4CAF50),
            ),
          ),
        ],
      );
    } else if (isDelivered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 12,
            color: Colors.white54, // Gray for delivered but not read
          ),
          const SizedBox(width: 2),
          Text(
            'Delivered',
            style: GoogleFonts.poppins(
              fontSize: 8,
              color: Colors.white54,
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done,
            size: 12,
            color: Colors.white38, // Light gray for sent
          ),
          const SizedBox(width: 2),
          Text(
            'Sent',
            style: GoogleFonts.poppins(
              fontSize: 8,
              color: Colors.white38,
            ),
          ),
        ],
      );
    }
  }

  // Widget _buildMessageInput() {
  //   return Container(
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [
  //           Colors.transparent,
  //           const Color(0xFF6C63FF).withOpacity(0.05),
  //         ],
  //       ),
  //       border: Border(
  //         top: BorderSide(
  //           color: const Color(0xFF6C63FF).withOpacity(0.2),
  //         ),
  //       ),
  //     ),
  //     child: Row(
  //       children: [
  //         Expanded(
  //           child: Container(
  //             decoration: BoxDecoration(
  //               color: Colors.white.withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(25),
  //               border: Border.all(
  //                 color: const Color(0xFF6C63FF).withOpacity(0.3),
  //               ),
  //             ),
  //             child: TextField(
  //               controller: _messageController,
  //               focusNode: _messageFocusNode,
  //               style: GoogleFonts.poppins(
  //                 color: Colors.white,
  //                 fontSize: 14,
  //               ),
  //               decoration: InputDecoration(
  //                 hintText: _isOnline ? 'Type a message...' : 'No internet connection',
  //                 hintStyle: GoogleFonts.poppins(
  //                   color: _isOnline ? Colors.white38 : Colors.red.withOpacity(0.7),
  //                   fontSize: 14,
  //                 ),
  //                 border: InputBorder.none,
  //                 contentPadding: const EdgeInsets.symmetric(
  //                   horizontal: 20,
  //                   vertical: 12,
  //                 ),
  //               ),
  //               maxLines: 4,
  //               minLines: 1,
  //               enabled: _isOnline,
  //               onChanged: (value) => _onTypingChanged(),
  //               onSubmitted: (value) => _sendMessage(),
  //             ),
  //           ),
  //         ),
  //         const SizedBox(width: 12),
          
  //         // Send button
  //         Container(
  //           width: 48,
  //           height: 48,
  //           decoration: BoxDecoration(
  //             shape: BoxShape.circle,
  //             gradient: _messageController.text.trim().isNotEmpty && _isOnline
  //                 ? const LinearGradient(
  //                     colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
  //                   )
  //                 : LinearGradient(
  //                     colors: [
  //                       Colors.white.withOpacity(0.1),
  //                       Colors.white.withOpacity(0.05),
  //                     ],
  //                   ),
  //           ),
  //           child: IconButton(
  //             icon: Icon(
  //               Icons.send,
  //               color: _messageController.text.trim().isNotEmpty && _isOnline
  //                   ? Colors.white
  //                   : Colors.white38,
  //               size: 20,
  //             ),
  //             onPressed: _messageController.text.trim().isNotEmpty && _isOnline ? _sendMessage : null,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildMessageInput() {
  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 360;
  
  return Container(
    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF6C63FF).withOpacity(0.05),
        ],
      ),
      border: Border(
        top: BorderSide(
          color: const Color(0xFF6C63FF).withOpacity(0.2),
        ),
      ),
    ),
    child: SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: isSmallScreen ? 80 : 100,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 20 : 25),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 13 : 14,
                ),
                decoration: InputDecoration(
                  hintText: _isOnline ? 'Type a message...' : 'No internet connection',
                  hintStyle: GoogleFonts.poppins(
                    color: _isOnline ? Colors.white38 : Colors.red.withOpacity(0.7),
                    fontSize: isSmallScreen ? 13 : 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20,
                    vertical: isSmallScreen ? 10 : 12,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                enabled: _isOnline,
                onChanged: (value) => _onTypingChanged(),
                onSubmitted: (value) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          
          // Send button
          Container(
            width: isSmallScreen ? 40 : 48,
            height: isSmallScreen ? 40 : 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _messageController.text.trim().isNotEmpty && _isOnline
                  ? const LinearGradient(
                      colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.send,
                color: _messageController.text.trim().isNotEmpty && _isOnline
                    ? Colors.white
                    : Colors.white38,
                size: isSmallScreen ? 18 : 20,
              ),
              onPressed: _messageController.text.trim().isNotEmpty && _isOnline ? _sendMessage : null,
            ),
          ),
        ],
      ),
    ),
  );
}


  String _formatDate(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  String _formatTime(DateTime timestamp) {
    return DateFormat('hh:mm a').format(timestamp);
  }

  String _formatMessageTime(DateTime timestamp) {
    return DateFormat('HH:mm').format(timestamp);
  }
}