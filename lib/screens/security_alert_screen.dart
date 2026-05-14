import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/app_router.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/knox_button.dart';

/// Security alert screen shown when biometric enrollment changes are detected.
///
/// This screen forces PIN verification before biometrics can be re-enabled.
/// It's displayed when:
/// - A new fingerprint was added to the device
/// - An existing fingerprint was removed
///
/// This prevents the attack vector where someone with physical access adds
/// their fingerprint to bypass Knox app lock.
class SecurityAlertScreen extends ConsumerStatefulWidget {
  const SecurityAlertScreen({super.key});

  @override
  ConsumerState<SecurityAlertScreen> createState() => _SecurityAlertScreenState();
}

class _SecurityAlertScreenState extends ConsumerState<SecurityAlertScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  bool _showError = false;
  bool _isVerifying = false;
  int _failedAttempts = 0;

  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _warningController;

  @override
  void initState() {
    super.initState();

    // Pulsing red danger animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Shake animation for wrong PIN
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    // Warning icon animation
    _warningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _warningController.dispose();
    super.dispose();
  }

  Future<void> _onDigitPressed(String digit) async {
    if (_pin.length >= 6 || _isVerifying) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _showError = false;
    });
    if (_pin.length == 6) await _verifyPin();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(milliseconds: 200));

    final authService = ref.read(authServiceProvider);
    final result = await authService.verifyPin(_pin);

    if (!mounted) return;

    if (result == PinVerificationResult.success) {
      // Clear biometric change lock and restore biometrics
      await ref.read(authStateProvider.notifier).clearBiometricChangeLock();
      HapticFeedback.mediumImpact();
      if (mounted) context.go(AppRoutes.dashboard);
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      setState(() {
        _showError = true;
        _pin = '';
        _isVerifying = false;
        _failedAttempts++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          // Danger glow background
          _buildDangerBackground(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 32),

                  // Warning header
                  _buildWarningHeader(),

                  const SizedBox(height: 32),

                  // Alert message
                  _buildAlertMessage(),

                  const SizedBox(height: 40),

                  // PIN input
                  _buildPinSection(),

                  const Spacer(),

                  // PIN pad
                  _buildPinPad(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.5),
              radius: 1.0,
              colors: [
                AppTheme.danger.withOpacity(0.04 + _pulseController.value * 0.06),
                AppTheme.black,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWarningHeader() {
    return Column(
      children: [
        // Animated warning shield
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            return Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.danger.withOpacity(0.08),
                border: Border.all(
                  color: AppTheme.danger.withOpacity(0.3 + _pulseController.value * 0.4),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.danger.withOpacity(0.1 + _pulseController.value * 0.2),
                    blurRadius: 30 + _pulseController.value * 20,
                    spreadRadius: _pulseController.value * 8,
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _warningController,
                builder: (context, child) => Icon(
                  Icons.shield_outlined,
                  size: 40,
                  color: AppTheme.danger.withOpacity(0.7 + _warningController.value * 0.3),
                ),
              ),
            );
          },
        )
            .animate()
            .scale(
              begin: const Offset(0.6, 0.6),
              duration: 600.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 400.ms),

        const SizedBox(height: 24),

        // SECURITY ALERT label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppTheme.danger.withOpacity(0.4),
              width: 0.5,
            ),
          ),
          child: Text(
            '⚠ SECURITY ALERT',
            style: AppTheme.labelLarge.copyWith(
              color: AppTheme.danger,
              letterSpacing: 2,
            ),
          ),
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildAlertMessage() {
    return Column(
      children: [
        Text(
          'Biometric configuration\nchanged',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w300,
            color: AppTheme.textPrimary,
            height: 1.3,
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.danger.withOpacity(0.06),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: AppTheme.danger.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Text(
            'A new fingerprint was added or an existing fingerprint was removed. '
            'For your security, biometric unlock has been disabled.\n\n'
            'Enter your master PIN to verify your identity and re-enable biometrics.',
            textAlign: TextAlign.center,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textSecondary,
              height: 1.7,
            ),
          ),
        ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
      ],
    );
  }

  Widget _buildPinSection() {
    return Column(
      children: [
        Text(
          'Enter master PIN',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
        ),

        const SizedBox(height: 20),

        // PIN dots with shake
        AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            final offset = _showError
                ? (1 - _shakeAnimation.value) *
                    14 *
                    ((_shakeAnimation.value * 6).floor() % 2 == 0 ? 1 : -1)
                : 0.0;
            return Transform.translate(
              offset: Offset(offset, 0),
              child: child,
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final filled = i < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _showError
                      ? AppTheme.danger
                      : filled
                          ? AppTheme.danger.withOpacity(0.9)
                          : Colors.transparent,
                  border: Border.all(
                    color: _showError
                        ? AppTheme.danger
                        : filled
                            ? AppTheme.danger
                            : AppTheme.border,
                    width: 1.5,
                  ),
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: AppTheme.danger.withOpacity(0.4),
                            blurRadius: 6,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        AnimatedOpacity(
          opacity: _showError ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Text(
            _failedAttempts >= 3
                ? '${5 - _failedAttempts} attempts remaining'
                : 'Incorrect PIN. Try again.',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.danger),
          ),
        ),
      ],
    );
  }

  Widget _buildPinPad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) {
              if (key == 'del') {
                return PinPadButton(
                  label: '',
                  isDelete: true,
                  onTap: _onDelete,
                );
              }
              if (key.isEmpty) {
                return const SizedBox(width: 72, height: 72);
              }
              const subLabels = {
                '2': 'ABC',
                '3': 'DEF',
                '4': 'GHI',
                '5': 'JKL',
                '6': 'MNO',
                '7': 'PQRS',
                '8': 'TUV',
                '9': 'WXYZ',
              };
              return PinPadButton(
                label: key,
                sublabel: subLabels[key],
                onTap: () => _onDigitPressed(key),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
