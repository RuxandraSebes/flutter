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
  final _relCtrl = TextEditingController();

  @override
  void dispose() {
    _relCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Leagă însoțitor de pacient'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Patient dropdown
          DropdownButtonFormField<Map<String, dynamic>>(
            decoration: _dec('Pacient', Icons.person),
            items: widget.patients
                .map((p) =>
                    DropdownMenuItem(value: p, child: Text(p['name'] ?? '')))
                .toList(),
            onChanged: (v) => setState(() => _selectedPatient = v),
          ),
          const SizedBox(height: 14),
          // Companion dropdown
          DropdownButtonFormField<Map<String, dynamic>>(
            decoration: _dec('Însoțitor', Icons.people),
            items: widget.companions
                .map((c) =>
                    DropdownMenuItem(value: c, child: Text(c['name'] ?? '')))
                .toList(),
            onChanged: (v) => setState(() => _selectedCompanion = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _relCtrl,
            decoration: _dec(
                'Relație (opțional, ex: soț, mamă)', Icons.favorite_border),
          ),
        ]),
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
          onPressed: _selectedPatient != null && _selectedCompanion != null
              ? () => Navigator.pop(context, {
                    'patient_id': _selectedPatient!['id'],
                    'companion_id': _selectedCompanion!['id'],
                    if (_relCtrl.text.trim().isNotEmpty)
                      'relationship': _relCtrl.text.trim(),
                  })
              : null,
          child: const Text('Leagă'),
        ),
      ],
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A5276)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
      );
}
