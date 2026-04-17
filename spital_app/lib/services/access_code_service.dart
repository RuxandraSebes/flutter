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

  /// Patient calls this to generate a 6-digit code (valid 60 s).
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
          'expires_in': data['expires_in'] ?? 60,
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (e) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }

  /// Companion calls this to redeem a code and get linked to the patient.
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
    } catch (e) {
      return {'success': false, 'message': 'Nu se poate conecta la server'};
    }
  }
}
