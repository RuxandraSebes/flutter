// REQ-9: All errors shown inline below buttons, not as snackbars above keyboard

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/access_code_service.dart';

class GenerateAccessCodeScreen extends StatefulWidget {
  const GenerateAccessCodeScreen({super.key});

  @override
  State<GenerateAccessCodeScreen> createState() =>
      _GenerateAccessCodeScreenState();
}

class _GenerateAccessCodeScreenState extends State<GenerateAccessCodeScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;
  final _service = AccessCodeService();

  // ── Numeric code state ──────────────────────────────────────────────────────
  String? _code;
  int _secondsLeft = 0;
  bool _loadingCode = false;
  bool _expired = false;
  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ── Email invite state ──────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  bool _sendingEmail = false;
  String? _sentToken;
  bool? _mailSent;
  String? _emailSentTo;

  // REQ-9: inline error states per tab
  String? _codeError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _tabs.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Code logic ──────────────────────────────────────────────────────────────

  Future<void> _generateCode() async {
    setState(() {
      _loadingCode = true;
      _expired = false;
      _code = null;
      _codeError = null;
    });
    _timer?.cancel();

    final result = await _service.generateCode();
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _code = result['code'];
        _secondsLeft = result['expires_in'] ?? 300;
        _loadingCode = false;
      });
      _startCountdown();
    } else {
      setState(() {
        _loadingCode = false;
        // REQ-9: set inline error
        _codeError = result['message'] ?? 'Eroare la generarea codului';
      });
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _expired = true;
          _code = null;
          t.cancel();
        }
      });
    });
  }

  void _copyCode() {
    if (_code == null) return;
    Clipboard.setData(ClipboardData(text: _code!));
    _showSnack('Cod copiat în clipboard');
  }

  Color get _timerColor {
    if (_secondsLeft > 120) return Colors.green.shade600;
    if (_secondsLeft > 30) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return m > 0 ? '$m min ${s.toString().padLeft(2, '0')} sec' : '$s secunde';
  }

  // ── Email logic ─────────────────────────────────────────────────────────────

  Future<void> _sendEmailInvite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Introdu o adresă de email validă.');
      return;
    }

    setState(() {
      _sendingEmail = true;
      _emailError = null;
    });
    final result = await _service.sendEmailInvite(email);
    if (!mounted) return;
    setState(() => _sendingEmail = false);

    if (result['success'] == true) {
      setState(() {
        _sentToken = result['invite_token'];
        _mailSent = result['mail_sent'] ?? false;
        _emailSentTo = email;
        _emailError = null;
      });
      _emailCtrl.clear();
    } else {
      // REQ-9: inline error below send button
      setState(() =>
          _emailError = result['message'] ?? 'Eroare la trimiterea invitației');
    }
  }

  void _copyToken() {
    if (_sentToken == null) return;
    Clipboard.setData(ClipboardData(text: _sentToken!));
    _showSnack('Token copiat în clipboard');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: const Text('Oferă acces însoțitor'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dialpad), text: 'Cod numeric'),
            Tab(icon: Icon(Icons.email_outlined), text: 'Invitație email'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_codeTab(), _emailTab()],
      ),
    );
  }

  // ── Tab 1: Numeric code ─────────────────────────────────────────────────────

  Widget _codeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _howItWorksCard(
            steps: const [
              ('1', 'Apasă „Generează cod"'),
              ('2', 'Comunică cele 6 cifre însoțitorului'),
              ('3', 'Însoțitorul introduce codul în aplicație'),
            ],
            note: 'Codul este valabil 5 minute.',
          ),
          const SizedBox(height: 32),

          // Code display
          if (_loadingCode)
            const CircularProgressIndicator(color: Color(0xFF1A5276))
          else if (_code != null && !_expired) ...[
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5276),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A5276).withOpacity(0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(children: [
                  const Text('Codul tău de acces',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 10),
                  Text(
                    _code!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.timer_outlined, color: _timerColor, size: 18),
                    const SizedBox(width: 6),
                    Text(_timerLabel,
                        style: TextStyle(
                            color: _timerColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _copyCode,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiază codul'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A5276),
                side: const BorderSide(color: Color(0xFF1A5276)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ] else if (_expired) ...[
            _expiredCard(),
          ] else ...[
            Container(
              height: 120,
              alignment: Alignment.center,
              child: Text(
                'Apasă butonul pentru a genera un cod',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loadingCode ? null : _generateCode,
              icon: _loadingCode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(_code != null && !_expired
                      ? Icons.refresh
                      : Icons.generating_tokens),
              label: Text(
                _code != null && !_expired
                    ? 'Regenerează codul'
                    : 'Generează cod',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5276),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          // REQ-9: Inline error below the generate button
          if (_codeError != null) ...[
            const SizedBox(height: 16),
            _inlineErrorWidget(_codeError!,
                onDismiss: () => setState(() => _codeError = null)),
          ],
        ],
      ),
    );
  }

  // ── Tab 2: Email invite ─────────────────────────────────────────────────────

  Widget _emailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _howItWorksCard(
            steps: const [
              ('1', 'Introdu adresa de email a însoțitorului'),
              ('2', 'Apasă „Trimite invitație"'),
              ('3', 'Însoțitorul primește un link pe email'),
            ],
            note: 'Link-ul este valabil 24 de ore.',
          ),
          const SizedBox(height: 28),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adresa de email',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A5276))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    onChanged: (_) {
                      if (_emailError != null)
                        setState(() => _emailError = null);
                    },
                    decoration: InputDecoration(
                      hintText: 'insotitorul@exemplu.ro',
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: Color(0xFF1A5276)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1A5276), width: 2)),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onSubmitted: (_) => _sendEmailInvite(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _sendingEmail ? null : _sendEmailInvite,
                      icon: _sendingEmail
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_outlined),
                      label: Text(
                        _sendingEmail ? 'Se trimite...' : 'Trimite invitație',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A5276),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  // REQ-9: Inline error below send button
                  if (_emailError != null) ...[
                    const SizedBox(height: 14),
                    _inlineErrorWidget(_emailError!,
                        onDismiss: () => setState(() => _emailError = null)),
                  ],
                ],
              ),
            ),
          ),
          if (_sentToken != null) ...[
            const SizedBox(height: 24),
            _inviteSentCard(),
          ],
        ],
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  // REQ-9: Reusable inline error widget
  Widget _inlineErrorWidget(String message, {VoidCallback? onDismiss}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.shade100,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        if (onDismiss != null)
          GestureDetector(
            onTap: onDismiss,
            child: Icon(Icons.close, color: Colors.red.shade400, size: 18),
          ),
      ]),
    );
  }

  Widget _howItWorksCard({
    required List<(String, String)> steps,
    required String note,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.people_alt_outlined,
              size: 40, color: Color(0xFF1A5276)),
          const SizedBox(height: 10),
          const Text('Cum funcționează?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A5276))),
          const SizedBox(height: 12),
          ...steps.map((s) => _step(s.$1, s.$2)),
          const SizedBox(height: 6),
          Text(note,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _step(String num, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Text(num,
                style: const TextStyle(
                    color: Color(0xFF1A5276),
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14))),
        ]),
      );

  Widget _expiredCard() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(children: [
          Icon(Icons.timer_off_outlined, size: 48, color: Colors.red.shade400),
          const SizedBox(height: 8),
          Text('Codul a expirat',
              style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          const SizedBox(height: 4),
          Text('Generează un cod nou',
              style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
        ]),
      );

  Widget _inviteSentCard() {
    final sent = _mailSent == true;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Icon(
            sent ? Icons.mark_email_read_outlined : Icons.info_outline,
            size: 48,
            color: sent ? Colors.green.shade600 : Colors.orange.shade600,
          ),
          const SizedBox(height: 12),
          Text(
            sent ? 'Invitație trimisă!' : 'Token generat (email indisponibil)',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: sent ? Colors.green.shade700 : Colors.orange.shade700),
            textAlign: TextAlign.center,
          ),
          if (_emailSentTo != null) ...[
            const SizedBox(height: 6),
            Text(
              sent
                  ? 'Email trimis la $_emailSentTo'
                  : 'Trimite manual tokenul de mai jos însoțitorului',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: const Color(0xFF1A5276).withOpacity(0.2)),
            ),
            child: Column(children: [
              Text('Token de invitație',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              SelectableText(
                _sentToken!,
                style: const TextStyle(
                    color: Color(0xFF1A5276),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _copyToken,
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copiază tokenul'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A5276),
              side: const BorderSide(color: Color(0xFF1A5276)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _sentToken = null;
              _mailSent = null;
              _emailSentTo = null;
            }),
            child: const Text('Trimite altă invitație',
                style: TextStyle(color: Colors.grey)),
          ),
        ]),
      ),
    );
  }
}
