import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

class NextClassCard extends StatefulWidget {
  final String subject;
  final String teacher;
  final String startTime;
  final bool isLive;
  final VoidCallback? onJoin;

  const NextClassCard({
    super.key,
    required this.subject,
    required this.teacher,
    required this.startTime,
    this.isLive = false,
    this.onJoin,
  });

  @override
  State<NextClassCard> createState() => _NextClassCardState();
}

class _NextClassCardState extends State<NextClassCard> {
  // هذا الجزء لإضافة لمسة جمالية (زر نابض)
  double _opacity = 1.0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isLive) {
      _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
        if (mounted) setState(() => _opacity = _opacity == 1.0 ? 0.5 : 1.0);
      });
    }
  }

  @override
  void dispose() {
    if (widget.isLive) _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isLive 
              ? [Colors.red.shade700, Colors.red.shade400] 
              : [const Color(0xFF2196F3), const Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (widget.isLive ? Colors.red : Colors.blue).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBadge(
                widget.isLive ? "بث مباشر الآن" : "الحصة القادمة",
                widget.isLive ? Colors.white : Colors.white24,
              ),
              if (widget.isLive)
                AnimatedOpacity(
                  opacity: _opacity,
                  duration: const Duration(milliseconds: 400),
                  child: const Icon(Icons.circle, color: Colors.white, size: 12),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.subject,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(IconlyLight.user_1, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(widget.teacher, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const Spacer(),
              const Icon(IconlyLight.time_circle, color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text(widget.startTime, style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.isLive ? widget.onJoin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isLive ? Colors.white : Colors.white10,
              foregroundColor: widget.isLive ? Colors.red.shade700 : Colors.white38,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Text(
              widget.isLive ? "انضم للحصة الآن" : "بانتظار بدء المعلم للدرس",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(
          color: widget.isLive ? Colors.red.shade700 : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
