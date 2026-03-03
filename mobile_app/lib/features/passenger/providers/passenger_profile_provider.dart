import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/passenger_service.dart';

class PassengerProfileProvider extends ChangeNotifier {
  final _service = PassengerService();

  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;

  Future<void> fetchProfile() async {
    _setLoading(true);
    try {
      _profile = await _service.getProfile();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = _msg(e);
    }
    _setLoading(false);
  }

  Future<bool> saveProfile({
    required String fullName,
    String cardHolderName = '',
    String cardLast4 = '',
    String cardExpiryMmYy = '',
    XFile? profilePicture,
  }) async {
    _setLoading(true);
    try {
      _profile = hasProfile
          ? await _service.patchProfile(
              fullName: fullName,
              cardHolderName: cardHolderName,
              cardLast4: cardLast4,
              cardExpiryMmYy: cardExpiryMmYy,
              profilePicture: profilePicture,
            )
          : await _service.createProfile(
              fullName: fullName,
              cardHolderName: cardHolderName,
              cardLast4: cardLast4,
              cardExpiryMmYy: cardExpiryMmYy,
              profilePicture: profilePicture,
            );
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
