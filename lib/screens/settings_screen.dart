import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/app_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shield_logo.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final permStatus = ref.watch(permissionProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── Security ─────────────────────────────────────────────────────
          _SectionHeader(title: 'SECURITY'),

          _SettingsTile(
            icon: Icons.pin_outlined,
            iconColor: AppTheme.accent,
            title: 'Change PIN',
            subtitle: 'Update your master unlock PIN',
            onTap: () => context.push(AppRoutes.pinSetup),
          ).animate().fadeIn(delay: 50.ms, duration: 300.ms),

          _SettingsTile(
            icon: Icons.fingerprint,
            iconColor: AppTheme.accent,
            title: 'Fingerprint Unlock',
            subtitle: authState.isBiometricChangeLocked
                ? 'Disabled — biometrics changed'
                : authState.isBiometricEnabled
                    ? 'Enabled'
                    : 'Disabled',
            trailing: authState.isBiometricChangeLocked
                ? Icon(Icons.warning_rounded, color: AppTheme.danger, size: 18)
                : Switch(
                    value: authState.isBiometricEnabled,
                    onChanged: authState.hasBiometrics
                        ? (v) => ref
                            .read(authStateProvider.notifier)
                            .setBiometricEnabled(v)
                        : null,
                  ),
          ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

          if (authState.isBiometricChangeLocked)
            _SettingsTile(
              icon: Icons.shield_outlined,
              iconColor: AppTheme.danger,
              title: 'Security Alert Active',
              subtitle: 'Tap to verify identity and restore biometrics',
              trailingIcon: Icons.chevron_right,
              onTap: () => context.push(AppRoutes.securityAlert),
            ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

          // ── Permissions ────────────────────────────────────────────────
          _SectionHeader(title: 'PERMISSIONS'),

          _PermissionTile(
            icon: Icons.bar_chart_outlined,
            title: 'Usage Access',
            subtitle: 'Required to detect opened apps',
            isGranted: permStatus.usageStats,
            onTap: () async {
              await ref.read(appLockServiceProvider).openUsageStatsSettings();
              await Future.delayed(const Duration(seconds: 2));
              ref.read(permissionProvider.notifier).checkAll();
            },
          ).animate().fadeIn(delay: 120.ms, duration: 300.ms),

          _PermissionTile(
            icon: Icons.accessibility_new_outlined,
            title: 'Accessibility Service',
            subtitle: 'Monitors app switching',
            isGranted: permStatus.accessibility,
            onTap: () async {
              await ref.read(appLockServiceProvider).openAccessibilitySettings();
              await Future.delayed(const Duration(seconds: 2));
              ref.read(permissionProvider.notifier).checkAll();
            },
          ).animate().fadeIn(delay: 140.ms, duration: 300.ms),

          _PermissionTile(
            icon: Icons.layers_outlined,
            title: 'Draw Over Apps',
            subtitle: 'Required for lock overlay',
            isGranted: permStatus.overlay,
            onTap: () async {
              await ref.read(appLockServiceProvider).openOverlaySettings();
              await Future.delayed(const Duration(seconds: 2));
              ref.read(permissionProvider.notifier).checkAll();
            },
          ).animate().fadeIn(delay: 160.ms, duration: 300.ms),

          // ── Guard Service ────────────────────────────────────────────────
          _SectionHeader(title: 'GUARD SERVICE'),

          _SettingsTile(
            icon: Icons.security_outlined,
            iconColor: AppTheme.cyan,
            title: 'Knox Guard',
            subtitle: 'Runs in background to protect apps',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: permStatus.allGranted ? AppTheme.success : AppTheme.danger,
                    boxShadow: [
                      BoxShadow(
                        color: (permStatus.allGranted ? AppTheme.success : AppTheme.danger)
                            .withOpacity(0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  permStatus.allGranted ? 'Active' : 'Inactive',
                  style: AppTheme.bodyMedium.copyWith(
                    color: permStatus.allGranted ? AppTheme.success : AppTheme.danger,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 180.ms, duration: 300.ms),

          // ── About ────────────────────────────────────────────────────────
          _SectionHeader(title: 'ABOUT'),

          _SettingsTile(
            icon: Icons.shield_outlined,
            iconColor: AppTheme.accent,
            title: 'Knox High Security Layer',
            subtitle: 'Version 1.0.0 · Enterprise Edition',
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: AppTheme.textSecondary,
            title: 'Privacy',
            subtitle: 'No data collection · No internet · 100% offline',
          ).animate().fadeIn(delay: 220.ms, duration: 300.ms),

          _SettingsTile(
            icon: Icons.info_outline,
            iconColor: AppTheme.textSecondary,
            title: 'App Lock Limitations',
            subtitle: 'Tap to learn about Android restrictions',
            trailingIcon: Icons.chevron_right,
            onTap: () => _showLimitationsDialog(),
          ).animate().fadeIn(delay: 240.ms, duration: 300.ms),

          const SizedBox(height: 24),

          // Logo
          Center(
            child: Column(
              children: [
                const ShieldLogo(size: 32),
                const SizedBox(height: 8),
                Text(
                  'KNOX · HIGH SECURITY LAYER',
                  style: AppTheme.monoSmall.copyWith(color: AppTheme.textTertiary),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }

  void _showLimitationsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          side: const BorderSide(color: AppTheme.border, width: 0.5),
        ),
        title: const Text('Android Limitations', style: AppTheme.titleMedium),
        content: Text(
          '• Android 12+ restricts background app monitoring for battery optimization.\n\n'
          '• The Accessibility Service approach is the most reliable method but '
          'Samsung OneUI may kill background services — grant "Allow background activity" in battery settings.\n\n'
          '• Some launcher apps and system-level apps cannot be locked due to Android security restrictions.\n\n'
          '• Secure apps (banking, system) that use FLAG_SECURE cannot be overlaid.\n\n'
          '• Knox requires Accessibility Service enabled to function — some device manufacturers disable this.',
          style: AppTheme.bodyMedium.copyWith(height: 1.7),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Understood',
              style: TextStyle(color: AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title,
        style: AppTheme.labelLarge.copyWith(color: AppTheme.textTertiary),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    this.iconColor = AppTheme.textSecondary,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(title, style: AppTheme.bodyLarge),
      subtitle: Text(subtitle, style: AppTheme.bodyMedium),
      trailing: trailing ??
          (trailingIcon != null
              ? Icon(trailingIcon, size: 18, color: AppTheme.textTertiary)
              : null),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isGranted;
  final VoidCallback? onTap;

  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isGranted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      iconColor: isGranted ? AppTheme.success : AppTheme.warning,
      title: title,
      subtitle: subtitle,
      onTap: isGranted ? null : onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: isGranted ? AppTheme.success : AppTheme.warning,
          ),
          if (!isGranted) ...[
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textTertiary),
          ],
        ],
      ),
    );
  }
}
