import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_provider.dart';
import '../screens/login_screen.dart';
import '../screens/main_shell.dart';
import '../screens/home_tab.dart';
import '../screens/nouveau_ticket_screen.dart';
import '../screens/resultats_screen.dart';
import '../screens/profil_screen.dart';
import 'splash_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String nouveauTicket = '/home/ticket';
  static const String resultats = '/home/resultats';
  static const String profil = '/home/profil';

  static GoRouter createRouter(AuthProvider auth) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: auth,
      redirect: (context, state) {
        final isAuth = auth.status == AuthStatus.authenticated;
        final isUnknown = auth.status == AuthStatus.unknown;
        final loc = state.matchedLocation;
        if (isUnknown) return splash;
        if (!isAuth && loc != login) return login;
        if (isAuth && (loc == login || loc == splash)) return home;
        return null;
      },
      routes: [
        GoRoute(path: splash, builder: (_, __) => const SplashScreen()),
        GoRoute(
          path: login,
          pageBuilder: (_, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const LoginScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ),
        ),
        ShellRoute(
          builder: (_, __, child) => MainShell(child: child),
          routes: [
            GoRoute(path: home, pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const HomeTab())),
            GoRoute(path: nouveauTicket, pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const NouveauTicketScreen())),
            GoRoute(path: resultats, pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ResultatsScreen())),
            GoRoute(path: profil, pageBuilder: (_, state) =>
                NoTransitionPage(key: state.pageKey, child: const ProfilScreen())),
          ],
        ),
      ],
      errorBuilder: (_, state) => Scaffold(
        body: Center(child: Text('Erreur: ${state.error}')),
      ),
    );
  }
}
