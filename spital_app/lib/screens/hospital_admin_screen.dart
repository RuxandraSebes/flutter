import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/document_service.dart';
import 'login_screen.dart';
import 'user_form_dialog.dart';
import 'companion_link_dialog.dart';
import 'pdf_viewer_screen.dart';

class HospitalAdminScreen extends StatefulWidget {
  final UserModel user;
  const HospitalAdminScreen({super.key, required this.user});

  @override
  State<HospitalAdminScreen> createState() => _HospitalAdminScreenState();
}

class _HospitalAdminScreenState extends State<HospitalAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _admin = AdminService();
  final _docService = DocumentService();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _documents = [];
  bool _loadingU = true;
  bool _loadingD = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadUsers();
    _loadDocs();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingU = true);
    final list = await _admin.getUsers();
    if (mounted)
      setState(() {
        _users = list;
        _loadingU = false;
      });
  }

  Future<void> _loadDocs() async {
    setState(() => _loadingD = true);
    final list = await _docService.getDocuments();
    if (mounted)
      setState(() {
        _documents = list;
        _loadingD = false;
      });
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  // ── User CRUD ─────────────────────────────────────────────────────────────

  Future<void> _addUser() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => UserFormDialog(hospitals: [], isHospitalAdmin: true),
    );
    if (result == null) return;
    final r = await _admin.createUser(result);
    if (r['success'] == true) {
      _snack('Utilizator creat');
      _loadUsers();
    } else
      _snack(r['message'], isError: true);
  }

  Future<void> _editUser(Map<String, dynamic> u) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          UserFormDialog(hospitals: [], existing: u, isHospitalAdmin: true),
    );
    if (result == null) return;
    final r = await _admin.updateUser(u['id'], result);
    if (r['success'] == true) {
      _snack('Actualizat');
      _loadUsers();
    } else
      _snack(r['message'], isError: true);
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final ok = await _confirm('Șterge utilizator', 'Ștergi "${u['name']}"?');
    if (!ok) return;
    if (await _admin.deleteUser(u['id'])) {
      _snack('Șters');
      _loadUsers();
    } else
      _snack('Eroare', isError: true);
  }

  Future<void> _linkCompanion() async {
    final patients = _users.where((u) => u['role'] == 'patient').toList();
    final companions = _users.where((u) => u['role'] == 'companion').toList();
    if (patients.isEmpty || companions.isEmpty) {
      _snack('Lipsesc pacienți sau însoțitori', isError: true);
      return;
    }
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          CompanionLinkDialog(patients: patients, companions: companions),
    );
    if (result == null) return;
    final r = await _admin.linkCompanion(
      patientId: result['patient_id'],
      companionId: result['companion_id'],
      relationship: result['relationship'],
    );
    _snack(r['message'] ?? (r['success'] ? 'Legat' : 'Eroare'),
        isError: r['success'] != true);
  }

  Future<bool> _confirm(String title, String content) async {
    final v = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Anulează')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Confirmă', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return v == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Admin Spital',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          Text(widget.user.hospitalName,
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
            Tab(icon: Icon(Icons.people_outline), text: 'Utilizatori'),
            Tab(icon: Icon(Icons.link), text: 'Însoțitori'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Documente'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _usersTab(),
        _companionTab(),
        _docsTab(),
      ]),
    );
  }

  // ── Tabs ──────────────────────────────────────────────────────────────────

  Widget _usersTab() {
    if (_loadingU) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _addUser,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Adaugă utilizator'),
              style: _btnStyle(),
            ),
          ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadUsers,
          child: _users.isEmpty
              ? const Center(child: Text('Niciun utilizator'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _users.length,
                  itemBuilder: (_, i) => _userCard(_users[i]),
                ),
        ),
      ),
    ]);
  }

  Widget _companionTab() {
    final patients = _users.where((u) => u['role'] == 'patient').toList();
    final companions = _users.where((u) => u['role'] == 'companion').toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _linkCompanion,
            icon: const Icon(Icons.link),
            label: const Text('Leagă însoțitor de pacient'),
            style: _btnStyle(),
          ),
        ),
        const SizedBox(height: 20),
        _sectionHeader('Pacienți (${patients.length})'),
        const SizedBox(height: 8),
        ...patients.map((p) => _simpleTile(
            icon: Icons.person,
            title: p['name'] ?? '',
            subtitle: p['email'] ?? '',
            color: const Color(0xFF1A5276))),
        const SizedBox(height: 16),
        _sectionHeader('Însoțitori (${companions.length})'),
        const SizedBox(height: 8),
        ...companions.map((c) => _simpleTile(
            icon: Icons.people,
            title: c['name'] ?? '',
            subtitle: c['email'] ?? '',
            color: Colors.orange)),
      ]),
    );
  }

  Widget _docsTab() {
    if (_loadingD) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _loadDocs,
      child: _documents.isEmpty
          ? const Center(child: Text('Niciun document'))
          : ListView.builder(
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
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _userCard(Map<String, dynamic> u) {
    final roleColors = {
      'hospital_admin': Colors.indigo,
      'doctor': Colors.teal,
      'patient': const Color(0xFF1A5276),
      'companion': Colors.orange,
    };
    final color = roleColors[u['role']] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: Icon(Icons.person, color: color)),
        title: Text(u['name'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u['email'] ?? ''),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(_roleLabel(u['role']),
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF1A5276)),
              onPressed: () => _editUser(u)),
          IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
              onPressed: () => _deleteUser(u)),
        ]),
        isThreeLine: true,
      ),
    );
  }

  Widget _simpleTile(
      {required IconData icon,
      required String title,
      required String subtitle,
      required Color color}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(text,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A5276)));

  ButtonStyle _btnStyle() => ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1A5276),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)));

  String _roleLabel(String? role) {
    switch (role) {
      case 'hospital_admin':
        return 'Admin Spital';
      case 'doctor':
        return 'Medic';
      case 'patient':
        return 'Pacient';
      case 'companion':
        return 'Însoțitor';
      default:
        return role ?? '';
    }
  }
}
