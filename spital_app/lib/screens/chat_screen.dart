import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';

/// ChatScreen — shown for both patients/companions (single conversation)
/// and doctors/admins (a specific patient conversation passed in).
///
/// Usage:
///   // From doctor: pass patientId + patientName
///   ChatScreen(currentUser: doctor, patientId: 42, patientName: 'Ion Popescu')
///
///   // From patient/companion: patientId = the patient's own id
///   ChatScreen(currentUser: patient, patientId: patient.id, patientName: patient.name)
class ChatScreen extends StatefulWidget {
  final UserModel currentUser;
  final int patientId;
  final String patientName;

  const ChatScreen({
    super.key,
    required this.currentUser,
    required this.patientId,
    required this.patientName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = ChatService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Poll for new messages every 5 seconds
    _pollTimer = Timer.periodic(
        const Duration(seconds: 5), (_) => _loadMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final msgs = await _service.getMessages(widget.patientId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    final result = await _service.sendMessage(widget.patientId, text);
    if (!mounted) return;
    setState(() => _sending = false);

    if (result['success'] == true) {
      await _loadMessages(silent: true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['error'] ?? 'Eroare la trimitere'),
        backgroundColor: Colors.red.shade700,
      ));
      _msgCtrl.text = text; // restore text on failure
    }
  }

  bool _isMine(Map<String, dynamic> msg) {
    final senderId = msg['sender_id'];
    return senderId == widget.currentUser.id;
  }

  bool _isFromDoctorSide(Map<String, dynamic> msg) {
    return msg['sender_role'] == 'doctor_side';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.patientName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Text(
            'Conversatie medicala',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reincarca',
            onPressed: () => _loadMessages(),
          ),
        ],
      ),
      body: Column(children: [
        // Info banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1A5276).withOpacity(0.07),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 14, color: Color(0xFF1A5276)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.currentUser.isDoctor ||
                        widget.currentUser.isHospitalAdmin ||
                        widget.currentUser.isGlobalAdmin
                    ? 'Mesajele sunt vizibile pacientului si apartinatorilor acestuia.'
                    : 'Mesajele sunt trimise echipei medicale.',
                style: const TextStyle(fontSize: 11, color: Color(0xFF1A5276)),
              ),
            ),
          ]),
        ),

        // Messages list
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1A5276)))
              : _messages.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: _messages[i],
                        isMine: _isMine(_messages[i]),
                        isFromDoctorSide: _isFromDoctorSide(_messages[i]),
                        showSenderName: !_isMine(_messages[i]),
                      ),
                    ),
        ),

        // Input area
        Container(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgCtrl,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Scrie un mesaj...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Material(
                color: const Color(0xFF1A5276),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _sending ? null : _send,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          'Niciun mesaj inca.',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 6),
        Text(
          'Fii primul care trimite un mesaj.',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        ),
      ]),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMine;
  final bool isFromDoctorSide;
  final bool showSenderName;

  const _MessageBubble({
    required this.msg,
    required this.isMine,
    required this.isFromDoctorSide,
    required this.showSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? const Color(0xFF1A5276)
        : isFromDoctorSide
            ? const Color(0xFF2E86C1).withOpacity(0.12)
            : Colors.white;

    final textColor = isMine ? Colors.white : const Color(0xFF2C3E50);

    final time = _formatTime(msg['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSenderName)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Row(children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isFromDoctorSide
                        ? const Color(0xFF1A5276).withOpacity(0.15)
                        : Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFromDoctorSide
                        ? Icons.medical_services_outlined
                        : Icons.person_outline,
                    size: 12,
                    color: isFromDoctorSide
                        ? const Color(0xFF1A5276)
                        : Colors.orange,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  msg['sender_name'] ?? '',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isFromDoctorSide
                        ? const Color(0xFF1A5276)
                        : Colors.orange.shade700,
                  ),
                ),
              ]),
            ),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  msg['message'] ?? '',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        color: isMine
                            ? Colors.white.withOpacity(0.65)
                            : Colors.grey.shade400,
                        fontSize: 10,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg['read_at'] != null ? Icons.done_all : Icons.done,
                        size: 12,
                        color: msg['read_at'] != null
                            ? Colors.lightBlueAccent
                            : Colors.white.withOpacity(0.65),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
