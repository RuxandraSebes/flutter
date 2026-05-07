import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../main.dart';
import '../i18n/language_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  final int userId;
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isResending = false;
  String? _error;

  String _tr(String key) => LanguageProvider.of(context)?.tr(key) ?? key;

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-submit when all 6 digits filled
    if (_code.length == 6) _handleVerify();
    setState(() => _error = null);
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerify() async {
    if (_code.length != 6) {
      setState(() => _error = _tr('enter_full_code'));
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _authService.verifyEmail(
      userId: widget.userId,
      code: _code,
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
      setState(() => _error = _tr(result['message'] ?? 'error'));
      // Clear inputs on error
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    final result = await _authService.resendVerification(userId: widget.userId);
    if (!mounted) return;
    setState(() => _isResending = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_tr(result['success'] == true
          ? 'verification_code_resent'
          : (result['message'] ?? 'error'))),
      backgroundColor: result['success'] == true
          ? Colors.green.shade700
          : Colors.red.shade700,
    ));
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
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
        leading: BackButton(onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A5276).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    size: 40, color: Color(0xFF1A5276)),
              ),
              const SizedBox(height: 24),
              Text(
                _tr('verify_email_title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A5276),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '${_tr('verify_email_sent_to')} ${widget.email}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              // 6-digit OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) => _buildDigitBox(i)),
              ),

              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300, width: 1.5),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline,
                        color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
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
                      : Text(_tr('verify_button'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _isResending ? null : _handleResend,
                icon: _isResending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                label: Text(_tr('resend_code')),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1A5276)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 46,
      height: 56,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (e) => _onKeyDown(index, e),
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => _onDigitChanged(index, v),
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A5276)),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1A5276), width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
