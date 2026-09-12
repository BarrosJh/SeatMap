import 'package:flutter/foundation.dart';
import 'webauthn/webauthn_stub.dart'
    if (dart.library.js_interop) 'webauthn/webauthn_web.dart';

class WebAuthnClientService {
  static final WebAuthnClientService _instance = WebAuthnClientService._internal();
  factory WebAuthnClientService() => _instance;
  WebAuthnClientService._internal();

  final WebAuthnClientImpl _impl = WebAuthnClientImpl();

  bool get isWeb => kIsWeb;

  Future<bool> isBiometricsAvailable() => _impl.isBiometricsAvailable();
  Future<Map<String, dynamic>?> registerBiometrics(Map<String, dynamic> options) => _impl.registerBiometrics(options);
  Future<Map<String, dynamic>?> authenticateBiometrics(Map<String, dynamic> options) => _impl.authenticateBiometrics(options);
}


