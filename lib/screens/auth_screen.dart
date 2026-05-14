import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/knox_button.dart';
import '../widgets/shield_logo.dart';
import '../services/biometric_service.dart';
import '../services/auth_service.dart';

/// Platform channel to communicate back to LockOverlayActivity
const _overlayChannel = MethodChannel('com.knox.applocker/lock_overlay');

/// Lock overlay screen displayed when user opens a locked app
class AuthScreen extends ConsumerStatefulWidget {
  final String appName;
  final String packageName;
  // Nullable: when null, we're running inside LockOverlayActivity and signal
  // success via MethodChannel instead of calling a Dart callback.
  final VoidCallback? onSuccess;

  const AuthScreen({
    super.key,
    required this.appName,
    required this.packageName,
    this.onSuccess,
  });

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  bool _showError = false;
  bool _isLockedOut = false;
  int _lockoutSeconds = 0;
  bool _isAuthenticating = false;

  // Resolved app info (may be fetched from LockOverlayActivity via MethodChannel)
  String _appName = '';
  String _packageName = '';
  bool _infoLoaded = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _initLockInfo();
  }

  /// Resolve app name/package from props or from LockOverlayActivity MethodChannel.
  /// When launched standalone (from dashboard test), props are set directly.
  /// When launched from LockOverlayActivity, we fetch via getLockInfo channel.
  Future<void> _initLockInfo() async {
    if (widget.appName.isNotEmpty) {
      setState(() {
        _appName = widget.appName;
        _packageName = widget.packageName;
        _infoLoaded = true;
      });
    } else {
      // Attempt to fetch from LockOverlayActivity MethodChannel
      try {
        final info = await _overlayChannel.invokeMethod<Map>('getLockInfo');
        if (mounted && info != null) {
          setState(() {
            _appName = info['appName'] as String? ?? '';
            _packageName = info['packageName'] as String? ?? '';
            _infoLoaded = true;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _infoLoaded = true);
      }
    }

    // Attempt biometric auth automatically on open
    _tryBiometricAuth();
  }

  /// Signal success — call Dart callback if provided (in-app use),
  /// otherwise signal LockOverlayActivity via MethodChannel (overlay launch).
  Future<void> _signalSuccess() async {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
      return;
    }
    try {
      await _overlayChannel.invokeMethod('onAuthSuccess');
    } catch (_) {
      // Channel unavailable — not running inside LockOverlayActivity
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometricAuth() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isBiometricEnabled || authState.isBiometricChangeLocked) return;

    final biometricService = ref.read(biometricServiceProvider);
    if (!await biometricService.isAvailable()) return;
    if (!await biometricService.isEnrolled()) return;

    // Check for enrollment changes before allowing biometric
    final changeStatus = await biometricService.checkEnrollmentChange();
    if (changeStatus == EnrollmentChangeStatus.changed) {
      // Security: enrollment changed — lock biometrics and require PIN
      await biometricService.lockBiometricsAfterChange();
      ref.read(authStateProvider.notifier).refresh();
      return;
    }

    final result = await biometricService.authenticate(
      reason: 'Verify your identity to unlock $_appName',
    );

    if (result == BiometricResult.success && mounted) {
      await _signalSuccess();
    }
  }

  Future<void> _onDigitPressed(String digit) async {
    if (_pin.length >= 6 || _isLockedOut) return;

    HapticFeedback.selectionClick();
    setState(() {
      _pin += digit;
      _showError = false;
    });

    if (_pin.length == 6) {
      await _verifyPin();
    }
  }

  void _onDelete() {
    if (_pin.isEmpty || _isLockedOut) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifyPin() async {
    setState(() => _isAuthenticating = true);

    // Small delay for UX feel
    await Future.delayed(const Duration(milliseconds: 150));

    final authService = ref.read(authServiceProvider);
    final result = await authService.verifyPin(_pin);

    if (!mounted) return;

    switch (result) {
      case PinVerificationResult.success:
        HapticFeedback.mediumImpact();
        await _signalSuccess();
        break;

      case PinVerificationResult.incorrect:
        HapticFeedback.heavyImpact();
        _shakeController.forward(from: 0);
        final failed = await authService.getFailedAttempts();
        setState(() {
          _showError = true;
          _pin = '';
          _isAuthenticating = false;
        });
        if (failed >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${5 - failed} attempts remaining',
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              backgroundColor: AppTheme.surface3,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;

      case PinVerificationResult.lockedOut:
        final remaining = await authService.getLockoutRemainingSeconds();
        setState(() {
          _isLockedOut = true;
          _lockoutSeconds = remaining;
          _pin = '';
          _isAuthenticating = false;
        });
        _startLockoutTimer();
        break;
    }
  }

  void _startLockoutTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _lockoutSeconds = (_lockoutSeconds - 1).clamp(0, 999);
        if (_lockoutSeconds <= 0) _isLockedOut = false;
      });
      return _isLockedOut;
    });
  }

  @override
  Widget build(BuildContext context) {
    // FLAG_SECURE equivalent hint — prevent screenshots of auth screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    final authState = ref.watch(authStateProvider);
    final canUseBiometrics = authState.isBiometricEnabled &&
        !authState.isBiometricChangeLocked;

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: Stack(
        children: [
          // Animated background
          _buildBackground(),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // App name being locked
                  _buildAppLabel(),

                  const SizedBox(height: 32),

                  // Knox shield
                  AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) => Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accent.withOpacity(
                                0.1 + _glowController.value * 0.2),
                            blurRadius: 30 + _glowController.value * 20,
                            spreadRadius: _glowController.value * 5,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                    child: const ShieldLogo(size: 64),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    'Protected by Knox',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.accent,
                      letterSpacing: 2,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // PIN dots
                  if (!_isLockedOut)
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        final offset = _showError
                            ? (1 - _shakeAnimation.value) *
                                14 *
                                ((_shakeAnimation.value * 6).floor() % 2 == 0
                                    ? 1
                                    : -1)
                            : 0.0;
                        return Transform.translate(
                          offset: Offset(offset, 0),
                          child: child,
                        );
                      },
                      child: _buildPinDots(),
                    )
                  else
                    _buildLockoutIndicator(),

                  const SizedBox(height: 12),

                  // Error message
                  AnimatedOpacity(
                    opacity: _showError ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      'Incorrect PIN',
                      style: AppTheme.bodyMedium.copyWith(color: AppTheme.danger),
                    ),
                  ),

                  const Spacer(),

                  // PIN Pad
                  if (!_isLockedOut) _buildPinPad(canUseBiometrics),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.3),
              radius: 1.2,
              colors: [
                AppTheme.accent.withOpacity(0.04 + _glowController.value * 0.03),
                AppTheme.black,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppLabel() {
    return Column(
      children: [
        Text(
          _appName.isNotEmpty ? _appName : widget.appName,
          style: AppTheme.titleLarge.copyWith(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w300,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'is protected',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textTertiary),
        ),
      ],
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 9),
          width: filled ? 13 : 11,
          height: filled ? 13 : 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _showError
                ? AppTheme.danger
                : filled
                    ? AppTheme.accent
                    : Colors.transparent,
            border: Border.all(
              color: _showError
                  ? AppTheme.danger
                  : filled
                      ? AppTheme.accent
                      : AppTheme.border,
              width: 1.5,
            ),
            boxShadow: filled && !_showError
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.4),
                      blurRadius: 6,
                    )
                  ]
                : null,
          ),
        );
      }),
    );
  }

  Widget _buildLockoutIndicator() {
    return Column(
      children: [
        Icon(Icons.lock_clock_outlined, color: AppTheme.danger, size: 40),
        const SizedBox(height: 12),
        Text(
          'Too many attempts',
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.danger),
        ),
        const SizedBox(height: 8),
        Text(
          'Try again in ${_lockoutSeconds}s',
          style: AppTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildPinPad(bool showBiometrics) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [showBiometrics ? 'bio' : '', '0', 'del'],
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
              if (key == 'bio') {
                return GestureDetector(
                  onTap: _tryBiometricAuth,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface2,
                      border: Border.all(color: AppTheme.border, width: 0.5),
                    ),
                    child: const Icon(
                      Icons.fingerprint,
                      size: 30,
                      color: AppTheme.accent,
                    ),
                  ),
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
