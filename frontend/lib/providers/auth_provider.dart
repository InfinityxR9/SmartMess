import 'package:flutter/foundation.dart';
import 'package:smart_mess/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = true; // Start as loading
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  AuthProvider() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    try {
      print('[AuthProvider] Starting auth initialization...');
      _isLoading = true;
      notifyListeners();
      
      _user = _authService.getCurrentUser();
      print('[AuthProvider] Current user check: ${_user?.uid ?? "null"}');
      if (_user == null) {
        print('[AuthProvider] No user found, attempting anonymous sign-in...');
        await signInAnonymously();
      }
      _isLoading = false;
      _error = null;
      print('[AuthProvider] Auth initialization complete, user: ${_user?.uid ?? "null"}');
      notifyListeners();
    } catch (e) {
      print('[AuthProvider] Auth initialization ERROR: $e');
      _error = 'Auth init error: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signInAnonymously() async {
    try {
      print('[AuthProvider] signInAnonymously() called');
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userCredential = await _authService.signInAnonymously();
      if (userCredential != null) {
        _user = userCredential.user;
        _isLoading = false;
        _error = null;
        print('[AuthProvider] Anonymous sign-in success: ${_user?.uid}');
        notifyListeners();
        return true;
      }
      _isLoading = false;
      _error = 'Anonymous sign in failed';
      print('[AuthProvider] Anonymous sign-in returned null credential');
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sign in error: $e';
      _isLoading = false;
      print('[AuthProvider] Sign-in ERROR: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      await _authService.signOut();
      _user = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      // Handle error silently
      _isLoading = false;
      notifyListeners();
    }
  }
}
