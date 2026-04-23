// REQ-12: CNP mandatory for both patient and companion on registration
// REQ-9: Inline error messages below button, not snackbar above keyboard
// REQ-18: No active/inactive status field

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../main.dart';

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
  // REQ-12: CNP now mandatory for both patient and companion
  final _cnpController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _loadingHospitals = true;
  bool _obscurePassword = true;

  late String _selectedRole;
  List<Map<String, dynamic>> _hospitals = [];
  int? _selectedHospitalId;

  // REQ-9: inline error instead of snackbar-above-keyboard
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.preselectedRole ?? 'patient';
    _loadHospitals();
  }

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
    _cnpController.dispose();
    super.dispose();
  }

  void _setError(String msg) {
    setState(() => _inlineError = msg);
  }

  void _clearError() {
    if (_inlineError != null) setState(() => _inlineError = null);
  }

  Future<void> _handleRegister() async {
    _clearError();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    // REQ-12: CNP required for both roles
    final cnp = _cnpController.text.trim();

    if (name.isEmpty) {
      _setError('Introdu numele complet.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _setError('Introdu o adresă de email validă.');
      return;
    }
    if (password.length < 6) {
      _setError('Parola trebuie să aibă minim 6 caractere.');
      return;
    }
    // REQ-12: CNP mandatory for patient AND companion
    if (cnp.isEmpty) {
      _setError('CNP-ul este obligatoriu. Verifică că ai 13 cifre.');
      return;
    }
    if (cnp.length != 13 || !RegExp(r'^\d{13}$').hasMatch(cnp)) {
      _setError('CNP-ul trebuie să aibă exact 13 cifre.');
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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => roleBasedHome(user)),
        (_) => false,
      );
    } else {
      _setError(
          result['message'] ?? 'Eroare la înregistrare. Încearcă din nou.');
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Creare cont',
                  style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A5276))),
              const SizedBox(height: 6),
              Text(
                'Înregistrează-te pentru a accesa portalul UPU',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              // ── Role selector ───────────────────────────────────────────────
              Row(children: [
                _roleChip(
                    label: 'Pacient',
                    icon: Icons.personal_injury_outlined,
                    value: 'patient'),
                const SizedBox(width: 12),
                _roleChip(
                    label: 'Însoțitor',
                    icon: Icons.people_alt_outlined,
                    value: 'companion'),
              ]),
              const SizedBox(height: 8),
              Text(
                _selectedRole == 'patient'
                    ? 'Accesează și gestionează propriile documente medicale'
                    : 'Vizualizează documentele pacientului la care ești asociat',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // ── Form ────────────────────────────────────────────────────────
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    _buildField(
                      controller: _nameController,
                      label: 'Nume complet *',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _emailController,
                      label: 'Email *',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _passwordController,
                      label: 'Parolă * (min. 6 caractere)',
                      icon: Icons.lock_outline,
                      obscure: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),

                    // REQ-12: CNP mandatory for BOTH patient and companion
                    const SizedBox(height: 16),
                    _buildField(
                      controller: _cnpController,
                      label: 'CNP * (13 cifre)',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      helperText: _selectedRole == 'patient'
                          ? 'Necesar pentru identificarea fișelor UPU din Hipocrate'
                          : 'Necesar pentru identificarea corectă în sistemul spitalului',
                    ),

                    // ── Hospital picker ────────────────────────────────────────
                    const SizedBox(height: 16),
                    _loadingHospitals
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF1A5276)),
                            ),
                          )
                        : _hospitals.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(children: [
                                  Icon(Icons.warning_amber_outlined,
                                      color: Colors.orange.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Nu s-au putut încărca spitalele. Poți selecta ulterior din profil.',
                                      style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontSize: 12),
                                    ),
                                  ),
                                ]),
                              )
                            : DropdownButtonFormField<int?>(
                                value: _selectedHospitalId,
                                decoration: InputDecoration(
                                  labelText: 'Spital (opțional)',
                                  prefixIcon: const Icon(
                                      Icons.local_hospital_outlined,
                                      color: Color(0xFF1A5276)),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                          color: Colors.grey.shade300)),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF1A5276), width: 2)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  helperText:
                                      'Selectează spitalul la care ai mers',
                                ),
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('— Nu selectez acum —'),
                                  ),
                                  ..._hospitals
                                      .map((h) => DropdownMenuItem<int?>(
                                            value: h['id'] as int,
                                            child: Text(
                                              '${h['name']} — ${h['city']}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          )),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedHospitalId = v),
                              ),

                    const SizedBox(height: 28),

                    // Register button
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
                            : const Text('Creează cont',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),

                    // REQ-9: Inline error BELOW the button
                    if (_inlineError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.red.shade300, width: 1.5),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _inlineError!,
                                style: TextStyle(
                                  color: Colors.red.shade800,
                                  fontSize: 14,
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
                  ]),
                ),
              ),

              // Info tip for companion
              if (_selectedRole == 'companion') ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'După înregistrare, cere pacientului un cod de 6 cifre '
                        'sau un token de invitație pentru a te asocia dosarului său.',
                        style:
                            TextStyle(fontSize: 13, color: Colors.deepOrange),
                      ),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Ai deja cont? Loghează-te',
                      style: TextStyle(color: Color(0xFF1A5276))),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
                color:
                    selected ? const Color(0xFF1A5276) : Colors.grey.shade300,
                width: selected ? 2 : 1),
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
                    color: selected ? Colors.white : Colors.grey.shade700)),
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
}
