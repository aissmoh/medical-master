import 'package:shared_preferences/shared_preferences.dart';

class AuthStorageService {
  const AuthStorageService();

  static const String _tokenKey = 'auth_token';
  static const String _emailKey = 'auth_email';
  static const String _nameKey = 'auth_name';
  static const String _rememberMeKey = 'remember_me';

  Future<void> saveSession({
    required String token,
    required String email,
    required bool rememberMe,
    String? name,
  }) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_tokenKey, token);
    await preferences.setString(_emailKey, email);
    await preferences.setBool(_rememberMeKey, rememberMe);

    if (name != null && name.isNotEmpty) {
      await preferences.setString(_nameKey, name);
    }

    // Always save token regardless of rememberMe for current session
    print('Token saved: ${token.substring(0, 20)}...');
  }

  Future<void> saveName(String name) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_nameKey, name);
  }

  Future<void> clearSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_emailKey);
    await preferences.remove(_nameKey);
  }

  Future<String?> getToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    print(
      'Token retrieved: ${token != null ? token.substring(0, 20) + '...' : 'null'}',
    );
    return token;
  }

  Future<String?> getEmail() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_emailKey);
  }

  Future<String?> getName() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_nameKey);
  }
}
