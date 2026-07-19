import 'dart:math';
import 'package:flutter/material.dart';

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

  Color _getPrimaryColor(BuildContext context) {
    if (type == GaugeType.engagement) {
      return const Color(0xFF6366F1); // Indigo
    } else {
      return const Color(0xFF10B981); // Emerald
    }
  }

  List<Color> _getGradientColors() {
    if (type == GaugeType.engagement) {
      return [
        const Color(0xFF818CF8),
        const Color(0xFF6366F1),
        const Color(0xFFF59E0B),
      ];
    } else {
      return [
        const Color(0xFF34D399),
        const Color(0xFF10B981),
        const Color(0xFF059669),
      ];
    }
  }

  String get _levelLabel {
    if (value <= 2.5) return 'Low';
    if (value <= 5.0) return 'Moderate';
    if (value <= 7.5) return 'High';
    return 'Flow State!';
  }

  IconData get _icon {
    if (type == GaugeType.engagement) {
      return Icons.bolt_rounded;
    } else {
      return Icons.favorite_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = _getPrimaryColor(context);

    return Container(
      padding: EdgeInsets.all(isInteractive ? 16 : 8),
      decoration: isInteractive
          ? BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 80 : 15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon, color: primaryColor, size: isInteractive ? 22 : 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: isInteractive ? 16 : 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onPanUpdate: isInteractive
                ? (details) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final center = box.size.center(Offset.zero);
                    final pos = details.localPosition - center;
                    double angle = atan2(pos.dy, pos.dx);
                    double norm = (angle + pi) / pi;
                    if (norm < 0) norm = 0;
                    if (norm > 1) norm = 1;
                    double newValue = (norm * 10).clamp(0.0, 10.0);
                    onChanged?.call((newValue * 10).round() / 10.0);
                  }
                : null,
            child: SizedBox(
              width: size,
              height: size * 0.65,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(size, size * 0.65),
                    painter: _GaugePainter(
                      value: value,
                      colors: _getGradientColors(),
                      isDark: isDark,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: isInteractive ? 32 : 20,
                            fontWeight: FontWeight.w900,
                            color: primaryColor,
                          ),
                        ),
                        if (isInteractive) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _levelLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isInteractive && onChanged != null) ...[
            const SizedBox(height: 8),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: primaryColor,
                inactiveTrackColor: primaryColor.withAlpha(50),
                thumbColor: primaryColor,
                overlayColor: primaryColor.withAlpha(38),
                trackHeight: 6,
                valueIndicatorShape: const RectangularSliderValueIndicatorShape(),
                valueIndicatorColor: primaryColor,
                valueIndicatorTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 10,
                divisions: 100,
                label: value.toStringAsFixed(1),
                onChanged: (val) {
                  onChanged!((val * 10).round() / 10.0);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                Text('5', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                Text('10', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
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
    const strokeWidth = 14.0;

    final trackPaint = Paint()
      ..color = isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(15)
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

    final pointerAngle = pi + sweepAngle;
    final pointerX = center.dx + radius * cos(pointerAngle);
    final pointerY = center.dy + radius * sin(pointerAngle);

    final pointerGlow = Paint()
      ..color = colors.last.withAlpha(75)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pointerX, pointerY), strokeWidth, pointerGlow);

    final pointerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pointerX, pointerY), strokeWidth / 2.2, pointerPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.isDark != isDark ||
        oldDelegate.colors != colors;
  }
}
