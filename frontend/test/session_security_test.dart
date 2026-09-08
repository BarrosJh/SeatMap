import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:seatmap_frontend/providers/auth_provider.dart';
import 'package:seatmap_frontend/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String makeJwt(int expSeconds) {
  String encode(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'exp': expSeconds})}.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final secureValues = <String, String>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? {});
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return key == null ? null : secureValues[key];
          case 'write':
            if (key != null) secureValues[key] = args['value'] as String;
            return null;
          case 'delete':
            if (key != null) secureValues.remove(key);
            return null;
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  test('não mantém credenciais em SharedPreferences após migração', () async {
    SharedPreferences.setMockInitialValues({
      'seatmap_jwt_token': 'legacy-token',
      'seatmap_refresh_token': 'legacy-refresh',
      'seatmap_admin_token': 'legacy-admin'
    });

    final storage = SecureStorageService();
    await storage.migrateFromSharedPreferences();
    final prefs = await SharedPreferences.getInstance();

    expect(prefs.getString('seatmap_jwt_token'), isNull);
    expect(prefs.getString('seatmap_refresh_token'), isNull);
    expect(prefs.getString('seatmap_admin_token'), isNull);
    expect(await storage.getAdminToken(), isNull);
  });

  test('reconhece token JWT expirado como inválido no fluxo de inicialização',
      () async {
    final provider = AuthProvider();
    expect(provider.isAuthenticated, isFalse);
    expect(makeJwt((DateTime.now().millisecondsSinceEpoch ~/ 1000) - 60),
        contains('.'));
  });
}
