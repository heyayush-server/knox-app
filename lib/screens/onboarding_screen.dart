import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/app_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../services/app_lock_service.dart';
import '../widgets/knox_button.dart';

class _OnboardingPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    this.iconColor = AppTheme.accent,
    this.actionLabel,
    this.onAction,
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  late final List<_OnboardingPage> _pages;

  @override
  void initState() {
    super.initState();
    final service = AppLockService();

    _pages = [
      const _OnboardingPage(
        title: 'Knox',
        subtitle: 'High Security Layer',
        description:
            'Enterprise-grade app protection inspired by Samsung Knox. '
            'Lock any app with PIN and biometric authentication.',
        icon: Icons.shield_outlined,
        iconColor: AppTheme.accent,
      ),
      _OnboardingPage(
        title: 'Usage Access',
        subtitle: 'Required Permission',
        description:
            'Knox needs Usage Access to detect when a locked app is opened. '
            'This data stays on your device and is never shared.',
        icon: Icons.bar_chart_outlined,
        iconColor: AppTheme.cyan,
        actionLabel: 'Grant Usage Access',
        onAction: () => service.openUsageStatsSettings(),
      ),
      _OnboardingPage(
        title: 'Accessibility',
        subtitle: 'Required Permission',
        description:
            'The Knox Accessibility Service monitors app switching to trigger '
            'the lock screen instantly. No content is read or recorded.',
        icon: Icons.accessibility_new_outlined,
        iconColor: AppTheme.accent,
        actionLabel: 'Enable Accessibility',
        onAction: () => service.openAccessibilitySettings(),
      ),
      _OnboardingPage(
        title: 'Overlay',
        subtitle: 'Required Permission',
        description:
            'Overlay permission allows Knox to display the lock screen '
            'on top of other apps to prevent unauthorized access.',
        icon: Icons.layers_outlined,
        iconColor: AppTheme.cyan,
        actionLabel: 'Grant Overlay Permission',
        onAction: () => service.openOverlaySettings(),
      ),
      const _OnboardingPage(
        title: 'All Set',
        subtitle: 'Ready to Secure',
        description:
            'Knox is ready to protect your apps. '
            'Next, create your master PIN to begin.',
        icon: Icons.check_circle_outline,
        iconColor: AppTheme.success,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await ref.read(authServiceProvider).markOnboardingComplete();
    if (mounted) context.go(AppRoutes.pinSetup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'Skip',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),

            // Bottom navigation
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.iconColor.withOpacity(0.08),
              border: Border.all(
                color: page.iconColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: page.iconColor.withOpacity(0.15),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              page.icon,
              size: 44,
              color: page.iconColor,
            ),
          )
              .animate(key: ValueKey(page.title))
              .scale(
                begin: const Offset(0.7, 0.7),
                duration: 400.ms,
                curve: Curves.easeOutBack,
              )
              .fadeIn(duration: 300.ms),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w200,
              color: AppTheme.textPrimary,
              letterSpacing: 2,
            ),
          )
              .animate(key: ValueKey('title_${page.title}'))
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0, delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            page.subtitle,
            style: AppTheme.labelLarge.copyWith(
              color: page.iconColor,
              letterSpacing: 2,
            ),
          )
              .animate(key: ValueKey('subtitle_${page.title}'))
              .fadeIn(delay: 150.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.textSecondary,
              height: 1.7,
            ),
          )
              .animate(key: ValueKey('desc_${page.title}'))
              .fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 32),

          // Action button (if any)
          if (page.actionLabel != null)
            KnoxOutlineButton(
              label: page.actionLabel!,
              onTap: page.onAction,
            )
                .animate(key: ValueKey('action_${page.title}'))
                .fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _currentPage ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _currentPage
                      ? AppTheme.accent
                      : AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Continue button
          KnoxPrimaryButton(
            label: _currentPage == _pages.length - 1
                ? 'Create PIN'
                : 'Continue',
            onTap: _nextPage,
          ),
        ],
      ),
    );
  }
}
