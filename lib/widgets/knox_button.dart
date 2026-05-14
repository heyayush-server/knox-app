import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Primary filled button with glow effect
class KnoxPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isDestructive;
  final IconData? icon;

  const KnoxPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isDestructive = false,
    this.icon,
  });

  @override
  State<KnoxPrimaryButton> createState() => _KnoxPrimaryButtonState();
}

class _KnoxPrimaryButtonState extends State<KnoxPrimaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Color get _color =>
      widget.isDestructive ? AppTheme.danger : AppTheme.accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: widget.onTap == null
                ? _color.withOpacity(0.3)
                : _color,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: widget.onTap != null
                ? [
                    BoxShadow(
                      color: _color.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: widget.isLoading
              ? Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.black.withOpacity(0.8),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 18, color: AppTheme.black),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.black,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Outline button variant
class KnoxOutlineButton extends StatelessWidget {
  final String label;
  final Future<void> Function()? onTap;
  final IconData? icon;
  final Color? color;

  const KnoxOutlineButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
          border: Border.all(color: c.withOpacity(0.6), width: 1),
          color: c.withOpacity(0.06),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PIN pad button
class PinPadButton extends StatefulWidget {
  final String label;
  final String? sublabel;
  final VoidCallback? onTap;
  final bool isDelete;
  final bool isEmpty;

  const PinPadButton({
    super.key,
    required this.label,
    this.sublabel,
    this.onTap,
    this.isDelete = false,
    this.isEmpty = false,
  });

  @override
  State<PinPadButton> createState() => _PinPadButtonState();
}

class _PinPadButtonState extends State<PinPadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmpty) return const SizedBox();

    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _controller.forward();
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.surface2,
            border: Border.all(
              color: AppTheme.border,
              width: 0.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isDelete)
                const Icon(
                  Icons.backspace_outlined,
                  color: AppTheme.textSecondary,
                  size: 22,
                )
              else ...[
                Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.textPrimary,
                    height: 1,
                  ),
                ),
                if (widget.sublabel != null)
                  Text(
                    widget.sublabel!,
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary,
                      letterSpacing: 1,
                      height: 1.2,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
