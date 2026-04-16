import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/document_service.dart';
import 'login_screen.dart';
import 'pdf_viewer_screen.dart';

class DoctorScreen extends StatefulWidget {
  final UserModel user;
  const DoctorScreen({super.key, required this.user});

  @override
  State<DoctorScreen> createState() => _DoctorScreenState();
}

class _DoctorScreenState extends State<DoctorScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _admin = AdminService();
  final _docService = DocumentService();

  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>? _selectedPatient;
  bool _loadingP = true;
  bool _loadingD = true;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadPatients();
    _loadDocs();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _loadingP = true);
    final list = await _admin.getUsers(role: 'patient');
    if (mounted)
      setState(() {
        _patients = list;
        _loadingP = false;
      });
  }

  Future<void> _loadDocs({int? patientId}) async {
    setState(() => _loadingD = true);
    final list = await _docService.getDocuments(patientId: patientId);
    if (mounted)
      setState(() {
        _documents = list;
        _loadingD = false;
      });
  }

  Future<void> _uploadForPatient() async {
    if (_selectedPatient == null) {
      _snack('Selectează mai întâi un pacient', isError: true);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() => _uploading = true);
    final r = await _docService.uploadDocument(
      file.bytes!,
      file.name,
      patientId: _selectedPatient!['id'],
    );
    if (!mounted) return;
    setState(() => _uploading = false);

    if (r['success'] == true) {
      _snack('Document încărcat');
      _loadDocs(patientId: _selectedPatient!['id']);
    } else {
      _snack(r['message'], isError: true);
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.user.name,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Text(
              '${widget.user.specialization ?? 'Medic'} · ${widget.user.hospitalName}',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Pacienți'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Documente'),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 1
          ? FloatingActionButton.extended(
              onPressed: _uploading ? null : _uploadForPatient,
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
      body: TabBarView(controller: _tabs, children: [
        _patientsTab(),
        _documentsTab(),
      ]),
    );
  }

  Widget _patientsTab() {
    if (_loadingP) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadPatients,
      child: _patients.isEmpty
          ? const Center(child: Text('Niciun pacient în spital'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _patients.length,
              itemBuilder: (_, i) {
                final p = _patients[i];
                final isSelected = _selectedPatient?['id'] == p['id'];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                          color: isSelected
                              ? const Color(0xFF1A5276)
                              : Colors.transparent,
                          width: 2)),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? const Color(0xFF1A5276)
                            : const Color(0xFF1A5276).withOpacity(0.1),
                        child: Icon(Icons.person,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF1A5276))),
                    title: Text(p['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(p['email'] ?? ''),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle,
                            color: Color(0xFF1A5276))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedPatient = isSelected ? null : p;
                        _tabs.animateTo(1);
                      });
                      _loadDocs(patientId: isSelected ? null : p['id']);
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _documentsTab() {
    return Column(children: [
      if (_selectedPatient != null)
        Container(
          color: const Color(0xFF1A5276).withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.person, color: Color(0xFF1A5276), size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Pacient: ${_selectedPatient!['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A5276)))),
            TextButton(
              onPressed: () {
                setState(() => _selectedPatient = null);
                _loadDocs();
              },
              child: const Text('Toți',
                  style: TextStyle(color: Color(0xFF1A5276))),
            ),
          ]),
        ),
      Expanded(
        child: _loadingD
            ? const Center(child: CircularProgressIndicator())
            : _documents.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                              _selectedPatient != null
                                  ? 'Niciun document pentru pacient'
                                  : 'Selectează un pacient',
                              style: TextStyle(color: Colors.grey.shade600)),
                        ]),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        _loadDocs(patientId: _selectedPatient?['id']),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _documents.length,
                      itemBuilder: (_, i) {
                        final doc = _documents[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.picture_as_pdf,
                                color: Color(0xFF1A5276), size: 28),
                            title: Text(doc['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${doc['owner']?['name'] ?? ''} · ${doc['created_at'] ?? ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new,
                                  color: Color(0xFF1A5276)),
                              onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PdfViewerScreen(
                                        url: doc['url'], name: doc['name']),
                                  )),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}
