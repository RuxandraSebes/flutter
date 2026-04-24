// REQ-3: Trash icon for removing companions/patients
// REQ-5: Patient can view and remove companions
// REQ-6: Companion can view and remove patients
// REQ-6-ext: Show CNP instead of email in relationships
// REQ-5-ext: Management row for both roles

import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/access_code_service.dart';
import '../i18n/language_provider.dart';

/// REQ-5: Patients can view and remove their companions.
/// REQ-6: Companions can view and remove their linked patients.
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

  String _tr(String key) => LanguageProvider.of(context)?.tr(key) ?? key;

  String get _title => _isPatient ? _tr('my_companions') : _tr('my_patients');
  String get _emptyText =>
      _isPatient ? _tr('no_companions') : _tr('not_associated');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final data = _isPatient
        ? await _service.getMyCompanions()
        : await _service.getMyPatients();
    if (mounted) {
      setState(() {
        _people = data;
        _loading = false;
      });
    }
  }

  Future<void> _remove(Map<String, dynamic> person) async {
    final name = person['name'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade600, size: 28),
          const SizedBox(width: 8),
          Text(_isPatient ? _tr('remove_companion') : _tr('remove_patient'),
              textAlign: TextAlign.center),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${_tr('remove_access')}\n"$name"?',
              textAlign: TextAlign.center),
        ]),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tr('cancel')),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text(_tr('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    bool ok;
    if (_isPatient) {
      ok = await _service.unlinkCompanion(person['id']);
    } else {
      ok = await _service.unlinkPatient(person['id']);
    }

    if (mounted) {
      if (ok) {
        _showSnack('$name ${_tr('removed')}');
        _load();
      } else {
        _showError(_tr('remove_link_error'));
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

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Center(
          child: Text(msg,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
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
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: _tr('refresh'),
              onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A5276)))
          : _people.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Column(children: [
                    // Info banner
                    Container(
                      color: _isPatient
                          ? const Color(0xFF1A5276).withOpacity(0.07)
                          : Colors.orange.withOpacity(0.07),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(children: [
                        Icon(
                          _isPatient
                              ? Icons.people_alt_outlined
                              : Icons.person_outline,
                          color: _isPatient
                              ? const Color(0xFF1A5276)
                              : Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                          _isPatient
                              ? '${_people.length} însoțitor${_people.length == 1 ? '' : 'i'} asociat${_people.length == 1 ? '' : 'i'}'
                              : '${_people.length} pacient${_people.length == 1 ? '' : 'i'} asociat${_people.length == 1 ? '' : 'i'}',
                          style: TextStyle(
                            color: _isPatient
                                ? const Color(0xFF1A5276)
                                : Colors.orange,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        )),
                      ]),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _people.length,
                        itemBuilder: (_, i) {
                          final person = _people[i];
                          return _PersonCard(
                            person: person,
                            isPatient: _isPatient,
                            onRemove: () => _remove(person),
                          );
                        },
                      ),
                    ),
                  ]),
                ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isPatient ? Icons.people_outline : Icons.person_outline,
              size: 52,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(_emptyText,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            _isPatient
                ? 'Generează un cod pentru a adăuga un însoțitor'
                : 'Introdu un cod de la pacient pentru a te asocia',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ]),
      );
}

class _PersonCard extends StatelessWidget {
  final Map<String, dynamic> person;
  final bool isPatient;
  final VoidCallback onRemove;

  const _PersonCard({
    required this.person,
    required this.isPatient,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPatient ? const Color(0xFF1A5276) : Colors.orange;
    // REQ-6: Show CNP instead of email
    final cnp = person['cnp_pacient'] as String?;
    final email = person['email'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPatient ? Icons.people_alt : Icons.person,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(person['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              // REQ-6: Prefer CNP over email
              if (cnp != null && cnp.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.badge_outlined, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text('CNP: $cnp',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600)),
                  ]),
                )
              else if (email != null)
                Row(children: [
                  Icon(Icons.email_outlined,
                      size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(email,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ]),
            ]),
          ),
          // REQ-3: Clear trash/delete icon
          Material(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.delete_outline,
                    color: Colors.red.shade600, size: 22),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
