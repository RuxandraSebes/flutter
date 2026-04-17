import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/access_code_service.dart';

class RedeemAccessCodeScreen extends StatefulWidget {
  const RedeemAccessCodeScreen({super.key});

  @override
  State<RedeemAccessCodeScreen> createState() => _RedeemAccessCodeScreenState();
}

class _RedeemAccessCodeScreenState extends State<RedeemAccessCodeScreen> {
  final _service = AccessCodeService();
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _success = false;
  String? _patientName;

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _fullCode =>
      _controllers.map((c) => c.text).join();

  bool get _isComplete => _fullCode.length == 6;

  Future<void> _redeem() async {
    if (!_isComplete) return;
    setState(() => _loading = true);

    final result = await _service.redeemCode(_fullCode);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      setState(() {
        _success = true;
        _patientName = result['patient']?['name'] ?? 'Pacient';
      });
    } else {
      // Clear all fields and refocus first
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message'] ?? 'Cod invalid sau expirat'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  void _onDigitChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Auto-submit when last digit entered
        if (_isComplete) _redeem();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: const Text('Introdu codul de acces'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _success ? _successView() : _inputView(),
        ),
      ),
    );
  }

  Widget _inputView() => Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header illustration
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.vpn_key_outlined,
                size: 40, color: Color(0xFF1A5276)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Asociere cu pacientul',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A5276)),
          ),
          const SizedBox(height: 8),
          Text(
            'Cere pacientului codul de 6 cifre generat\ndin aplicația sa și introdu-l mai jos.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // 6 digit boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: KeyboardListener(
                  focusNode: FocusNode(),
                  onKeyEvent: (e) => _onKeyEvent(e, i),
                  child: SizedBox(
                    width: 46,
                    height: 58,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF1A5276), width: 2),
                        ),
                      ),
                      onChanged: (v) => _onDigitChanged(v, i),
                    ),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 12),
          Text(
            'Codul este valabil 60 de secunde.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),

          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: (_isComplete && !_loading) ? _redeem : null,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link),
              label: Text(
                _loading ? 'Se verifică...' : 'Conectează-te',
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

          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              for (final c in _controllers) c.clear();
              _focusNodes[0].requestFocus();
            },
            child: const Text('Șterge codul',
                style: TextStyle(color: Colors.grey)),
          ),
        ],
      );

  Widget _successView() => Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline,
                size: 60, color: Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          const Text(
            'Asociere reușită!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A5276)),
          ),
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade700, height: 1.5),
              children: [
                const TextSpan(text: 'Ești acum asociat pacientului\n'),
                TextSpan(
                  text: _patientName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A5276),
                      fontSize: 17),
                ),
                const TextSpan(
                    text:
                        '\n\nVei putea acum vedea documentele\nmediale ale acestuia.'),
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A5276),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Înapoi la documente',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
}