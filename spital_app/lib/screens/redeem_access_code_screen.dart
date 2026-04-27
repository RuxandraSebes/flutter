// REQ-9: All errors shown inline below buttons, not as snackbars above keyboard

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/access_code_service.dart';
import '../i18n/translations.dart';

class RedeemAccessCodeScreen extends StatefulWidget {
  const RedeemAccessCodeScreen({super.key});

  @override
  State<RedeemAccessCodeScreen> createState() => _RedeemAccessCodeScreenState();
}

class _RedeemAccessCodeScreenState extends State<RedeemAccessCodeScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;
  final _service = AccessCodeService();

  // ── Numeric code state ──────────────────────────────────────────────────────
  final _codeCtrl = TextEditingController();
  bool _redeemingCode = false;
  bool _codeSuccess = false;
  String? _codePatientName;

  // ── Email token state ───────────────────────────────────────────────────────
  final _tokenCtrl = TextEditingController();
  bool _redeemingToken = false;
  bool _tokenSuccess = false;
  String? _tokenPatientName;

  // REQ-9: inline error states per tab
  String? _codeError;
  String? _tokenError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _codeCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  // ── Numeric code redeem ─────────────────────────────────────────────────────

  Future<void> _redeemCode() async {
    final l10n = AppLocalizations.of(context);
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || code.length != 6) {
      setState(() => _codeError = l10n.get('enter_6digit'));
      return;
    }

    setState(() {
      _redeemingCode = true;
      _codeError = null;
      _codeSuccess = false;
    });

    final result = await _service.redeemCode(code);
    if (!mounted) return;
    setState(() => _redeemingCode = false);

    if (result['success'] == true) {
      setState(() {
        _codeSuccess = true;
        _codePatientName = result['patient']?['name'];
      });
      _codeCtrl.clear();
      // Return true to caller so HomeScreen can refresh docs
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(
          () => _codeError = result['message'] ?? l10n.get('code_invalid'));
    }
  }

  // ── Email token redeem ──────────────────────────────────────────────────────

  Future<void> _redeemToken() async {
    final l10n = AppLocalizations.of(context);
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _tokenError = l10n.get('enter_token'));
      return;
    }

    setState(() {
      _redeemingToken = true;
      _tokenError = null;
      _tokenSuccess = false;
    });

    final result = await _service.redeemEmailInvite(token);
    if (!mounted) return;
    setState(() => _redeemingToken = false);

    if (result['success'] == true) {
      setState(() {
        _tokenSuccess = true;
        _tokenPatientName = result['patient']?['name'];
      });
      _tokenCtrl.clear();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } else {
      setState(
          () => _tokenError = result['message'] ?? l10n.get('token_invalid'));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A5276),
        foregroundColor: Colors.white,
        title: Text(l10n.get('associate_patient')),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
                icon: const Icon(Icons.dialpad),
                text: l10n.get('numeric_code')),
            Tab(
                icon: const Icon(Icons.token_outlined),
                text: l10n.get('invite_token_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_codeTab(), _tokenTab()],
      ),
    );
  }

  // ── Tab 1: Numeric code ─────────────────────────────────────────────────────

  Widget _codeTab() {
    final l10n = AppLocalizations.of(context);

    if (_codeSuccess) {
      return _successView(
        l10n.get('association_success'),
        '${l10n.get('invite_success_desc_prefix')}'
        '${_codePatientName != null ? '\n$_codePatientName' : ''}.\n'
        '${l10n.get('invite_success_desc_suffix')}',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _howItWorksCard(
            steps: [
              ('1', l10n.get('redeem_code_step_1')),
              ('2', l10n.get('redeem_code_step_2')),
              ('3', l10n.get('redeem_code_step_3')),
            ],
            note: l10n.get('code_valid_5min_note'),
          ),
          const SizedBox(height: 32),

          // Code input
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text(l10n.get('access_code_6digits'),
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A5276))),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {
                    if (_codeError != null) setState(() => _codeError = null);
                  },
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10,
                      color: Color(0xFF1A5276)),
                  decoration: InputDecoration(
                    hintText: '------',
                    hintStyle: TextStyle(
                        color: Colors.grey.shade300,
                        letterSpacing: 10,
                        fontSize: 32),
                    counterText: '',
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onSubmitted: (_) => _redeemCode(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _redeemingCode ? null : _redeemCode,
                    icon: _redeemingCode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.link),
                    label: Text(
                      _redeemingCode
                          ? l10n.get('verifying')
                          : l10n.get('activate_code'),
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

                // REQ-9: Inline error below button
                if (_codeError != null) ...[
                  const SizedBox(height: 14),
                  _inlineErrorWidget(_codeError!,
                      onDismiss: () => setState(() => _codeError = null)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Email token ──────────────────────────────────────────────────────

  Widget _tokenTab() {
    final l10n = AppLocalizations.of(context);

    if (_tokenSuccess) {
      return _successView(
        l10n.get('invite_accepted'),
        '${l10n.get('invite_success_desc_prefix')}'
        '${_tokenPatientName != null ? '\n$_tokenPatientName' : ''}.\n'
        '${l10n.get('invite_success_desc_suffix')}',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _howItWorksCard(
            steps: [
              ('1', l10n.get('redeem_token_step_1')),
              ('2', l10n.get('redeem_token_step_2')),
              ('3', l10n.get('redeem_token_step_3')),
            ],
            note: l10n.get('token_valid_24h'),
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
                  Text(l10n.get('invite_token_label'),
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A5276))),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tokenCtrl,
                    autocorrect: false,
                    onChanged: (_) {
                      if (_tokenError != null)
                        setState(() => _tokenError = null);
                    },
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Color(0xFF1A5276)),
                    decoration: InputDecoration(
                      hintText: l10n.get('insert_token'),
                      prefixIcon: const Icon(Icons.token_outlined,
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
                    onSubmitted: (_) => _redeemToken(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _redeemingToken ? null : _redeemToken,
                      icon: _redeemingToken
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline),
                      label: Text(
                        _redeemingToken
                            ? l10n.get('verifying')
                            : l10n.get('accept_invite'),
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

                  // REQ-9: Inline error below button
                  if (_tokenError != null) ...[
                    const SizedBox(height: 14),
                    _inlineErrorWidget(_tokenError!,
                        onDismiss: () => setState(() => _tokenError = null)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────────

  Widget _successView(String title, String body) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
                color: Colors.green.shade50, shape: BoxShape.circle),
            child: Icon(Icons.check_circle_outline,
                size: 60, color: Colors.green.shade600),
          ),
          const SizedBox(height: 24),
          Text(title,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A5276))),
          const SizedBox(height: 12),
          Text(body,
              style: TextStyle(
                  fontSize: 15, color: Colors.grey.shade700, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: Color(0xFF1A5276)),
          const SizedBox(height: 12),
          Text(l10n.get('redirecting'),
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _inlineErrorWidget(String message, {VoidCallback? onDismiss}) {
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
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Icon(Icons.vpn_key_outlined,
              size: 40, color: Color(0xFF1A5276)),
          const SizedBox(height: 10),
          Text(l10n.get('how_it_works'),
              style: const TextStyle(
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
}
