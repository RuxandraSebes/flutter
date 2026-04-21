import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// Shown when a patient's account was auto-created from a Hipocrate PDF
/// (the email ends with @hipocrate.internal) and they log in for the first time.
///
/// Allows them to update their name and set a real email.
class ClaimAccountScreen extends StatefulWidget {
  final UserModel user;

  const ClaimAccountScreen({super.key, required this.user});

  @override
  State<ClaimAccountScreen> createState() => _ClaimAccountScreenState();

  /// Returns true if this user was auto-created from Hipocrate ingestion.
  static bool needsClaim(UserModel user) {
    final email = user.email ?? '';
    final name = user.name ?? '';

    return email.endsWith('@hipocrate.internal') || name.startsWith('Pacient ');
  }
}

class _ClaimAccountScreenState extends State<ClaimAccountScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.name;
    // Don't pre-fill internal emails
    if (!(widget.user.email ?? '').endsWith('@hipocrate.internal')) {
      _emailCtrl.text = widget.user.email ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (name.isEmpty) {
      _snack('Introdu numele tău', isError: true);
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _snack('Introdu o adresă de email validă', isError: true);
      return;
    }

    setState(() => _loading = true);

    // Use the /me endpoint after updating via admin panel
    // For now update via the auth service updateProfile method
    final token = await _auth.getToken();
    if (token == null) return;

    // Patch user via API
    final result = await _auth.updateProfile(name: name, email: email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      _snack('Profil actualizat cu succes');
      // Small delay then pop so parent can refresh
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } else {
      _snack(result['message'] ?? 'Eroare la actualizare', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: const Text('Completează profilul'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.shade100)),
              child: Column(children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFF1A5276), size: 36),
                const SizedBox(height: 12),
                const Text(
                  'Documentul tău medical a fost primit',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A5276)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Contul tău a fost creat automat când documentul a fost preluat din Hipocrate. '
                  'Te rugăm să completezi datele de contact.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                if (widget.user.cnpPacient != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1A5276).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      'CNP identificat: ${widget.user.cnpPacient}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A5276)),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 28),
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  _field(_nameCtrl, 'Nume complet *', Icons.person_outline),
                  const SizedBox(height: 16),
                  _field(_emailCtrl, 'Email de contact *', Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5276),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Salvează și continuă',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboardType}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1A5276)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A5276), width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }
}
