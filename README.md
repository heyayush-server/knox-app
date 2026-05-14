# Knox High Security Layer
### Enterprise-grade Android App Lock — Flutter + Kotlin

---

## Prerequisites

| Tool | Version |
|------|---------|
| Flutter | 3.22.0+ stable |
| Dart | 3.3.0+ |
| Android Studio | Hedgehog (2023.1.1)+ |
| JDK | 17+ |
| Android SDK | API 34 (compileSdk) / API 26+ (minSdk) |
| Kotlin | 1.9.23 |
| Gradle | 8.4 |

---

## 1. Project Setup

```bash
# Clone / extract the project
cd knox_app_lock

# Install Flutter dependencies
flutter pub get

# Generate Hive adapters (run once after changes to models)
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 2. Configure local.properties

Edit `android/local.properties` with your actual paths:

```properties
sdk.dir=/Users/yourname/Library/Android/sdk
flutter.sdk=/Users/yourname/flutter
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
```

---

## 3. Run in Debug Mode

```bash
# Connect your Samsung device via USB with USB Debugging enabled
adb devices

# Run on device
flutter run --debug

# Run on specific device
flutter run -d <device-id>
```

---

## 4. Build Release APK

```bash
# Generate release APK (universal — works on all ABIs)
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk

# Build split APKs by ABI (smaller download per device)
flutter build apk --release --split-per-abi

# Outputs:
#   app-arm64-v8a-release.apk   ← Samsung Galaxy M56 (use this one)
#   app-armeabi-v7a-release.apk
#   app-x86_64-release.apk
```

### Install on device:
```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 5. Samsung OneUI Permission Setup

Knox requires 3 special permissions that must be manually granted by the user.
The onboarding screen guides users through each step.

### 5a. Usage Access (PACKAGE_USAGE_STATS)
> Settings → Apps → ⋮ (Special access) → Usage access → Knox Security → Allow

### 5b. Accessibility Service
> Settings → Accessibility → Installed apps → Knox App Guard → Toggle ON

⚠️ **Samsung OneUI note:** Samsung may show a warning about battery usage.
Tap "Allow" and continue.

### 5c. Draw Over Other Apps (Overlay)
> Settings → Apps → Knox Security → ⋮ → Allow display over other apps → Toggle ON

### 5d. Battery Optimization (Critical for Samsung)
To prevent Knox Guard Service from being killed:
> Settings → Battery → Background usage limits → Never sleeping apps → Add Knox Security

OR:
> Settings → Apps → Knox Security → Battery → Unrestricted

---

## 6. Architecture Overview

```
lib/
├── core/
│   ├── app_router.dart          # GoRouter navigation
│   ├── constants.dart           # SecureKeys, AppConstants
│   └── hive_boxes.dart          # Hive box initialization
├── models/
│   ├── app_info_model.dart      # AppInfoModel + SettingsModel (Hive)
│   └── app_info_model.g.dart    # Generated Hive adapters
├── providers/
│   └── auth_provider.dart       # All Riverpod state providers
├── screens/
│   ├── splash_screen.dart       # Animated launch screen
│   ├── onboarding_screen.dart   # Permission walkthrough
│   ├── pin_setup_screen.dart    # Master PIN creation
│   ├── dashboard_screen.dart    # App list + lock toggles
│   ├── auth_screen.dart         # Lock overlay (PIN + biometric)
│   ├── security_alert_screen.dart # Biometric change warning
│   └── settings_screen.dart    # OneUI-inspired settings
├── services/
│   ├── auth_service.dart        # PIN hashing (SHA-256 + salt)
│   ├── biometric_service.dart   # Fingerprint + enrollment detection
│   └── app_lock_service.dart    # Lock management + platform channels
├── theme/
│   └── app_theme.dart           # AMOLED color system + typography
└── widgets/
    ├── shield_logo.dart         # Knox shield + fingerprint icon
    └── knox_button.dart         # Primary/outline/PIN pad buttons

android/app/src/main/kotlin/com/knox/applocker/
├── MainActivity.kt              # Flutter entry + all MethodChannels
├── KnoxAccessibilityService.kt  # Core app detection engine
├── LockOverlayActivity.kt       # Lock screen activity
├── KnoxGuardService.kt          # Foreground guard service
├── BootReceiver.kt              # Auto-start on reboot
├── LockedAppsCache.kt           # In-memory locked apps cache
├── BiometricHelper.kt           # KeyStore enrollment change detection
└── AppHelper.kt                 # Installed app enumeration
```

