import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Executa migração transparente de SharedPreferences legados para o Cofre Seguro
  Future<void> migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await _migrateKey(prefs, AppConstants.keyToken);
      await _migrateKey(prefs, AppConstants.keyRefreshToken);
      await _migrateKey(prefs, AppConstants.keyUserData);

      // Admin step-up tokens are intentionally not migrated or persisted.
      await prefs.remove(AppConstants.keyAdminToken);
    } catch (e, stackTrace) {
      debugPrint(
          '[SecureStorageService] Falha não crítica na migração de SharedPreferences: $e\n$stackTrace');
    }
  }

  Future<void> _migrateKey(SharedPreferences prefs, String key) async {
    final legacyValue = prefs.getString(key);
    if (legacyValue == null || legacyValue.isEmpty) return;

    try {
      await write(key, legacyValue);
    } catch (e) {
      debugPrint(
          '[SecureStorageService] Não foi possível migrar $key para o cofre seguro: $e');
    } finally {
      // Never leave a credential in the insecure legacy store after startup.
      await prefs.remove(key);
    }
  }

  /// Gravação exclusivamente no armazenamento seguro.
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, stackTrace) {
      debugPrint(
          '[SecureStorageService] Falha ao gravar no FlutterSecureStorage ($key): $e\n$stackTrace');
      rethrow;
    }
  }

  /// Leitura exclusivamente do armazenamento seguro.
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint(
          '[SecureStorageService] Falha ao ler do FlutterSecureStorage ($key): $e');
      return null;
    }
  }

  /// Remove a credencial do armazenamento seguro e qualquer cópia legada.
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint(
          '[SecureStorageService] Falha ao deletar do FlutterSecureStorage ($key): $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      // ignore
    }
  }

  Future<void> saveToken(String token) async =>
      write(AppConstants.keyToken, token);
  Future<String?> getToken() async => read(AppConstants.keyToken);

  Future<void> saveRefreshToken(String refreshToken) async =>
      write(AppConstants.keyRefreshToken, refreshToken);
  Future<String?> getRefreshToken() async => read(AppConstants.keyRefreshToken);
  Future<void> deleteRefreshToken() async =>
      delete(AppConstants.keyRefreshToken);

  Future<void> saveUserData(String userDataJson) async =>
      write(AppConstants.keyUserData, userDataJson);
  Future<String?> getUserData() async => read(AppConstants.keyUserData);

  // Step-up token is session-only and intentionally not persisted.
  Future<void> saveAdminToken(String adminToken) async {}
  Future<String?> getAdminToken() async => null;

  Future<void> clearAll() async {
    await delete(AppConstants.keyToken);
    await delete(AppConstants.keyRefreshToken);
    await delete(AppConstants.keyUserData);
    await delete(AppConstants.keyAdminToken);
  }
}
