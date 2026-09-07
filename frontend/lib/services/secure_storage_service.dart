import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
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
      
      final legacyToken = prefs.getString(AppConstants.keyToken);
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await write(AppConstants.keyToken, legacyToken);
        await prefs.remove(AppConstants.keyToken);
      }

      final legacyUserData = prefs.getString(AppConstants.keyUserData);
      if (legacyUserData != null && legacyUserData.isNotEmpty) {
        await write(AppConstants.keyUserData, legacyUserData);
        await prefs.remove(AppConstants.keyUserData);
      }

      final legacyAdminToken = prefs.getString(AppConstants.keyAdminToken);
      if (legacyAdminToken != null && legacyAdminToken.isNotEmpty) {
        await write(AppConstants.keyAdminToken, legacyAdminToken);
        await prefs.remove(AppConstants.keyAdminToken);
      }
    } catch (e, stackTrace) {
      debugPrint('[SecureStorageService] Falha não crítica na migração de SharedPreferences: $e\n$stackTrace');
    }
  }

  /// Gravação segura com fallback automático para SharedPreferences
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e, stackTrace) {
      debugPrint('[SecureStorageService] Falha ao gravar no FlutterSecureStorage ($key): $e\n$stackTrace');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
      } catch (fallbackError) {
        debugPrint('[SecureStorageService] Falha no fallback SharedPreferences: $fallbackError');
      }
    }
  }

  /// Leitura segura com fallback automático para SharedPreferences
  Future<String?> read(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null) return val;
    } catch (e) {
      debugPrint('[SecureStorageService] Falha ao ler do FlutterSecureStorage ($key): $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (e) {
      return null;
    }
  }

  /// Exclusão segura com sincronização em SharedPreferences
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('[SecureStorageService] Falha ao deletar do FlutterSecureStorage ($key): $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (e) {
      // ignore
    }
  }

  Future<void> saveToken(String token) async => write(AppConstants.keyToken, token);
  Future<String?> getToken() async => read(AppConstants.keyToken);

  Future<void> saveRefreshToken(String refreshToken) async => write(AppConstants.keyRefreshToken, refreshToken);
  Future<String?> getRefreshToken() async => read(AppConstants.keyRefreshToken);
  Future<void> deleteRefreshToken() async => delete(AppConstants.keyRefreshToken);

  Future<void> saveUserData(String userDataJson) async => write(AppConstants.keyUserData, userDataJson);
  Future<String?> getUserData() async => read(AppConstants.keyUserData);

  Future<void> saveAdminToken(String adminToken) async => write(AppConstants.keyAdminToken, adminToken);
  Future<String?> getAdminToken() async => read(AppConstants.keyAdminToken);

  Future<void> clearAll() async {
    await delete(AppConstants.keyToken);
    await delete(AppConstants.keyRefreshToken);
    await delete(AppConstants.keyUserData);
    await delete(AppConstants.keyAdminToken);
  }
}

