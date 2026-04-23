// REQ-13: Relationship field removed from companion link dialog
// REQ-14: Search bar + scroll functionality for patient/companion lists

import 'package:flutter/material.dart';

class CompanionLinkDialog extends StatefulWidget {
  final List<Map<String, dynamic>> patients;
  final List<Map<String, dynamic>> companions;

  const CompanionLinkDialog({
    super.key,
    required this.patients,
    required this.companions,
  });

  @override
  State<CompanionLinkDialog> createState() => _CompanionLinkDialogState();
}

class _CompanionLinkDialogState extends State<CompanionLinkDialog> {
  Map<String, dynamic>? _selectedPatient;
  Map<String, dynamic>? _selectedCompanion;

  // REQ-14: search controllers for both lists
  final _patientSearchCtrl = TextEditingController();
  final _companionSearchCtrl = TextEditingController();
  String _patientQuery = '';
  String _companionQuery = '';

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    _companionSearchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPatients {
    if (_patientQuery.isEmpty) return widget.patients;
    final q = _patientQuery.toLowerCase();
    return widget.patients.where((p) {
      return (p['name'] ?? '').toLowerCase().contains(q) ||
          (p['cnp_pacient'] ?? '').contains(q) ||
          (p['email'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredCompanions {
    if (_companionQuery.isEmpty) return widget.companions;
    final q = _companionQuery.toLowerCase();
    return widget.companions.where((c) {
      return (c['name'] ?? '').toLowerCase().contains(q) ||
          (c['email'] ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title:
          const Text('Leagă însoțitor de pacient', textAlign: TextAlign.center),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Patient section ──────────────────────────────────────────────
            _sectionLabel('Selectează pacientul',
                Icons.personal_injury_outlined, const Color(0xFF1A5276)),
            const SizedBox(height: 8),
            // REQ-14: Search bar for patients
            _searchField(_patientSearchCtrl, 'Caută pacient (nume, CNP)...',
                (v) => setState(() => _patientQuery = v)),
            const SizedBox(height: 8),
            // REQ-14: Scrollable list of patients
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: _filteredPatients.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Niciun rezultat',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredPatients.length,
                      itemBuilder: (_, i) {
                        final p = _filteredPatients[i];
                        final isSelected = _selectedPatient?['id'] == p['id'];
                        return InkWell(
                          onTap: () => setState(() => _selectedPatient = p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF1A5276).withOpacity(0.12)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1A5276)
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected
                                    ? const Color(0xFF1A5276)
                                    : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(p['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      // REQ-12: CNP shown in selection
                                      if (p['cnp_pacient'] != null)
                                        Text(
                                          'CNP: ${p['cnp_pacient']}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500),
                                        ),
                                    ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 16),

            // ── Companion section ────────────────────────────────────────────
            _sectionLabel('Selectează însoțitorul', Icons.people_alt_outlined,
                Colors.orange),
            const SizedBox(height: 8),
            // REQ-14: Search bar for companions
            _searchField(_companionSearchCtrl, 'Caută însoțitor (nume)...',
                (v) => setState(() => _companionQuery = v)),
            const SizedBox(height: 8),
            // REQ-14: Scrollable list of companions
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: _filteredCompanions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Niciun rezultat',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredCompanions.length,
                      itemBuilder: (_, i) {
                        final c = _filteredCompanions[i];
                        final isSelected = _selectedCompanion?['id'] == c['id'];
                        return InkWell(
                          onTap: () => setState(() => _selectedCompanion = c),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.orange
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(children: [
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected ? Colors.orange : Colors.grey,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(c['name'] ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13)),
                                      Text(c['email'] ?? '',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500)),
                                    ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
            // REQ-13: Relationship field REMOVED entirely
            const SizedBox(height: 8),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          // REQ-13: only patient_id and companion_id, no relationship
          onPressed: _selectedPatient != null && _selectedCompanion != null
              ? () => Navigator.pop(context, {
                    'patient_id': _selectedPatient!['id'],
                    'companion_id': _selectedCompanion!['id'],
                    // relationship field removed per REQ-13
                  })
              : null,
          child: const Text('Leagă'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 6),
      Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }

  // REQ-14: Reusable search field
  Widget _searchField(
      TextEditingController ctrl, String hint, ValueChanged<String> onChanged) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        isDense: true,
      ),
    );
  }
}
