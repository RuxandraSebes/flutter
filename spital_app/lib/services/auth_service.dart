import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // Android emulator → 10.0.2.2, real device → your local IP e.g. 192.168.1.X
  static const String baseUrl = "http://127.0.0.1:8000/api";
  static const String _tokenKey = 'auth_token';

  final storage = const FlutterSecureStorage();

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<String?> getToken() => storage.read(key: _tokenKey);

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Map<String, String> _authHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

  // ── Auth ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        await storage.write(key: _tokenKey, value: data['token']);
        return {'success': true, 'user': data['user']};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Eroare la autentificare',
      };
    } catch (e) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? cnp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'password_confirmation': password,
          if (cnp != null && cnp.isNotEmpty) 'cnp_pacient': cnp,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        await storage.write(key: _tokenKey, value: data['token']);
        return {'success': true, 'user': data['user']};
      }

      // Extract first validation error if present
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

  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('$baseUrl/logout'),
          headers: _authHeaders(token),
        );
      }
    } catch (_) {
      // Even if server call fails, clear local token
    } finally {
      await storage.delete(key: _tokenKey);
    }
  }
}
