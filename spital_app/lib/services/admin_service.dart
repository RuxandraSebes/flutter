import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

class AuthService {
  // Android emulator  → 10.0.2.2
  // Physical device   → your machine's LAN IP, e.g. 192.168.1.100
  static const String baseUrl = "http://10.0.2.2:8000/api";

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  final _storage = const FlutterSecureStorage();

  // ── Token ──────────────────────────────────────────────────────────────────

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Cached user ────────────────────────────────────────────────────────────

  Future<UserModel?> getCachedUser() async {
    final raw = await _storage.read(key: _userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(json.decode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveUser(Map<String, dynamic> userJson) async {
    await _storage.write(key: _userKey, value: json.encode(userJson));
  }

  // ── Auth headers ───────────────────────────────────────────────────────────

  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  // ── Login ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await _storage.write(key: _tokenKey, value: data['token']);
        await _saveUser(data['user']);
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Eroare la autentificare',
      };
    } catch (e) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  // ── Register ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? cnp,
    String role = 'patient',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          'role': role,
          if (cnp != null && cnp.isNotEmpty) 'cnp_pacient': cnp,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        await _storage.write(key: _tokenKey, value: data['token']);
        await _saveUser(data['user']);
        return {'success': true, 'user': UserModel.fromJson(data['user'])};
      }

      String message = data['message'] ?? 'Eroare la înregistrare';
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        message = (errors.values.first as List).first.toString();
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  // ── Fetch fresh /me ────────────────────────────────────────────────────────

  Future<UserModel?> fetchMe() async {
    try {
      final headers = await authHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/me'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveUser(data);
        return UserModel.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: await authHeaders(),
        );
      }
    } catch (_) {
    } finally {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userKey);
    }
  }
}
