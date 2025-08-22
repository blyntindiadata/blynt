// lib/models/journey_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Journey {
  final String id;
  final String name;
  final String description;
  final String authorId;
  final String authorUsername;
  final bool isHiring;
  final int followersCount;
  final int postsCount;
  final DateTime createdAt;
  final bool isFollowing;
  final int streak;
  final String status;
  final DateTime? lastPostAt;
  final List<String> tags;
  final String category;

  Journey({
    required this.id,
    required this.name,
    required this.description,
    required this.authorId,
    required this.authorUsername,
    required this.isHiring,
    required this.followersCount,
    required this.postsCount,
    required this.createdAt,
    required this.isFollowing,
    required this.streak,
    required this.status,
    this.lastPostAt,
    this.tags = const [],
    this.category = 'general',
  });

  factory Journey.fromMap(Map<String, dynamic> data, [bool isFollowing = false]) {
    return Journey(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      isHiring: data['isHiring'] ?? false,
      followersCount: data['followersCount'] ?? 0,
      postsCount: data['postsCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isFollowing: isFollowing,
      streak: data['streak'] ?? 0,
      status: data['status'] ?? 'active',
      lastPostAt: (data['lastPostAt'] as Timestamp?)?.toDate(),
      tags: List<String>.from(data['tags'] ?? []),
      category: data['category'] ?? 'general',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'isHiring': isHiring,
      'followersCount': followersCount,
      'postsCount': postsCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'streak': streak,
      'status': status,
      'lastPostAt': lastPostAt != null ? Timestamp.fromDate(lastPostAt!) : null,
      'tags': tags,
      'category': category,
    };
  }

  Journey copyWith({
    String? id,
    String? name,
    String? description,
    String? authorId,
    String? authorUsername,
    bool? isHiring,
    int? followersCount,
    int? postsCount,
    DateTime? createdAt,
    bool? isFollowing,
    int? streak,
    String? status,
    DateTime? lastPostAt,
    List<String>? tags,
    String? category,
  }) {
    return Journey(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      isHiring: isHiring ?? this.isHiring,
      followersCount: followersCount ?? this.followersCount,
      postsCount: postsCount ?? this.postsCount,
      createdAt: createdAt ?? this.createdAt,
      isFollowing: isFollowing ?? this.isFollowing,
      streak: streak ?? this.streak,
      status: status ?? this.status,
      lastPostAt: lastPostAt ?? this.lastPostAt,
      tags: tags ?? this.tags,
      category: category ?? this.category,
    );
  }
}

class JourneyPost {
  final String id;
  final String journeyId;
  final String content;
  final String authorId;
  final String authorUsername;
  final DateTime createdAt;
  final int likes;
  final int commentsCount;
  final bool isLiked;
  final List<String> imageUrls;
  final String type; // 'text', 'image', 'milestone'

  JourneyPost({
    required this.id,
    required this.journeyId,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    required this.createdAt,
    required this.likes,
    required this.commentsCount,
    required this.isLiked,
    this.imageUrls = const [],
    this.type = 'text',
  });

  factory JourneyPost.fromMap(Map<String, dynamic> data, [bool isLiked = false]) {
    return JourneyPost(
      id: data['id'] ?? '',
      journeyId: data['journeyId'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      isLiked: isLiked,
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      type: data['type'] ?? 'text',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'journeyId': journeyId,
      'content': content,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'commentsCount': commentsCount,
      'imageUrls': imageUrls,
      'type': type,
    };
  }

  JourneyPost copyWith({
    String? id,
    String? journeyId,
    String? content,
    String? authorId,
    String? authorUsername,
    DateTime? createdAt,
    int? likes,
    int? commentsCount,
    bool? isLiked,
    List<String>? imageUrls,
    String? type,
  }) {
    return JourneyPost(
      id: id ?? this.id,
      journeyId: journeyId ?? this.journeyId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorUsername: authorUsername ?? this.authorUsername,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
      isLiked: isLiked ?? this.isLiked,
      imageUrls: imageUrls ?? this.imageUrls,
      type: type ?? this.type,
    );
  }
}

class JourneyComment {
  final String id;
  final String postId;
  final String content;
  final String authorId;
  final String authorUsername;
  final DateTime createdAt;
  final int likes;

  JourneyComment({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    required this.authorUsername,
    required this.createdAt,
    required this.likes,
  });

  factory JourneyComment.fromMap(Map<String, dynamic> data) {
    return JourneyComment(
      id: data['id'] ?? '',
      postId: data['postId'] ?? '',
      content: data['content'] ?? '',
      authorId: data['authorId'] ?? '',
      authorUsername: data['authorUsername'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likes: data['likes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'postId': postId,
      'content': content,
      'authorId': authorId,
      'authorUsername': authorUsername,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
    };
  }
}