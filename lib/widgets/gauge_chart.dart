import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

enum GaugeType { engagement, goodness }

class GaugeChartWidget extends StatelessWidget {
  final String title;
  final double value; // 0 to 10
  final ValueChanged<double>? onChanged;
  final GaugeType type;
  final bool isInteractive;
  final double size;

  const GaugeChartWidget({
    super.key,
    required this.title,
    required this.value,
    this.onChanged,
    required this.type,
    this.isInteractive = true,
    this.size = 200,
  });

  Color _getPrimaryColor(bool isDark) {
    if (type == GaugeType.engagement) {
      return isDark ? AppTheme.darkEngagement : AppTheme.lightEngagement;
    } else {
      return isDark ? AppTheme.darkGoodness : AppTheme.lightGoodness;
    }
  }

  List<Color> _getGradientColors(bool isDark) {
    if (type == GaugeType.engagement) {
      return isDark
          ? [const Color(0xFFC084FC), const Color(0xFFA78BFA), const Color(0xFF8B5CF6)]
          : [const Color(0xFF9E86FF), const Color(0xFF6E56CF), const Color(0xFF5B46E0)];
    } else {
      return isDark
          ? [const Color(0xFF6EE7B7), const Color(0xFF34D399), const Color(0xFF10B981)]
          : [const Color(0xFF34D399), const Color(0xFF10B981), const Color(0xFF059669)];
    }
  }

  IconData get _icon {
    return type == GaugeType.engagement ? Icons.bolt_rounded : Icons.favorite_rounded;
  }

  void _handleValueChange(double rawVal) {
    final double snappedVal = rawVal.roundToDouble().clamp(0.0, 10.0);
    if (snappedVal != value) {
      HapticFeedback.selectionClick();
      onChanged?.call(snappedVal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _getPrimaryColor(isDark);

    return Container(
      padding: EdgeInsets.all(isInteractive ? 18 : 10),
      decoration: isInteractive
          ? BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                width: 1,
              ),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, color: primaryColor, size: isInteractive ? 18 : 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: isInteractive ? 14 : 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: isInteractive
                ? (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final center = box.size.center(Offset.zero);
                    final pos = details.localPosition - center;
                    double angle = atan2(pos.dy, pos.dx);
                    double norm = (angle + pi) / pi;
                    if (norm < 0) norm = 0;
                    if (norm > 1) norm = 1;
                    double rawValue = norm * 10;
                    _handleValueChange(rawValue);
                  }
                : null,
            child: SizedBox(
              width: size,
              height: size * 0.55,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(size, size * 0.55),
                    painter: _GaugePainter(
                      value: value,
                      colors: _getGradientColors(isDark),
                      isDark: isDark,
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        fontSize: isInteractive ? 36 : 26,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isInteractive && onChanged != null) ...[
            const SizedBox(height: 10),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: primaryColor,
                inactiveTrackColor: primaryColor.withValues(alpha: 0.15),
                thumbColor: Colors.white,
                overlayColor: primaryColor.withValues(alpha: 0.12),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  elevation: 2,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
                activeTickMarkColor: Colors.white.withValues(alpha: 0.8),
                inactiveTickMarkColor: primaryColor.withValues(alpha: 0.3),
                valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
                valueIndicatorColor: primaryColor,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              child: Slider(
                value: value.clamp(0.0, 10.0),
                min: 0,
                max: 10,
                divisions: 10,
                label: value.toInt().toString(),
                onChanged: (val) {
                  _handleValueChange(val);
                },
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(11, (index) {
                  final isSelected = index == value.toInt();
                  return SizedBox(
                    width: 18,
                    child: Text(
                      '$index',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                        color: isSelected
                            ? primaryColor
                            : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double value; // 0 to 10
  final List<Color> colors;
  final bool isDark;

  _GaugePainter({
    required this.value,
    required this.colors,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.85);
    final radius = size.width * 0.42;
    const strokeWidth = 7.0;

    final trackPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      trackPaint,
    );

    final sweepAngle = (value / 10.0).clamp(0.0, 1.0) * pi;
    if (sweepAngle > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final activePaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: pi,
          endAngle: 2 * pi,
          colors: colors,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, pi, sweepAngle, false, activePaint);
    }

    // Indicator Dot
    final pointerAngle = pi + sweepAngle;
    final pointerX = center.dx + radius * cos(pointerAngle);
    final pointerY = center.dy + radius * sin(pointerAngle);

    final pointerGlow = Paint()
      ..color = colors.last.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pointerX, pointerY), 6.0, pointerGlow);

    final pointerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pointerX, pointerY), 3.0, pointerPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colors != colors;
  }
}
