import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/parent/screens/parent_home_screen.dart';
import '../../features/parent/screens/parent_settings_screen.dart';
import '../../features/teacher/screens/teacher_home_screen.dart';
import '../../features/admin/screens/admin_home_screen.dart';

// ── Listens to Supabase auth state and notifies GoRouter to re-evaluate ──────
class _SupabaseAuthNotifier extends ChangeNotifier {
  _SupabaseAuthNotifier() {
    _sub = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _SupabaseAuthNotifier();

// ── Helper: role → route ──────────────────────────────────────────────────────
String _routeForRole(String? role) => switch (role) {
      'teacher' => '/teacher',
      'admin' => '/admin',
      _ => '/parent',
    };

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _authNotifier, // ← re-runs redirect on auth changes
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;
      final isOnAuth = loc == '/login' || loc == '/register';

      // Not logged in → send to login
      if (!isLoggedIn && !isOnAuth) return '/login';

      // Logged in and trying to reach auth pages → redirect to role dashboard
      if (isLoggedIn && isOnAuth) {
        final role = session.user.userMetadata?['role'] as String?;
        return _routeForRole(role);
      }

      return null; // already on correct page
    },
    routes: [
      GoRoute(path: '/login',   builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      GoRoute(path: '/parent',  builder: (c, s) => const ParentHomeScreen()),
      GoRoute(path: '/teacher', builder: (c, s) => const TeacherHomeScreen()),
      GoRoute(path: '/admin',   builder: (c, s) => const AdminHomeScreen()),
    ],
  );
});