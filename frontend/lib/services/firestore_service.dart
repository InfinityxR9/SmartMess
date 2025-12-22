import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_mess/models/mess_model.dart';
import 'package:smart_mess/models/menu_model.dart';
import 'package:smart_mess/models/rating_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============ MESS OPERATIONS ============
  Future<List<Mess>> getAllMesses() async {
    try {
      final snapshot = await _db.collection('messes').get();
      return snapshot.docs.map((doc) => Mess.fromFirestore(doc)).toList();
    } catch (e) {
      // Handle error silently
      return [];
    }
  }

  Future<Mess?> getMessById(String messId) async {
    try {
      final doc = await _db.collection('messes').doc(messId).get();
      if (doc.exists) {
        return Mess.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // Handle error silently
      return null;
    }
  }

  Future<void> addMess(Mess mess) async {
    try {
      await _db.collection('messes').add(mess.toFirestore());
    } catch (e) {
      // Handle error silently
    }
  }

  // ============ SCAN OPERATIONS ============
  Future<void> logScan(String userId, String messId) async {
    try {
      await _db.collection('scans').add({
        'uid': userId,
        'messId': messId,
        'ts': Timestamp.now(),
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<int> getCurrentCrowdCount(String messId) async {
    try {
      final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 10));
      final snapshot = await _db
          .collection('scans')
          .where('messId', isEqualTo: messId)
          .where('ts', isGreaterThan: Timestamp.fromDate(tenMinutesAgo))
          .get();
      return snapshot.docs.length;
    } catch (e) {
      // Handle error silently
      return 0;
    }
  }

  Stream<int> getCrowdCountStream(String messId) {
    final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 10));
    return _db
        .collection('scans')
        .where('messId', isEqualTo: messId)
        .where('ts', isGreaterThan: Timestamp.fromDate(tenMinutesAgo))
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ============ MENU OPERATIONS ============
  Future<Menu?> getTodayMenu(String messId) async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      final snapshot = await _db
          .collection('menus')
          .where('messId', isEqualTo: messId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return Menu.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      // Handle error silently
      return null;
    }
  }

  Stream<Menu?> getTodayMenuStream(String messId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    return _db
        .collection('menus')
        .where('messId', isEqualTo: messId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Menu.fromFirestore(snapshot.docs.first);
      }
      return null;
    });
  }

  Future<void> addMenu(Menu menu) async {
    try {
      await _db.collection('menus').add(menu.toFirestore());
    } catch (e) {
      // Handle error silently
    }
  }

  // ============ RATING OPERATIONS ============
  Future<void> submitRating(Rating rating) async {
    try {
      await _db.runTransaction((transaction) async {
        await transaction.set(
          _db.collection('ratings').doc(),
          rating.toFirestore(),
        );

        final summaryDoc =
            _db.collection('rating_summary').doc(rating.messId);
        final summarySnapshot = await transaction.get(summaryDoc);

        if (summarySnapshot.exists) {
          final currentData = summarySnapshot.data() as Map<String, dynamic>;
          final newCount = (currentData['count'] ?? 0) + 1;
          final newSum = (currentData['sum'] ?? 0) + rating.score;
          final newAvg = newSum / newCount;

          transaction.update(summaryDoc, {
            'count': newCount,
            'sum': newSum,
            'avg': newAvg,
          });
        } else {
          transaction.set(summaryDoc, {
            'messId': rating.messId,
            'count': 1,
            'sum': rating.score,
            'avg': rating.score.toDouble(),
          });
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<RatingSummary?> getRatingSummary(String messId) async {
    try {
      final doc =
          await _db.collection('rating_summary').doc(messId).get();
      if (doc.exists) {
        return RatingSummary.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      // Handle error silently
      return null;
    }
  }

  Stream<RatingSummary?> getRatingSummaryStream(String messId) {
    return _db
        .collection('rating_summary')
        .doc(messId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return RatingSummary.fromFirestore(doc);
      }
      return null;
    });
  }

  // ============ USER PREFERENCE OPERATIONS ============
  Future<void> setUserHomeMess(String userId, String messId) async {
    try {
      await _db.collection('users').doc(userId).set({
        'homeMessId': messId,
      });
    } catch (e) {
      // Handle error silently
    }
  }

  Future<String?> getUserHomeMess(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data()?['homeMessId'];
      }
      return null;
    } catch (e) {
      // Handle error silently
      return null;
    }
  }
}