---

## 7. Android App Lock Limitations

These are Android OS-level constraints — not Knox bugs:

| Limitation | Explanation |
|------------|-------------|
| **Accessibility required** | Knox uses `AccessibilityService` to detect foreground app changes. This requires manual user activation and may be restricted by some OEMs. |
| **Samsung battery optimization** | OneUI aggressively kills background services. Users MUST add Knox to "Never sleeping apps" for reliable protection. |
| **System apps** | Android prevents overlaying certain system apps (Phone, Settings, SystemUI). Knox skips these intentionally. |
| **FLAG_SECURE apps** | Banking apps that set `FLAG_SECURE` cannot be overlaid. Knox cannot lock these. |
| **Split-screen / freeform** | App detection may be unreliable in split-screen mode on Android 12+. |
| **Android 13+ restrictions** | `TYPE_WINDOW_STATE_CHANGED` events may fire less frequently for certain app categories. |
| **No bypass-proof guarantee** | Advanced users with ADB access or developer options can potentially bypass app locks. Knox is a strong deterrent, not an absolute barrier. |

---

## 8. Security Architecture

### PIN Security
- PIN is **never stored in plain text**
- SHA-256 hash + random salt stored in Android Keystore-backed `EncryptedSharedPreferences`
- 5-attempt lockout with 30-second cooldown
- Salt stored separately from hash

### Biometric Security
- Fingerprint unlock uses `BiometricPrompt` with `BIOMETRIC_STRONG` class
- **Enrollment change detection** via `KeyStore` canary key with `setInvalidatedByBiometricEnrollment(true)`
- If new fingerprints added → biometrics disabled → PIN required → re-enrolled
- Prevents the "add attacker fingerprint" bypass attack

### Screen Security
- `FLAG_SECURE` on MainActivity and LockOverlayActivity prevents screenshots
- `excludeFromRecents=true` on LockOverlayActivity prevents it appearing in task switcher
- Grace period (3s) prevents rapid re-lock after legitimate unlock

### Data Privacy
- **No internet permission** — fully offline
- **No analytics, no ads, no tracking**
- All data stored locally in Android Keystore + Hive

---

## 9. Signing for Release

Create a keystore for release signing:

```bash
keytool -genkey -v -keystore knox-release.jks \
  -alias knox -keyalg RSA -keysize 2048 \
  -validity 10000
```

Add to `android/app/build.gradle`:
```groovy
signingConfigs {
    release {
        storeFile file('knox-release.jks')
        storePassword 'YOUR_STORE_PASSWORD'
        keyAlias 'knox'
        keyPassword 'YOUR_KEY_PASSWORD'
    }
}
buildTypes {
    release {
        signingConfig signingConfigs.release
        // ... rest of config
    }
}
```

---

## 10. Troubleshooting

| Issue | Fix |
|-------|-----|
| Apps not being locked | Enable Accessibility Service; check Samsung battery settings |
| Fingerprint not working | Check biometrics are enrolled; re-enable in Knox Settings |
| "Permissions required" banner | Grant all 3 permissions via Settings buttons |
| Service killed after a while | Add Knox to "Never sleeping apps" in Samsung Battery settings |
| Lock screen not appearing | Check Overlay permission is granted |
| Biometric security alert | Enter master PIN to re-verify after fingerprint change |
