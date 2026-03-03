import 'package:flutter/foundation.dart';
import '../../../core/services/complaint_service.dart';

class ComplaintProvider extends ChangeNotifier {
  final _service = ComplaintService();

  List<Map<String, dynamic>> _complaints = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchComplaints() async {
    _setLoading(true);
    try {
      _complaints = await _service.getComplaints();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _msg(e);
    }
    _setLoading(false);
  }

  Future<bool> fileComplaint({
    required int rideId,
    required String description,
  }) async {
    _setLoading(true);
    try {
      final c = await _service.fileComplaint(
          rideId: rideId, description: description);
      _complaints.insert(0, c);
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _msg(e);
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
