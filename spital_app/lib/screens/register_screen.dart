// REQ-2: Real-time CNP validation (13 digits, numeric only)
// REQ-9: Inline error messages below button
// REQ-11: Remove "active account" toggle from create forms
// REQ-12: Remove hospital field from Global Admin, license from doctor form
// REQ-13: Multilingual support (i18n)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../main.dart';
import '../i18n/language_provider.dart';

class RegisterScreen extends StatefulWidget {
  final String? preselectedRole;
  final String? inviteToken;

  const RegisterScreen({
    super.key,
    this.preselectedRole,
    this.inviteToken,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _cnpController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _loadingHospitals = true;
  bool _obscurePassword = true;

  late String _selectedRole;
  List<Map<String, dynamic>> _hospitals = [];
  int? _selectedHospitalId;

  String? _inlineError;

  // REQ-2: Real-time CNP validation state
  String? _cnpError;
  bool _cnpValid = false;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.preselectedRole ?? 'patient';
    _loadHospitals();
    _cnpController.addListener(_validateCnpRealTime);
  }

  // REQ-2: Real-time CNP validation
  void _validateCnpRealTime() {
    final cnp = _cnpController.text.trim();
    if (cnp.isEmpty) {
      setState(() {
        _cnpError = null;
        _cnpValid = false;
      });
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(cnp)) {
      setState(() {
        _cnpError = _tr('cnp_invalid');
        _cnpValid = false;
      });
      return;
    }
    if (cnp.length < 13) {
      setState(() {
        _cnpError = '${cnp.length}/13 cifre';
        _cnpValid = false;
      });
      return;
    }
    if (cnp.length == 13) {
      setState(() {
        _cnpError = null;
        _cnpValid = true;
      });
    } else {
      setState(() {
        _cnpError = _tr('cnp_invalid');
        _cnpValid = false;
      });
    }
  }

  String _tr(String key) => LanguageProvider.of(context)?.tr(key) ?? key;

  Future<void> _loadHospitals() async {
    final list = await _authService.getHospitals();
    if (mounted) {
      setState(() {
        _hospitals = list;
        _loadingHospitals = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _cnpController.removeListener(_validateCnpRealTime);
    _cnpController.dispose();
    super.dispose();
  }

  void _setError(String msg) => setState(() => _inlineError = msg);
  void _clearError() {
    if (_inlineError != null) setState(() => _inlineError = null);
  }

  Future<void> _handleRegister() async {
    _clearError();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final cnp = _cnpController.text.trim();

    if (name.isEmpty) {
      _setError(_tr('enter_name'));
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _setError(_tr('invalid_email'));
      return;
    }
    if (password.length < 6) {
      _setError(_tr('password_short'));
      return;
    }
    if (cnp.isEmpty) {
      _setError(_tr('cnp_required'));
      return;
    }
    if (cnp.length != 13 || !RegExp(r'^\d{13}$').hasMatch(cnp)) {
      _setError(_tr('cnp_invalid'));
      return;
    }

    setState(() => _isLoading = true);
    final result = await _authService.register(
      name: name,
      email: email,
      password: password,
      cnp: cnp,
      role: _selectedRole,
      hospitalId: _selectedHospitalId,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success'] == true) {
      final user = result['user'] as UserModel;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => roleBasedHome(user)), (_) => false);
    } else {
      // result['message'] may be an i18n key or a raw server message
      final rawKey = result['message'] as String? ?? 'connection_error';
      _setError(_tr(rawKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A5276),
        // ── Replaced old SimpleDialog language switcher with LanguageDropdown ──
        // LanguageDropdown is a const widget that reads the locale from the
        // inherited widget, so the flag updates immediately on switch.
        actions: const [LanguageDropdown()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_tr('create_account'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A5276))),
              const SizedBox(height: 6),
              Text(_tr('register_subtitle'),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey.shade600)),
              const SizedBox(height: 24),

              // Role selector
              Row(children: [
                _roleChip(
                    label: _tr('patient'),
                    icon: Icons.personal_injury_outlined,
                    value: 'patient'),
                const SizedBox(width: 12),
                _roleChip(
                    label: _tr('companion'),
                    icon: Icons.people_alt_outlined,
                    value: 'companion'),
              ]),
              const SizedBox(height: 8),
              Text(
                _selectedRole == 'patient'
                    ? _tr('patient_desc')
                    : _tr('companion_desc'),
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 20),

              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    _buildField(
                        controller: _nameController,
                        label: '${_tr('name')} *',
                        icon: Icons.person_outline),
                    const SizedBox(height: 16),
                    _buildField(
                        controller: _emailController,
                        label: '${_tr('email')} *',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    _buildField(
                        controller: _passwordController,
                        label: _tr('password_min'),
                        icon: Icons.lock_outline,
                        obscure: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        )),
                    const SizedBox(height: 16),

                    // REQ-2: Real-time CNP validation with visual feedback
                    _buildCnpField(),

                    const SizedBox(height: 16),
                    // Hospital picker
                    _buildHospitalPicker(),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A5276),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(_tr('create_account'),
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    if (_inlineError != null) ...[
                      const SizedBox(height: 16),
                      _inlineErrorWidget(_inlineError!),
                    ],
                  ]),
                ),
              ),

              if (_selectedRole == 'companion') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _tr('companion_info_note'),
                        style: const TextStyle(
                            fontSize: 13, color: Colors.deepOrange),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(_tr('have_account'),
                      style: const TextStyle(color: Color(0xFF1A5276))),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // REQ-2: CNP field with real-time validation
  Widget _buildCnpField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _cnpController,
          keyboardType: TextInputType.number,
          maxLength: 13,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => _clearError(),
          decoration: InputDecoration(
            labelText: _tr('cnp_field'),
            helperText: _selectedRole == 'patient'
                ? _tr('cnp_hipocrate')
                : _tr('cnp_companion_hint'),
            helperMaxLines: 2,
            counterText: '',
            prefixIcon: Icon(
              Icons.badge_outlined,
              color: _cnpValid
                  ? Colors.green.shade600
                  : _cnpError != null
                      ? Colors.red.shade600
                      : const Color(0xFF1A5276),
            ),
            suffixIcon: _cnpController.text.isNotEmpty
                ? Icon(
                    _cnpValid ? Icons.check_circle : Icons.error_outline,
                    color:
                        _cnpValid ? Colors.green.shade600 : Colors.red.shade500,
                    size: 20,
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _cnpValid
                    ? Colors.green.shade400
                    : _cnpError != null
                        ? Colors.red.shade400
                        : Colors.grey.shade300,
                width: _cnpValid || _cnpError != null ? 1.5 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color:
                    _cnpValid ? Colors.green.shade500 : const Color(0xFF1A5276),
                width: 2,
              ),
            ),
            filled: true,
            fillColor: _cnpValid
                ? Colors.green.shade50
                : _cnpError != null
                    ? Colors.red.shade50
                    : Colors.grey.shade50,
          ),
        ),
        if (_cnpController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_cnpController.text.trim().length / 13).clamp(0, 1),
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      _cnpValid
                          ? Colors.green.shade500
                          : _cnpController.text.trim().length < 8
                              ? Colors.orange.shade400
                              : Colors.red.shade400,
                    ),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _cnpValid
                    ? _tr('valid_status')
                    : _cnpError ?? '${_cnpController.text.trim().length}/13',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      _cnpValid ? Colors.green.shade600 : Colors.red.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _buildHospitalPicker() {
    if (_loadingHospitals) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Color(0xFF1A5276)),
        ),
      );
    }
    if (_hospitals.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_outlined,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
            _tr('hospital_load_error'),
            style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
          )),
        ]),
      );
    }
    return DropdownButtonFormField<int?>(
      value: _selectedHospitalId,
      decoration: InputDecoration(
        labelText: _tr('hospital_optional'),
        prefixIcon:
            const Icon(Icons.local_hospital_outlined, color: Color(0xFF1A5276)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A5276), width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
        helperText: _tr('select_hospital'),
      ),
      items: [
        DropdownMenuItem<int?>(value: null, child: Text(_tr('no_hospital'))),
        ..._hospitals.map((h) => DropdownMenuItem<int?>(
              value: h['id'] as int,
              child: Text('${h['name']} — ${h['city']}',
                  overflow: TextOverflow.ellipsis),
            )),
      ],
      onChanged: (v) => setState(() => _selectedHospitalId = v),
    );
  }

  Widget _roleChip(
      {required String label, required IconData icon, required String value}) {
    final selected = _selectedRole == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _clearError();
          setState(() => _selectedRole = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1A5276) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFF1A5276) : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(children: [
            Icon(icon,
                color: selected ? Colors.white : Colors.grey.shade500,
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: selected ? Colors.white : Colors.grey.shade700,
                )),
          ]),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
    String? helperText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: (_) => _clearError(),
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, color: const Color(0xFF1A5276)),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A5276), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _inlineErrorWidget(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                textAlign: TextAlign.center)),
      ]),
    );
  }
}
