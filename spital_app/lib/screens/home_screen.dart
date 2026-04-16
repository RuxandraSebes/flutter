import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import 'login_screen.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _docService = DocumentService();
  List<Map<String, dynamic>> _documents = [];
  bool _loadingDocs = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _fetchDocuments();
  }

  Future<void> _fetchDocuments() async {
    setState(() => _loadingDocs = true);
    final docs = await _docService.getDocuments();
    if (mounted)
      setState(() {
        _documents = docs;
        _loadingDocs = false;
      });
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
      _showSnack('Upload reușit');
      await _fetchDocuments();
    } else {
      _showSnack(response['message'], isError: true);
    }
  }

  Future<void> _deleteDocument(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Șterge document'),
        content: Text('Ești sigur că vrei să ștergi "$name"?'),
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
    } else
      _showSnack('Eroare la ștergere', isError: true);
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
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
      body: RefreshIndicator(
        onRefresh: _fetchDocuments,
        color: const Color(0xFF1A5276),
        child: _loadingDocs
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1A5276)))
            : _documents.isEmpty
                ? _emptyState(u)
                : _buildList(u),
      ),
    );
  }

  Widget _emptyState(UserModel u) => ListView(children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.65,
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
              u.isCompanion
                  ? 'Pacienții cu care ești asociat nu au documente'
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
          return _DocCard(
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

class _DocCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final bool canDelete;

  const _DocCard(
      {required this.doc,
      required this.onOpen,
      required this.onDelete,
      required this.canDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.picture_as_pdf,
              color: Color(0xFF1A5276), size: 28),
        ),
        title: Text(doc['name'] ?? 'Document',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc['created_at'] ?? '',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          if (doc['owner'] != null && doc['owner']['name'] != null)
            Text('Pacient: ${doc['owner']['name']}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.open_in_new, color: Color(0xFF1A5276)),
              tooltip: 'Deschide',
              onPressed: onOpen),
          if (canDelete)
            IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                tooltip: 'Șterge',
                onPressed: onDelete),
        ]),
      ),
    );
  }
}
