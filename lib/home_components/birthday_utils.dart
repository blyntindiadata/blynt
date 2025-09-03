import 'package:cloud_firestore/cloud_firestore.dart';

class BirthdayUtils {
  // FIXED: Remove orderBy from hasWishBeenSent
  static Future<bool> hasWishBeenSent(String senderId, String recipientId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      // REMOVED orderBy - just use where clauses
      final wishQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .where('type', isEqualTo: 'birthday_wish')
          .where('senderId', isEqualTo: senderId)
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      return wishQuery.docs.isNotEmpty;
    } catch (e) {
      print('Error checking wish status: $e');
      return false; // If error, allow sending wish
    }
  }
}