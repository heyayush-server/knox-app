// GENERATED CODE - DO NOT MODIFY BY HAND
// Run: flutter pub run build_runner build

part of 'app_info_model.dart';

class AppInfoModelAdapter extends TypeAdapter<AppInfoModel> {
  @override
  final int typeId = 0;

  @override
  AppInfoModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppInfoModel(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      isSystemApp: fields[2] as bool,
      iconBase64: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppInfoModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.isSystemApp)
      ..writeByte(3)
      ..write(obj.iconBase64);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppInfoModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SettingsModelAdapter extends TypeAdapter<SettingsModel> {
  @override
  final int typeId = 1;

  @override
  SettingsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SettingsModel(
      showSystemApps: fields[0] as bool,
      autoStartOnBoot: fields[1] as bool,
      preventScreenshots: fields[2] as bool,
      vibrateOnUnlock: fields[3] as bool,
      themeMode: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SettingsModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.showSystemApps)
      ..writeByte(1)
      ..write(obj.autoStartOnBoot)
      ..writeByte(2)
      ..write(obj.preventScreenshots)
      ..writeByte(3)
      ..write(obj.vibrateOnUnlock)
      ..writeByte(4)
      ..write(obj.themeMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
