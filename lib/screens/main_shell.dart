import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../router/app_router.dart';
import '../utils/app_theme.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _locationIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(AppRouter.nouveauTicket)) return 1;
    if (location.startsWith(AppRouter.resultats)) return 2;
    if (location.startsWith(AppRouter.profil)) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    switch (index) {
      case 0: context.go(AppRouter.home); break;
      case 1: context.go(AppRouter.nouveauTicket); break;
      case 2: context.go(AppRouter.resultats); break;
      case 3: context.go(AppRouter.profil); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _locationIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded,
                    label: 'Accueil', isActive: currentIndex == 0,
                    onTap: () => _onTap(context, 0)),
                _NavItem(icon: Icons.add_circle_outline_rounded, activeIcon: Icons.add_circle_rounded,
                    label: 'Ticket', isActive: currentIndex == 1,
                    onTap: () => _onTap(context, 1), isPrimary: true),
                _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded,
                    label: 'Résultats', isActive: currentIndex == 2,
                    onTap: () => _onTap(context, 2)),
                _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,
                    label: 'Profil', isActive: currentIndex == 3,
                    onTap: () => _onTap(context, 3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isActive, isPrimary;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon, required this.activeIcon,
    required this.label, required this.isActive,
    required this.onTap, this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: (isPrimary && !isActive)
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 50, height: 34,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(17),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: const Icon(Icons.add_rounded, color: AppColors.textOnPrimary, size: 22),
                ),
                const SizedBox(height: 3),
                Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(isActive ? activeIcon : icon, color: color, size: 23),
                const SizedBox(height: 2),
                Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500, color: color)),
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 14 : 0, height: 2,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(1)),
                ),
              ]),
      ),
    );
  }
}
