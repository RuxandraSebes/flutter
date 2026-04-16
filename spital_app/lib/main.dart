import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/global_admin_screen.dart';
import 'screens/hospital_admin_screen.dart';
import 'screens/doctor_screen.dart';
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
    );
  }
}

/// Checks local token → routes to the correct screen or LoginScreen.
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
