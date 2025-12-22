import 'package:flutter/foundation.dart';
import '../services/student_auth_service.dart';
import '../services/manager_auth_service.dart';

class UnifiedAuthProvider extends ChangeNotifier {
  final StudentAuthService _studentAuthService = StudentAuthService();
  final ManagerAuthService _managerAuthService = ManagerAuthService();

  // Current user state
  String? _userId;
  String? _userType; // 'student' or 'manager'
  String? _userName;
  String? _enrollmentId; // For students
  String? _messId;
  String? _messName;
  String? _messCode;
  List<String> _assignedMesses = []; // For managers
  bool _isLoading = false;
  String? _error;

  // Getters
  String? get userId => _userId;
  String? get userType => _userType;
  String? get userName => _userName;
  String? get enrollmentId => _enrollmentId;
  String? get messId => _messId;
  String? get messName => _messName;
  String? get messCode => _messCode;
  List<String> get assignedMesses => _assignedMesses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _userId != null;
  bool get isStudent => _userType == 'student';
  bool get isManager => _userType == 'manager';

  // Student Login
  Future<bool> studentLogin(String enrollmentId, String dateOfBirth) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('[UnifiedAuth] Student login attempt: $enrollmentId');

      // Authenticate student
      final userData = await _studentAuthService.authenticateStudent(
        enrollmentId,
        dateOfBirth,
      );

      if (userData == null) {
        _error = 'Invalid enrollment ID or date of birth';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get mess information using messId from login credentials
      final messInfo = await _studentAuthService.getStudentMessInfo(
        userData['messId'] as String,
      );

      if (messInfo == null) {
        _error = 'Could not load mess information';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Set student state
      _userId = userData['userId'] as String;
      _userType = 'student';
      _userName = userData['name'] as String?;
      _enrollmentId = enrollmentId.toUpperCase();
      _messId = messInfo['messId'] as String;
      _messName = messInfo['name'] as String?;
      _messCode = messInfo['messCode'] as String?;
      _isLoading = false;
      _error = null;

      print('[UnifiedAuth] Student login successful: $_userName ($_messName)');
      print('[UnifiedAuth] Student login successful: $_userName ($_messId)');
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Login error: $e';
      _isLoading = false;
      print('[UnifiedAuth] Student login error: $e');
      notifyListeners();
      return false;
    }
  }

  // Manager Login
  Future<bool> managerLogin(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('[UnifiedAuth] Manager login attempt: $email');

      // Authenticate manager
      final userData = await _managerAuthService.authenticateManager(email, password);

      if (userData == null) {
        _error = 'Invalid email or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get mess information using messId from login credentials
      final messInfo = await _managerAuthService.getManagerMessInfo(
        userData['messId'] as String,
      );

      if (messInfo == null) {
        _error = 'Could not load mess information';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Set manager state
      _userId = userData['userId'] as String;
      _userType = 'manager';
      _userName = userData['name'] as String?;
      _messId = messInfo['messId'] as String;
      _messName = messInfo['name'] as String?;
      _messCode = messInfo['messCode'] as String?;
      _isLoading = false;
      _error = null;

      print('[UnifiedAuth] Manager login successful: $_userName ($_messCode)');
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Login error: $e';
      _isLoading = false;
      print('[UnifiedAuth] Manager login error: $e');
      notifyListeners();
      return false;
    }
  }

  // Switch mess (for managers with multiple messes)
  Future<void> switchMess(String messId) async {
    try {
      if (!isManager || !_assignedMesses.contains(messId)) {
        _error = 'Cannot switch to this mess';
        notifyListeners();
        return;
      }

      _messId = messId;
      // Note: In a real app, fetch mess details from database
      _error = null;
      print('[UnifiedAuth] Switched to mess: $messId');
      notifyListeners();
    } catch (e) {
      _error = 'Error switching mess: $e';
      notifyListeners();
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      if (isManager) {
        await _managerAuthService.signOut();
      }

      _userId = null;
      _userType = null;
      _userName = null;
      _enrollmentId = null;
      _messId = null;
      _messName = null;
      _messCode = null;
      _assignedMesses = [];
      _error = null;

      print('[UnifiedAuth] User logged out');
      notifyListeners();
    } catch (e) {
      _error = 'Logout error: $e';
      notifyListeners();
    }
  }

  // Check if student belongs to specific mess
  Future<bool> canAccessMess(String messId) async {
    if (isStudent) {
      return _messId == messId;
    } else if (isManager) {
      return _assignedMesses.contains(messId);
    }
    return false;
  }
}
