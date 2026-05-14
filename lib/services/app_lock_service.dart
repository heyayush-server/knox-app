import 'package:flutter/services.dart';

import '../core/hive_boxes.dart';
import '../models/app_info_model.dart';

/// Knox App Lock Service
///
/// Manages the list of locked applications and interacts with
/// the Android platform via MethodChannels for:
/// - Installed app enumeration
/// - Usage stats (requires PACKAGE_USAGE_STATS permission)
/// - Accessibility service status
/// - Overlay permission status
class AppLockService {
  static const _channel = MethodChannel('com.knox.applocker/apps');
  static const _permChannel = MethodChannel('com.knox.applocker/permissions');
  // Sync channel keeps Kotlin LockedAppsCache (used by AccessibilityService) in sync
  static const _syncChannel = MethodChannel('com.knox.applocker/sync');

  // ─── App List ──────────────────────────────────────────────────────────────

  /// Get all installed user apps from Android
  Future<List<AppInfoModel>> getInstalledApps({bool includeSystem = false}) async {
    try {
      final result = await _channel.invokeMethod<List>('getInstalledApps', {
        'includeSystem': includeSystem,
      });

      if (result == null) return [];

      return result.map((app) {
        final map = Map<String, dynamic>.from(app as Map);
        return AppInfoModel(
          packageName: map['packageName'] as String,
          appName: map['appName'] as String,
          isSystemApp: map['isSystemApp'] as bool? ?? false,
          iconBase64: map['iconBase64'] as String?,
        );
      }).toList();
    } on PlatformException catch (e) {
      // Return empty list on error — better than crashing
      return [];
    }
  }

  // ─── Lock Management ───────────────────────────────────────────────────────

  /// Check if an app is locked
  bool isAppLocked(String packageName) {
    return HiveBoxes.lockedAppsBox.containsKey(packageName);
  }

  /// Get all locked package names
  Set<String> getLockedPackages() {
    return HiveBoxes.lockedAppsBox.keys.cast<String>().toSet();
  }

  /// Lock an app — persists to Hive AND syncs to Kotlin LockedAppsCache
  Future<void> lockApp(String packageName) async {
    await HiveBoxes.lockedAppsBox.put(packageName, packageName);
    _syncLockState(packageName, true);
  }

  /// Unlock an app — persists to Hive AND syncs to Kotlin LockedAppsCache
  Future<void> unlockApp(String packageName) async {
    await HiveBoxes.lockedAppsBox.delete(packageName);
    _syncLockState(packageName, false);
  }

  /// Sync a single lock state change to the Kotlin LockedAppsCache.
  /// Fire-and-forget — failure is non-critical (cache reloads on service restart).
  void _syncLockState(String packageName, bool locked) {
    try {
      _syncChannel.invokeMethod('setLocked', {
        'packageName': packageName,
        'locked': locked,
      });
    } catch (_) {
      // Non-fatal — AccessibilityService reloads cache on start
    }
  }

  /// Toggle lock state for an app
  Future<bool> toggleAppLock(String packageName) async {
    if (isAppLocked(packageName)) {
      await unlockApp(packageName);
      return false;
    } else {
      await lockApp(packageName);
      return true;
    }
  }

  // ─── Permission Checks ─────────────────────────────────────────────────────

  /// Check if PACKAGE_USAGE_STATS permission is granted
  Future<bool> hasUsageStatsPermission() async {
    try {
      final result = await _permChannel.invokeMethod<bool>('hasUsageStatsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open usage stats settings screen
  Future<void> openUsageStatsSettings() async {
    try {
      await _permChannel.invokeMethod('openUsageStatsSettings');
    } catch (_) {}
  }

  /// Check if SYSTEM_ALERT_WINDOW (overlay) permission is granted
  Future<bool> hasOverlayPermission() async {
    try {
      final result = await _permChannel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open overlay permission settings
  Future<void> openOverlaySettings() async {
    try {
      await _permChannel.invokeMethod('openOverlaySettings');
    } catch (_) {}
  }

  /// Check if Knox Accessibility Service is enabled
  Future<bool> hasAccessibilityPermission() async {
    try {
      final result = await _permChannel.invokeMethod<bool>('hasAccessibilityPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Open Accessibility settings
  Future<void> openAccessibilitySettings() async {
    try {
      await _permChannel.invokeMethod('openAccessibilitySettings');
    } catch (_) {}
  }

  /// Check if Knox guard service is running
  Future<bool> isGuardServiceRunning() async {
    try {
      final result = await _permChannel.invokeMethod<bool>('isGuardServiceRunning');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Start the Knox guard foreground service
  Future<void> startGuardService() async {
    try {
      await _permChannel.invokeMethod('startGuardService');
    } catch (_) {}
  }

  /// Stop the Knox guard foreground service
  Future<void> stopGuardService() async {
    try {
      await _permChannel.invokeMethod('stopGuardService');
    } catch (_) {}
  }

  // ─── App Icon ──────────────────────────────────────────────────────────────

  /// Get app icon as bytes for display
  Future<List<int>?> getAppIcon(String packageName) async {
    try {
      final result = await _channel.invokeMethod<List<int>>('getAppIcon', {
        'packageName': packageName,
      });
      return result;
    } catch (_) {
      return null;
    }
  }
}
