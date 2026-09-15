import 'package:flutter_secure_storage/flutter_secure_storage.dart';  
  
/// Contract §1/§5 — Sanctum token persistence.  
class TokenStorage {  
  TokenStorage({FlutterSecureStorage? storage})  
      : _storage = storage ?? const FlutterSecureStorage();  
  
  final FlutterSecureStorage _storage;  
  static const _tokenKey = 'auth_token';  
  
  Future<void> save(String token) => _storage.write(key: _tokenKey, value: token);  
  Future<String?> read() => _storage.read(key: _tokenKey);  
  Future<void> clear() => _storage.delete(key: _tokenKey);  
}  
