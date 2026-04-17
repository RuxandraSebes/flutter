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
  final _service = AccessCodeService();

  String? _code;
  int _secondsLeft = 0;
  bool _loading = false;
  bool _expired = false;

  Timer? _timer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateCode() async {
    setState(() {
      _loading = true;
      _expired = false;
      _code = null;
    });
    _timer?.cancel();

    final result = await _service.generateCode();
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _code = result['code'];
        _secondsLeft = result['expires_in'] ?? 60;
        _loading = false;
      });
      _startCountdown();
    } else {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Eroare'),
        backgroundColor: Colors.red.shade700,
      ));
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Cod copiat în clipboard'),
      backgroundColor: Colors.green,
      duration: Duration(seconds: 2),
    ));
  }

  Color get _timerColor {
    if (_secondsLeft > 30) return Colors.green.shade600;
    if (_secondsLeft > 10) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: const Text('Oferă acces aparținător'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Info card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    const Icon(Icons.people_alt_outlined,
                        size: 48, color: Color(0xFF1A5276)),
                    const SizedBox(height: 12),
                    const Text(
                      'Cum funcționează?',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A5276)),
                    ),
                    const SizedBox(height: 10),
                    _step('1', 'Apasă „Generează cod"'),
                    _step('2', 'Comunică codul aparținătorului tău'),
                    _step('3',
                        'Aparținătorul îl introduce în aplicație → vă conectați'),
                    const SizedBox(height: 4),
                    Text(
                      'Codul este valabil 60 de secunde.',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
              ),

              const SizedBox(height: 32),

              // Code display area
              if (_loading)
                const CircularProgressIndicator(color: Color(0xFF1A5276))
              else if (_code != null && !_expired) ...[
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5276),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A5276).withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(children: [
                      const Text('Codul tău de acces',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
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
                      // Countdown ring
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.timer_outlined,
                                color: _timerColor, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '$_secondsLeft secunde',
                              style: TextStyle(
                                  color: _timerColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15),
                            ),
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(children: [
                    Icon(Icons.timer_off_outlined,
                        size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 8),
                    Text('Codul a expirat',
                        style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Generează un cod nou',
                        style: TextStyle(
                            color: Colors.red.shade400, fontSize: 13)),
                  ]),
                ),
              ] else ...[
                Container(
                  height: 130,
                  alignment: Alignment.center,
                  child: Text(
                    'Apasă butonul pentru a genera un cod',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Generate button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _generateCode,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          _code != null && !_expired
                              ? Icons.refresh
                              : Icons.generating_tokens,
                        ),
                  label: Text(
                    _code != null && !_expired
                        ? 'Regenerează codul'
                        : 'Generează cod',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A5276),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
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
}
