import 'package:flutter/material.dart';

class ProbeDiagram extends StatelessWidget {
  const ProbeDiagram({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          const Text(
            'Probe Layout',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Probe body (rectangle)
                Positioned(
                  left: 60,
                  child: Container(
                    width: 200,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey[700]!,
                          Colors.grey[600]!,
                          Colors.grey[700]!,
                        ],
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                      border: Border.all(color: Colors.white24, width: 2),
                    ),
                  ),
                ),
                // Probe tip (triangle)
                Positioned(
                  left: 20,
                  child: CustomPaint(
                    size: const Size(50, 40),
                    painter: TrianglePainter(),
                  ),
                ),
                // Internal label and arrow
                Positioned(
                  left: 0,
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Internal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      CustomPaint(
                        size: const Size(50, 20),
                        painter: ArrowPainter(color: Colors.cyan),
                      ),
                    ],
                  ),
                ),
                // Ambient label and arrow
                Positioned(
                  left: 140,
                  bottom: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(20, 20),
                        painter: DownArrowPainter(color: Colors.orange),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Ambient',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.grey[600]!,
          Colors.grey[700]!,
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class ArrowPainter extends CustomPainter {
  final Color color;

  ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Arrowhead
    final arrowPath = Path()
      ..moveTo(size.width - 6, size.height / 2 - 4)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width - 6, size.height / 2 + 4);

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class DownArrowPainter extends CustomPainter {
  final Color color;

  DownArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Line
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Arrowhead
    final arrowPath = Path()
      ..moveTo(size.width / 2 - 4, size.height - 6)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width / 2 + 4, size.height - 6);

    canvas.drawPath(arrowPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
