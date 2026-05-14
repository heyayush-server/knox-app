import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../core/app_router.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../models/app_info_model.dart';
import '../widgets/shield_logo.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  bool _searchActive = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = ref.watch(filteredAppsProvider);
    final lockedApps = ref.watch(lockedAppsProvider);
    final permStatus = ref.watch(permissionProvider);

    return Scaffold(
      backgroundColor: AppTheme.black,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            pinned: true,
            expandedHeight: 140,
            backgroundColor: AppTheme.black,
            flexibleSpace: FlexibleSpaceBar(
              expandedTitleScale: 1,
              background: _buildHeader(),
            ),
            actions: [
              IconButton(
                onPressed: () => context.push(AppRoutes.settings),
                icon: const Icon(Icons.tune_rounded),
              ),
            ],
          ),

          // Permission warning banner (if permissions missing)
          if (!permStatus.allGranted)
            SliverToBoxAdapter(
              child: _buildPermissionBanner(permStatus),
            ),

          // Search bar
          SliverToBoxAdapter(
            child: _buildSearchBar(),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'INSTALLED APPS',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  filteredApps.when(
                    data: (apps) => Text(
                      '${lockedApps.length} locked',
                      style: AppTheme.labelLarge.copyWith(
                        color: AppTheme.accent,
                      ),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, __) => const SizedBox(),
                  ),
                ],
              ),
            ),
          ),

          // App list
          filteredApps.when(
            loading: () => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: AppTheme.accent,
                      strokeWidth: 1.5,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scanning apps...',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            error: (error, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.danger, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load apps',
                      style: AppTheme.bodyLarge.copyWith(color: AppTheme.danger),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Grant Usage Stats permission',
                      style: AppTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            data: (apps) => SliverList.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final isLocked = lockedApps.contains(app.packageName);

                return _AppCard(
                  app: app,
                  isLocked: isLocked,
                  index: index,
                  onToggle: () {
                    ref
                        .read(lockedAppsProvider.notifier)
                        .toggleLock(app.packageName);
                  },
                );
              },
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              const ShieldLogo(size: 28),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Knox Security',
                    style: AppTheme.titleLarge,
                  ),
                  Text(
                    'HIGH SECURITY LAYER',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.accent,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(PermissionStatus status) {
    return GestureDetector(
      onTap: () {
        if (!status.accessibility) {
          ref.read(appLockServiceProvider).openAccessibilitySettings();
        } else if (!status.usageStats) {
          ref.read(appLockServiceProvider).openUsageStatsSettings();
        } else if (!status.overlay) {
          ref.read(appLockServiceProvider).openOverlaySettings();
        }
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) ref.read(permissionProvider.notifier).checkAll();
        });
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.warning.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppTheme.warning.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Permissions required',
                    style: AppTheme.bodyMedium.copyWith(color: AppTheme.warning),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getMissingPermissionsText(status),
                    style: AppTheme.bodyMedium.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.warning, size: 18),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  String _getMissingPermissionsText(PermissionStatus status) {
    final missing = <String>[];
    if (!status.accessibility) missing.add('Accessibility');
    if (!status.usageStats) missing.add('Usage Stats');
    if (!status.overlay) missing.add('Overlay');
    return 'Missing: ${missing.join(', ')}';
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.surface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(
            color: _searchActive ? AppTheme.accent.withOpacity(0.5) : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (q) => ref.read(searchQueryProvider.notifier).state = q,
          onTap: () => setState(() => _searchActive = true),
          onTapOutside: (_) => setState(() => _searchActive = false),
          style: AppTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Search apps...',
            hintStyle: AppTheme.bodyLarge.copyWith(color: AppTheme.textTertiary),
            prefixIcon: const Icon(Icons.search, color: AppTheme.textTertiary, size: 18),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                    icon: const Icon(Icons.close, size: 16, color: AppTheme.textTertiary),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// Individual app card with lock toggle
class _AppCard extends StatefulWidget {
  final AppInfoModel app;
  final bool isLocked;
  final int index;
  final VoidCallback onToggle;

  const _AppCard({
    required this.app,
    required this.isLocked,
    required this.index,
    required this.onToggle,
  });

  @override
  State<_AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<_AppCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _lockController;

  @override
  void initState() {
    super.initState();
    _lockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: widget.isLocked ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_AppCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLocked != oldWidget.isLocked) {
      if (widget.isLocked) {
        _lockController.forward();
      } else {
        _lockController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _lockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _lockController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          decoration: BoxDecoration(
            color: Color.lerp(
              AppTheme.surface1,
              AppTheme.accent.withOpacity(0.06),
              _lockController.value,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(
              color: Color.lerp(
                AppTheme.border,
                AppTheme.accent.withOpacity(0.3),
                _lockController.value,
              )!,
              width: 0.5,
            ),
          ),
          child: child,
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        leading: _buildAppIcon(),
        title: Text(
          widget.app.appName,
          style: AppTheme.bodyLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          widget.app.packageName,
          style: AppTheme.bodyMedium.copyWith(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock icon
            AnimatedBuilder(
              animation: _lockController,
              builder: (context, _) => Icon(
                widget.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 16,
                color: Color.lerp(
                  AppTheme.textTertiary,
                  AppTheme.accent,
                  _lockController.value,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Toggle switch
            Switch(
              value: widget.isLocked,
              onChanged: (_) => widget.onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: (widget.index * 20).clamp(0, 300)))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0, duration: 300.ms);
  }

  Widget _buildAppIcon() {
    // In production, this would decode the base64 icon from AppInfoModel.iconBase64
    // For now, display a colored placeholder with first letter
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: _getAppColor(widget.app.packageName),
      ),
      child: Center(
        child: Text(
          widget.app.appName.isNotEmpty
              ? widget.app.appName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  /// Deterministic color from package name
  Color _getAppColor(String packageName) {
    final colors = [
      const Color(0xFF0066CC),
      const Color(0xFF005C99),
      const Color(0xFF007AFF),
      const Color(0xFF00A8FF),
      const Color(0xFF0055AA),
      const Color(0xFF004488),
    ];
    final index = packageName.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    return colors[index];
  }
}
