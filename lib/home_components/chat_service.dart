// services/chat_service.dart - COMPLETE WORKING VERSION

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:startup/home_components/chat_models.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _currentSessionId;
  String? _currentPartnerId;
  bool _isInChat = false;
  
  // Getters
  bool get isInChat => _isInChat;
  String? get currentSessionId => _currentSessionId;
  String? get currentPartnerId => _currentPartnerId;

  // Collections references
  CollectionReference _liveZoneRef(String communityId) =>
      _firestore.collection('communities').doc(communityId).collection('live_zone');
  
  CollectionReference _chatSessionsRef(String communityId) =>
      _firestore.collection('communities').doc(communityId).collection('chat_sessions');
  
  CollectionReference _messagesRef(String communityId, String sessionId) =>
      _chatSessionsRef(communityId).doc(sessionId).collection('messages');
  
  CollectionReference _chatHistoryRef(String communityId, String userId) =>
      _firestore.collection('communities').doc(communityId)
          .collection('user_chat_history').doc(userId).collection('sessions');

  // Get live zone count
  Stream<int> getLiveZoneCount(String communityId) {
    return _liveZoneRef(communityId)
        .where('status', whereIn: ['waiting', 'paired'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Check if user has active session
  Future<ChatSession?> getActiveSession(String communityId, String userId) async {
    try {
      final userDoc = await _liveZoneRef(communityId).doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['status'] == 'paired' && data['sessionId'] != null) {
          final sessionDoc = await _chatSessionsRef(communityId).doc(data['sessionId']).get();
          if (sessionDoc.exists) {
            final session = ChatSession.fromFirestore(sessionDoc);
            if (session.status == 'active') {
              return session;
            }
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error checking active session: $e');
      return null;
    }
  }

  // Get user data from global users collection
 Future<UserData> _fetchUserData(String communityId, String username) async {
  try {
    // First try to get from members collection
    final membersQuery = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (membersQuery.docs.isNotEmpty) {
      final userData = membersQuery.docs.first.data();
      return UserData(
        branch: userData['branch'] ?? '',
        year: userData['year'] ?? '',
        profileImageUrl: userData['profileImageUrl'],
        firstName: userData['firstName'] ?? '',
        lastName: userData['lastName'] ?? '',
      );
    }

    // If not found in members, try trio collection
    final trioQuery = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('trio')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (trioQuery.docs.isNotEmpty) {
      final userData = trioQuery.docs.first.data();
      return UserData(
        branch: userData['branch'] ?? '',
        year: userData['year'] ?? '',
        profileImageUrl: userData['profileImageUrl'],
        firstName: userData['firstName'] ?? '',
        lastName: userData['lastName'] ?? '',
      );
    }
    
    throw Exception('User not found in community');
  } catch (e) {
    throw Exception('Failed to fetch user data: $e');
  }
}

// Update the joinLiveZone method call to include communityId:
Future<void> joinLiveZone(String communityId, String userId, String username) async {
  try {
    // Check if user already has an active session
    final activeSession = await getActiveSession(communityId, userId);
    if (activeSession != null) {
      // User already in a session, set local state
      _currentSessionId = activeSession.sessionId;
      _currentPartnerId = activeSession.getPartnerId(userId);
      _isInChat = true;
      throw Exception('ACTIVE_SESSION_EXISTS');
    }

    // Fetch user data - UPDATED LINE
    final userData = await _fetchUserData(communityId, username);

    // Add user to live zone
    final liveZoneUser = LiveZoneUser(
      userId: userId,
      username: username,
      status: 'waiting',
      joinedAt: DateTime.now(),
      userData: userData,
    );

    await _liveZoneRef(communityId).doc(userId).set(liveZoneUser.toFirestore());
    
    // Try to find a match immediately
    _attemptPairing(communityId, userId);
  } catch (e) {
    if (e.toString().contains('ACTIVE_SESSION_EXISTS')) {
      rethrow;
    }
    throw Exception('Failed to join live zone: $e');
  }
}

  // Join live zone
  // Future<void> joinLiveZone(String communityId, String userId, String username) async {
  //   try {
  //     // Check if user already has an active session
  //     final activeSession = await getActiveSession(communityId, userId);
  //     if (activeSession != null) {
  //       // User already in a session, set local state
  //       _currentSessionId = activeSession.sessionId;
  //       _currentPartnerId = activeSession.getPartnerId(userId);
  //       _isInChat = true;
  //       throw Exception('ACTIVE_SESSION_EXISTS');
  //     }

  //     // Fetch user data
  //     final userData = await _fetchUserData(username);

  //     // Add user to live zone
  //     final liveZoneUser = LiveZoneUser(
  //       userId: userId,
  //       username: username,
  //       status: 'waiting',
  //       joinedAt: DateTime.now(),
  //       userData: userData,
  //     );

  //     await _liveZoneRef(communityId).doc(userId).set(liveZoneUser.toFirestore());
      
  //     // Try to find a match immediately
  //     _attemptPairing(communityId, userId);
  //   } catch (e) {
  //     if (e.toString().contains('ACTIVE_SESSION_EXISTS')) {
  //       rethrow;
  //     }
  //     throw Exception('Failed to join live zone: $e');
  //   }
  // }

  // Leave live zone
  Future<void> leaveLiveZone(String communityId, String userId) async {
    try {
      await _liveZoneRef(communityId).doc(userId).update({
        'status': 'offline',
        'pairedWith': null,
        'sessionId': null,
      });
    } catch (e) {
      debugPrint('Error leaving live zone: $e');
    }
  }

  // Attempt to pair with another user
  Future<void> _attemptPairing(String communityId, String currentUserId) async {
    try {
      final availableUsersQuery = await _liveZoneRef(communityId)
          .where('status', isEqualTo: 'waiting')
          .where(FieldPath.documentId, isNotEqualTo: currentUserId)
          .limit(1)
          .get();

      if (availableUsersQuery.docs.isEmpty) {
        debugPrint('No available users for pairing');
        return;
      }

      final targetUser = availableUsersQuery.docs.first;
      final targetUserId = targetUser.id;

      await _firestore.runTransaction((transaction) async {
        final currentUserDoc = await transaction.get(_liveZoneRef(communityId).doc(currentUserId));
        final targetUserDoc = await transaction.get(_liveZoneRef(communityId).doc(targetUserId));

        if (!currentUserDoc.exists || !targetUserDoc.exists) {
          throw Exception('One or both users no longer exist');
        }

        final currentUserData = currentUserDoc.data() as Map<String, dynamic>?;
        final targetUserData = targetUserDoc.data() as Map<String, dynamic>?;

        if (currentUserData == null || targetUserData == null) {
          throw Exception('User data is null');
        }

        if (currentUserData['status'] != 'waiting' || targetUserData['status'] != 'waiting') {
          throw Exception('Users are no longer available for pairing');
        }

        final sessionId = _generateSessionId();
        final now = DateTime.now();
        final session = ChatSession(
          sessionId: sessionId,
          participants: [currentUserId, targetUserId],
          createdAt: now,
          status: 'active',
          revealRequests: {},
          identityRevealed: false,
          onlineStatus: {
            currentUserId: true,
            targetUserId: true,
          },
          typingStatus: {
            currentUserId: false,
            targetUserId: false,
          },
          lastSeen: {
            currentUserId: now,
            targetUserId: now,
          },
        );

        transaction.set(_chatSessionsRef(communityId).doc(sessionId), session.toFirestore());
        
        transaction.update(_liveZoneRef(communityId).doc(currentUserId), {
          'status': 'paired',
          'pairedWith': targetUserId,
          'sessionId': sessionId,
        });
        
        transaction.update(_liveZoneRef(communityId).doc(targetUserId), {
          'status': 'paired',
          'pairedWith': currentUserId,
          'sessionId': sessionId,
        });

        debugPrint('Successfully paired users: $currentUserId and $targetUserId');
      });
    } catch (e) {
      debugPrint('Pairing failed: $e');
    }
  }

  // Listen to user's live zone status
  Stream<LiveZoneUser?> listenToUserStatus(String communityId, String userId) {
    return _liveZoneRef(communityId).doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LiveZoneUser.fromFirestore(doc);
    });
  }

  // Start chat session
  void startChat(String sessionId, String partnerId) {
    _currentSessionId = sessionId;
    _currentPartnerId = partnerId;
    _isInChat = true;
  }

  // Set user online/offline status
  Future<void> setUserOnline(
    String communityId,
    String sessionId,
    String userId,
    bool isOnline,
  ) async {
    try {
      final updates = <String, dynamic>{
        'onlineStatus.$userId': isOnline,
        'lastSeen.$userId': FieldValue.serverTimestamp(),
      };
      
      if (!isOnline) {
        updates['typingStatus.$userId'] = false;
      }

      await _chatSessionsRef(communityId).doc(sessionId).update(updates);
    } catch (e) {
      debugPrint('Error setting user online status: $e');
    }
  }

  // Set user typing status
  Future<void> setUserTyping(
    String communityId,
    String sessionId,
    String userId,
    bool isTyping,
  ) async {
    try {
      await _chatSessionsRef(communityId).doc(sessionId).update({
        'typingStatus.$userId': isTyping,
        'lastSeen.$userId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error setting user typing status: $e');
    }
  }

  // Listen to specific user's typing status
  Stream<bool> listenToUserTyping(String communityId, String sessionId, String userId) {
    return _chatSessionsRef(communityId).doc(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data() as Map<String, dynamic>?;
      final typingStatus = data?['typingStatus'] as Map<String, dynamic>?;
      return typingStatus?[userId] ?? false;
    });
  }

  // Listen to specific user's online status
  Stream<bool> listenToUserOnline(String communityId, String sessionId, String userId) {
    return _chatSessionsRef(communityId).doc(sessionId).snapshots().map((snapshot) {
      if (!snapshot.exists) return false;
      final data = snapshot.data() as Map<String, dynamic>?;
      final onlineStatus = data?['onlineStatus'] as Map<String, dynamic>?;
      return onlineStatus?[userId] ?? false;
    });
  }

  // FIXED: Send message with proper ordering using timestamp + microseconds
  Future<void> sendMessage(
    String communityId, 
    String sessionId, 
    String senderId, 
    String message, {
    int? sequenceNumber,
  }) async {
    try {
      final docRef = _messagesRef(communityId, sessionId).doc();
      final now = DateTime.now();
      
      // Create unique ordering number using microseconds since epoch
      // This ensures proper ordering even for messages sent in quick succession
      final orderingNumber = now.microsecondsSinceEpoch;
      
      final chatMessage = ChatMessage(
        messageId: docRef.id,
        senderId: senderId,
        message: message.trim(),
        timestamp: now,
        sequenceNumber: orderingNumber, // Use microseconds for precise ordering
        readBy: [senderId], // Sender has "read" their own message
        status: 'sent',
      );

      // Use batch write for better performance
      final batch = _firestore.batch();
      
      // Add message
      batch.set(docRef, chatMessage.toFirestore());
      
      // Update session last activity
      batch.update(_chatSessionsRef(communityId).doc(sessionId), {
        'lastActivity': FieldValue.serverTimestamp(),
        'lastMessage': message,
        'lastMessageSender': senderId,
        'lastSeen.$senderId': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      
      // Mark as delivered after successful send
      await _markMessageAsDelivered(communityId, sessionId, docRef.id);
      
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  // FIXED: Listen to messages with proper ordering
  Stream<List<ChatMessage>> listenToMessages(String communityId, String sessionId) {
    return _messagesRef(communityId, sessionId)
        .orderBy('sequenceNumber', descending: false) // Primary ordering by sequence number
        .snapshots()
        .map((snapshot) {
      final messages = snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList();
      
      // Additional safety sort (shouldn't be needed with proper sequence numbers)
      messages.sort((a, b) {
        // Primary sort by sequence number
        if (a.sequenceNumber != null && b.sequenceNumber != null) {
          return a.sequenceNumber!.compareTo(b.sequenceNumber!);
        }
        
        // Fallback to timestamp
        return a.timestamp.compareTo(b.timestamp);
      });
      
      return messages;
    });
  }

  // Mark message as delivered
  Future<void> _markMessageAsDelivered(
    String communityId,
    String sessionId,
    String messageId,
  ) async {
    try {
      await _messagesRef(communityId, sessionId).doc(messageId).update({
        'status': 'delivered'
      });
    } catch (e) {
      debugPrint('Error marking message as delivered: $e');
    }
  }

  // Mark message as read
  Future<void> markMessageAsRead(
    String communityId,
    String sessionId,
    String messageId,
    String userId,
  ) async {
    try {
      await _messagesRef(communityId, sessionId).doc(messageId).update({
        'readBy': FieldValue.arrayUnion([userId]),
        'status': 'read',
      });
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  // Listen to session status
  Stream<ChatSession?> listenToSession(String communityId, String sessionId) {
    return _chatSessionsRef(communityId).doc(sessionId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatSession.fromFirestore(doc);
    });
  }

  // Request identity reveal
  Future<void> requestIdentityReveal(String communityId, String sessionId, String userId) async {
    try {
      await _chatSessionsRef(communityId).doc(sessionId).update({
        'revealRequests.$userId': true,
      });
    } catch (e) {
      throw Exception('Failed to request identity reveal: $e');
    }
  }

  // Process identity revelation
  Future<void> processIdentityReveal(String communityId, String sessionId, List<String> participants) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get session data
        final sessionDoc = await transaction.get(_chatSessionsRef(communityId).doc(sessionId));
        final sessionData = sessionDoc.data() as Map<String, dynamic>;
        
        // Get user data for both participants
        final user1Doc = await transaction.get(_liveZoneRef(communityId).doc(participants[0]));
        final user2Doc = await transaction.get(_liveZoneRef(communityId).doc(participants[1]));
        
        final user1Data = user1Doc.data() as Map<String, dynamic>;
        final user2Data = user2Doc.data() as Map<String, dynamic>;

        // Update session
        transaction.update(_chatSessionsRef(communityId).doc(sessionId), {
          'identityRevealed': true,
          'identityRevealedAt': FieldValue.serverTimestamp(),
        });

        // Add system message about identity reveal
        final systemMessageRef = _messagesRef(communityId, sessionId).doc();
        final now = DateTime.now();
        transaction.set(systemMessageRef, {
          'senderId': 'system',
          'message': '🎭 Identities have been revealed! You can now see each other\'s usernames.',
          'timestamp': FieldValue.serverTimestamp(),
          'sequenceNumber': now.microsecondsSinceEpoch,
          'readBy': [],
          'status': 'delivered',
          'isSystemMessage': true,
          'messageType': 'system',
        });

        // Update chat history for both users with revealed identity
        final startedAt = (sessionData['createdAt'] as Timestamp).toDate();

        // User 1 history
        transaction.set(_chatHistoryRef(communityId, participants[0]).doc(sessionId), {
          'partnerId': participants[1],
          'partnerData': user2Data['userData'],
          'startedAt': Timestamp.fromDate(startedAt),
          'identityRevealed': true,
          'totalMessages': 0,
        });

        // User 2 history
        transaction.set(_chatHistoryRef(communityId, participants[1]).doc(sessionId), {
          'partnerId': participants[0],
          'partnerData': user1Data['userData'],
          'startedAt': Timestamp.fromDate(startedAt),
          'identityRevealed': true,
          'totalMessages': 0,
        });
      });

      // Count messages outside of transaction
      final messagesSnapshot = await _messagesRef(communityId, sessionId).get();
      final totalMessages = messagesSnapshot.docs.length;

      // Update message count in history
      await _chatHistoryRef(communityId, participants[0]).doc(sessionId).update({
        'totalMessages': totalMessages,
      });
      await _chatHistoryRef(communityId, participants[1]).doc(sessionId).update({
        'totalMessages': totalMessages,
      });
    } catch (e) {
      throw Exception('Failed to process identity reveal: $e');
    }
  }

  // End chat session - Enhanced with proper cleanup
  Future<void> endChat(String communityId, String sessionId, String userId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        // Get session data first
        final sessionDoc = await transaction.get(_chatSessionsRef(communityId).doc(sessionId));
        if (!sessionDoc.exists) return;
        
        final session = ChatSession.fromFirestore(sessionDoc);
        final partnerId = session.getPartnerId(userId);

        // Update session status
        transaction.update(_chatSessionsRef(communityId).doc(sessionId), {
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
          'endedBy': userId,
          'onlineStatus.$userId': false,
          'onlineStatus.$partnerId': false,
          'typingStatus.$userId': false,
          'typingStatus.$partnerId': false,
        });

        // Add system message about chat end
        final systemMessageRef = _messagesRef(communityId, sessionId).doc();
        final now = DateTime.now();
        transaction.set(systemMessageRef, {
          'senderId': 'system',
          'message': '💔 Chat session has ended.',
          'timestamp': FieldValue.serverTimestamp(),
          'sequenceNumber': now.microsecondsSinceEpoch,
          'readBy': [],
          'status': 'delivered',
          'isSystemMessage': true,
          'messageType': 'system',
        });

        // Update both users' status in live zone to offline
        transaction.update(_liveZoneRef(communityId).doc(userId), {
          'status': 'offline',
          'pairedWith': null,
          'sessionId': null,
        });

        transaction.update(_liveZoneRef(communityId).doc(partnerId), {
          'status': 'offline',
          'pairedWith': null,
          'sessionId': null,
        });

        // Save to chat history for both users
        await _saveChatHistory(communityId, sessionId, session.participants, transaction);
      });

      // Reset local state
      _currentSessionId = null;
      _currentPartnerId = null;
      _isInChat = false;
    } catch (e) {
      throw Exception('Failed to end chat: $e');
    }
  }

  // Save chat history
  Future<void> _saveChatHistory(String communityId, String sessionId, List<String> participants, Transaction transaction) async {
    try {
      // Get session data
      final sessionDoc = await transaction.get(_chatSessionsRef(communityId).doc(sessionId));
      final sessionData = sessionDoc.data() as Map<String, dynamic>;
      
      // Get user data for both participants
      final user1Doc = await transaction.get(_liveZoneRef(communityId).doc(participants[0]));
      final user2Doc = await transaction.get(_liveZoneRef(communityId).doc(participants[1]));
      
      final user1Data = user1Doc.data() as Map<String, dynamic>;
      final user2Data = user2Doc.data() as Map<String, dynamic>;

      final now = DateTime.now();
      final startedAt = (sessionData['createdAt'] as Timestamp).toDate();

      // User 1 history
      transaction.set(_chatHistoryRef(communityId, participants[0]).doc(sessionId), {
        'partnerId': participants[1],
        'partnerData': user2Data['userData'],
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': Timestamp.fromDate(now),
        'identityRevealed': sessionData['identityRevealed'] ?? false,
        'totalMessages': 0,
      });

      // User 2 history
      transaction.set(_chatHistoryRef(communityId, participants[1]).doc(sessionId), {
        'partnerId': participants[0],
        'partnerData': user1Data['userData'],
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': Timestamp.fromDate(now),
        'identityRevealed': sessionData['identityRevealed'] ?? false,
        'totalMessages': 0,
      });

      // Update message count separately after transaction
      Future.delayed(Duration.zero, () async {
        final messagesSnapshot = await _messagesRef(communityId, sessionId).get();
        final totalMessages = messagesSnapshot.docs.length;

        await _chatHistoryRef(communityId, participants[0]).doc(sessionId).update({
          'totalMessages': totalMessages,
        });
        await _chatHistoryRef(communityId, participants[1]).doc(sessionId).update({
          'totalMessages': totalMessages,
        });
      });
    } catch (e) {
      debugPrint('Error saving chat history: $e');
    }
  }

  // Get chat history
  Stream<List<ChatHistory>> getChatHistory(String communityId, String userId) {
    return _chatHistoryRef(communityId, userId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatHistory.fromFirestore(doc))
            .toList());
  }

  // Generate unique session ID
  String _generateSessionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomNum = random.nextInt(999999);
    return '${timestamp}_$randomNum';
  }

  // Reset service state (for logout/cleanup)
  void reset() {
    _currentSessionId = null;
    _currentPartnerId = null;
    _isInChat = false;
  }

  // Clean up when service is disposed
  void dispose() {
    if (_currentSessionId != null && _currentPartnerId != null) {
      // This would ideally be called when the user leaves the chat
    }
  }
}