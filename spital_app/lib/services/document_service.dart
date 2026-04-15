import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
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

  /// Fetch all documents for the logged-in user
  Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/documents'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['documents']);
      }
    } catch (e) {
      print('getDocuments error: $e');
    }
    return [];
  }

  /// Upload a PDF file
  Future<Map<String, dynamic>> uploadDocument(File file, String name) async {
    try {
      final token = await _auth.getToken();
      final uri = Uri.parse('$baseUrl/documents');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json'
        ..fields['name'] = name
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: MediaType('application', 'pdf'),
        ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        return {'success': true, 'document': data['document']};
      }

      return {
        'success': false,
        'message': data['message'] ?? 'Upload eșuat',
      };
    } catch (e) {
      print('uploadDocument error: $e');
      return {'success': false, 'message': 'Eroare la upload'};
    }
  }

  /// Delete a document
  Future<bool> deleteDocument(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/documents/$id'),
        headers: await _headers(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
