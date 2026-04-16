import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class DocumentService {
  static const String baseUrl = AuthService.baseUrl;
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    };
  }

  /// Fetch documents. Pass [patientId] to filter by a specific patient (doctors / admins).
  Future<List<Map<String, dynamic>>> getDocuments({int? patientId}) async {
    try {
      final uri = Uri.parse('$baseUrl/documents').replace(
          queryParameters:
              patientId != null ? {'patient_id': patientId.toString()} : null);
      final response = await http.get(uri, headers: await _headers());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['documents']);
      }
    } catch (e) {
      print('getDocuments error: $e');
    }
    return [];
  }

  /// Upload a PDF. Pass [patientId] when a doctor uploads on behalf of a patient.
  Future<Map<String, dynamic>> uploadDocument(
    Uint8List bytes,
    String name, {
    int? patientId,
  }) async {
    try {
      final token = await _auth.getToken();
      final uri = Uri.parse('$baseUrl/documents');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json'
        ..fields['name'] = name
        ..files
            .add(http.MultipartFile.fromBytes('file', bytes, filename: name));

      if (patientId != null) {
        request.fields['patient_id'] = patientId.toString();
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'document': data['document']};
      }
      return {'success': false, 'message': data['message'] ?? 'Upload eșuat'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> deleteDocument(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$id'),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
