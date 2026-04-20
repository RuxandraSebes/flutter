import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class AccessCodeService {
  static const String _base = AuthService.baseUrl;
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  // ── Numeric code ────────────────────────────────────────────────────────────

  /// Patient generates a 6-digit code (valid 5 minutes).
  Future<Map<String, dynamic>> generateCode() async {
    try {
      final r = await http.post(
        Uri.parse('$_base/access-codes/generate'),
        headers: await _headers(),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 201) {
        return {
          'success': true,
          'code': data['code'],
          'expires_in': data['expires_in'] ?? 300,
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (_) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  /// Companion redeems a 6-digit code → linked to patient.
  Future<Map<String, dynamic>> redeemCode(String code) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/access-codes/redeem'),
        headers: await _headers(),
        body: json.encode({'code': code}),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'patient': data['patient'],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (_) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  // ── Email invitation ────────────────────────────────────────────────────────

  /// Patient sends an email invite (valid 24 hours).
  Future<Map<String, dynamic>> sendEmailInvite(String email) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/access-codes/invite'),
        headers: await _headers(),
        body: json.encode({'email': email}),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'invite_token': data['invite_token'],
          'mail_sent': data['mail_sent'] ?? false,
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (_) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  /// Companion redeems an email invite token → linked to patient.
  Future<Map<String, dynamic>> redeemEmailInvite(String token) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/access-codes/invite/redeem'),
        headers: await _headers(),
        body: json.encode({'token': token}),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'],
          'patient': data['patient'],
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (_) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  // ── Companion management (patient POV) ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMyCompanions() async {
    try {
      final r = await http.get(
        Uri.parse('$_base/my-companions'),
        headers: await _headers(),
      );
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        return List<Map<String, dynamic>>.from(data['companions']);
      }
    } catch (_) {}
    return [];
  }

  Future<bool> unlinkCompanion(int companionId) async {
    try {
      final r = await http.delete(
        Uri.parse('$_base/my-companions/$companionId'),
        headers: await _headers(),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
