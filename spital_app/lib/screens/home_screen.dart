// home_screen.dart — FIXED
// FIX 1: Unread dot now refreshes when returning from chat (patient)
// FIX 2: _fetchUnread also called on resume via WidgetsBindingObserver

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/chat_service.dart';
import '../i18n/translations.dart';
import '../i18n/language_provider.dart';
import 'login_screen.dart';
import 'pdf_viewer_screen.dart';
import 'generate_access_code_screen.dart';
import 'redeem_access_code_screen.dart';
import 'chat_screen.dart';
import 'my_companions_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _docService = DocumentService();
  final _chatService = ChatService();
  List<Map<String, dynamic>> _documents = [];
  bool _loadingDocs = true;
  bool _uploading = false;
  int _unreadMessages = 0;
  String? _inlineError;
  final Set<int> _deletingIds = {};

  String _tr(String key) => AppLocalizations.of(context).get(key);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchDocuments();
    _fetchUnread();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check unread count when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchUnread();
    }
  }

  Future<void> _fetchDocuments() async {
    setState(() => _loadingDocs = true);
    final docs = await _docService.getDocuments();
    if (mounted) {
      setState(() {
        _documents = docs;
        _loadingDocs = false;
      });
    }
  }

  Future<void> _fetchUnread() async {
    final convs = await _chatService.getConversations();
    if (mounted) {
      int total = 0;
      for (final c in convs) {
        total += (c['unread_count'] ?? 0) as int;
      }
      setState(() => _unreadMessages = total);
    }
  }

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    final response = await _docService.uploadDocument(file.bytes!, file.name);
    if (!mounted) return;
    setState(() => _uploading = false);

    if (response['success'] == true) {
      _clearInlineError();
      _showSnack(_tr('upload_success'));
      await _fetchDocuments();
    } else {
      _setInlineError(response['message'] ?? _tr('connection_error'));
    }
  }

  /// Called AFTER the swipe card has already shown its own confirm dialog.
  /// No second dialog here — just perform the deletion directly.
  Future<void> _deleteDocument(int id, String name) async {
    if (_deletingIds.contains(id)) return;
    _deletingIds.add(id);
    _clearInlineError();

    final ok = await _docService.deleteDocument(id);
    _deletingIds.remove(id);

    if (!mounted) return;
    if (ok) {
      _showSnack(_tr('document_deleted'));
      await _fetchDocuments();
    } else {
      _setInlineError(_tr('delete_error'));
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_tr('logout_confirm_title')),
        content: Text(_tr('logout_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_tr('cancel'))),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_tr('logout'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _setInlineError(String msg) {
    if (!mounted) return;
    setState(() => _inlineError = msg);
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) setState(() => _inlineError = null);
    });
  }

  void _clearInlineError() {
    if (mounted) setState(() => _inlineError = null);
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  /// Opens chat. Always refreshes unread count when returning.
  Future<void> _openChat() async {
    _clearInlineError();
    final u = widget.user;

    if (u.isPatient) {
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChatScreen(
                    currentUser: u,
                    patientId: u.id,
                    patientName: u.name,
                  )));
      // ← Always refresh unread when returning from chat
      _fetchUnread();
      return;
    }

    if (u.isCompanion) {
      final convs = await _chatService.getConversations();
      if (!mounted) return;
      if (convs.isEmpty) {
        _setInlineError(_tr('not_associated_any_patient'));
        return;
      }
      if (convs.length == 1) {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ChatScreen(
                      currentUser: u,
                      patientId: convs[0]['patient_id'],
                      patientName: convs[0]['patient_name'] ?? '',
                    )));
        _fetchUnread();
      } else {
        _showPatientPickerDialog(convs);
      }
    }
  }

  void _showPatientPickerDialog(List<Map<String, dynamic>> patients) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1A5276).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline,
                  color: Color(0xFF1A5276), size: 28),
            ),
            const SizedBox(height: 16),
            Text(_tr('select_conversation'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A5276),
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(_tr('choose_patient'),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ...patients.map((p) {
              final unread = (p['unread_count'] ?? 0) as int;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      Navigator.pop(context);
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                                currentUser: widget.user,
                                patientId: p['patient_id'],
                                patientName: p['patient_name'] ?? ''),
                          ));
                      _fetchUnread();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A5276).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFF1A5276).withOpacity(0.15)),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor:
                              const Color(0xFF1A5276).withOpacity(0.12),
                          child: const Icon(Icons.person,
                              color: Color(0xFF1A5276), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(p['patient_name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: Color(0xFF2C3E50),
                                  )),
                              if (p['last_message'] != null)
                                Text(p['last_message'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500)),
                            ])),
                        if (unread > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A5276),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                )),
                          )
                        else
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF1A5276)),
                      ]),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_tr('cancel'),
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u.name,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Text(u.roleLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          if (u.isPatient)
            IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: _tr('grant_access'),
                onPressed: () {
                  _clearInlineError();
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GenerateAccessCodeScreen()));
                }),
          if (u.isCompanion)
            IconButton(
                icon: const Icon(Icons.vpn_key_outlined),
                tooltip: _tr('associate_patient'),
                onPressed: () async {
                  _clearInlineError();
                  final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RedeemAccessCodeScreen()));
                  if (result == true) _fetchDocuments();
                }),
          const LanguageDropdown(),
          // ── Chat icon with unread badge ─────────────────────────────────
          Stack(children: [
            IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: _tr('messages'),
                onPressed: _openChat),
            if (_unreadMessages > 0)
              Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$_unreadMessages',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700)),
                  )),
          ]),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: _tr('logout'),
              onPressed: _logout),
        ],
      ),
      floatingActionButton: u.isPatient
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _uploadPdf,
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.upload_file),
              label: Text(_uploading ? _tr('uploading') : _tr('add_pdf')),
            )
          : null,
      body: Column(children: [
        if (u.isPatient) ...[
          _patientAccessBanner(),
          _managementRow(
            icon: Icons.manage_accounts_outlined,
            label: _tr('my_companions'),
            color: const Color(0xFF1A5276),
            onTap: () {
              _clearInlineError();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MyCompanionsScreen(user: u)));
            },
          ),
        ],
        if (u.isCompanion) ...[
          _companionAccessBanner(),
          _managementRow(
            icon: Icons.key_off_outlined,
            label: _tr('my_patients'),
            color: Colors.deepOrange,
            onTap: () {
              _clearInlineError();
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MyCompanionsScreen(user: u)));
            },
          ),
        ],
        if (_inlineError != null) _inlineErrorBanner(_inlineError!),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDocuments,
            color: const Color(0xFF1A5276),
            child: _loadingDocs
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A5276)))
                : _documents.isEmpty
                    ? _emptyState(u)
                    : _buildList(u),
          ),
        ),
      ]),
    );
  }

  Widget _patientAccessBanner() => InkWell(
        onTap: () {
          _clearInlineError();
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const GenerateAccessCodeScreen()));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF1A5276).withOpacity(0.07),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: const Color(0xFF1A5276).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.person_add_outlined,
                  color: Color(0xFF1A5276), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_tr('grant_access'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A5276),
                          fontSize: 14)),
                  Text(_tr('gen_code_desc'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
            const Icon(Icons.chevron_right, color: Color(0xFF1A5276)),
          ]),
        ),
      );

  Widget _companionAccessBanner() => InkWell(
        onTap: () async {
          _clearInlineError();
          final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (_) => const RedeemAccessCodeScreen()));
          if (result == true) _fetchDocuments();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.orange.withOpacity(0.07),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.vpn_key_outlined,
                  color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_tr('associate_patient'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                          fontSize: 14)),
                  Text(_tr('enter_code_desc'),
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ])),
            const Icon(Icons.chevron_right, color: Colors.orange),
          ]),
        ),
      );

  Widget _managementRow({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            border: Border(
              top: BorderSide(color: color.withOpacity(0.1)),
              bottom: BorderSide(color: color.withOpacity(0.1)),
            ),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6), size: 18),
          ]),
        ),
      );

  Widget _inlineErrorBanner(String message) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 22),
        const SizedBox(width: 12),
        Expanded(
            child: Text(message,
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center)),
        GestureDetector(
            onTap: _clearInlineError,
            child: Icon(Icons.close, color: Colors.red.shade400, size: 18)),
      ]),
    );
  }

  Widget _emptyState(UserModel u) => ListView(children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.folder_open_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_tr('no_documents'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                )),
            const SizedBox(height: 8),
            Text(
                u.isCompanion
                    ? _tr('associate_to_see_docs')
                    : _tr('no_docs_uploaded'),
                style: TextStyle(color: Colors.grey.shade500),
                textAlign: TextAlign.center),
          ]),
        ),
      ]);

  Widget _buildList(UserModel u) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        itemBuilder: (context, i) {
          final doc = _documents[i];
          return _SwipeToDeleteDocCard(
            doc: doc,
            canDelete: u.isPatient,
            patientPrefix: _tr('patient_prefix'),
            deleteTitle: _tr('delete_document_title'),
            deleteConfirm: _tr('delete_confirm'),
            cancelLabel: _tr('cancel'),
            deleteLabel: _tr('delete'),
            onOpen: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        PdfViewerScreen(url: doc['url'], name: doc['name']))),
            onDelete: () => _deleteDocument(doc['id'], doc['name']),
          );
        },
      );
}

class _SwipeToDeleteDocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool canDelete;
  final String patientPrefix;
  final String deleteTitle;
  final String deleteConfirm;
  final String cancelLabel;
  final String deleteLabel;

  const _SwipeToDeleteDocCard({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
    required this.canDelete,
    required this.patientPrefix,
    required this.deleteTitle,
    required this.deleteConfirm,
    required this.cancelLabel,
    required this.deleteLabel,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFF1A5276).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.picture_as_pdf,
                  color: Color(0xFF1A5276), size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(doc['name'] ?? 'Document',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(doc['created_at'] ?? '',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  if (doc['owner'] != null && doc['owner']['name'] != null)
                    Text('$patientPrefix: ${doc['owner']['name']}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12)),
                ])),
            const Icon(Icons.chevron_right, color: Color(0xFF1A5276), size: 20),
          ]),
        ),
      ),
    );

    if (!canDelete) return card;

    return Dismissible(
      key: Key('doc-${doc['id']}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(deleteTitle),
            content: Text('$deleteConfirm "${doc['name']}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(cancelLabel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(deleteLabel),
              ),
            ],
          ),
        );
        if (confirm == true) {
          onDelete();
          return true;
        }
        return false;
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: card,
    );
  }
}
