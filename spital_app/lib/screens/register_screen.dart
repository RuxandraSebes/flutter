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
  final _cnpController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _loadingHospitals = true;
  bool _obscurePassword = true;

  late String _selectedRole;
  List<Map<String, dynamic>> _hospitals = [];
  int? _selectedHospitalId;

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

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final cnp = _cnpController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnack('Completeaza campurile obligatorii', isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnack('Parola trebuie sa aiba minim 6 caractere', isError: true);
      return;
    }
    if (_selectedRole == 'patient' && cnp.isNotEmpty && cnp.length != 13) {
      _showSnack('CNP-ul trebuie sa aiba exact 13 cifre', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.register(
      name: name,
      email: email,
      password: password,
      cnp: (_selectedRole == 'patient' && cnp.isNotEmpty) ? cnp : null,
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
      _showSnack(result['message'] ?? 'Eroare la inregistrare', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
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
                'Inregistreaza-te pentru a accesa portalul UPU',
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
                    label: 'Apartinator',
                    icon: Icons.people_alt_outlined,
                    value: 'companion'),
              ]),
              const SizedBox(height: 8),
              Text(
                _selectedRole == 'patient'
                    ? 'Acceseaza si gestioneaza propriile documente medicale'
                    : 'Vizualizeaza documentele pacientului la care esti asociat',
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
                      label: 'Parola * (min. 6 caractere)',
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

                    // CNP — patients only
                    if (_selectedRole == 'patient') ...[
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _cnpController,
                        label: 'CNP (optional — 13 cifre)',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.number,
                        helperText:
                            'Permite gasirea automata a fiselor UPU din Hipocrate',
                      ),
                    ],

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
                                      'Nu s-au putut incarca spitalele. Poti selecta ulterior din profil.',
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
                                  labelText: 'Spital (optional)',
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
                                      'Selecteaza spitalul la care ai mers',
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
                            : const Text('Creeaza cont',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
              ),

              // Companion tip
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
                    const Expanded(
                      child: Text(
                        'Dupa inregistrare, cere pacientului un cod de 6 cifre '
                        'sau un token de invitatie pentru a te asocia dosarului sau.',
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
                  child: const Text('Ai deja cont? Logheaza-te',
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
        onTap: () => setState(() => _selectedRole = value),
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
