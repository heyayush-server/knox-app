import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/pin_setup_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/security_alert_screen.dart';

// Route name constants
class AppRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const pinSetup = '/pin-setup';
  static const dashboard = '/dashboard';
  static const settings = '/settings';
  static const auth = '/auth';
  static const securityAlert = '/security-alert';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        builder: (context, state) => const PinSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) {
          // LockOverlayActivity passes params via query string (getInitialRoute)
          // In-app navigation passes params via state.extra
          final queryPackage = state.uri.queryParameters['packageName'];
          final queryApp = state.uri.queryParameters['appName'];

          final extra = state.extra as Map<String, dynamic>?;
          final packageName = queryPackage ?? extra?['packageName'] as String? ?? '';
          final appName = queryApp ?? extra?['appName'] as String? ?? '';
          // nullable — null means we're inside LockOverlayActivity, use MethodChannel
          final onSuccess = extra?['onSuccess'] as VoidCallback?;

          return AuthScreen(
            appName: appName,
            packageName: packageName,
            onSuccess: onSuccess,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.securityAlert,
        builder: (context, state) => const SecurityAlertScreen(),
      ),
    ],
  );
});
