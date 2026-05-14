import 'package:hive/hive.dart';

part 'app_info_model.g.dart';

/// Represents an installed Android application
@HiveType(typeId: 0)
class AppInfoModel extends HiveObject {
  @HiveField(0)
  final String packageName;

  @HiveField(1)
  final String appName;

  @HiveField(2)
  final bool isSystemApp;

  @HiveField(3)
  final String? iconBase64; // Base64 encoded icon for caching

  AppInfoModel({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.iconBase64,
  });

  @override
  String toString() => 'AppInfoModel($packageName, $appName)';
}

/// Settings model stored in Hive
@HiveType(typeId: 1)
class SettingsModel extends HiveObject {
  @HiveField(0)
  bool showSystemApps;

  @HiveField(1)
  bool autoStartOnBoot;

  @HiveField(2)
  bool preventScreenshots;

  @HiveField(3)
  bool vibrateOnUnlock;

  @HiveField(4)
  int themeMode; // 0=auto, 1=dark, 2=light (always dark in this app)

  SettingsModel({
    this.showSystemApps = false,
    this.autoStartOnBoot = true,
    this.preventScreenshots = true,
    this.vibrateOnUnlock = true,
    this.themeMode = 1,
  });
}
