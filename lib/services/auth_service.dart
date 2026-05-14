import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/constants.dart';

/// Result of PIN verification
enum PinVerificationResult {
  success,
  incorrect,
  lockedOut,
}

/// Knox Authentication Service
///
/// Manages master PIN with SHA-256 hashing + salt.
/// PIN is NEVER stored in plain text. Only the hash + salt is persisted
/// in Android Keystore-backed encrypted shared preferences.
class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  // ─── PIN Salt (stored separately, makes rainbow table attacks impractical) ──
  static const String _saltKey = 'knox_pin_salt';

  /// Hash a PIN with SHA-256 and a stored salt
  Future<String> _hashPin(String pin) async {
    String? salt = await _storage.read(key: _saltKey);

    if (salt == null) {
      // Generate a random salt on first use
      salt = DateTime.now().microsecondsSinceEpoch.toString() +
          pin.length.toString() +
          'knox_v1_salt';
      await _storage.write(key: _saltKey, value: salt);
    }

    final combined = '$salt:$pin:knox_applocker';
    final bytes = utf8.encode(combined);
    return sha256.convert(bytes).toString();
  }

  // ─── PIN Setup ─────────────────────────────────────────────────────────────

  /// Check if a master PIN has been set
  Future<bool> hasPinSet() async {
    final hash = await _storage.read(key: SecureKeys.pinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Set the master PIN (initial setup or change)
  Future<void> setPin(String pin) async {
    final hash = await _hashPin(pin);
    await _storage.write(key: SecureKeys.pinHash, value: hash);

    // Reset failed attempts when PIN is set
    await _storage.write(key: SecureKeys.failedAttempts, value: '0');
    await _storage.delete(key: SecureKeys.lockoutUntil);
  }

  // ─── PIN Verification ──────────────────────────────────────────────────────

  /// Verify the master PIN
  /// Handles lockout logic automatically
  Future<PinVerificationResult> verifyPin(String pin) async {
    // Check lockout first
    final lockoutResult = await _checkLockout();
    if (lockoutResult == PinVerificationResult.lockedOut) {
      return PinVerificationResult.lockedOut;
    }

    final storedHash = await _storage.read(key: SecureKeys.pinHash);
    if (storedHash == null) return PinVerificationResult.incorrect;

    final inputHash = await _hashPin(pin);

    if (inputHash == storedHash) {
      // Success — reset failed attempts
      await _storage.write(key: SecureKeys.failedAttempts, value: '0');
      await _storage.delete(key: SecureKeys.lockoutUntil);

      // Update last auth timestamp
      await _storage.write(
        key: SecureKeys.lastAuthTimestamp,
        value: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      return PinVerificationResult.success;
    }

    // Incorrect — increment failed attempts
    await _incrementFailedAttempts();
    return PinVerificationResult.incorrect;
  }

  Future<PinVerificationResult> _checkLockout() async {
    final lockoutUntilStr = await _storage.read(key: SecureKeys.lockoutUntil);
    if (lockoutUntilStr != null) {
      final lockoutUntil = int.tryParse(lockoutUntilStr) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now < lockoutUntil) {
        return PinVerificationResult.lockedOut;
      }
    }
    return PinVerificationResult.success; // Not locked out
  }

  Future<void> _incrementFailedAttempts() async {
    final attemptsStr = await _storage.read(key: SecureKeys.failedAttempts);
    final attempts = int.tryParse(attemptsStr ?? '0') ?? 0;
    final newAttempts = attempts + 1;

    await _storage.write(
      key: SecureKeys.failedAttempts,
      value: newAttempts.toString(),
    );

    if (newAttempts >= AppConstants.maxFailedAttempts) {
      // Trigger lockout
      final lockoutUntil = DateTime.now()
          .add(const Duration(seconds: AppConstants.lockoutDurationSeconds))
          .millisecondsSinceEpoch;
      await _storage.write(
        key: SecureKeys.lockoutUntil,
        value: lockoutUntil.toString(),
      );
    }
  }

  /// Get remaining lockout time in seconds (0 if not locked out)
  Future<int> getLockoutRemainingSeconds() async {
    final lockoutUntilStr = await _storage.read(key: SecureKeys.lockoutUntil);
    if (lockoutUntilStr == null) return 0;

    final lockoutUntil = int.tryParse(lockoutUntilStr) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final remaining = (lockoutUntil - now) ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  /// Get failed attempt count
  Future<int> getFailedAttempts() async {
    final str = await _storage.read(key: SecureKeys.failedAttempts);
    return int.tryParse(str ?? '0') ?? 0;
  }

  // ─── Setup State ───────────────────────────────────────────────────────────

  Future<bool> isSetupComplete() async {
    final val = await _storage.read(key: SecureKeys.setupComplete);
    return val == 'true';
  }

  Future<void> markSetupComplete() async {
    await _storage.write(key: SecureKeys.setupComplete, value: 'true');
  }

  Future<bool> isOnboardingComplete() async {
    final val = await _storage.read(key: SecureKeys.onboardingComplete);
    return val == 'true';
  }

  Future<void> markOnboardingComplete() async {
    await _storage.write(key: SecureKeys.onboardingComplete, value: 'true');
  }

  // ─── Grace Period ──────────────────────────────────────────────────────────

  /// Check if within grace period (recently authenticated)
  Future<bool> isWithinGracePeriod() async {
    final lastAuthStr = await _storage.read(key: SecureKeys.lastAuthTimestamp);
    if (lastAuthStr == null) return false;

    final lastAuth = int.tryParse(lastAuthStr) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastAuth) < AppConstants.gracePeriodMs;
  }
}
