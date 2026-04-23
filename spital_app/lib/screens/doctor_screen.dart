import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../services/document_service.dart';
import '../services/chat_service.dart';
import 'login_screen.dart';
import 'pdf_viewer_screen.dart';
import 'chat_screen.dart';
import 'chat_conversations_screen.dart';

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
  final _chatService = ChatService();

  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _documents = [];
  Map<String, dynamic>? _selectedPatient;
  bool _loadingP = true;
  bool _loadingD = true;
  bool _uploading = false;
  String _searchQuery = '';
  int _unreadMessages = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _loadPatients();
    _loadDocs();
    _loadUnread();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _loadingP = true);
    final list = await _admin.getUsers(role: 'patient');
    if (mounted) {
      setState(() {
        _patients = list;
        _loadingP = false;
      });
    }
  }

  Future<void> _loadDocs({int? patientId}) async {
    setState(() => _loadingD = true);
    final list = await _docService.getDocuments(patientId: patientId);
    if (mounted) {
      setState(() {
        _documents = list;
        _loadingD = false;
      });
    }
  }

  Future<void> _loadUnread() async {
    final convs = await _chatService.getConversations();
    if (mounted) {
      int total = 0;
      for (final c in convs) {
        total += (c['unread_count'] ?? 0) as int;
      }
      setState(() => _unreadMessages = total);
    }
  }

  Future<void> _uploadForPatient() async {
    if (_selectedPatient == null) {
      _snack('Selecteaza mai intai un pacient', isError: true);
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
      _snack('Document incarcat cu succes');
      _loadDocs(patientId: _selectedPatient!['id']);
    } else {
      _snack(r['message'] ?? 'Eroare la upload', isError: true);
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

  List<Map<String, dynamic>> get _filteredPatients {
    if (_searchQuery.isEmpty) return _patients;
    final q = _searchQuery.toLowerCase();
    return _patients.where((p) {
      return (p['name'] ?? '').toLowerCase().contains(q) ||
          (p['email'] ?? '').toLowerCase().contains(q) ||
          (p['cnp_pacient'] ?? '').contains(q);
    }).toList();
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
          IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Deconectare',
              onPressed: _logout)
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            const Tab(icon: Icon(Icons.people_outline), text: 'Pacienti'),
            const Tab(icon: Icon(Icons.folder_outlined), text: 'Documente'),
            Tab(
              child: Stack(alignment: Alignment.topRight, children: [
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline),
                      Text('Mesaje', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                if (_unreadMessages > 0)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        '$_unreadMessages',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ]),
            ),
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
              label: Text(_uploading ? 'Se incarca...' : 'Adauga PDF'),
            )
          : null,
      body: TabBarView(controller: _tabs, children: [
        _patientsTab(),
        _documentsTab(),
        _chatTab(),
      ]),
    );
  }

  // ── Patients tab ──────────────────────────────────────────────────────────

  Widget _patientsTab() {
    if (_loadingP) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Cauta pacient (nume, email, CNP)...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF1A5276)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadPatients,
          child: _patients.isEmpty
              ? const Center(child: Text('Niciun pacient inregistrat'))
              : _filteredPatients.isEmpty
                  ? Center(
                      child: Text('Niciun rezultat pentru "$_searchQuery"',
                          style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredPatients.length,
                      itemBuilder: (_, i) {
                        final p = _filteredPatients[i];
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['email'] ?? '',
                                    style: const TextStyle(fontSize: 12)),
                                if (p['cnp_pacient'] != null)
                                  Text('CNP: ${p['cnp_pacient']}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500)),
                                if (p['hospital'] != null)
                                  Text('Spital: ${p['hospital']['name']}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500)),
                              ],
                            ),
                            trailing:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline,
                                    color: Color(0xFF1A5276), size: 20),
                                tooltip: 'Mesaj',
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      currentUser: widget.user,
                                      patientId: p['id'],
                                      patientName: p['name'] ?? '',
                                    ),
                                  ),
                                ).then((_) => _loadUnread()),
                              ),
                              isSelected
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF1A5276))
                                  : const Icon(Icons.chevron_right,
                                      color: Colors.grey),
                            ]),
                            isThreeLine: p['cnp_pacient'] != null,
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
        ),
      ),
    ]);
  }

  // ── Documents tab ─────────────────────────────────────────────────────────

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
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pacient: ${_selectedPatient!['name']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Color(0xFF1A5276))),
                if (_selectedPatient!['cnp_pacient'] != null)
                  Text('CNP: ${_selectedPatient!['cnp_pacient']}',
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF1A5276))),
              ],
            )),
            TextButton(
              onPressed: () {
                setState(() => _selectedPatient = null);
                _loadDocs();
              },
              child: const Text('Toti',
                  style: TextStyle(color: Color(0xFF1A5276))),
            ),
          ]),
        )
      else
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.grey, size: 18),
            const SizedBox(width: 8),
            const Expanded(
                child: Text(
                    'Selecteaza un pacient din tab-ul Pacienti pentru a filtra documentele',
                    style: TextStyle(color: Colors.grey, fontSize: 12))),
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
                                  ? 'Niciun document pentru acest pacient'
                                  : 'Selecteaza un pacient sau apasa refresh',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center),
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
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF1A5276).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.picture_as_pdf,
                                  color: Color(0xFF1A5276), size: 26),
                            ),
                            title: Text(doc['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(doc['created_at'] ?? '',
                                    style: const TextStyle(fontSize: 11)),
                                if (doc['owner']?['name'] != null)
                                  Text('Pacient: ${doc['owner']['name']}',
                                      style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                            isThreeLine: doc['owner']?['name'] != null,
                            trailing: IconButton(
                              icon: const Icon(Icons.open_in_new,
                                  color: Color(0xFF1A5276)),
                              tooltip: 'Deschide PDF',
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

  // ── Chat tab ──────────────────────────────────────────────────────────────

  Widget _chatTab() {
    return ChatConversationsScreen(currentUser: widget.user);
  }
}
