import 'package:flutter/material.dart';
import 'dart:convert';
import '../core/constants.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/api/api_client_base.dart';
import '../services/secure_storage_service.dart';
import '../services/websocket_service.dart';
import '../services/webauthn_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SecureStorageService _secureStorage = SecureStorageService();
  final WebSocketService _webSocketService = WebSocketService();

  UserModel? _user;
  String? _token;
  String? _refreshToken;
  String? _adminToken;
  String? _mfaTempToken;
  String? _mfaType;
  String? _emailMascarado;
  bool _isLoading = false;
  String? _errorMessage;

  // Auto-Lock por Inatividade (Segurança Bancária)
  bool _autoLockAtivo = true;
  int _autoLockMinutos = 15;
  bool _isSessionLocked = false;
  bool _shouldSuggestBiometrics = false;

  UserModel? get user => _user;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get adminToken => _adminToken ?? _token;
  String? get mfaTempToken => _mfaTempToken;
  String? get mfaType => _mfaType;
  String? get emailMascarado => _emailMascarado;
  bool get requiresMfaStep => _mfaTempToken != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get shouldSuggestBiometrics => _shouldSuggestBiometrics;

  void clearShouldSuggestBiometrics() {
    _shouldSuggestBiometrics = false;
  }
  bool get isAuthenticated =>
      _token != null && _user != null && _isTokenUsable(_token!);
  bool get isAdminStepUpAuthenticated =>
      _adminToken != null && _isTokenUsable(_adminToken!);

  bool get autoLockAtivo => _autoLockAtivo;
  int get autoLockMinutos => _autoLockMinutos;
  bool get isSessionLocked => _isSessionLocked;

  void lockSession() {
    if (isAuthenticated && !_isSessionLocked && _autoLockAtivo) {
      _isSessionLocked = true;
      notifyListeners();
    }
  }

  void unlockSession() {
    _isSessionLocked = false;
    notifyListeners();
  }

  Future<void> carregarConfigSeguranca() async {
    try {
      final res = await _apiService.getConfigSeguranca();
      if (res.success && res.data != null) {
        final autoLock = res.data!['autoLock'];
        if (autoLock != null) {
          _autoLockAtivo = autoLock['ativo'] == true;
          _autoLockMinutos = (autoLock['minutos'] as int?) ?? 15;
          notifyListeners();
        }
      }
    } catch (e, stackTrace) {
      debugPrint(
          '[AuthProvider] Erro ao carregar configurações públicas de segurança: $e\n$stackTrace');
    }
  }

  Future<void> initAuth() async {
    // Configura callbacks do Interceptor HTTP para sincronização transparente de estado
    ApiClientBase.onTokenRefreshed = (newToken, newRefreshToken) {
      _token = newToken;
      if (newRefreshToken != null) {
        _refreshToken = newRefreshToken;
      }
      notifyListeners();
    };

    ApiClientBase.onSessionExpired = (reason) {
      debugPrint('[AuthProvider] Sessão expirada pelo interceptor: $reason');
      logout();
    };

    // Carrega políticas públicas de segurança da sessão
    await carregarConfigSeguranca();

    // Executa migração transparente de SharedPreferences legados, se houver
    await _secureStorage.migrateFromSharedPreferences();

    _token = await _secureStorage.getToken();
    _refreshToken = await _secureStorage.getRefreshToken();
    final userJson = await _secureStorage.getUserData();
    if (userJson != null) {
      try {
        _user = UserModel.fromJsonString(userJson);
      } catch (e) {
        _user = null;
      }
    }
    _adminToken = await _secureStorage.getAdminToken();

    if (_token != null && !_isTokenUsable(_token!)) {
      _token = null;
      _adminToken = null;
      await _secureStorage.delete(AppConstants.keyToken);
    }

    if (_token == null && _refreshToken == null) {
      _user = null;
      await _secureStorage.delete(AppConstants.keyUserData);
    } else if (_token == null && _refreshToken != null) {
      await renovarSessaoComRefreshToken();
    } else if (_token != null) {
      // Validação autoritativa e busca de perfil mais recente no Backend (PostgreSQL)
      try {
        final meRes = await _apiService.getMe(_token!);
        if (meRes.success && meRes.data != null) {
          _user = meRes.data;
          await _secureStorage.saveUserData(_user!.toJsonString());
        } else if (meRes.statusCode == 401) {
          // Token revogado, usuário inativo ou tokenVersion alterada
          debugPrint('[AuthProvider] Sessão inválida no backend ao iniciar. Executando logout.');
          await logout();
          return;
        }
      } catch (e) {
        debugPrint('[AuthProvider] Falha de conexão ao sincronizar com /auth/me: $e');
      }
    }
    notifyListeners();
  }

  bool _isTokenUsable(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final exp = payload['exp'];
      return exp is num && DateTime.now().millisecondsSinceEpoch < exp * 1000;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String login, String senha) async {
    _isLoading = true;
    _errorMessage = null;
    _mfaTempToken = null;
    _mfaType = null;
    _emailMascarado = null;
    notifyListeners();

    final response = await _apiService.login(login, senha);

    _isLoading = false;
    if (response.success && response.data != null) {
      if (response.data!['requiresMfa'] == true) {
        _mfaTempToken = response.data!['tempToken'];
        _mfaType = response.data!['mfaType'] ?? 'TOTP';
        _emailMascarado = response.data!['emailMascarado'];
        notifyListeners();
        return false;
      }

      _token = response.data!['token'];
      _refreshToken = response.data!['refreshToken'];
      _user = response.data!['user'];

      await _secureStorage.saveToken(_token!);
      if (_refreshToken != null) {
        await _secureStorage.saveRefreshToken(_refreshToken!);
      }
      await _secureStorage.saveUserData(_user!.toJsonString());

      try {
        final bioSupported = await isBiometricsAvailable();
        if (bioSupported) {
          _shouldSuggestBiometrics = true;
        }
      } catch (_) {}

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
      _refreshToken = response.data!['refreshToken'];
      _user = response.data!['user'];
      _mfaTempToken = null;
      _mfaType = null;
      _emailMascarado = null;

      await _secureStorage.saveToken(_token!);
      if (_refreshToken != null) {
        await _secureStorage.saveRefreshToken(_refreshToken!);
      }
      await _secureStorage.saveUserData(_user!.toJsonString());

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.error ?? 'Código de autenticação inválido.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> validarLoginEmailMfa(String codigo) async {
    if (_mfaTempToken == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response =
        await _apiService.validarLoginEmailMfa(_mfaTempToken!, codigo);
    _isLoading = false;

    if (response.success && response.data != null) {
      _token = response.data!['token'];
      _refreshToken = response.data!['refreshToken'];
      _user = response.data!['user'];
      _mfaTempToken = null;
      _mfaType = null;
      _emailMascarado = null;

      await _secureStorage.saveToken(_token!);
      if (_refreshToken != null) {
        await _secureStorage.saveRefreshToken(_refreshToken!);
      }
      await _secureStorage.saveUserData(_user!.toJsonString());

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.error ??
          'Código de verificação por e-mail inválido ou expirado.';
      notifyListeners();
      return false;
    }
  }

  void cancelarMfaStep() {
    _mfaTempToken = null;
    _mfaType = null;
    _emailMascarado = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> renovarSessaoComRefreshToken() async {
    if (_refreshToken == null) return false;
    final res = await _apiService.refreshToken(_refreshToken!);
    if (res.success && res.data != null) {
      _token = res.data!['token'];
      _refreshToken = res.data!['refreshToken'];
      _user = res.data!['user'];
      await _secureStorage.saveToken(_token!);
      if (_refreshToken != null) {
        await _secureStorage.saveRefreshToken(_refreshToken!);
      }
      await _secureStorage.saveUserData(_user!.toJsonString());
      notifyListeners();
      return true;
    } else {
      await logout();
      return false;
    }
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
      await _secureStorage.saveAdminToken(_adminToken!);
      notifyListeners();
      return true;
    } else {
      _errorMessage = res.error ?? 'Código MFA inválido.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginSso({
    required String provider,
    required String email,
    String? name,
    String? ssoId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final response = await _apiService.loginSso(
      provider: provider,
      email: email,
      name: name,
      ssoId: ssoId,
    );

    _isLoading = false;
    if (response.success && response.data != null) {
      _token = response.data!['token'];
      _refreshToken = response.data!['refreshToken'];
      _user = response.data!['user'];

      await _secureStorage.saveToken(_token!);
      if (_refreshToken != null) {
        await _secureStorage.saveRefreshToken(_refreshToken!);
      }
      await _secureStorage.saveUserData(_user!.toJsonString());

      notifyListeners();
      return true;
    } else {
      _errorMessage = response.error ?? 'Erro ao realizar login via SSO.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> isBiometricsAvailable() async {
    return await WebAuthnClientService().isBiometricsAvailable();
  }

  Future<bool> loginComBiometria({String? emailOrMatricula}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final optRes = await _apiService.getWebAuthnLoginOptions(emailOrMatricula: emailOrMatricula);
      if (!optRes.success || optRes.data == null) {
        _isLoading = false;
        _errorMessage = optRes.error ?? 'Falha ao iniciar autenticação biométrica.';
        notifyListeners();
        return false;
      }

      final challengeKey = optRes.data!['challengeKey'] as String;
      final options = optRes.data!['options'] as Map<String, dynamic>;

      final credentialPayload = await WebAuthnClientService().authenticateBiometrics(options);
      if (credentialPayload == null) {
        _isLoading = false;
        _errorMessage = 'Biometria cancelada.';
        notifyListeners();
        return false;
      }

      final verifyRes = await _apiService.verifyWebAuthnLogin(challengeKey, credentialPayload);
      _isLoading = false;

      if (verifyRes.success && verifyRes.data != null) {
        _token = verifyRes.data!['token'];
        _refreshToken = verifyRes.data!['refreshToken'];
        _user = verifyRes.data!['user'];

        await _secureStorage.saveToken(_token!);
        if (_refreshToken != null) {
          await _secureStorage.saveRefreshToken(_refreshToken!);
        }
        await _secureStorage.saveUserData(_user!.toJsonString());

        notifyListeners();
        return true;
      } else {
        _errorMessage = verifyRes.error ?? 'Falha ao validar biometria.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Erro ao processar biometria: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cadastrarBiometriaAtual({String? deviceName}) async {
    if (_token == null) return false;
    try {
      final optRes = await _apiService.getWebAuthnRegisterOptions(_token!);
      if (!optRes.success || optRes.data == null) {
        _errorMessage = optRes.error ?? 'Falha ao obter opções de registro.';
        notifyListeners();
        return false;
      }

      final options = optRes.data!;
      final credentialPayload = await WebAuthnClientService().registerBiometrics(options);
      if (credentialPayload == null) return false;

      final verifyRes = await _apiService.verifyWebAuthnRegister(_token!, credentialPayload, deviceName: deviceName);
      return verifyRes.success;
    } catch (e) {
      debugPrint('[AuthProvider] Erro ao cadastrar biometria: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final currentToken = _token;
    final currentRefresh = _refreshToken;
    _token = null;
    _refreshToken = null;
    _user = null;
    _adminToken = null;
    _isSessionLocked = false;
    _mfaTempToken = null;
    _mfaType = null;
    _emailMascarado = null;
    _webSocketService.disconnect();
    await _secureStorage.clearAll();
    notifyListeners();

    AppConstants.navigatorKey.currentState?.popUntil((route) => route.isFirst);

    if (currentToken != null || currentRefresh != null) {
      await _apiService.logout(currentToken, refreshToken: currentRefresh);
    }
  }
}
