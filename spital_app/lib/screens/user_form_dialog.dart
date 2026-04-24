// REQ-12: CNP shown and required for patient AND companion
// REQ-11: is_active toggle REMOVED entirely (from both create and edit forms)
// REQ-12: hospital field hidden when selected role is global_admin
// REQ-12: license_number field REMOVED for doctors
// REQ-9: inline error messages below the create button

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

  String _role = 'patient';
  int? _hospitalId;
  bool _obscure = true;

  // REQ-9: inline validation error
  String? _inlineError;

  bool get _isEdit => widget.existing != null;

  List<String> get _allowedRoles => widget.isHospitalAdmin
      ? ['doctor', 'patient', 'companion']
      : ['global_admin', 'hospital_admin', 'doctor', 'patient', 'companion'];

  // REQ-12: CNP needed for patient and companion
  bool get _needsCnp => _role == 'patient' || _role == 'companion';
  bool get _needsDoctor => _role == 'doctor';

  // REQ-12: Hospital field should NOT appear for global_admin role
  bool get _showHospital =>
      !widget.isHospitalAdmin &&
      widget.hospitals.isNotEmpty &&
      _role != 'global_admin';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e['name'] ?? '';
      _emailCtrl.text = e['email'] ?? '';
      _cnpCtrl.text = e['cnp_pacient'] ?? '';
      _specCtrl.text = e['specialization'] ?? '';
      _role = e['role'] ?? 'patient';
      _hospitalId = e['hospital_id'];
      // REQ-11: is_active intentionally NOT loaded — field removed entirely
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
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _setError(String msg) => setState(() => _inlineError = msg);
  void _clearError() {
    if (_inlineError != null) setState(() => _inlineError = null);
  }

  void _submit() {
    _clearError();

    if (_nameCtrl.text.trim().isEmpty) {
      _setError('Introdu numele complet.');
      return;
    }
    if (_emailCtrl.text.trim().isEmpty || !_emailCtrl.text.contains('@')) {
      _setError('Introdu o adresă de email validă.');
      return;
    }
    if (!_isEdit && _passwordCtrl.text.length < 6) {
      _setError('Parola trebuie să aibă minim 6 caractere.');
      return;
    }
    // REQ-12: Validate CNP for patient and companion
    if (_needsCnp && !_isEdit) {
      final cnp = _cnpCtrl.text.trim();
      if (cnp.isEmpty) {
        _setError('CNP-ul este obligatoriu pentru ${_roleLabel(_role)}.');
        return;
      }
      if (cnp.length != 13 || !RegExp(r'^\d{13}$').hasMatch(cnp)) {
        _setError('CNP-ul trebuie să aibă exact 13 cifre.');
        return;
      }
    }

    final fields = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'role': _role,
      // REQ-11: is_active NEVER sent — removed entirely
      if (!_isEdit) 'password': _passwordCtrl.text,
      if (_cnpCtrl.text.isNotEmpty) 'cnp_pacient': _cnpCtrl.text.trim(),
      if (_specCtrl.text.isNotEmpty) 'specialization': _specCtrl.text.trim(),
      // REQ-12: license_number removed from doctor form
      if (_hospitalId != null && _showHospital) 'hospital_id': _hospitalId,
    };

    Navigator.pop(context, fields);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        _isEdit ? 'Editează utilizator' : 'Utilizator nou',
        textAlign: TextAlign.center,
      ),
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
              onChanged: (v) {
                _clearError();
                setState(() {
                  _role = v ?? _role;
                  // REQ-12: clear hospital when switching to global_admin
                  if (_role == 'global_admin') _hospitalId = null;
                });
              },
            ),
            // REQ-12: Hospital dropdown — hidden for global_admin role
            if (_showHospital) ...[
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
            // REQ-12: CNP for patient AND companion
            if (_needsCnp) ...[
              const SizedBox(height: 12),
              _field(
                _cnpCtrl,
                _isEdit ? 'CNP (13 cifre)' : 'CNP * (13 cifre, obligatoriu)',
                Icons.badge_outlined,
                type: TextInputType.number,
              ),
            ],
            // REQ-12: Only specialization for doctors — license_number removed
            if (_needsDoctor) ...[
              const SizedBox(height: 12),
              _field(
                  _specCtrl, 'Specializare', Icons.medical_services_outlined),
            ],
            // REQ-11: is_active toggle REMOVED entirely — no longer shown anywhere
            const SizedBox(height: 16),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Anulează')),
                const SizedBox(width: 8),
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
            ),
            // REQ-9: Inline error BELOW the buttons
            if (_inlineError != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade300, width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _inlineError!,
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
          ]),
        ),
      ),
      // Override default actions since we embed them in content
      actions: const [],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type, bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      onChanged: (_) => _clearError(),
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
