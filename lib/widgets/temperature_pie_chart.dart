import 'package:flutter/material.dart';
import 'dart:math' as math;

class TemperaturePieChart extends StatefulWidget {
  final double temperature;
  final String label;
  final double minTemp;
  final double maxTemp;

  const TemperaturePieChart({
    super.key,
    required this.temperature,
    required this.label,
    this.minTemp = 0,
    this.maxTemp = 100,
  });

  @override
  State<TemperaturePieChart> createState() => _TemperaturePieChartState();
}

class _TemperaturePieChartState extends State<TemperaturePieChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _previousTemp = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.temperature).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _previousTemp = widget.temperature;
  }

  @override
  void didUpdateWidget(TemperaturePieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.temperature != widget.temperature) {
      _animation = Tween<double>(
        begin: _previousTemp,
        end: widget.temperature,
      ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );
      _animationController.forward(from: 0);
      _previousTemp = widget.temperature;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getTemperatureColor(double temp) {
    double normalizedTemp = (temp - widget.minTemp) / (widget.maxTemp - widget.minTemp);
    normalizedTemp = normalizedTemp.clamp(0.0, 1.0);

    if (normalizedTemp < 0.5) {
      // Blue to Yellow
      return Color.lerp(
        Colors.blue,
        Colors.yellow,
        normalizedTemp * 2,
      )!;
    } else {
      // Yellow to Red
      return Color.lerp(
        Colors.yellow,
        Colors.red,
        (normalizedTemp - 0.5) * 2,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final temp = _animation.value;
        final percentage = ((temp - widget.minTemp) / (widget.maxTemp - widget.minTemp)).clamp(0.0, 1.0);

        return Column(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: PieChartPainter(
                      percentage: percentage,
                      color: _getTemperatureColor(temp),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${temp.toStringAsFixed(1)}°F',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${((temp - 32) * 5 / 9).toStringAsFixed(1)}°C',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class PieChartPainter extends CustomPainter {
  final double percentage;
  final Color color;

  PieChartPainter({
    required this.percentage,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;

    canvas.drawCircle(center, radius - 10, bgPaint);

    // Filled arc
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.6), color],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * percentage;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 10),
      -math.pi / 2,
      sweepAngle,
      false,
      fillPaint,
    );

    // Glow effect
    if (percentage > 0) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 25
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 10),
        -math.pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(PieChartPainter oldDelegate) {
    return oldDelegate.percentage != percentage || oldDelegate.color != color;
  }
}
