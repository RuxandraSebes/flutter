import 'package:flutter/material.dart';
import '../services/access_code_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../main.dart';
import 'register_screen.dart';
import 'login_screen.dart';

/// Shown when the app is opened via the email invite deep-link:
///   spitalapp://invite/<token>
/// or when the companion manually pastes a token.
///
/// Flow:
///   1. Check if user is logged in
///      - Yes → redeem token immediately → navigate to home
///      - No  → show Login / Register options, then redeem after auth
class InviteTokenScreen extends StatefulWidget {
  final String token;

  const InviteTokenScreen({super.key, required this.token});

  @override
  State<InviteTokenScreen> createState() => _InviteTokenScreenState();
}

class _InviteTokenScreenState extends State<InviteTokenScreen> {
  final _service = AccessCodeService();
  final _auth = AuthService();

  bool _loading = true;
  bool _isLoggedIn = false;
  bool _redeeming = false;
  bool _success = false;
  String? _patientName;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await _auth.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _loading = false;
    });

    if (loggedIn) {
      // Check role — only companions should redeem
      final user = await _auth.getCachedUser();
      if (user != null && user.isCompanion) {
        _redeemNow();
      } else if (user != null && !user.isCompanion) {
        setState(() => _error = 'Doar însoțitorii pot accepta invitații. '
            'Conectează-te cu un cont de tip Aparținător.');
      }
    }
  }

  Future<void> _redeemNow() async {
    setState(() {
      _redeeming = true;
      _error = null;
    });

    final result = await _service.redeemEmailInvite(widget.token);
    if (!mounted) return;
    setState(() => _redeeming = false);

    if (result['success'] == true) {
      setState(() {
        _success = true;
        _patientName = result['patient']?['name'];
      });
    } else {
      setState(() => _error = result['message'] ?? 'Token invalid sau expirat');
    }
  }

  void _goHome() async {
    final user = await _auth.getCachedUser();
    if (!mounted) return;
    if (user == null) {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
      return;
    }
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => roleBasedHome(user)), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: const Text('Invitație acces dosar'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _success
                  ? _successView()
                  : _isLoggedIn
                      ? _redeemView()
                      : _authChoiceView(),
        ),
      ),
    );
  }

  // ── Success view ────────────────────────────────────────────────────────────

  Widget _successView() {
    return Center(
      child: Column(children: [
        const SizedBox(height: 40),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
              color: Colors.green.shade50, shape: BoxShape.circle),
          child: Icon(Icons.check_circle_outline,
              size: 60, color: Colors.green.shade600),
        ),
        const SizedBox(height: 24),
        const Text('Asociere reușită!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A5276))),
        const SizedBox(height: 12),
        Text(
          'Ești acum asociat pacientului${_patientName != null ? '\n$_patientName' : ''}.\n'
          'Poți vizualiza documentele sale medicale.',
          style:
              TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goHome,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Mergi la documente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  // ── Redeem view (logged in companion) ──────────────────────────────────────

  Widget _redeemView() {
    return Center(
      child: Column(children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF1A5276).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mail_outline,
              size: 40, color: Color(0xFF1A5276)),
        ),
        const SizedBox(height: 20),
        const Text('Invitație primită',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A5276))),
        const SizedBox(height: 12),
        Text(
          'Un pacient ți-a trimis o invitație pentru a-i vizualiza dosarul medical.',
          style:
              TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          textAlign: TextAlign.center,
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200)),
            child: Row(children: [
              Icon(Icons.error_outline, color: Colors.red.shade600),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700))),
            ]),
          ),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _redeeming ? null : _redeemNow,
            icon: _redeeming
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.link),
            label: Text(
              _redeeming ? 'Se verifică...' : 'Acceptă invitația',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Auth choice view (not logged in) ───────────────────────────────────────

  Widget _authChoiceView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: const Color(0xFF1A5276).withOpacity(0.15))),
          child: Column(children: [
            const Icon(Icons.mail_outline, size: 40, color: Color(0xFF1A5276)),
            const SizedBox(height: 12),
            const Text('Invitație de acces dosar medical',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A5276))),
            const SizedBox(height: 8),
            Text(
              'Conectează-te sau creează un cont de tip Aparținător '
              'pentru a accepta această invitație.',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ]),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
              if (!mounted) return;
              // After login, check if now authenticated
              final loggedIn = await _auth.isLoggedIn();
              if (loggedIn) {
                setState(() => _isLoggedIn = true);
                _redeemNow();
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Am deja cont — Loghează-mă',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A5276),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => RegisterScreen(
                            preselectedRole: 'companion',
                            inviteToken: widget.token,
                          )));
              if (!mounted) return;
              final loggedIn = await _auth.isLoggedIn();
              if (loggedIn) {
                setState(() => _isLoggedIn = true);
                _redeemNow();
              }
            },
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Cont nou de Aparținător',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A5276),
              side: const BorderSide(color: Color(0xFF1A5276), width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200)),
          child: Row(children: [
            Icon(Icons.timer_outlined, color: Colors.amber.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Invitația este valabilă 24 de ore de la trimitere.',
                    style:
                        TextStyle(color: Colors.amber.shade800, fontSize: 12))),
          ]),
        ),
      ],
    );
  }
}
