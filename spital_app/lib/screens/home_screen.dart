// REQ-1: Open PDF on row click (removed separate view icon)
// REQ-2: Swipe to delete PDF with confirmation
// REQ-3: person_add icon for Grant Access
// REQ-4: "Aparținător" → "Însoțitor" everywhere
// REQ-5: Patient can view and remove companions
// REQ-6: Companion can view and remove linked patients
// REQ-9: Improved error message visibility (centered, longer duration)

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/chat_service.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  final _docService = DocumentService();
  final _chatService = ChatService();
  List<Map<String, dynamic>> _documents = [];
  bool _loadingDocs = true;
  bool _uploading = false;
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
    _fetchUnread();
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
      _showSnack('Upload reusit');
      await _fetchDocuments();
    } else {
      // REQ-9: centered, longer error
      _showError(response['message'] ?? 'Eroare la upload');
    }
  }

  // REQ-2: Swipe to delete with confirmation
  Future<void> _deleteDocument(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // REQ-9: centered
        title: const Text('Sterge document', textAlign: TextAlign.center),
        content: Text('Ești sigur că vrei să ștergi "$name"?',
            textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anulează')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Șterge', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _docService.deleteDocument(id);
    if (ok) {
      _showSnack('Document șters');
      await _fetchDocuments();
    } else {
      _showError('Eroare la ștergere');
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deconectare'),
        content: const Text('Ești sigur că vrei să ieși din cont?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anulează')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Deconectare')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  // REQ-9: Centered, longer-duration error snackbar
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Center(
        child: Text(
          msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: Colors.red.shade700,
      duration: const Duration(seconds: 5), // REQ-9: longer
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
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

  void _openGenerateCode() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const GenerateAccessCodeScreen()));
  }

  Future<void> _openRedeemCode() async {
    final result = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => const RedeemAccessCodeScreen()));
    if (result == true) _fetchDocuments();
  }

  // REQ-5 & REQ-6: Open companion/patient management screen
  void _openRelationships() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MyCompanionsScreen(user: widget.user),
      ),
    );
  }

  Future<void> _openChat() async {
    final u = widget.user;
    if (u.isPatient) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            currentUser: u,
            patientId: u.id,
            patientName: u.name,
          ),
        ),
      ).then((_) => _fetchUnread());
      return;
    }
    if (u.isCompanion) {
      final convs = await _chatService.getConversations();
      if (!mounted) return;
      if (convs.isEmpty) {
        _showError('Nu ești asociat niciunui pacient');
        return;
      }
      if (convs.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              currentUser: u,
              patientId: convs[0]['patient_id'],
              patientName: convs[0]['patient_name'] ?? '',
            ),
          ),
        ).then((_) => _fetchUnread());
      } else {
        _showPatientPicker(convs);
      }
    }
  }

  void _showPatientPicker(List<Map<String, dynamic>> patients) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Selectează pacientul',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1A5276))),
          ),
          ...patients.map((p) => ListTile(
                leading: const CircleAvatar(
                    backgroundColor: Color(0xFF1A5276),
                    child: Icon(Icons.person, color: Colors.white, size: 18)),
                title: Text(p['patient_name'] ?? ''),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        currentUser: widget.user,
                        patientId: p['patient_id'],
                        patientName: p['patient_name'] ?? '',
                      ),
                    ),
                  ).then((_) => _fetchUnread());
                },
              )),
          const SizedBox(height: 16),
        ],
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
          // REQ-4: "Aparținător" → "Însoțitor" via UserModel.roleLabel
          Text(u.roleLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          if (u.isPatient)
            IconButton(
              // REQ-3: person_add icon replaces old grant-access icon
              icon: const Icon(Icons.person_add_outlined),
              // REQ-4: updated tooltip
              tooltip: 'Oferă acces însoțitor',
              onPressed: _openGenerateCode,
            ),
          if (u.isCompanion)
            IconButton(
              icon: const Icon(Icons.vpn_key_outlined),
              tooltip: 'Introdu cod pacient',
              onPressed: _openRedeemCode,
            ),
          // REQ-5 & REQ-6: manage relationships
          if (u.isPatient || u.isCompanion)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: u.isPatient ? 'Însoțitorii mei' : 'Pacienții mei',
              onPressed: _openRelationships,
            ),
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Mesaje',
              onPressed: _openChat,
            ),
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
                  child: Text(
                    '$_unreadMessages',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ]),
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Deconectare',
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
              label: Text(_uploading ? 'Se încarcă...' : 'Adaugă PDF'),
            )
          : null,
      body: Column(children: [
        // REQ-4: updated banner text
        if (u.isPatient) _patientAccessBanner(),
        if (u.isCompanion) _companionAccessBanner(),
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
        onTap: _openGenerateCode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: const Color(0xFF1A5276).withOpacity(0.07),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A5276).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              // REQ-3: person_add icon
              child: const Icon(Icons.person_add_outlined,
                  color: Color(0xFF1A5276), size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // REQ-4: "Însoțitor"
                    Text('Oferă acces însoțitor',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A5276),
                            fontSize: 14)),
                    Text('Generează un cod temporar de 6 cifre',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF1A5276)),
          ]),
        ),
      );

  Widget _companionAccessBanner() => InkWell(
        onTap: _openRedeemCode,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.orange.withOpacity(0.07),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.vpn_key_outlined,
                  color: Colors.orange, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Asociază-te cu un pacient',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                            fontSize: 14)),
                    Text('Introdu codul primit de la pacient',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
            ),
            const Icon(Icons.chevron_right, color: Colors.orange),
          ]),
        ),
      );

  Widget _emptyState(UserModel u) => ListView(children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.folder_open_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Niciun document',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(
              // REQ-4: "Însoțitor"
              u.isCompanion
                  ? 'Asociază-te cu un pacient pentru a vedea documentele'
                  : 'Nu ai documente încărcate',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
      ]);

  Widget _buildList(UserModel u) => ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _documents.length,
        itemBuilder: (context, i) {
          final doc = _documents[i];
          // REQ-1 & REQ-2: tap row to open, swipe to delete
          return _SwipeToDeleteDocCard(
            doc: doc,
            canDelete: u.isPatient,
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

// REQ-1: Entire row opens PDF (no separate view icon)
// REQ-2: Swipe left to reveal delete with confirmation
class _SwipeToDeleteDocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool canDelete;

  const _SwipeToDeleteDocCard({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
    required this.canDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // REQ-1: entire row tappable — no separate view icon button
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
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                    if (doc['owner'] != null && doc['owner']['name'] != null)
                      Text('Pacient: ${doc['owner']['name']}',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12)),
                  ]),
            ),
            // REQ-1: simple chevron to indicate tappable (no extra icon button)
            const Icon(Icons.chevron_right, color: Color(0xFF1A5276), size: 20),
          ]),
        ),
      ),
    );

    // REQ-2: Dismissible for swipe-to-delete (patients only)
    if (!canDelete) return card;

    return Dismissible(
      key: Key('doc-${doc['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
            SizedBox(height: 4),
            Text('Șterge',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      // REQ-2: confirm before delete
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            // REQ-9: centered
            title: const Text('Șterge document', textAlign: TextAlign.center),
            content: Text(
              'Ești sigur că vrei să ștergi\n"${doc['name']}"?',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Anulează')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Șterge', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: card,
    );
  }
}
