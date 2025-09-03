// screens/chat_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:startup/home_components/anonymous_chat_landing.dart';
import 'package:startup/home_components/chat_models.dart';
import 'package:startup/home_components/chat_service.dart';
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

  bool _isNavigatingAway = false;
  final Map<String, ChatMessage> _pendingMessages = {};
  bool _isScrollingToBottom = false;
  
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
  bool _isDialogShowing = false;
  int _globalMessageSequence = 0;
  int _messageSequence = 0;
  Timer? _connectivityDebouncer;
  UserData? _partnerData;

  late AnimationController _messageAnimationController;
  late AnimationController _statusController;
  
  @override
  void initState() {
    super.initState();
    _initAnimations();
    _setupListeners();
    _setupConnectivity();
    _messageFocusNode.requestFocus();
    
    _chatService.startChat(widget.sessionId, widget.partnerId);
    _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
  _scrollToBottom();
  Timer(const Duration(milliseconds: 500), () {
  if (mounted) {
    _scrollToBottom();
  }
});
});
  }

void _initAnimations() {
  _typingController = AnimationController(
    duration: const Duration(milliseconds: 1500),
    vsync: this,
  )..repeat();
  
  _messageAnimationController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  
  _statusController = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );
  
  // IMPROVED: Smoother typing animation with better curves
  _typingAnimation = CurvedAnimation(
    parent: _typingController,
    curve: Curves.easeInOut,
  );
}

  void _handleKeyboardVisibility() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollToBottom();
    }
  });
}

  void _setupConnectivity() {
    _checkInitialConnectivity();
    
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _connectivityDebouncer?.cancel();
        _connectivityDebouncer = Timer(const Duration(milliseconds: 500), () {
          final isOnline = results.any((result) => 
              result == ConnectivityResult.wifi || 
              result == ConnectivityResult.mobile ||
              result == ConnectivityResult.ethernet);
          
          if (mounted && _isOnline != isOnline) {
            setState(() {
              _isOnline = isOnline;
            });
            
            _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, isOnline);
            
            if (isOnline) {
              _showSuccessMessage('Connection restored');
            } else {
              _showErrorMessage('Connection lost');
            }
          }
        });
      },
    );
  }

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
      
      _chatService.setUserOnline(widget.communityId, widget.sessionId, widget.userId, isOnline);
    } catch (e) {
      setState(() {
        _isOnline = true;
      });
    }
  }

  void _showRevealRequestBanner() {
    if (_partnerRequestedReveal && !_hasRequestedReveal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.visibility, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your chat partner wants to reveal identities!',
                  style: GoogleFonts.poppins(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6C63FF),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Reveal',
            textColor: Colors.white,
            onPressed: _requestIdentityReveal,
          ),
        ),
      );
    }
  }

  void _showSimplifiedIdentityDialog() {
    if (_isDialogShowing) return;
    
    _isDialogShowing = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
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
                Icons.visibility,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'identity revealed!',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.1),
                      const Color(0xFF9C88FF).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Chat Partner Identity Revealed!',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    Text(
                      'You can now see each other\'s real identities in the chat.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The chat has ended and been saved to your history.',
                        style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isDialogShowing = false;
              Navigator.pop(context);
            },
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  void _setupListeners() {
    _messagesSubscription = _chatService.listenToMessages(widget.communityId, widget.sessionId).listen(
      (messages) {
        if (mounted) {
          setState(() {
        for (final message in messages) {
  _pendingMessages.removeWhere((tempId, pendingMsg) {
    // Remove by sequence number if both have it
    if (pendingMsg.sequenceNumber != null && message.sequenceNumber != null) {
      return pendingMsg.sequenceNumber == message.sequenceNumber;
    }
    
    // Remove by content match for same sender (more reliable)
    return pendingMsg.senderId == message.senderId && 
           pendingMsg.message == message.message &&
           message.timestamp.difference(pendingMsg.timestamp).abs().inSeconds < 10; // Increased tolerance
  });
}

final allMessages = <ChatMessage>[...messages];

// Only add pending messages that don't match any server message
for (final pendingMessage in _pendingMessages.values) {
  final isDuplicate = allMessages.any((msg) => 
      (msg.sequenceNumber != null && pendingMessage.sequenceNumber != null && 
       msg.sequenceNumber == pendingMessage.sequenceNumber) ||
      (msg.senderId == pendingMessage.senderId && 
       msg.message == pendingMessage.message &&
       msg.timestamp.difference(pendingMessage.timestamp).abs().inSeconds < 10));
  
  if (!isDuplicate) {
    allMessages.add(pendingMessage);
  }
}
            
            allMessages.sort((a, b) {
              if (a.sequenceNumber != null && b.sequenceNumber != null) {
                final seqCompare = a.sequenceNumber!.compareTo(b.sequenceNumber!);
                if (seqCompare != 0) return seqCompare;
              }
              
              if (a.sequenceNumber != null && b.sequenceNumber != null) {
                final serverCompare = a.sequenceNumber!.compareTo(b.sequenceNumber!);
                if (serverCompare != 0) return serverCompare;
              }
              
              final timestampCompare = a.timestamp.compareTo(b.timestamp);
              if (timestampCompare != 0) return timestampCompare;
              
              return a.messageId.compareTo(b.messageId);
            });
            
            _messages = allMessages;
            if (_messages.isNotEmpty) {
              final maxSequence = _messages
                  .where((m) => m.sequenceNumber != null)
                  .map((m) => m.sequenceNumber!)
                  .fold(0, (max, seq) => seq > max ? seq : max);
              _globalMessageSequence = maxSequence;
            }
          });
          _scrollToBottom();
          _markMessagesAsRead();
        }
      },
      onError: (error) {
        debugPrint('Error listening to messages: $error');
      },
    );

    _sessionSubscription = _chatService.listenToSession(widget.communityId, widget.sessionId).listen(
      (session) {
        if (mounted && session != null) {
          final wasIdentityRevealed = _currentSession?.identityRevealed ?? false;
          final wasSessionEnded = _currentSession?.status == 'ended';
          
          setState(() {
            _currentSession = session;
            _canRevealIdentity = session.canRevealIdentity();
            _hasRequestedReveal = session.revealRequests[widget.userId] ?? false;
            _partnerRequestedReveal = session.revealRequests[widget.partnerId] ?? false;
            _isSessionEnded = session.status == 'ended';
            _partnerIsOnline = session.isUserOnline(widget.partnerId);
          });

          if (_hasRequestedReveal && _partnerRequestedReveal && !session.identityRevealed) {
            _processIdentityReveal();
          }

          if (session.identityRevealed && !wasIdentityRevealed) {
            _showIdentityRevealedMessage();
            _fetchPartnerData();
            
            if (_partnerData != null && !_isDialogShowing) {
              _showIdentityRevealDialog();
            } else {
              Future.delayed(const Duration(milliseconds: 1000), () {
                if (mounted && _partnerData != null && !_isDialogShowing && !_isNavigatingAway) {
                  _showIdentityRevealDialog();
                } else {
                  _showSimplifiedIdentityDialog();
                }
              });
            }
            
            if (session.status == 'ended') {
              Future.delayed(const Duration(seconds: 6), () {
                if (mounted) {
                  _isNavigatingAway = true;
                  Future.delayed(const Duration(seconds: 2), () {
                    if (mounted) {
                      _handleSessionEnd();
                    }
                  });
                }
              });
            }
          }
          else if (session.status == 'ended' && !wasSessionEnded && !session.identityRevealed && !_isNavigatingAway) {
            _handleSessionEnd();
          }
        }
      },
      onError: (error) {
        debugPrint('Error listening to session: $error');
      },
    );

    _partnerTypingSubscription = _chatService.listenToUserTyping(
      widget.communityId, 
      widget.sessionId, 
      widget.partnerId
    ).listen(
      (isTyping) {
        if (mounted && _partnerIsTyping != isTyping) {
          setState(() {
            _partnerIsTyping = isTyping;
          });
          _handleKeyboardVisibility();
        }
      },
    );

    _partnerOnlineSubscription = _chatService.listenToUserOnline(
      widget.communityId, 
      widget.sessionId, 
      widget.partnerId
    ).listen(
      (isOnline) {
        if (mounted && _partnerIsOnline != isOnline) {
          setState(() {
            _partnerIsOnline = isOnline;
          });
        }
      },
    );
  }

  String _getPartnerDisplayName() {
    if (_currentSession?.identityRevealed == true && _partnerData != null) {
      final firstName = _partnerData!.firstName.isNotEmpty ? _partnerData!.firstName : 'User';
      final lastName = _partnerData!.lastName.isNotEmpty ? _partnerData!.lastName : '';
      return lastName.isNotEmpty ? '$firstName $lastName' : firstName;
    } else if (_currentSession?.identityRevealed == true) {
      return 'Identity Revealed';
    }
    return 'Anonymous User';
  }

  void _scrollToBottom({bool forceImmediate = false}) {
  if (_isScrollingToBottom && !forceImmediate) return;
  
  _isScrollingToBottom = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients && mounted) {
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        _scrollController.animateTo(
          maxExtent,
          duration: Duration(milliseconds: forceImmediate ? 50 : 100),
          curve: Curves.easeOut,
        ).then((_) {
          _isScrollingToBottom = false;
        }).catchError((_) {
          _isScrollingToBottom = false;
        });
      } else {
        _isScrollingToBottom = false;
      }
    } else {
      _isScrollingToBottom = false;
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

  // FIXED: Race condition prevention
  final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}';
  final sequenceNumber = ++_globalMessageSequence;
  final timestamp = DateTime.now();
  
  // Clear input immediately for better UX
  _messageController.clear();
  _stopTyping();
  
  // FIXED: Create optimistic message with unique temp ID
  final optimisticMessage = ChatMessage(
    messageId: tempId,
    senderId: widget.userId,
    message: message,
    timestamp: timestamp,
    sequenceNumber: sequenceNumber,
    status: 'sending',
  );
  
  // Add to pending messages immediately
  setState(() {
    _pendingMessages[tempId] = optimisticMessage;
  });
  _scrollToBottom();
  
  try {
    // Send message with retry logic
    await _sendMessageWithRetry(message, sequenceNumber, tempId);
  } catch (e) {
    // Remove failed message and show error
    setState(() {
      _pendingMessages.remove(tempId);
    });
    _showErrorMessage('Failed to send message');
    // Restore message to input for retry
    _messageController.text = message;
  }
}
Future<void> _sendMessageWithRetry(String message, int sequenceNumber, String tempId, {int retryCount = 0}) async {
  const maxRetries = 3;
  const retryDelay = Duration(seconds: 1);
  
  try {
    await _chatService.sendMessage(
      widget.communityId, 
      widget.sessionId, 
      widget.userId, 
      message,
      sequenceNumber: sequenceNumber,
    ).timeout(const Duration(seconds: 10)); // Add timeout
    
    // Message sent successfully, it will be handled by the stream listener
    
  } catch (e) {
    if (retryCount < maxRetries) {
      // Update pending message status
      if (_pendingMessages.containsKey(tempId)) {
        setState(() {
          _pendingMessages[tempId] = _pendingMessages[tempId]!.copyWith(
            status: 'retrying'
          );
        });
      }
      
      await Future.delayed(retryDelay);
      return _sendMessageWithRetry(message, sequenceNumber, tempId, retryCount: retryCount + 1);
    } else {
      rethrow; // Max retries exceeded
    }
  }
}


  void _onTypingChanged() {
    final isCurrentlyTyping = _messageController.text.isNotEmpty;
    
    if (isCurrentlyTyping && !_isTyping) {
      _startTyping();
    } else if (!isCurrentlyTyping && _isTyping) {
      _stopTyping();
    }
    
    _typingTimer?.cancel();
    if (isCurrentlyTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          _stopTyping();
        }
      });
    }
    _maintainKeyboardFocus();
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

  Timer? _readMarkingTimer;

  void _markMessagesAsRead() {
    _readMarkingTimer?.cancel();
    _readMarkingTimer = Timer(const Duration(milliseconds: 500), () {
      if (_messages.isNotEmpty && _isOnline && mounted) {
        final unreadMessages = _messages.where(
          (msg) => !msg.isSentByMe(widget.userId) && 
                   !msg.isReadBy(widget.userId) &&
                   !msg.messageId.startsWith('temp_')
        ).toList();
        
        for (final message in unreadMessages) {
          _chatService.markMessageAsRead(
            widget.communityId, 
            widget.sessionId, 
            message.messageId, 
            widget.userId
          ).catchError((e) {
            debugPrint('Error marking message as read: $e');
          });
        }
      }
    });
  }

  Future<void> _requestIdentityReveal() async {
    if (!_canRevealIdentity) {
      _showErrorMessage('Identity can only be revealed after 3 days');
      return;
    }

    final shouldReveal = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.visibility, color: const Color(0xFF6C63FF), size: 24),
            const SizedBox(width: 8),
            Text(
              'Reveal Identity?',
              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reveal your identity to your chat partner?',
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: const Color(0xFF6C63FF), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Once identities are revealed, the chat will end and be saved to your history.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6C63FF),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.white60),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Reveal Identity',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldReveal == true) {
      try {
        await _chatService.requestIdentityReveal(widget.communityId, widget.sessionId, widget.userId);
        _showSuccessMessage('Identity reveal request sent!');
      } catch (e) {
        _showErrorMessage('Failed to request identity reveal');
      }
    }
  }

  void _showIdentityRevealDialog() {
    if (_partnerData == null || _isDialogShowing) {
      return;
    }
    
    _isDialogShowing = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
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
                Icons.visibility,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Identity Revealed!',
                style: GoogleFonts.dmSerifDisplay(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.1),
                      const Color(0xFF9C88FF).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
                        ),
                      ),
                      child: _partnerData!.profileImageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                _partnerData!.profileImageUrl!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 40,
                                  );
                                },
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 40,
                            ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      _getPartnerDisplayName(),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildDetailRow('Branch', _partnerData!.branch),
                    const SizedBox(height: 8),
                    _buildDetailRow('Year', _partnerData!.year),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The chat has ended and been saved to your history.',
                        style: GoogleFonts.poppins(
                          color: Colors.orange,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isDialogShowing = false;
              Navigator.pop(context);
            },
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C63FF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white60,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6C63FF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value.isNotEmpty ? value : 'Not specified',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
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

  void _maintainKeyboardFocus() {
  if (!_messageFocusNode.hasFocus && !_isSessionEnded) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && !_isSessionEnded) {
        _messageFocusNode.requestFocus();
      }
    });
  }
}

  void _showIdentityRevealedMessage() {
    if (_currentSession != null && _currentSession!.identityRevealed) {
      final hasRevealMessage = _messages.any((msg) => 
          msg.messageId.contains('identity_reveal') && msg.isSystemMessage);
      
      if (!hasRevealMessage) {
        final revealMessage = ChatMessage(
          messageId: 'identity_reveal_${DateTime.now().millisecondsSinceEpoch}',
          senderId: 'system',
          message: 'Identities have been revealed! You can now see each other\'s real names.',
          timestamp: DateTime.now(),
          isSystemMessage: true,
        );
        
        setState(() {
          _messages.add(revealMessage);
        });
        _scrollToBottom();
      }
    }
  }

  void _handleSessionEnd() {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AnonymousChatLanding(
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

  Future<void> _fetchPartnerData() async {
    if (_currentSession?.identityRevealed == true && _partnerData == null) {
      try {
        final partnerId = _currentSession!.getPartnerId(widget.userId);
        
        final partnerDoc = await FirebaseFirestore.instance
            .collection('communities')
            .doc(widget.communityId)
            .collection('live_zone')
            .doc(partnerId)
            .get();
        
        if (partnerDoc.exists) {
          final data = partnerDoc.data() as Map<String, dynamic>;
          
          setState(() {
            _partnerData = UserData.fromMap(data['userData'] ?? {});
          });
        }
      } catch (e) {
        debugPrint('Error fetching partner data: $e');
      }
    }
  }

  @override
  void dispose() {
    _isNavigatingAway = true;
    _isDialogShowing = false;
    
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
    _messageAnimationController.dispose();
    _statusController.dispose();
    _connectivityDebouncer?.cancel();
    _readMarkingTimer?.cancel();
    _pendingMessages.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
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
                if (_partnerIsTyping && !(_currentSession?.identityRevealed ?? false)) 
                  _buildTypingIndicator(),
                if (!_isSessionEnded && !(_currentSession?.identityRevealed ?? false)) 
                  _buildMessageInput(),
                if (_currentSession?.identityRevealed == true) 
                  _buildIdentityRevealedInput(),
                if (_isSessionEnded) 
                  _buildSessionEndedIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: 14,
            ),
          ),
          const SizedBox(width: 12),
          AnimatedBuilder(
            animation: _typingAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
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
                    const SizedBox(width: 4),
                    ...List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        child: Text(
                          '•',
                          style: GoogleFonts.poppins(
                            color: ((_typingAnimation.value + index * 0.3) % 1.0) > 0.5 
                                ? const Color(0xFF6C63FF) 
                                : Colors.white24,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isTablet = screenWidth > 600;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : (isSmallScreen ? 12 : 16),
        vertical: isSmallScreen ? 12 : 16,
      ),
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     colors: [
      //       const Color(0xFF6C63FF).withOpacity(0.1),
      //       Colors.transparent,
      //     ],
      //   ),
      //   border: Border(
      //     bottom: BorderSide(
      //       color: const Color(0xFF6C63FF).withOpacity(0.2),
      //     ),
      //   ),
      // ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back, 
              color: Colors.white, 
              size: isSmallScreen ? 20 : 24
            ),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          Container(
            width: isSmallScreen ? 32 : (isTablet ? 40 : 36),
            height: isSmallScreen ? 32 : (isTablet ? 40 : 36),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: isSmallScreen ? 16 : (isTablet ? 20 : 18),
            ),
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentSession?.identityRevealed == true 
                      ? _getPartnerDisplayName() 
                      : 'Anonymous User',
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 13 : (isTablet ? 16 : 14),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 5 : 6,
                      height: isSmallScreen ? 5 : 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSessionEnded 
                            ? Colors.grey 
                            : _partnerIsOnline 
                                ? const Color(0xFF4CAF50)
                                : Colors.orange,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 3 : 4),
                    Flexible(
                      child: Text(
                        _isSessionEnded 
                            ? 'Chat Ended' 
                            : _partnerIsOnline 
                                ? 'Online'
                                : 'Offline',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 9 : 10,
                          color: _isSessionEnded 
                              ? Colors.grey 
                              : _partnerIsOnline 
                                  ? const Color(0xFF4CAF50)
                                  : Colors.orange,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_isOnline) ...[
            Icon(
              Icons.wifi_off, 
              color: Colors.red, 
              size: isSmallScreen ? 12 : 14
            ),
            SizedBox(width: isSmallScreen ? 3 : 4),
          ],
          if (_canRevealIdentity && !_hasRequestedReveal && !_isSessionEnded && !(_currentSession?.identityRevealed ?? false))
            IconButton(
              icon: Icon(
                Icons.visibility, 
                color: const Color(0xFF6C63FF), 
                size: isSmallScreen ? 18 : 20
              ),
              onPressed: _requestIdentityReveal,
              tooltip: 'Reveal Identity',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: isSmallScreen ? 28 : 32, 
                minHeight: isSmallScreen ? 28 : 32
              ),
            ),
          if ((_hasRequestedReveal || _partnerRequestedReveal) && !_isSessionEnded && !(_currentSession?.identityRevealed ?? false))
            Container(
              constraints: BoxConstraints(maxWidth: isSmallScreen ? 80 : 100),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6C63FF),
                    Color(0xFF9C88FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: isSmallScreen ? 12 : 14,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _hasRequestedReveal && _partnerRequestedReveal
                        ? 'Revealing...'
                        : _hasRequestedReveal
                            ? 'You requested'
                            : 'Partner wants reveal',
                    style: GoogleFonts.poppins(
                      fontSize: isSmallScreen ? 8 : 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          if (!_isSessionEnded && !(_currentSession?.identityRevealed ?? false))
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert, 
                color: Colors.white60, 
                size: isSmallScreen ? 16 : 18
              ),
              color: const Color(0xFF1A1A1A),
              onSelected: (value) {
                if (value == 'end') _endChat();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'end',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.close, color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'End Chat', 
                        style: GoogleFonts.poppins(
                          color: Colors.white, 
                          fontSize: 12
                        )
                      ),
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
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 600 ? 24 : 8,
        vertical: 16,
      ),
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
    
    return currentMessage.timestamp.difference(previousMessage.timestamp).inMinutes >= 5;
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    
    final currentMessage = _messages[index];
    final previousMessage = _messages[index - 1];
    
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
          const Expanded(child: Divider(color: Colors.white24)),
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
          const Expanded(child: Divider(color: Colors.white24)),
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

Widget _buildMessageBubble(ChatMessage message, bool isMe) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  final isTablet = screenWidth > 600;
  final isSmallScreen = screenWidth < 360;
  
  // Responsive sizing
  final avatarSize = isSmallScreen ? 24.0 : (isTablet ? 35.0 : 30.0);
  // FIXED: Better max width calculation to prevent full-width bubbles
  final maxBubbleWidth = isTablet 
      ? screenWidth * 0.65 
      : isSmallScreen 
          ? screenWidth * 0.75  // Reduced from 0.82
          : screenWidth * 0.70;  // Reduced from 0.78
  final minBubbleWidth = screenWidth * 0.15; // Minimum width for short messages
  final horizontalPadding = isSmallScreen ? 12.0 : (isTablet ? 20.0 : 16.0);
  final verticalPadding = isSmallScreen ? 8.0 : (isTablet ? 14.0 : 10.0);
  final borderRadius = isSmallScreen ? 16.0 : (isTablet ? 24.0 : 20.0);
  final fontSize = isSmallScreen ? 13.0 : (isTablet ? 16.0 : 14.0);
  
  return Container(
    margin: EdgeInsets.symmetric(
      vertical: isSmallScreen ? 2 : 3, // Slightly increased for better spacing
      horizontal: isTablet ? 8 : 4,
    ),
    child: Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMe) ...[
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: Icon(
              Icons.face_retouching_natural,
              color: Colors.white,
              size: avatarSize * 0.5,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : (isTablet ? 12 : 8)),
        ],
        
        // FIXED: Improved flexible layout with proper constraints
        Flexible(
          child: IntrinsicWidth(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxBubbleWidth,
                minWidth: minBubbleWidth,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), // Smooth appearance
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
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
                    topLeft: Radius.circular(borderRadius),
                    topRight: Radius.circular(borderRadius),
                    bottomLeft: Radius.circular(isMe ? borderRadius : 4),
                    bottomRight: Radius.circular(isMe ? 4 : borderRadius),
                  ),
                  border: !isMe
                      ? Border.all(
                          color: const Color(0xFF6C63FF).withOpacity(0.2),
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: (isMe ? const Color(0xFF6C63FF) : Colors.black)
                          .withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // FIXED: Better text layout with proper wrapping
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: maxBubbleWidth - (horizontalPadding * 2),
                      ),
                      child: Text(
                        message.message,
                        style: GoogleFonts.poppins(
                          fontSize: fontSize,
                          color: Colors.white,
                          height: 1.3, // Improved line height
                        ),
                        softWrap: true,
                        textWidthBasis: TextWidthBasis.longestLine,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : (isTablet ? 8 : 6)),
                    // Status row
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _formatMessageTime(message.timestamp),
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 9 : (isTablet ? 11 : 10),
                            color: isMe ? Colors.white70 : Colors.white54,
                          ),
                        ),
                        if (isMe) ...[
                          SizedBox(width: isSmallScreen ? 3 : (isTablet ? 6 : 4)),
                          _buildMessageStatus(message),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        if (isMe) ...[
          SizedBox(width: isSmallScreen ? 6 : (isTablet ? 12 : 8)),
          Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
              ),
            ),
            child: Icon(
              Icons.person,
              color: Colors.white,
              size: avatarSize * 0.5,
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildMessageStatus(ChatMessage message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final iconSize = isSmallScreen ? 10.0 : 12.0;
    final fontSize = isSmallScreen ? 7.0 : 8.0;
    
    bool isRead = message.readBy != null && 
                  message.readBy!.contains(widget.partnerId);
    bool isDelivered = message.messageId.isNotEmpty && message.status != 'sent';
    
    if (isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: iconSize,
            color: const Color(0xFF4CAF50),
          ),
          const SizedBox(width: 2),
          Text(
            'Read',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
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
            size: iconSize,
            color: Colors.white54,
          ),
          const SizedBox(width: 2),
          Text(
            'Delivered',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
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
            size: iconSize,
            color: Colors.white38,
          ),
          const SizedBox(width: 2),
          Text(
            'Sent',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              color: Colors.white38,
            ),
          ),
        ],
      );
    }
  }

    Widget _buildMessageInput() {
  final screenWidth = MediaQuery.of(context).size.width;
  final isSmallScreen = screenWidth < 360;
  
  return GestureDetector(
  onTap: () => _messageFocusNode.requestFocus(),
  child: Container(
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
  ),
  );
}

Widget _buildIdentityRevealedInput() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF6C63FF).withOpacity(0.1),
      border: Border(
        top: BorderSide(
          color: const Color(0xFF6C63FF).withOpacity(0.3),
        ),
      ),
    ),
    child: SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.visibility, color: const Color(0xFF6C63FF), size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Identities revealed! You can now see each other. Chat has ended.',
              style: GoogleFonts.poppins(
                color: const Color(0xFF6C63FF),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
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