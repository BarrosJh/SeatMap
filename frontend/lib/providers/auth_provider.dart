import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  UserModel? _user;
  String? _token;
  String? _adminToken;
  String? _mfaTempToken;
  String? _mfaType;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get token => _token;
  String? get adminToken => _adminToken ?? _token;
  String? get mfaTempToken => _mfaTempToken;
  String? get mfaType => _mfaType;
  bool get requiresMfaStep => _mfaTempToken != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isAdminStepUpAuthenticated => _user?.isAdmin == true;

  Future<void> initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.keyToken);
    final userJson = prefs.getString(AppConstants.keyUserData);
    if (userJson != null) {
      try {
        _user = UserModel.fromJsonString(userJson);
      } catch (e) {
        _user = null;
      }
    }
    _adminToken = prefs.getString(AppConstants.keyAdminToken);
    notifyListeners();
  }

  Future<bool> login(String login, String senha) async {
    _isLoading = true;
    _errorMessage = null;
    _mfaTempToken = null;
    _mfaType = null;
    notifyListeners();

    final response = await _apiService.login(login, senha);

    _isLoading = false;
    if (response.success && response.data != null) {
      if (response.data!['requiresMfa'] == true) {
        _mfaTempToken = response.data!['tempToken'];
        _mfaType = response.data!['mfaType'] ?? 'TOTP';
        notifyListeners();
        return false;
      }

      _token = response.data!['token'];
      _user = response.data!['user'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyToken, _token!);
      await prefs.setString(AppConstants.keyUserData, _user!.toJsonString());

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.error ?? 'Erro ao realizar login.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> validarLoginTotp(String codigo) async {
    if (_mfaTempToken == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _apiService.validarLoginTotp(_mfaTempToken!, codigo);
    _isLoading = false;

    if (response.success && response.data != null) {
      _token = response.data!['token'];
      _user = response.data!['user'];
      _mfaTempToken = null;
      _mfaType = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyToken, _token!);
      await prefs.setString(AppConstants.keyUserData, _user!.toJsonString());

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.error ?? 'Código de autenticação inválido.';
      notifyListeners();
      return false;
    }
  }

  void cancelarMfaStep() {
    _mfaTempToken = null;
    _mfaType = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> solicitarMfa() async {
    if (_token == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _apiService.solicitarMfa(_token!);
    _isLoading = false;
    notifyListeners();
    return res.success;
  }

  Future<bool> validarMfa(String codigo) async {
    if (_token == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final res = await _apiService.validarMfa(_token!, codigo);
    _isLoading = false;

    if (res.success && res.data != null) {
      _adminToken = res.data;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAdminToken, _adminToken!);
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.error ?? 'Código MFA inválido.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    _adminToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyToken);
    await prefs.remove(AppConstants.keyUserData);
    await prefs.remove(AppConstants.keyAdminToken);
    notifyListeners();
  }
}

