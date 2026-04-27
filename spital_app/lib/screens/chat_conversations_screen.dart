import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';
import '../i18n/language_provider.dart'; // Import necesar
import 'chat_screen.dart';

class ChatConversationsScreen extends StatefulWidget {
  final UserModel currentUser;

  const ChatConversationsScreen({super.key, required this.currentUser});

  @override
  State<ChatConversationsScreen> createState() =>
      _ChatConversationsScreenState();
}

class _ChatConversationsScreenState extends State<ChatConversationsScreen> {
  final _service = ChatService();
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  // Metodă helper pentru traduceri
  String _tr(String key) => LanguageProvider.of(context)?.tr(key) ?? key;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _service.getConversations();
    if (mounted) {
      setState(() {
        _conversations = list;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Text(_tr('chat_title'),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A5276)))
          : _conversations.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversations.length,
                    itemBuilder: (_, i) {
                      final conv = _conversations[i];
                      final unread = (conv['unread_count'] ?? 0) as int;
                      final total = (conv['total_count'] ?? 0) as int;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF1A5276).withOpacity(0.12),
                            child: const Icon(Icons.person,
                                color: Color(0xFF1A5276)),
                          ),
                          title: Text(
                            conv['patient_name'] ?? '',
                            style: TextStyle(
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conv['last_message'] ?? _tr('no_message'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread > 0
                                      ? const Color(0xFF1A5276)
                                      : Colors.grey.shade500,
                                  fontSize: 12,
                                  fontWeight: unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (total > 0)
                                Text(
                                  '$total ${total == 1 ? _tr('message_count_singular') : _tr('messages_count')}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400),
                                ),
                            ],
                          ),
                          isThreeLine: total > 0,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (conv['last_time'] != null)
                                Text(
                                  _formatTime(conv['last_time']),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade400),
                                ),
                              if (unread > 0) ...[
                                const SizedBox(height: 4),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A5276),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  currentUser: widget.currentUser,
                                  patientId: conv['patient_id'],
                                  patientName: conv['patient_name'] ?? '',
                                ),
                              ),
                            );

                            if (!mounted) return;
                            // Add a small delay so the backend's markSeen (called during
                            // dispose's getMessages) has time to commit before we reload
                            await Future.delayed(
                                const Duration(milliseconds: 300));
                            await _load();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.chat_bubble_outline,
              size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(_tr('no_messages'),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text(_tr('patients_initiate'),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center),
        ]),
      );

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
