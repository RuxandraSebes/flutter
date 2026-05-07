import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'translations.dart';

// ── Language notifier ──────────────────────────────────────────────────────

class LanguageProvider extends StatefulWidget {
  final Widget child;
  const LanguageProvider({super.key, required this.child});

  @override
  State<LanguageProvider> createState() => _LanguageProviderState();

  static _LanguageProviderState? of(BuildContext context) {
    return context.findAncestorStateOfType<_LanguageProviderState>();
  }

  static Locale localeOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<_LocaleInherited>()
            ?.locale ??
        const Locale('ro');
  }
}

class _LanguageProviderState extends State<LanguageProvider> {
  Locale _locale = const Locale('ro');
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final code = await _storage.read(key: 'app_language') ?? 'ro';
    if (mounted) setState(() => _locale = Locale(code));
  }

  Future<void> setLocale(Locale locale) async {
    await _storage.write(key: 'app_language', value: locale.languageCode);
    if (mounted) setState(() => _locale = locale);
  }

  Locale get locale => _locale;

  String tr(String key) {
    return AppLocalizations(_locale).get(key);
  }

  @override
  Widget build(BuildContext context) {
    return _LocaleInherited(
      locale: _locale,
      state: this,
      child: widget.child,
    );
  }
}

class _LocaleInherited extends InheritedWidget {
  final Locale locale;
  final _LanguageProviderState state;

  const _LocaleInherited({
    required this.locale,
    required this.state,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LocaleInherited old) => old.locale != locale;
}

// ── Supported languages ────────────────────────────────────────────────────

class _LangOption {
  final String code;
  final String label;
  final String flag;
  const _LangOption(this.code, this.label, this.flag);
}

const List<_LangOption> _kLanguages = [
  _LangOption('ro', 'Română', '🇷🇴'),
  //_LangOption('en', 'English', '🇬🇧'),
  _LangOption('hu', 'Magyar', '🇭🇺'),
  _LangOption('uk', 'Українська', '🇺🇦'),
  _LangOption('sk', 'Slovenčina', '🇸🇰'),
];

// ── LanguageDropdown ───────────────────────────────────────────────────────
//
// Reads the locale via dependOnInheritedWidgetOfExactType so Flutter
// automatically schedules a rebuild whenever setLocale() is called —
// the flag emoji updates without any extra setState.
//
// Drop into any AppBar actions list:
//   actions: [ const LanguageDropdown(), ... ]

class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    // Registering as a dependent of _LocaleInherited is what makes this
    // widget rebuild when the locale changes.
    final currentLocale = context
            .dependOnInheritedWidgetOfExactType<_LocaleInherited>()
            ?.locale ??
        const Locale('ro');

    final currentCode = currentLocale.languageCode;
    final current = _kLanguages.firstWhere(
      (l) => l.code == currentCode,
      orElse: () => _kLanguages.first,
    );

    // findAncestorStateOfType does NOT register a rebuild dependency — that is
    // intentional; we already depend on the inherited widget above.
    final provider = LanguageProvider.of(context);

    return PopupMenuButton<String>(
      tooltip: t.get('language'),
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 6,
      onSelected: (code) => provider?.setLocale(Locale(code)),
      itemBuilder: (_) => _kLanguages
          .map(
            (lang) => PopupMenuItem<String>(
              value: lang.code,
              child: Row(children: [
                Text(lang.flag, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: lang.code == currentCode
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: lang.code == currentCode
                          ? const Color(0xFF1A5276)
                          : null,
                    ),
                  ),
                ),
                if (lang.code == currentCode)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF1A5276), size: 16),
              ]),
            ),
          )
          .toList(),
      // Button face: flag + small chevron
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(current.flag, style: const TextStyle(fontSize: 22)),
          const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
        ]),
      ),
    );
  }
}

// ── LanguageSelectorDialog — kept for screens that still reference it ───────

class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final provider = LanguageProvider.of(context);
    final currentCode = context
            .dependOnInheritedWidgetOfExactType<_LocaleInherited>()
            ?.locale
            .languageCode ??
        'ro';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.language, color: Color(0xFF1A5276)),
          const SizedBox(width: 8),
          Text(t.get('language'),
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A5276))),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: _kLanguages
            .map((lang) => _LangTile(
                  lang: lang,
                  selected: lang.code == currentCode,
                  onTap: () {
                    provider?.setLocale(Locale(lang.code));
                    Navigator.pop(context);
                  },
                ))
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.get('cancel')),
        ),
      ],
    );
  }
}

class _LangTile extends StatelessWidget {
  final _LangOption lang;
  final bool selected;
  final VoidCallback onTap;

  const _LangTile(
      {required this.lang, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A5276).withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF1A5276) : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Text(lang.flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lang.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color:
                    selected ? const Color(0xFF1A5276) : Colors.grey.shade800,
              ),
            ),
          ),
          if (selected)
            const Icon(Icons.check_circle, color: Color(0xFF1A5276), size: 22),
        ]),
      ),
    );
  }
}

// ── LanguageButton — legacy icon-only button ───────────────────────────────

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: t.get('language'),
      onPressed: () => showDialog(
        context: context,
        builder: (_) => const LanguageSelectorDialog(),
      ),
    );
  }
}
