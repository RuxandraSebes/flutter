import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/access_code_service.dart';

/// REQ-5: Patients can view and remove their companions.
/// REQ-6: Companions can view and remove their linked patients.
/// Both roles use this single screen, adapted by role.
class MyCompanionsScreen extends StatefulWidget {
  final UserModel user;

  const MyCompanionsScreen({super.key, required this.user});

  @override
  State<MyCompanionsScreen> createState() => _MyCompanionsScreenState();
}

class _MyCompanionsScreenState extends State<MyCompanionsScreen> {
  final _service = AccessCodeService();

  List<Map<String, dynamic>> _people = [];
  bool _loading = true;

  bool get _isPatient => widget.user.isPatient;

  String get _title => _isPatient ? 'Însoțitorii mei' : 'Pacienții mei';
  String get _emptyText => _isPatient
      ? 'Nu ai niciun însoțitor asociat.'
      : 'Nu ești asociat niciunui pacient.';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final data = _isPatient
        ? await _service.getMyCompanions() // REQ-5
        : await _service.getMyPatients(); // REQ-6

    if (mounted) {
      setState(() {
        _people = data;
        _loading = false;
      });
    }
  }

  // REQ-5: patient removes companion / REQ-6: companion removes patient
  Future<void> _remove(Map<String, dynamic> person) async {
    final name = person['name'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // REQ-9: centered dialogs
        title: Text(
          _isPatient ? 'Elimină însoțitor' : 'Elimină pacient',
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Ești sigur că vrei să elimini accesul pentru\n"$name"?',
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
            child: const Text('Elimină', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    bool ok;
    if (_isPatient) {
      ok = await _service.unlinkCompanion(person['id']); // REQ-5
    } else {
      ok = await _service.unlinkPatient(person['id']); // REQ-6
    }

    if (mounted) {
      if (ok) {
        _showSnack('$name a fost eliminat');
        _load();
      } else {
        _showError('Nu s-a putut elimina legătura');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // REQ-9: centered, longer error
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Center(
        child: Text(msg,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title:
            Text(_title, style: const TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A5276)))
          : _people.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _people.length,
                    itemBuilder: (_, i) {
                      final person = _people[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                const Color(0xFF1A5276).withOpacity(0.12),
                            child: Icon(
                              _isPatient ? Icons.people_alt : Icons.person,
                              color: const Color(0xFF1A5276),
                            ),
                          ),
                          title: Text(
                            person['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            person['email'] ?? '',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.person_remove_outlined,
                                color: Colors.red.shade400),
                            tooltip: _isPatient
                                ? 'Elimină însoțitor'
                                : 'Elimină pacient',
                            onPressed: () => _remove(person),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isPatient ? Icons.people_outline : Icons.person_outline,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _emptyText,
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}
