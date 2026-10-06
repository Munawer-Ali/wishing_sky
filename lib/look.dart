import 'dart:math';

import 'package:flutter/material.dart';

const ceilingTop = Color(0xFF13162C);
const ceilingBottom = Color(0xFF1F1B3A);
const glowGreen = Color(0xFFD9F99D);
const stickerYellow = Color(0xFFFFE27A);
const crayonPink = Color(0xFFFF8FAB);
const nightLight = Color(0xFFFFB86B);
const paper = Color(0xFFFFF7E3);
const ink = Color(0xFF2B3A67);
const pencil = Color(0xFF8C8FA1);
const ruledLine = Color(0xFFC3D9F2);
const marginLine = Color(0xFFF2A8A8);

class PaperNote extends StatelessWidget {
  const PaperNote({
    super.key,
    required this.child,
    this.angle = 0,
    this.tape = true,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double angle;
  final bool tape;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle * pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: paper,
              borderRadius: BorderRadius.circular(3),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6))],
            ),
            child: child,
          ),
          if (tape)
            Positioned(
              top: -9,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.06,
                  child: Container(width: 70, height: 20, color: Colors.white.withValues(alpha: 0.45)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RuledPaperPainter extends CustomPainter {
  const RuledPaperPainter({this.firstLine = 70, this.gap = 32});

  final double firstLine;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = ruledLine
      ..strokeWidth = 1;
    for (var y = firstLine; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawLine(
      const Offset(34, 0),
      Offset(34, size.height),
      Paint()
        ..color = marginLine
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(RuledPaperPainter oldDelegate) => false;
}
