import 'package:flutter/material.dart';

class UserFormDialog extends StatefulWidget {
  final List<Map<String, dynamic>> hospitals;
  final Map<String, dynamic>? existing;
  final bool isHospitalAdmin;

  const UserFormDialog({
    super.key,
    required this.hospitals,
    this.existing,
    this.isHospitalAdmin = false,
  });

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _cnpCtrl = TextEditingController();
  final _specCtrl = TextEditingController();
  final _licCtrl = TextEditingController();

  String _role = 'patient';
  int? _hospitalId;
  bool _isActive = true;
  bool _obscure = true;

  bool get _isEdit => widget.existing != null;

  List<String> get _allowedRoles => widget.isHospitalAdmin
      ? ['doctor', 'patient', 'companion']
      : ['global_admin', 'hospital_admin', 'doctor', 'patient', 'companion'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] ?? '';
      _emailCtrl.text = e['email'] ?? '';
      _cnpCtrl.text = e['cnp_pacient'] ?? '';
      _specCtrl.text = e['specialization'] ?? '';
      _licCtrl.text = e['license_number'] ?? '';
      _role = e['role'] ?? 'patient';
      _hospitalId = e['hospital_id'];
      _isActive = e['is_active'] ?? true;
    } else {
      _role = _allowedRoles.first;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _passwordCtrl,
      _cnpCtrl,
      _specCtrl,
      _licCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_nameCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) return;
    if (!_isEdit && _passwordCtrl.text.isEmpty) return;

    final fields = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'role': _role,
      'is_active': _isActive,
      if (!_isEdit) 'password': _passwordCtrl.text,
      if (_cnpCtrl.text.isNotEmpty) 'cnp_pacient': _cnpCtrl.text.trim(),
      if (_specCtrl.text.isNotEmpty) 'specialization': _specCtrl.text.trim(),
      if (_licCtrl.text.isNotEmpty) 'license_number': _licCtrl.text.trim(),
      if (_hospitalId != null && !widget.isHospitalAdmin)
        'hospital_id': _hospitalId,
    };

    Navigator.pop(context, fields);
  }

  @override
  Widget build(BuildContext context) {
    final needsDoctor = _role == 'doctor';
    final needsCnp = _role == 'patient';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_isEdit ? 'Editează utilizator' : 'Utilizator nou'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _field(_nameCtrl, 'Nume complet *', Icons.person_outline),
            const SizedBox(height: 12),
            _field(_emailCtrl, 'Email *', Icons.email_outlined,
                type: TextInputType.emailAddress),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              _field(_passwordCtrl, 'Parolă *', Icons.lock_outline,
                  obscure: _obscure,
                  suffix: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure))),
            ],
            const SizedBox(height: 12),
            // Role dropdown
            DropdownButtonFormField<String>(
              value:
                  _allowedRoles.contains(_role) ? _role : _allowedRoles.first,
              decoration: _dec('Rol', Icons.badge_outlined),
              items: _allowedRoles
                  .map((r) =>
                      DropdownMenuItem(value: r, child: Text(_roleLabel(r))))
                  .toList(),
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            // Hospital dropdown (global admin only)
            if (!widget.isHospitalAdmin && widget.hospitals.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _hospitalId,
                decoration: _dec('Spital', Icons.local_hospital_outlined),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('— Fără spital —')),
                  ...widget.hospitals.map((h) => DropdownMenuItem(
                      value: h['id'] as int, child: Text(h['name'] ?? ''))),
                ],
                onChanged: (v) => setState(() => _hospitalId = v),
              ),
            ],
            if (needsCnp) ...[
              const SizedBox(height: 12),
              _field(_cnpCtrl, 'CNP Pacient (13 cifre)', Icons.badge_outlined,
                  type: TextInputType.number),
            ],
            if (needsDoctor) ...[
              const SizedBox(height: 12),
              _field(
                  _specCtrl, 'Specializare', Icons.medical_services_outlined),
              const SizedBox(height: 12),
              _field(_licCtrl, 'Număr licență', Icons.assignment_outlined),
            ],
            const SizedBox(height: 12),
            Row(children: [
              const Text('Cont activ'),
              const Spacer(),
              Switch(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: const Color(0xFF1A5276),
              ),
            ]),
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
          onPressed: _submit,
          child: Text(_isEdit ? 'Salvează' : 'Creează'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      decoration: _dec(label, icon).copyWith(suffixIcon: suffix),
    );
  }

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A5276)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  String _roleLabel(String r) {
    switch (r) {
      case 'global_admin':
        return 'Admin Global';
      case 'hospital_admin':
        return 'Admin Spital';
      case 'doctor':
        return 'Medic';
      case 'patient':
        return 'Pacient';
      case 'companion':
        return 'Însoțitor';
      default:
        return r;
    }
  }
}
