import 'dart:async';
import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import '../models/user_model.dart';

/// REQ-10: Messages clearly indicate who is companion, patient, or doctor.
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
      // REQ-9: centered, visible error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Center(
          child: Text(result['error'] ?? 'Eroare la trimitere',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      _msgCtrl.text = text;
    }
  }

  bool _isMine(Map<String, dynamic> msg) {
    return msg['sender_id'] == widget.currentUser.id;
  }

  // REQ-10: Determine the display role label from sender context
  String _senderRoleLabel(Map<String, dynamic> msg) {
    final senderRole = msg['sender_role'] ?? '';
    final senderId = msg['sender_id'];

    if (senderRole == 'doctor_side') {
      return 'Medic';
    }

    // patient_side: could be patient or companion
    // We know the patientId — if sender is the patient, label "Pacient", else "Însoțitor"
    if (senderId == widget.patientId) {
      return 'Pacient';
    }
    // REQ-4 & REQ-10: Companion label
    return 'Însoțitor';
  }

  Color _senderRoleColor(Map<String, dynamic> msg) {
    final label = _senderRoleLabel(msg);
    switch (label) {
      case 'Medic':
        return const Color(0xFF1A5276);
      case 'Pacient':
        return Colors.green.shade700;
      case 'Însoțitor':
      default:
        return Colors.orange.shade700;
    }
  }

  IconData _senderRoleIcon(Map<String, dynamic> msg) {
    final label = _senderRoleLabel(msg);
    switch (label) {
      case 'Medic':
        return Icons.medical_services_outlined;
      case 'Pacient':
        return Icons.personal_injury_outlined;
      case 'Însoțitor':
      default:
        return Icons.people_alt_outlined;
    }
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
            'Conversație medicală',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reîncarcă',
            onPressed: () => _loadMessages(),
          ),
        ],
      ),
      body: Column(children: [
        // REQ-10: legend strip showing participant roles
        _roleLegend(),

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
                        roleLabel: _senderRoleLabel(_messages[i]),
                        roleColor: _senderRoleColor(_messages[i]),
                        roleIcon: _senderRoleIcon(_messages[i]),
                        showSenderName: !_isMine(_messages[i]),
                      ),
                    ),
        ),

        _inputBar(),
      ]),
    );
  }

  /// REQ-10: Small legend at the top clarifying the 3 roles
  Widget _roleLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendChip(Icons.medical_services_outlined, 'Medic',
              const Color(0xFF1A5276)),
          _legendChip(
              Icons.personal_injury_outlined, 'Pacient', Colors.green.shade700),
          _legendChip(
              Icons.people_alt_outlined, 'Însoțitor', Colors.orange.shade700),
        ],
      ),
    );
  }

  Widget _legendChip(IconData icon, String label, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _inputBar() {
    return Container(
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
        Material(
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
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          'Niciun mesaj încă.',
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
  final bool showSenderName;
  // REQ-10: role-based display
  final String roleLabel;
  final Color roleColor;
  final IconData roleIcon;

  const _MessageBubble({
    required this.msg,
    required this.isMine,
    required this.showSenderName,
    required this.roleLabel,
    required this.roleColor,
    required this.roleIcon,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? const Color(0xFF1A5276) : Colors.white;
    final textColor = isMine ? Colors.white : const Color(0xFF2C3E50);
    final time = _formatTime(msg['created_at']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // REQ-10: show role badge for all non-mine messages
          if (showSenderName)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(roleIcon, size: 12, color: roleColor),
                  const SizedBox(width: 4),
                  Text(
                    // REQ-10: show both role and name, e.g. "Medic · Dr. Popescu"
                    '$roleLabel · ${msg['sender_name'] ?? ''}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: roleColor,
                    ),
                  ),
                ]),
              ),
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
                  style: TextStyle(color: textColor, fontSize: 14, height: 1.4),
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
