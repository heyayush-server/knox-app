import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

import '../core/constants.dart';

/// Result of a biometric authentication attempt
enum BiometricResult {
  success,
  failed,
  notAvailable,
  notEnrolled,
  lockout,
  cancelled,
  error,
}

/// Enrollment change status
enum EnrollmentChangeStatus {
  noChange,       // Enrollment matches stored hash
  changed,        // Enrollment has changed (fingerprints added/removed)
  firstTime,      // No stored hash yet — initial setup
  unavailable,    // Device doesn't support biometrics
}

/// Knox Biometric Service
///
/// Handles all biometric operations with Samsung OneUI compatibility.
/// Key security feature: detects enrollment changes (new fingerprints added,
/// existing fingerprints removed) to prevent unauthorized biometric bypass.
///
/// Security reasoning:
/// If a bad actor adds their fingerprint to the device, Knox detects this change
/// and immediately requires the master PIN before biometrics are re-trusted.
/// This prevents the classic "add fingerprint to bypass app lock" attack vector.
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
  );

  // ─── Platform Channel ─────────────────────────────────────────────────────
  // Used to query BiometricManager enrollment hash on Android 13+
  static const _channel = MethodChannel('com.knox.applocker/biometrics');

  // ─── Availability ─────────────────────────────────────────────────────────

  /// Check if device supports biometrics at all
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Check if biometrics are currently enrolled on device
  Future<bool> isEnrolled() async {
    try {
      final available = await _localAuth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  // ─── Authentication ────────────────────────────────────────────────────────

  /// Attempt biometric authentication
  /// Returns [BiometricResult] indicating success or failure reason
  Future<BiometricResult> authenticate({
    String reason = 'Verify your identity to unlock',
  }) async {
    try {
      // Check if biometrics are available first
      if (!await isAvailable() || !await isEnrolled()) {
        return BiometricResult.notAvailable;
      }

      // Check if biometric unlock is locked due to enrollment change
      final changeLocked = await _secureStorage.read(
        key: SecureKeys.biometricChangeLocked,
      );
      if (changeLocked == 'true') {
        return BiometricResult.notAvailable;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          // Use strong biometrics only (Class 3 — fingerprint/face with security chip)
          // This maps to BIOMETRIC_STRONG on Android
          biometricOnly: true,
          stickyAuth: true, // Keep dialog alive if app goes to background
          sensitiveTransaction: true,
          useErrorDialogs: true,
        ),
      );

      return authenticated ? BiometricResult.success : BiometricResult.failed;
    } on PlatformException catch (e) {
      return _mapPlatformException(e);
    } catch (_) {
      return BiometricResult.error;
    }
  }

  /// Maps PlatformException error codes to BiometricResult
  BiometricResult _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case auth_error.notAvailable:
        return BiometricResult.notAvailable;
      case auth_error.notEnrolled:
        return BiometricResult.notEnrolled;
      case auth_error.lockedOut:
      case auth_error.permanentlyLockedOut:
        return BiometricResult.lockout;
      case auth_error.passcodeNotSet:
        return BiometricResult.notAvailable;
      default:
        if (e.code.contains('cancel') || e.code.contains('Cancel')) {
          return BiometricResult.cancelled;
        }
        return BiometricResult.error;
    }
  }

  // ─── Enrollment Change Detection ──────────────────────────────────────────
  //
  // Strategy: We obtain an "enrollment hash" from Android's KeyStore/BiometricManager.
  // Android 13+ provides BiometricManager.getLastBiometricAuthenticatedTime()
  // and KeyStore key invalidation on enrollment change. We use a platform channel
  // to create a test KeyStore key with setInvalidatedByBiometricEnrollment(true).
  // If the key is invalidated on next use, enrollment has changed.
  //
  // Additionally, we store a hash of enrollment count/identifiers using
  // the platform channel to BiometricManager.
  //
  // Samsung OneUI compatibility: Samsung devices sometimes use a custom
  // BiometricManager implementation. Our platform channel handles both
  // AOSP and Samsung-specific APIs gracefully.

  /// Check current enrollment status and detect changes
  ///
  /// Returns [EnrollmentChangeStatus] indicating whether fingerprints changed
  Future<EnrollmentChangeStatus> checkEnrollmentChange() async {
    try {
      // Get enrollment hash from Android via platform channel
      final currentHash = await _getEnrollmentHash();

      if (currentHash == null) {
        return EnrollmentChangeStatus.unavailable;
      }

      // Retrieve stored hash
      final storedHash = await _secureStorage.read(
        key: SecureKeys.biometricEnrollmentHash,
      );

      if (storedHash == null) {
        // First time — no stored hash yet
        await _saveEnrollmentHash(currentHash);
        return EnrollmentChangeStatus.firstTime;
      }

      if (storedHash == currentHash) {
        return EnrollmentChangeStatus.noChange;
      }

      // Hash mismatch = enrollment changed!
      return EnrollmentChangeStatus.changed;
    } catch (_) {
      return EnrollmentChangeStatus.unavailable;
    }
  }

  /// Get enrollment hash via platform channel
  /// The Android side creates a BiometricPrompt-bound KeyStore key and returns
  /// an identifier that changes whenever biometric enrollment changes
  Future<String?> _getEnrollmentHash() async {
    try {
      final result = await _channel.invokeMethod<String>('getEnrollmentHash');
      return result;
    } catch (_) {
      // Fallback: use biometric count as proxy (less precise but works)
      return _getFallbackEnrollmentHash();
    }
  }

  /// Fallback enrollment hash using available biometric count
  /// Less precise than KeyStore-based detection but works on all devices
  Future<String?> _getFallbackEnrollmentHash() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      // Hash the list of biometric type names as a simple proxy
      final content = biometrics.map((b) => b.name).join(',');
      final bytes = utf8.encode(content + '_knox_salt_v1');
      return sha256.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }

  /// Save current enrollment hash to secure storage
  Future<void> _saveEnrollmentHash(String hash) async {
    await _secureStorage.write(
      key: SecureKeys.biometricEnrollmentHash,
      value: hash,
    );
  }

  /// Save latest enrollment hash (called after PIN verification post-change)
  Future<void> updateEnrollmentHash() async {
    final hash = await _getEnrollmentHash();
    if (hash != null) {
      await _saveEnrollmentHash(hash);
    }
  }

  // ─── Biometric Lock State ─────────────────────────────────────────────────

  /// Lock biometric unlock due to enrollment change
  /// This forces the user to re-verify with master PIN
  Future<void> lockBiometricsAfterChange() async {
    await _secureStorage.write(
      key: SecureKeys.biometricChangeLocked,
      value: 'true',
    );
  }

  /// Unlock biometrics after successful PIN verification
  Future<void> unlockBiometricsAfterPinVerification() async {
    await _secureStorage.write(
      key: SecureKeys.biometricChangeLocked,
      value: 'false',
    );
    // Also update stored enrollment hash to current state
    await updateEnrollmentHash();
  }

  /// Check if biometrics are currently locked due to enrollment change
  Future<bool> isBiometricChangeLocked() async {
    final locked = await _secureStorage.read(
      key: SecureKeys.biometricChangeLocked,
    );
    return locked == 'true';
  }

  // ─── User Preferences ─────────────────────────────────────────────────────

  /// Check if user has enabled biometric unlock
  Future<bool> isBiometricUnlockEnabled() async {
    final enabled = await _secureStorage.read(
      key: SecureKeys.biometricsEnabled,
    );
    return enabled == 'true';
  }

  Future<void> setBiometricUnlockEnabled(bool enabled) async {
    await _secureStorage.write(
      key: SecureKeys.biometricsEnabled,
      value: enabled.toString(),
    );

    if (enabled) {
      // Store enrollment hash when enabling
      await updateEnrollmentHash();
    }
  }
}
