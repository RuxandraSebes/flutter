import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:spital_visu_upu/i18n/language_provider.dart';
import 'package:spital_visu_upu/i18n/translations.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/global_admin_screen.dart';
import 'screens/hospital_admin_screen.dart';
import 'screens/doctor_screen.dart';
import 'screens/claim_account_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(
    const LanguageProvider(
      // Adaugă acest provider
      child: MyApp(),
    ),
  );
}

// lib/main.dart
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Obține provider-ul pentru a accesa locale-ul curent
    final locale = LanguageProvider.localeOf(context);

    return MaterialApp(
      title: 'Spital Vișeu UPU',
      debugShowCheckedModeBanner: false,
      locale: locale, // was: lp?.locale ?? const Locale('ro')
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ro'),
        Locale('en'),
        Locale('hu'),
        Locale('uk'),
        Locale('sk'),
      ],

      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A5276)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      // ... restul codului (onGenerateRoute)
    );
  }
}

/// Checks local token → routes to the correct screen.
/// Also detects Hipocrate-auto-created patients and shows claim screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService().isLoggedIn(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == true) {
          return FutureBuilder<UserModel?>(
            future: AuthService().getCachedUser(),
            builder: (context, userSnap) {
              if (!userSnap.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              final user = userSnap.data;
              if (user == null) return const LoginScreen();

              // Hipocrate auto-created accounts need to claim their profile
              if (ClaimAccountScreen.needsClaim(user)) {
                return ClaimAccountScreen(user: user);
              }

              return roleBasedHome(user);
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

/// Public helper used after login / register to navigate to the correct screen.
Widget roleBasedHome(UserModel user) {
  // Auto-created patients should complete their profile first
  if (ClaimAccountScreen.needsClaim(user)) {
    return ClaimAccountScreen(user: user);
  }

  switch (user.role) {
    case 'global_admin':
      return GlobalAdminScreen(user: user);
    case 'hospital_admin':
      return HospitalAdminScreen(user: user);
    case 'doctor':
      return DoctorScreen(user: user);
    case 'patient':
    case 'companion':
    default:
      return HomeScreen(user: user);
  }
}
