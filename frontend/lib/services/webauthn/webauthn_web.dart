import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

class WebAuthnClientImpl {
  Future<bool> isBiometricsAvailable() async {
    try {
      if (!globalContext.has('SeatMapWebAuthn')) return false;
      final bridge = globalContext['SeatMapWebAuthn'] as JSObject?;
      if (bridge == null || !bridge.has('isAvailable')) return false;

      final jsPromise = bridge.callMethod('isAvailable'.toJS) as JSPromise<JSBoolean>;
      final jsResult = await jsPromise.toDart;
      return jsResult.toDart;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> registerBiometrics(Map<String, dynamic> options) async {
    try {
      final bridge = globalContext['SeatMapWebAuthn'] as JSObject;
      final optionsJson = jsonEncode(options).toJS;

      final jsPromise = bridge.callMethod('register'.toJS, optionsJson) as JSPromise<JSString>;
      final jsResult = await jsPromise.toDart;
      final resultStr = jsResult.toDart;
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (_) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> authenticateBiometrics(Map<String, dynamic> options) async {
    try {
      final bridge = globalContext['SeatMapWebAuthn'] as JSObject;
      final optionsJson = jsonEncode(options).toJS;

      final jsPromise = bridge.callMethod('authenticate'.toJS, optionsJson) as JSPromise<JSString>;
      final jsResult = await jsPromise.toDart;
      final resultStr = jsResult.toDart;
      return jsonDecode(resultStr) as Map<String, dynamic>;
    } catch (_) {
      rethrow;
    }
  }
}

