import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../i18n/backend_message_mapper.dart';

class ChatService {
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

  /// List conversations for the current user.
  Future<List<Map<String, dynamic>>> getConversations() async {
    try {
      final r = await http.get(
        Uri.parse('$_base/chat/conversations'),
        headers: await _headers(),
      );
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        return List<Map<String, dynamic>>.from(data['conversations']);
      }
    } catch (_) {}
    return [];
  }

  /// Get messages for a conversation (by patient_id).
  Future<List<Map<String, dynamic>>> getMessages(int patientId) async {
    try {
      final r = await http.get(
        Uri.parse('$_base/chat/messages?patient_id=$patientId'),
        headers: await _headers(),
      );
      if (r.statusCode == 200) {
        final data = json.decode(r.body);
        return List<Map<String, dynamic>>.from(data['messages']);
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> markSeen(int patientId) async {
    final response = await http.post(
      Uri.parse('$_base/conversations/seen'),
      headers: await _headers(),
      body: {
        'patient_id': patientId.toString(),
      },
    );

    if (response.statusCode == 200) {
      return {'success': true};
    }

    return {'success': false};
  }

  /// Send a message.
  Future<Map<String, dynamic>> sendMessage(
      int patientId, String message) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/chat/messages'),
        headers: await _headers(),
        body: json.encode({'patient_id': patientId, 'message': message}),
      );
      final data = json.decode(r.body);
      if (r.statusCode == 201) {
        return {'success': true, 'message': backendMessageKey(data['message'])};
      }
      return {
        'success': false,
        'error': backendMessageKey(data['message'] ?? 'error')
      };
    } catch (_) {
      return {'success': false, 'error': 'connection_error'};
    }
  }
}
