/// All secure storage key constants for Knox App Lock
/// These are stored encrypted via flutter_secure_storage (AES-256 on Android Keystore)
class SecureKeys {
  /// SHA-256 hashed PIN
  static const String pinHash = 'knox_pin_hash';

  /// Whether initial setup is complete
  static const String setupComplete = 'knox_setup_complete';

  /// Whether biometrics are enabled by user
  static const String biometricsEnabled = 'knox_biometrics_enabled';

  /// Stored biometric enrollment hash (to detect changes)
  /// We store a hash/fingerprint of the current BiometricManager enrollment
  static const String biometricEnrollmentHash = 'knox_biometric_enrollment_hash';

  /// Whether biometric lock is triggered due to change detection
  static const String biometricChangeLocked = 'knox_biometric_change_locked';

  /// Timestamp of last successful authentication (epoch ms)
  static const String lastAuthTimestamp = 'knox_last_auth_timestamp';

  /// Whether onboarding has been shown
  static const String onboardingComplete = 'knox_onboarding_complete';

  /// Failed PIN attempt count
  static const String failedAttempts = 'knox_failed_attempts';

  /// Lockout timestamp after too many failed attempts
  static const String lockoutUntil = 'knox_lockout_until';
}

/// App-level constants
class AppConstants {
  /// Max failed PIN attempts before lockout
  static const int maxFailedAttempts = 5;

  /// Lockout duration in seconds after max failed attempts
  static const int lockoutDurationSeconds = 30;

  /// Grace period in milliseconds — if app was recently unlocked, skip re-auth
  static const int gracePeriodMs = 3000;

  /// Foreground service notification channel ID
  static const String notificationChannelId = 'knox_guard_channel';

  /// Accessibility service class name (must match AndroidManifest)
  static const String accessibilityServiceClass =
      'com.knox.applocker.KnoxAccessibilityService';

  /// App package name
  static const String packageName = 'com.knox.applocker';
}
