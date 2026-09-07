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
        await _storage.write(key: AppConstants.keyToken, value: legacyToken);
        await prefs.remove(AppConstants.keyToken);
      }

      final legacyUserData = prefs.getString(AppConstants.keyUserData);
      if (legacyUserData != null && legacyUserData.isNotEmpty) {
        await _storage.write(key: AppConstants.keyUserData, value: legacyUserData);
        await prefs.remove(AppConstants.keyUserData);
      }

      final legacyAdminToken = prefs.getString(AppConstants.keyAdminToken);
      if (legacyAdminToken != null && legacyAdminToken.isNotEmpty) {
        await _storage.write(key: AppConstants.keyAdminToken, value: legacyAdminToken);
        await prefs.remove(AppConstants.keyAdminToken);
      }
    } catch (_) {
      // Falha silenciosa na migração para não bloquear inicialização
    }
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.keyToken);
  }

  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.keyRefreshToken);
  }

  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: AppConstants.keyRefreshToken);
  }

  Future<void> saveUserData(String userDataJson) async {
    await _storage.write(key: AppConstants.keyUserData, value: userDataJson);
  }

  Future<String?> getUserData() async {
    return await _storage.read(key: AppConstants.keyUserData);
  }

  Future<void> saveAdminToken(String adminToken) async {
    await _storage.write(key: AppConstants.keyAdminToken, value: adminToken);
  }

  Future<String?> getAdminToken() async {
    return await _storage.read(key: AppConstants.keyAdminToken);
  }

  Future<void> clearAll() async {
    await _storage.delete(key: AppConstants.keyToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
    await _storage.delete(key: AppConstants.keyUserData);
    await _storage.delete(key: AppConstants.keyAdminToken);
  }
}

