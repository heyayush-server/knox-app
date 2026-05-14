import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/app_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shield_logo.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanController;
  late final AnimationController _glowController;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 3000));

    if (!mounted) return;

    final authState = ref.read(authStateProvider);

    if (authState.isLoading) {
      // Wait for auth state to load
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (!mounted) return;

    final state = ref.read(authStateProvider);

    if (!state.isOnboardingComplete) {
      context.go(AppRoutes.onboarding);
    } else if (!state.isSetupComplete) {
      context.go(AppRoutes.pinSetup);
    } else if (state.isBiometricChangeLocked) {
      context.go(AppRoutes.securityAlert);
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    _glowController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          // Background grid pattern
          _buildBackgroundGrid(),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield logo with animations
                _buildAnimatedShield(),

                const SizedBox(height: 48),

                // App name
                _buildAppName(),

                const SizedBox(height: 16),

                // Tagline
                _buildTagline(),

                const SizedBox(height: 80),

                // Loading indicator
                _buildLoadingBar(),
              ],
            ),
          ),

          // Scan line animation
          _buildScanLine(),

          // Bottom version text
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'ENTERPRISE SECURITY v1.0',
              textAlign: TextAlign.center,
              style: AppTheme.monoSmall.copyWith(
                color: AppTheme.textTertiary,
                letterSpacing: 2,
              ),
            ).animate().fadeIn(delay: 1500.ms, duration: 800.ms),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGrid() {
    return CustomPaint(
      painter: _GridPainter(),
      child: const SizedBox.expand(),
    );
  }

  Widget _buildAnimatedShield() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glowIntensity = _glowController.value;
        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.2 + glowIntensity * 0.3),
                blurRadius: 40 + glowIntensity * 30,
                spreadRadius: 5 + glowIntensity * 10,
              ),
              BoxShadow(
                color: AppTheme.cyan.withOpacity(0.05 + glowIntensity * 0.1),
                blurRadius: 80,
                spreadRadius: 20,
              ),
            ],
          ),
          child: child,
        );
      },
      child: const ShieldLogo(size: 120),
    )
        .animate()
        .scale(
          begin: const Offset(0.5, 0.5),
          end: const Offset(1.0, 1.0),
          duration: 800.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 600.ms);
  }

  Widget _buildAppName() {
    return Column(
      children: [
        Text(
          'KNOX',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w200,
            color: AppTheme.textPrimary,
            letterSpacing: 12,
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 700.ms).slideY(
              begin: 0.3,
              end: 0,
              delay: 400.ms,
              duration: 700.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 4),
        Text(
          'HIGH SECURITY LAYER',
          style: AppTheme.labelLarge.copyWith(
            color: AppTheme.accent,
            letterSpacing: 4,
            fontSize: 11,
          ),
        ).animate().fadeIn(delay: 700.ms, duration: 700.ms),
      ],
    );
  }

  Widget _buildTagline() {
    return Text(
      'Enterprise-grade app protection',
      style: AppTheme.bodyMedium.copyWith(
        color: AppTheme.textTertiary,
        fontStyle: FontStyle.italic,
      ),
    ).animate().fadeIn(delay: 1000.ms, duration: 700.ms);
  }

  Widget _buildLoadingBar() {
    return SizedBox(
      width: 120,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          backgroundColor: AppTheme.surface3,
          valueColor: const AlwaysStoppedAnimation(AppTheme.accent),
          minHeight: 1.5,
        ),
      ),
    ).animate().fadeIn(delay: 1200.ms, duration: 500.ms);
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, _) {
        final height = MediaQuery.of(context).size.height;
        final y = _scanController.value * height;

        return Positioned(
          top: y - 1,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.accent.withOpacity(0.6),
                  AppTheme.cyan.withOpacity(0.8),
                  AppTheme.accent.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Subtle grid background painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.textTertiary.withOpacity(0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;

    // Vertical lines
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
