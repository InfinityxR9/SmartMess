import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_mess/utils/logger.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> signInAnonymously() async {
    try {
      logDebug('[AuthService] Attempting anonymous sign-in...');
      final userCredential = await _auth.signInAnonymously();
      logDebug('[AuthService] Anonymous sign-in successful: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      logError('[AuthService] Anonymous sign-in FAILED: $e');
      return null;
    }
  }

  User? getCurrentUser() {
    final user = _auth.currentUser;
    logDebug('[AuthService] getCurrentUser: ${user?.uid ?? "null"}');
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }
}
