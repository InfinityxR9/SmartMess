import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential?> signInAnonymously() async {
    try {
      print('[AuthService] Attempting anonymous sign-in...');
      final userCredential = await _auth.signInAnonymously();
      print('[AuthService] Anonymous sign-in successful: ${userCredential.user?.uid}');
      return userCredential;
    } catch (e) {
      print('[AuthService] Anonymous sign-in FAILED: $e');
      return null;
    }
  }

  User? getCurrentUser() {
    final user = _auth.currentUser;
    print('[AuthService] getCurrentUser: ${user?.uid ?? "null"}');
    return user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }
}
