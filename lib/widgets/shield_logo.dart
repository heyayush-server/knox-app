import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Knox Shield Logo — drawn with CustomPainter for crisp rendering at any size
/// No external assets required — pure vector rendering
class ShieldLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final Color? glowColor;

  const ShieldLogo({
    super.key,
    required this.size,
    this.color,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ShieldPainter(
        color: color ?? AppTheme.accent,
        glowColor: glowColor ?? AppTheme.accentGlow,
      ),
      size: Size(size, size),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color color;
  final Color glowColor;

  _ShieldPainter({required this.color, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Shield path
    final shieldPath = Path();

    // Start at top-center
    shieldPath.moveTo(cx, h * 0.05);

    // Top-right curve
    shieldPath.cubicTo(
      cx + w * 0.42, h * 0.05,
      cx + w * 0.48, h * 0.12,
      cx + w * 0.48, h * 0.28,
    );

    // Right side going down
    shieldPath.cubicTo(
      cx + w * 0.48, h * 0.48,
      cx + w * 0.35, h * 0.65,
      cx, h * 0.92,
    );

    // Left side going up
    shieldPath.cubicTo(
      cx - w * 0.35, h * 0.65,
      cx - w * 0.48, h * 0.48,
      cx - w * 0.48, h * 0.28,
    );

    // Top-left curve
    shieldPath.cubicTo(
      cx - w * 0.48, h * 0.12,
      cx - w * 0.42, h * 0.05,
      cx, h * 0.05,
    );

    shieldPath.close();

    // Draw glow
    final glowPaint = Paint()
      ..color = glowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawPath(shieldPath, glowPaint);

    // Draw shield fill (dark)
    final fillPaint = Paint()
      ..color = AppTheme.surface2.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, fillPaint);

    // Draw shield border
    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(shieldPath, borderPaint);

    // Inner highlight line (left edge)
    final highlightPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final highlightPath = Path();
    highlightPath.moveTo(cx - w * 0.3, h * 0.2);
    highlightPath.cubicTo(
      cx - w * 0.38, h * 0.3,
      cx - w * 0.38, h * 0.45,
      cx - w * 0.2, h * 0.6,
    );
    canvas.drawPath(highlightPath, highlightPaint);

    // Draw K letter in center
    _drawK(canvas, size, color);
  }

  void _drawK(Canvas canvas, Size size, Color color) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final kH = h * 0.38;
    final kW = w * 0.28;
    final startX = cx - kW * 0.45;
    final startY = cy - kH / 2;

    // Vertical bar of K
    final kPath = Path();
    kPath.moveTo(startX, startY);
    kPath.lineTo(startX, startY + kH);

    // Upper diagonal
    kPath.moveTo(startX, cy + kH * 0.05);
    kPath.lineTo(startX + kW * 0.9, startY);

    // Lower diagonal
    kPath.moveTo(startX + kW * 0.35, cy + kH * 0.08);
    kPath.lineTo(startX + kW * 0.9, startY + kH);

    canvas.drawPath(kPath, paint);

    // Glow version
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(kPath, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Animated pulsing fingerprint icon widget
class FingerprintIcon extends StatefulWidget {
  final double size;
  final bool isAnimating;

  const FingerprintIcon({
    super.key,
    this.size = 64,
    this.isAnimating = false,
  });

  @override
  State<FingerprintIcon> createState() => _FingerprintIconState();
}

class _FingerprintIconState extends State<FingerprintIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    if (widget.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(FingerprintIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = widget.isAnimating ? _controller.value : 0.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.1 + glow * 0.4),
                blurRadius: 20 + glow * 20,
                spreadRadius: glow * 8,
              ),
            ],
          ),
          child: Icon(
            Icons.fingerprint,
            size: widget.size * 0.75,
            color: AppTheme.accent.withOpacity(0.6 + glow * 0.4),
          ),
        );
      },
    );
  }
}
