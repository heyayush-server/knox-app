import 'package:hive_flutter/hive_flutter.dart';
import '../models/app_info_model.dart';

/// Manages all Hive box initialization and box name constants
class HiveBoxes {
  static const String lockedApps = 'locked_apps';
  static const String settings = 'settings';
  static const String appCache = 'app_cache';

  static Future<void> init() async {
    // Register adapters
    if (!Hive.isAdapterRegistered(AppInfoModelAdapter().typeId)) {
      Hive.registerAdapter(AppInfoModelAdapter());
    }
    if (!Hive.isAdapterRegistered(SettingsModelAdapter().typeId)) {
      Hive.registerAdapter(SettingsModelAdapter());
    }

    // Open boxes
    await Hive.openBox<String>(lockedApps);
    await Hive.openBox<SettingsModel>(settings);
    await Hive.openBox<AppInfoModel>(appCache);
  }

  static Box<String> get lockedAppsBox => Hive.box<String>(lockedApps);
  static Box<SettingsModel> get settingsBox => Hive.box<SettingsModel>(settings);
  static Box<AppInfoModel> get appCacheBox => Hive.box<AppInfoModel>(appCache);
}
