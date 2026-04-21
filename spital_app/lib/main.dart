import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/global_admin_screen.dart';
import 'screens/hospital_admin_screen.dart';
import 'screens/doctor_screen.dart';
import 'screens/claim_account_screen.dart';
import 'screens/invite_token_screen.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spital Vișeu UPU',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A5276),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
      // Deep-link routing — handles spitalapp://invite/<token>
      onGenerateRoute: (settings) {
        final name = settings.name ?? '';
        if (name.startsWith('/invite/')) {
          final token = name.replaceFirst('/invite/', '');
          if (token.isNotEmpty) {
            return MaterialPageRoute(
              builder: (_) => InviteTokenScreen(token: token),
            );
          }
        }
        return null;
      },
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
