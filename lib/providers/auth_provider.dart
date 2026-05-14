import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/app_lock_service.dart';
import '../models/app_info_model.dart';

// ─── Service Providers ────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());
final appLockServiceProvider = Provider<AppLockService>((ref) => AppLockService());

// ─── Auth State ───────────────────────────────────────────────────────────────

class AuthState {
  final bool isSetupComplete;
  final bool isOnboardingComplete;
  final bool hasBiometrics;
  final bool isBiometricEnabled;
  final bool isBiometricChangeLocked;
  final bool isLoading;

  const AuthState({
    this.isSetupComplete = false,
    this.isOnboardingComplete = false,
    this.hasBiometrics = false,
    this.isBiometricEnabled = false,
    this.isBiometricChangeLocked = false,
    this.isLoading = true,
  });

  AuthState copyWith({
    bool? isSetupComplete,
    bool? isOnboardingComplete,
    bool? hasBiometrics,
    bool? isBiometricEnabled,
    bool? isBiometricChangeLocked,
    bool? isLoading,
  }) {
    return AuthState(
      isSetupComplete: isSetupComplete ?? this.isSetupComplete,
      isOnboardingComplete: isOnboardingComplete ?? this.isOnboardingComplete,
      hasBiometrics: hasBiometrics ?? this.hasBiometrics,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isBiometricChangeLocked: isBiometricChangeLocked ?? this.isBiometricChangeLocked,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final BiometricService _biometricService;

  AuthStateNotifier(this._authService, this._biometricService)
      : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final setupComplete = await _authService.isSetupComplete();
    final onboardingComplete = await _authService.isOnboardingComplete();
    final hasBiometrics = await _biometricService.isEnrolled();
    final biometricEnabled = await _biometricService.isBiometricUnlockEnabled();
    final biometricChangeLocked = await _biometricService.isBiometricChangeLocked();

    state = state.copyWith(
      isSetupComplete: setupComplete,
      isOnboardingComplete: onboardingComplete,
      hasBiometrics: hasBiometrics,
      isBiometricEnabled: biometricEnabled,
      isBiometricChangeLocked: biometricChangeLocked,
      isLoading: false,
    );
  }

  Future<void> refresh() => _init();

  Future<bool> verifyPin(String pin) async {
    final result = await _authService.verifyPin(pin);
    return result == PinVerificationResult.success;
  }

  Future<void> markSetupComplete() async {
    await _authService.markSetupComplete();
    state = state.copyWith(isSetupComplete: true);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _biometricService.setBiometricUnlockEnabled(enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  Future<void> clearBiometricChangeLock() async {
    await _biometricService.unlockBiometricsAfterPinVerification();
    state = state.copyWith(isBiometricChangeLocked: false);
  }
}

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>(
  (ref) => AuthStateNotifier(
    ref.watch(authServiceProvider),
    ref.watch(biometricServiceProvider),
  ),
);

// ─── App List Provider ────────────────────────────────────────────────────────

final installedAppsProvider = FutureProvider<List<AppInfoModel>>((ref) async {
  final service = ref.watch(appLockServiceProvider);
  return service.getInstalledApps(includeSystem: false);
});

// ─── Locked Apps Provider ─────────────────────────────────────────────────────

class LockedAppsNotifier extends StateNotifier<Set<String>> {
  final AppLockService _service;

  LockedAppsNotifier(this._service) : super(_service.getLockedPackages());

  Future<void> toggleLock(String packageName) async {
    final isNowLocked = await _service.toggleAppLock(packageName);
    if (isNowLocked) {
      state = {...state, packageName};
    } else {
      state = state.where((p) => p != packageName).toSet();
    }
  }

  bool isLocked(String packageName) => state.contains(packageName);
}

final lockedAppsProvider = StateNotifierProvider<LockedAppsNotifier, Set<String>>(
  (ref) => LockedAppsNotifier(ref.watch(appLockServiceProvider)),
);

// ─── Permission Status Provider ───────────────────────────────────────────────

class PermissionStatus {
  final bool usageStats;
  final bool overlay;
  final bool accessibility;

  const PermissionStatus({
    this.usageStats = false,
    this.overlay = false,
    this.accessibility = false,
  });

  bool get allGranted => usageStats && overlay && accessibility;

  PermissionStatus copyWith({
    bool? usageStats,
    bool? overlay,
    bool? accessibility,
  }) {
    return PermissionStatus(
      usageStats: usageStats ?? this.usageStats,
      overlay: overlay ?? this.overlay,
      accessibility: accessibility ?? this.accessibility,
    );
  }
}

class PermissionNotifier extends StateNotifier<PermissionStatus> {
  final AppLockService _service;

  PermissionNotifier(this._service) : super(const PermissionStatus()) {
    checkAll();
  }

  Future<void> checkAll() async {
    final usageStats = await _service.hasUsageStatsPermission();
    final overlay = await _service.hasOverlayPermission();
    final accessibility = await _service.hasAccessibilityPermission();

    state = PermissionStatus(
      usageStats: usageStats,
      overlay: overlay,
      accessibility: accessibility,
    );
  }
}

final permissionProvider = StateNotifierProvider<PermissionNotifier, PermissionStatus>(
  (ref) => PermissionNotifier(ref.watch(appLockServiceProvider)),
);

// ─── Search Query Provider ────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

// ─── Filtered Apps Provider ───────────────────────────────────────────────────

final filteredAppsProvider = Provider<AsyncValue<List<AppInfoModel>>>((ref) {
  final apps = ref.watch(installedAppsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();

  return apps.when(
    data: (list) {
      if (query.isEmpty) return AsyncValue.data(list);
      final filtered = list
          .where((a) =>
              a.appName.toLowerCase().contains(query) ||
              a.packageName.toLowerCase().contains(query))
          .toList();
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, s) => AsyncValue.error(e, s),
  );
});
