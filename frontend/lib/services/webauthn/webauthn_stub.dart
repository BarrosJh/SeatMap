class WebAuthnClientImpl {
  Future<bool> isBiometricsAvailable() async => false;
  Future<Map<String, dynamic>?> registerBiometrics(Map<String, dynamic> options) async => null;
  Future<Map<String, dynamic>?> authenticateBiometrics(Map<String, dynamic> options) async => null;
}

