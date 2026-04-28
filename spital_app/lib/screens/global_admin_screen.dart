import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../i18n/translations.dart';
import 'login_screen.dart';
import '../i18n/language_provider.dart';
import 'user_form_dialog.dart';
import 'hospital_form_dialog.dart' as hfd;

class GlobalAdminScreen extends StatefulWidget {
  final UserModel user;
  const GlobalAdminScreen({super.key, required this.user});

  @override
  State<GlobalAdminScreen> createState() => _GlobalAdminScreenState();
}

class _GlobalAdminScreenState extends State<GlobalAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _admin = AdminService();

  List<Map<String, dynamic>> _hospitals = [];
  List<Map<String, dynamic>> _users = [];
  bool _loadingH = true;
  bool _loadingU = true;

  String _tr(String key) => AppLocalizations.of(context).get(key);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadHospitals();
    _loadUsers();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadHospitals() async {
    setState(() => _loadingH = true);
    final list = await _admin.getHospitals();
    if (mounted)
      setState(() {
        _hospitals = list;
        _loadingH = false;
      });
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

  // ── Hospital CRUD ─────────────────────────────────────────────────────────

  Future<void> _addHospital() async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const hfd.HospitalFormDialog());
    if (result == null) return;
    final r = await _admin.createHospital(result);
    if (r['success'] == true) {
      _snack(_tr('hospital_added'));
      _loadHospitals();
    } else
      _snack(r['message'], isError: true);
  }

  Future<void> _editHospital(Map<String, dynamic> h) async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => hfd.HospitalFormDialog(existing: h));
    if (result == null) return;
    final r = await _admin.updateHospital(h['id'], result);
    if (r['success'] == true) {
      _snack(_tr('hospital_updated'));
      _loadHospitals();
    } else
      _snack(r['message'], isError: true);
  }

  Future<void> _deleteHospital(Map<String, dynamic> h) async {
    final ok = await _confirm(
      _tr('delete_hospital'),
      '${_tr('delete_hospital_confirm')} "${h['name']}"?',
    );
    if (!ok) return;
    if (await _admin.deleteHospital(h['id'])) {
      _snack(_tr('hospital_deleted'));
      _loadHospitals();
    } else
      _snack(_tr('delete_error'), isError: true);
  }

  // ── User CRUD ─────────────────────────────────────────────────────────────

  Future<void> _addUser() async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => UserFormDialog(hospitals: _hospitals));
    if (result == null) return;
    final r = await _admin.createUser(result);
    if (r['success'] == true) {
      _snack(_tr('user_created'));
      _loadUsers();
    } else
      _snack(r['message'], isError: true);
  }

  Future<void> _editUser(Map<String, dynamic> u) async {
    final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => UserFormDialog(hospitals: _hospitals, existing: u));
    if (result == null) return;
    final r = await _admin.updateUser(u['id'], result);
    if (r['success'] == true) {
      _snack(_tr('user_updated'));
      _loadUsers();
    } else
      _snack(r['message'], isError: true);
  }

  Future<void> _deleteUser(Map<String, dynamic> u) async {
    final ok = await _confirm(
      _tr('delete_user'),
      '${_tr('delete_user_confirm')} "${u['name']}"?',
    );
    if (!ok) return;
    if (await _admin.deleteUser(u['id'])) {
      _snack(_tr('user_deleted'));
      _loadUsers();
    } else
      _snack(_tr('delete_error'), isError: true);
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
              child: Text(_tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tr('delete'),
                style: const TextStyle(color: Colors.white)),
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
          Text(_tr('global_admin_panel'),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              overflow: TextOverflow.ellipsis),
          Text(widget.user.name,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          const LanguageDropdown(),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout)
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
                icon: const Icon(Icons.local_hospital_outlined),
                text: _tr('hospitals')),
            Tab(icon: const Icon(Icons.people_outline), text: _tr('users')),
          ],
        ),
      ),
      body: TabBarView(
          controller: _tabs, children: [_hospitalsTab(), _usersTab()]),
    );
  }

  // ── Hospitals tab ─────────────────────────────────────────────────────────

  Widget _hospitalsTab() {
    if (_loadingH) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      _addBtn(_tr('add_hospital'), Icons.add, _addHospital),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadHospitals,
          child: _hospitals.isEmpty
              ? Center(child: Text(_tr('no_hospitals')))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _hospitals.length,
                  itemBuilder: (_, i) {
                    final h = _hospitals[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const CircleAvatar(
                            backgroundColor: Color(0xFF1A5276),
                            child: Icon(Icons.local_hospital,
                                color: Colors.white, size: 20)),
                        title: Text(h['name'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${h['city'] ?? ''} · ${h['users_count'] ?? 0} ${_tr('users_count_suffix')}'),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Color(0xFF1A5276)),
                              onPressed: () => _editHospital(h)),
                          IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400),
                              onPressed: () => _deleteHospital(h)),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    ]);
  }

  // ── Users tab ─────────────────────────────────────────────────────────────

  Widget _usersTab() {
    if (_loadingU) return const Center(child: CircularProgressIndicator());
    return Column(children: [
      _addBtn(_tr('add_user'), Icons.person_add_outlined, _addUser),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _loadUsers,
          child: _users.isEmpty
              ? Center(child: Text(_tr('no_users')))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _users.length,
                  itemBuilder: (_, i) {
                    final u = _users[i];
                    final roleColors = {
                      'global_admin': Colors.purple,
                      'hospital_admin': Colors.indigo,
                      'doctor': Colors.teal,
                      'patient': const Color(0xFF1A5276),
                      'companion': Colors.orange,
                    };
                    final color = roleColors[u['role']] ?? Colors.grey;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.15),
                            child: Icon(Icons.person, color: color)),
                        title: Text(u['name'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u['email'] ?? ''),
                              Row(children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text(_roleLabel(u['role']),
                                      style: TextStyle(
                                          color: color,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                ),
                                if (u['hospital'] != null) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                      child: Text('· ${u['hospital']['name']}',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis)),
                                ],
                              ]),
                            ]),
                        trailing:
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  color: Color(0xFF1A5276)),
                              onPressed: () => _editUser(u)),
                          IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: Colors.red.shade400),
                              onPressed: () => _deleteUser(u)),
                        ]),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ),
    ]);
  }

  Widget _addBtn(String label, IconData icon, VoidCallback onPressed) =>
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5276),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ),
      );

  String _roleLabel(String? role) {
    switch (role) {
      case 'global_admin':
        return _tr('role_global_admin');
      case 'hospital_admin':
        return _tr('role_hospital_admin');
      case 'doctor':
        return _tr('role_doctor');
      case 'patient':
        return _tr('role_patient_label');
      case 'companion':
        return _tr('role_companion_label');
      default:
        return role ?? '';
    }
  }
}
