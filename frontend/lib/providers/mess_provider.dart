import 'package:flutter/foundation.dart';
import 'package:smart_mess/services/firestore_service.dart';
import 'package:smart_mess/models/mess_model.dart';

class MessProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  List<Mess> _messes = [];
  Mess? _selectedMess;
  bool _isLoading = false;
  String? _error;

  List<Mess> get messes => _messes;
  Mess? get selectedMess => _selectedMess;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAllMesses() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();
      _messes = await _firestoreService.getAllMesses();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load messes: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectMess(String messId) async {
    try {
      _selectedMess = await _firestoreService.getMessById(messId);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to select mess: $e';
      notifyListeners();
    }
  }

  void setSelectedMess(Mess mess) {
    _selectedMess = mess;
    _error = null;
    notifyListeners();
  }
}
