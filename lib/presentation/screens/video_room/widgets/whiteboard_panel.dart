import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class WhiteboardPanel extends StatefulWidget {
  const WhiteboardPanel({super.key});

  @override
  State<WhiteboardPanel> createState() => _WhiteboardPanelState();
}

class _WhiteboardPanelState extends State<WhiteboardPanel> {
  List<Offset> _currentPoints = [];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // مساحة الرسم
          GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                RenderBox renderBox = context.findRenderObject() as RenderBox;
                _currentPoints.add(renderBox.globalToLocal(details.globalPosition));
              });
            },
            onPanEnd: (details) {
              if (_currentPoints.isNotEmpty) {
                controller.addStroke(_currentPoints);
                _currentPoints = [];
              }
            },
            child: CustomPaint(
              painter: WhiteboardPainter(
                strokes: controller.whiteboardStrokes,
                currentPoints: _currentPoints,
                activeColor: controller.selectedColor,
              ),
              size: Size.infinite,
            ),
          ),
          
          // شريط الأدوات العلوي (Undo, Redo, Clear, Close)
          Positioned(
            top: topPadding + 60,
            left: 10,
            right: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    _ToolButton(
                      icon: Icons.undo,
                      onPressed: controller.undoWhiteboard,
                    ),
                    _ToolButton(
                      icon: Icons.redo,
                      onPressed: controller.redoWhiteboard,
                    ),
                    _ToolButton(
                      icon: Icons.delete_outline,
                      onPressed: controller.clearWhiteboard,
                    ),
                    const SizedBox(width: 8),
                    _ToolButton(
                      icon: Icons.close,
                      onPressed: controller.toggleWhiteboard,
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // شريط اختيار الألوان والممحاة (سفلي)
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ColorDot(color: Colors.black, controller: controller),
                    _ColorDot(color: Colors.red, controller: controller),
                    _ColorDot(color: Colors.blue, controller: controller),
                    _ColorDot(color: Colors.green, controller: controller),
                    const VerticalDivider(width: 20),
                    // زر الممحاة (أبيض مع سمك أكبر)
                    IconButton(
                      icon: Icon(
                        Icons.cleaning_services, 
                        color: controller.selectedColor == Colors.white ? Colors.blue : Colors.grey
                      ),
                      onPressed: () {
                        controller.setWhiteboardColor(Colors.white);
                        controller.setStrokeWidth(20.0);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final VideoRoomController controller;
  const _ColorDot({required this.color, required this.controller});

  @override
  Widget build(BuildContext context) {
    final isSelected = controller.selectedColor == color;
    return GestureDetector(
      onTap: () {
        controller.setWhiteboardColor(color);
        controller.setStrokeWidth(3.0);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4)] : null,
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;

  const _ToolButton({required this.icon, required this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: IconButton(
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        icon: Icon(icon, color: color ?? Colors.black87, size: 20),
        onPressed: onPressed,
      ),
    );
  }
}

class WhiteboardPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<Offset> currentPoints;
  final Color activeColor;

  WhiteboardPainter({required this.strokes, required this.currentPoints, required this.activeColor});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (var stroke in strokes) {
      paint.color = stroke.color;
      paint.strokeWidth = stroke.width;
      for (int i = 0; i < stroke.points.length - 1; i++) {
        canvas.drawLine(stroke.points[i], stroke.points[i + 1], paint);
      }
    }

    // رسم الخط الحالي
    paint.color = activeColor;
    paint.strokeWidth = activeColor == Colors.white ? 20.0 : 3.0;
    for (int i = 0; i < currentPoints.length - 1; i++) {
      canvas.drawLine(currentPoints[i], currentPoints[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
