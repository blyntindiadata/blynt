// models/chat_models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class LiveZoneUser {
  final String userId;
  final String username;
  final String status; // 'waiting', 'paired', 'offline'
  final DateTime joinedAt;
  final String? pairedWith;
  final String? sessionId;
  final UserData userData;

  LiveZoneUser({
    required this.userId,
    required this.username,
    required this.status,
    required this.joinedAt,
    this.pairedWith,
    this.sessionId,
    required this.userData,
  });

  factory LiveZoneUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveZoneUser(
      userId: doc.id,
      username: data['username'] ?? '',
      status: data['status'] ?? 'offline',
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
      pairedWith: data['pairedWith'],
      sessionId: data['sessionId'],
      userData: UserData.fromMap(data['userData'] ?? {}),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'status': status,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'pairedWith': pairedWith,
      'sessionId': sessionId,
      'userData': userData.toMap(),
    };
  }

  LiveZoneUser copyWith({
    String? status,
    String? pairedWith,
    String? sessionId,
  }) {
    return LiveZoneUser(
      userId: userId,
      username: username,
      status: status ?? this.status,
      joinedAt: joinedAt,
      pairedWith: pairedWith ?? this.pairedWith,
      sessionId: sessionId ?? this.sessionId,
      userData: userData,
    );
  }
}

class UserData {
  final String branch;
  final String year;
  final String? profileImageUrl;
  final String firstName;
  final String lastName;

  UserData({
    required this.branch,
    required this.year,
    this.profileImageUrl,
    required this.firstName,
    required this.lastName,
  });

  factory UserData.fromMap(Map<String, dynamic> map) {
    return UserData(
      branch: map['branch'] ?? '',
      year: map['year'] ?? '',
      profileImageUrl: map['profileImageUrl'],
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branch': branch,
      'year': year,
      'profileImageUrl': profileImageUrl,
      'firstName': firstName,
      'lastName': lastName,
    };
  }
}

class ChatSession {
  final String sessionId;
  final List<String> participants;
  final DateTime createdAt;
  final String status; // 'active', 'ended'
  final Map<String, bool> revealRequests;
  final bool identityRevealed;
  final DateTime? endedAt;
  final Map<String, bool> onlineStatus; // Track online status of participants
  final Map<String, bool> typingStatus; // Track typing status of participants
  final Map<String, DateTime> lastSeen; // Track when users were last seen

  ChatSession({
    required this.sessionId,
    required this.participants,
    required this.createdAt,
    required this.status,
    required this.revealRequests,
    required this.identityRevealed,
    this.endedAt,
    required this.onlineStatus,
    required this.typingStatus,
    required this.lastSeen,
  });

  factory ChatSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatSession(
      sessionId: doc.id,
      participants: List<String>.from(data['participants'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'active',
      revealRequests: Map<String, bool>.from(data['revealRequests'] ?? {}),
      identityRevealed: data['identityRevealed'] ?? false,
      endedAt: data['endedAt'] != null ? (data['endedAt'] as Timestamp).toDate() : null,
      onlineStatus: Map<String, bool>.from(data['onlineStatus'] ?? {}),
      typingStatus: Map<String, bool>.from(data['typingStatus'] ?? {}),
      lastSeen: Map<String, DateTime>.from(
        (data['lastSeen'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, (value as Timestamp).toDate()),
        ) ?? {},
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participants': participants,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'revealRequests': revealRequests,
      'identityRevealed': identityRevealed,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'onlineStatus': onlineStatus,
      'typingStatus': typingStatus,
      'lastSeen': lastSeen.map(
        (key, value) => MapEntry(key, Timestamp.fromDate(value)),
      ),
    };
  }

  bool canRevealIdentity() {
    final now = DateTime.now();
    final daysSinceCreated = now.difference(createdAt).inSeconds;
    return daysSinceCreated >= 20;
  }

  String getPartnerId(String currentUserId) {
    return participants.firstWhere((id) => id != currentUserId);
  }

  bool isUserOnline(String userId) {
    return onlineStatus[userId] ?? false;
  }

  bool isUserTyping(String userId) {
    return typingStatus[userId] ?? false;
  }

  DateTime? getUserLastSeen(String userId) {
    return lastSeen[userId];
  }
}

class ChatMessage {
  final String messageId;
  final String senderId;
  final String message;
  final DateTime timestamp;
  final String messageType; // 'text', 'system'
  final int? sequenceNumber; // For proper ordering
  final List<String>? readBy; // Users who have read this message
  final String status; // 'sent', 'delivered', 'read'
  final bool isSystemMessage; // Whether this is a system message

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.message,
    required this.timestamp,
    this.messageType = 'text',
    this.sequenceNumber,
    this.readBy,
    this.status = 'sent',
    this.isSystemMessage = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      messageId: doc.id,
      senderId: data['senderId'] ?? '',
      message: data['message'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      messageType: data['messageType'] ?? 'text',
      sequenceNumber: data['sequenceNumber'],
      readBy: data['readBy'] != null ? List<String>.from(data['readBy']) : null,
      status: data['status'] ?? 'sent',
      isSystemMessage: data['isSystemMessage'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'messageType': messageType,
      'sequenceNumber': sequenceNumber,
      'readBy': readBy ?? [],
      'status': status,
      'isSystemMessage': isSystemMessage,
    };
  }

  bool isSentByMe(String currentUserId) {
    return senderId == currentUserId;
  }

  bool isReadBy(String userId) {
    return readBy?.contains(userId) ?? false;
  }

  ChatMessage copyWith({
    String? messageId,
    String? senderId,
    String? message,
    DateTime? timestamp,
    String? messageType,
    int? sequenceNumber,
    List<String>? readBy,
    String? status,
    bool? isSystemMessage,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      messageType: messageType ?? this.messageType,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      readBy: readBy ?? this.readBy,
      status: status ?? this.status,
      isSystemMessage: isSystemMessage ?? this.isSystemMessage,
    );
  }
}

class ChatHistory {
  final String sessionId;
  final String partnerId;
  final UserData? partnerData;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool identityRevealed;
  final int totalMessages;

  ChatHistory({
    required this.sessionId,
    required this.partnerId,
    this.partnerData,
    required this.startedAt,
    this.endedAt,
    required this.identityRevealed,
    required this.totalMessages,
  });

  factory ChatHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatHistory(
      sessionId: doc.id,
      partnerId: data['partnerId'] ?? '',
      partnerData: data['partnerData'] != null 
          ? UserData.fromMap(data['partnerData']) 
          : null,
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      endedAt: data['endedAt'] != null ? (data['endedAt'] as Timestamp).toDate() : null,
      identityRevealed: data['identityRevealed'] ?? false,
      totalMessages: data['totalMessages'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'partnerId': partnerId,
      'partnerData': partnerData?.toMap(),
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'identityRevealed': identityRevealed,
      'totalMessages': totalMessages,
    };
  }

  String get displayName {
    if (identityRevealed && partnerData != null) {
      return '${partnerData!.firstName} ${partnerData!.lastName}';
    }
    return 'Anonymous User';
  }

  String get sessionDuration {
    if (endedAt == null) return 'Ongoing';
    final duration = endedAt!.difference(startedAt);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }

  String get chatStatus {
    if (endedAt == null) {
      return 'Active';
    } else {
      return 'Ended';
    }
  }

  bool get isActive => endedAt == null;
}