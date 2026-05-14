import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/app_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/knox_button.dart';
import '../widgets/shield_logo.dart';

enum _PinSetupStep { create, confirm, enableBiometrics }

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen>
    with TickerProviderStateMixin {
  _PinSetupStep _step = _PinSetupStep.create;
  String _pin = '';
  String _firstPin = '';
  bool _showError = false;
  bool _isLoading = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _successController;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_pin.length >= 6) return;
    HapticFeedback.selectionClick();

    setState(() {
      _pin += digit;
      _showError = false;
    });

    if (_pin.length == 6) {
      _handlePinComplete();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _handlePinComplete() async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (_step == _PinSetupStep.create) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _step = _PinSetupStep.confirm;
      });
    } else if (_step == _PinSetupStep.confirm) {
      if (_pin == _firstPin) {
        // PINs match — save
        setState(() => _isLoading = true);

        final authService = ref.read(authServiceProvider);
        await authService.setPin(_pin);

        // Check biometrics availability
        final biometricService = ref.read(biometricServiceProvider);
        final hasFingerprint = await biometricService.isEnrolled();

        if (mounted) {
          setState(() {
            _isLoading = false;
            _pin = '';
          });

          if (hasFingerprint) {
            setState(() => _step = _PinSetupStep.enableBiometrics);
          } else {
            await _completeSetup(false);
          }
        }
      } else {
        // Mismatch — shake and reset
        HapticFeedback.mediumImpact();
        _shakeController.forward(from: 0);
        setState(() {
          _showError = true;
          _pin = '';
        });
      }
    }
  }

  Future<void> _completeSetup(bool enableBiometrics) async {
    setState(() => _isLoading = true);

    if (enableBiometrics) {
      await ref.read(biometricServiceProvider).setBiometricUnlockEnabled(true);
    }

    await ref.read(authServiceProvider).markSetupComplete();

    if (mounted) {
      context.go(AppRoutes.dashboard);
    }
  }

  String get _stepTitle {
    switch (_step) {
      case _PinSetupStep.create:
        return 'Create PIN';
      case _PinSetupStep.confirm:
        return 'Confirm PIN';
      case _PinSetupStep.enableBiometrics:
        return 'Biometrics';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case _PinSetupStep.create:
        return 'Choose a 6-digit master PIN';
      case _PinSetupStep.confirm:
        return 'Enter your PIN again to confirm';
      case _PinSetupStep.enableBiometrics:
        return 'Unlock apps faster with fingerprint';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _PinSetupStep.enableBiometrics) {
      return _buildBiometricsStep();
    }

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 48),

              // Shield logo
              const ShieldLogo(size: 64)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .scale(begin: const Offset(0.8, 0.8), duration: 400.ms),

              const SizedBox(height: 32),

              // Title
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Column(
                  key: ValueKey(_step),
                  children: [
                    Text(_stepTitle, style: AppTheme.displayMedium),
                    const SizedBox(height: 8),
                    Text(
                      _stepSubtitle,
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // PIN dots with shake animation
              AnimatedBuilder(
                animation: _shakeAnimation,
                builder: (context, child) {
                  final offset = _showError
                      ? (1 - _shakeAnimation.value) * 16 *
                          ((_shakeAnimation.value * 6).floor() % 2 == 0 ? 1 : -1)
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: _buildPinDots(),
              ),

              if (_showError) ...[
                const SizedBox(height: 16),
                Text(
                  'PINs do not match. Try again.',
                  style: AppTheme.bodyMedium.copyWith(color: AppTheme.danger),
                ).animate().fadeIn(duration: 200.ms),
              ],

              const Spacer(),

              // PIN Pad
              _buildPinPad(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: filled ? 14 : 12,
          height: filled ? 14 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppTheme.accent : Colors.transparent,
            border: Border.all(
              color: filled ? AppTheme.accent : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
        );
      }),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
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

  Widget _buildBiometricsStep() {
    return Scaffold(
      backgroundColor: AppTheme.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FingerprintIcon(size: 96, isAnimating: true)
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(
                    begin: const Offset(0.7, 0.7),
                    duration: 500.ms,
                    curve: Curves.easeOutBack,
                  ),

              const SizedBox(height: 40),

              const Text(
                'Enable Fingerprint',
                style: AppTheme.displayMedium,
              ),

              const SizedBox(height: 12),

              Text(
                'Unlock locked apps quickly with your fingerprint. '
                'Knox detects if new fingerprints are added and requires '
                'PIN re-verification for security.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.7,
                ),
              ),

              const SizedBox(height: 48),

              KnoxPrimaryButton(
                label: 'Enable Fingerprint',
                icon: Icons.fingerprint,
                onTap: () => _completeSetup(true),
                isLoading: _isLoading,
              ),

              const SizedBox(height: 16),

              TextButton(
                onPressed: () => _completeSetup(false),
                child: Text(
                  'Skip for now',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
