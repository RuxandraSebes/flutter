import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Handles all admin API calls:
///   - Hospital CRUD  (global_admin only)
///   - User CRUD      (global_admin + hospital_admin)
///   - Companion link / unlink
class AdminService {
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

  // ── Hospitals ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHospitals() async {
    try {
      final r = await http.get(
        Uri.parse('$_base/hospitals'),
        headers: await _headers(),
      );
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        return List<Map<String, dynamic>>.from(data['hospitals']);
      }
    } catch (e) {
      print('getHospitals error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createHospital(
      Map<String, dynamic> fields) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/hospitals'),
        headers: await _headers(),
        body: json.encode(fields),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 201)
        return {'success': true, 'hospital': data['hospital']};
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateHospital(
      int id, Map<String, dynamic> fields) async {
    try {
      final r = await http.put(
        Uri.parse('$_base/hospitals/$id'),
        headers: await _headers(),
        body: json.encode(fields),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 200)
        return {'success': true, 'hospital': data['hospital']};
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> deleteHospital(int id) async {
    try {
      final r = await http.delete(
        Uri.parse('$_base/hospitals/$id'),
        headers: await _headers(),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsers({String? role}) async {
    try {
      final uri = Uri.parse('$_base/users')
          .replace(queryParameters: role != null ? {'role': role} : null);
      final r = await http.get(uri, headers: await _headers());
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        return List<Map<String, dynamic>>.from(data['users']);
      }
    } catch (e) {
      print('getUsers error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> fields) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/users'),
        headers: await _headers(),
        body: json.encode(fields),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 201) return {'success': true, 'user': data['user']};
      String msg = data['message'] ?? 'Eroare';
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        msg = (errors.values.first as List).first.toString();
      }
      return {'success': false, 'message': msg};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUser(
      int id, Map<String, dynamic> fields) async {
    try {
      final r = await http.put(
        Uri.parse('$_base/users/$id'),
        headers: await _headers(),
        body: json.encode(fields),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 200) return {'success': true, 'user': data['user']};
      return {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> deleteUser(int id) async {
    try {
      final r = await http.delete(
        Uri.parse('$_base/users/$id'),
        headers: await _headers(),
      );
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Companion linking ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> linkCompanion({
    required int patientId,
    required int companionId,
    String? relationship,
    bool canViewDocuments = true,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/companions/link'),
        headers: await _headers(),
        body: json.encode({
          'patient_id': patientId,
          'companion_id': companionId,
          if (relationship != null) 'relationship': relationship,
          'can_view_documents': canViewDocuments,
        }),
      );
      final data = json.decode(r.body);
      return r.statusCode == 200
          ? {'success': true, 'message': data['message']}
          : {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> unlinkCompanion({
    required int patientId,
    required int companionId,
  }) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/companions/unlink'),
        headers: await _headers(),
        body: json.encode({
          'patient_id': patientId,
          'companion_id': companionId,
        }),
      );
      final data = json.decode(r.body);
      return r.statusCode == 200
          ? {'success': true, 'message': data['message']}
          : {'success': false, 'message': data['message'] ?? 'Eroare'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
