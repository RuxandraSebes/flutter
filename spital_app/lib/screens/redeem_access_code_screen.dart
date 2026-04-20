import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/access_code_service.dart';

class RedeemAccessCodeScreen extends StatefulWidget {
  const RedeemAccessCodeScreen({super.key});

  @override
  State<RedeemAccessCodeScreen> createState() => _RedeemAccessCodeScreenState();
}

class _RedeemAccessCodeScreenState extends State<RedeemAccessCodeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = AccessCodeService();

  // ── Numeric code state ──────────────────────────────────────────────────────
  final _digitControllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loadingCode = false;
  bool _successCode = false;

  // ── Token state ─────────────────────────────────────────────────────────────
  final _tokenCtrl = TextEditingController();
  bool _loadingToken = false;
  bool _successToken = false;

  // ── Shared success state ────────────────────────────────────────────────────
  String? _linkedPatientName;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in _digitControllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  // ── Numeric code logic ──────────────────────────────────────────────────────

  String get _fullCode => _digitControllers.map((c) => c.text).join();

  bool get _isCodeComplete => _fullCode.length == 6;

  Future<void> _redeemCode() async {
    if (!_isCodeComplete) return;
    setState(() => _loadingCode = true);

    final result = await _service.redeemCode(_fullCode);
    if (!mounted) return;
    setState(() => _loadingCode = false);

    if (result['success'] == true) {
      setState(() {
        _successCode = true;
        _linkedPatientName = result['patient']?['name'] ?? 'Pacient';
      });
    } else {
      for (final c in _digitControllers) c.clear();
      _focusNodes[0].requestFocus();
      _snack(result['message'] ?? 'Cod invalid sau expirat', isError: true);
    }
  }

  void _onDigitChanged(String value, int index) {
    if (value.length == 1) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_isCodeComplete) _redeemCode();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _onKeyEvent(KeyEvent event, int index) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _digitControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  // ── Token logic ─────────────────────────────────────────────────────────────

  Future<void> _redeemToken() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      _snack('Introdu tokenul de invitație', isError: true);
      return;
    }
    setState(() => _loadingToken = true);

    final result = await _service.redeemEmailInvite(token);
    if (!mounted) return;
    setState(() => _loadingToken = false);

    if (result['success'] == true) {
      setState(() {
        _successToken = true;
        _linkedPatientName = result['patient']?['name'] ?? 'Pacient';
      });
    } else {
      _snack(result['message'] ?? 'Token invalid sau expirat', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
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
        title: const Text('Asociere cu pacientul'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dialpad), text: 'Cod numeric'),
            Tab(icon: Icon(Icons.vpn_key_outlined), text: 'Token email'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_codeTab(), _tokenTab()],
      ),
    );
  }

  // ── Tab 1: 6-digit code ─────────────────────────────────────────────────────

  Widget _codeTab() {
    if (_successCode) return _successView();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF1A5276).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.dialpad, size: 40, color: Color(0xFF1A5276)),
          ),
          const SizedBox(height: 20),
          const Text('Introdu codul numeric',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A5276))),
          const SizedBox(height: 8),
          Text(
            'Cere pacientului codul de 6 cifre generat\ndin aplicația sa.',
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
                      controller: _digitControllers[i],
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
            'Codul expiră după 5 minute.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 36),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  (_isCodeComplete && !_loadingCode) ? _redeemCode : null,
              icon: _loadingCode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link),
              label: Text(
                _loadingCode ? 'Se verifică...' : 'Conectează-te',
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
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              for (final c in _digitControllers) c.clear();
              _focusNodes[0].requestFocus();
            },
            child: const Text('Șterge', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Email token ──────────────────────────────────────────────────────

  Widget _tokenTab() {
    if (_successToken) return _successView();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.vpn_key_outlined,
                size: 40, color: Colors.orange),
          ),
          const SizedBox(height: 20),
          const Text('Introdu tokenul din email',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A5276))),
          const SizedBox(height: 8),
          Text(
            'Copiază tokenul primit în emailul de invitație\nși lipește-l mai jos.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                TextField(
                  controller: _tokenCtrl,
                  autocorrect: false,
                  maxLines: 2,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Token de invitație',
                    hintText: 'Lipește tokenul aici...',
                    prefixIcon: const Icon(Icons.vpn_key_outlined,
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
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loadingToken ? null : _redeemToken,
                    icon: _loadingToken
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.link),
                    label: Text(
                      _loadingToken ? 'Se verifică...' : 'Acceptă invitația',
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
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tokenul se găsește în emailul de invitație, sau pacientul ți-l poate trimite direct.',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 13),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Shared success view ─────────────────────────────────────────────────────

  Widget _successView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
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
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade700, height: 1.5),
              children: [
                const TextSpan(text: 'Ești acum asociat pacientului\n'),
                TextSpan(
                  text: _linkedPatientName ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A5276),
                      fontSize: 17),
                ),
                const TextSpan(
                    text:
                        '\n\nPoți acum vedea documentele\nmediale ale acestuia.'),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
