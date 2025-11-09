import 'package:flutter/material.dart';
import 'dart:math' as math;

class PieChartData {
  final String label;
  final double value;
  final Color color;

  PieChartData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class PieChartWidget extends StatelessWidget {
  final List<PieChartData> data;
  final double size;

  const PieChartWidget({
    Key? key,
    required this.data,
    this.size = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double total = data.fold(0, (sum, item) => sum + item.value);

    return Column(
      children: [
        // Gráfico circular
        CustomPaint(
          size: Size(size, size),
          painter: _PieChartPainter(data: data, total: total),
        ),
        SizedBox(height: 16),
        // Leyenda
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: data.map((item) {
            double percentage = total > 0 ? (item.value / total * 100) : 0;
            return _buildLegendItem(item.label, item.color, percentage);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, double percentage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 6),
        Text(
          '$label (${percentage.toStringAsFixed(1)}%)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<PieChartData> data;
  final double total;

  _PieChartPainter({required this.data, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total == 0) {
      // Dibujar círculo gris si no hay datos
      final paint = Paint()
        ..color = Colors.grey.shade300
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2,
        paint,
      );
      return;
    }

    double startAngle = -math.pi / 2; // Empezar desde arriba
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (var item in data) {
      final sweepAngle = (item.value / total) * 2 * math.pi;

      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Dibujar borde blanco entre secciones
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }

    // Círculo blanco en el centro para hacer un "donut chart"
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
