import 'package:flutter/material.dart';

class HospitalFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const HospitalFormDialog({super.key, this.existing});

  @override
  State<HospitalFormDialog> createState() => _HospitalFormDialogState();
}

class _HospitalFormDialogState extends State<HospitalFormDialog> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] ?? '';
      _cityCtrl.text = e['city'] ?? '';
      _addrCtrl.text = e['address'] ?? '';
      _phoneCtrl.text = e['phone'] ?? '';
      _emailCtrl.text = e['email'] ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _cityCtrl, _addrCtrl, _phoneCtrl, _emailCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty || _cityCtrl.text.trim().isEmpty) return;

    final fields = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      if (_addrCtrl.text.isNotEmpty) 'address': _addrCtrl.text.trim(),
      if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
    };

    Navigator.pop(context, fields);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEdit ? 'Editează spital' : 'Spital nou',
        textAlign: TextAlign.center,
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(_nameCtrl, 'Nume spital *', Icons.local_hospital_outlined),
            const SizedBox(height: 12),
            _field(_cityCtrl, 'Oraș *', Icons.location_city_outlined),
            const SizedBox(height: 12),
            _field(_addrCtrl, 'Adresă', Icons.place_outlined),
            const SizedBox(height: 12),
            _field(_phoneCtrl, 'Telefon', Icons.phone_outlined,
                type: TextInputType.phone),
            const SizedBox(height: 12),
            _field(_emailCtrl, 'Email', Icons.email_outlined,
                type: TextInputType.emailAddress),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Anulează'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A5276),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: _submit,
          child: Text(_isEdit ? 'Salvează' : 'Creează'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A5276)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
