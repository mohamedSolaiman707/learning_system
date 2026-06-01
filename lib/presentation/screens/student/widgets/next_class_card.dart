import 'dart:async';
import 'package:flutter/material.dart';

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
  double _opacity = 1.0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isLive) {
      _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
        if (mounted) setState(() => _opacity = _opacity == 1.0 ? 0.6 : 1.0);
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header الجزء العلوي الملون بشكل خفيف
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: widget.isLive ? const Color(0xFFFFF1F0) : const Color(0xFFF0F7FF),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isLive ? Colors.red.shade400 : Colors.blue.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isLive ? Icons.sensors_rounded : Icons.event_note_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.isLive ? "بث مباشر الآن" : "الحصة القادمة",
                    style: TextStyle(
                      color: widget.isLive ? Colors.red.shade700 : Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isLive)
                    AnimatedOpacity(
                      opacity: _opacity,
                      duration: const Duration(milliseconds: 500),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text("LIVE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.subject,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF102A43),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoTile(Icons.person_outline_rounded, widget.teacher),
                      const SizedBox(width: 24),
                      _buildInfoTile(Icons.access_time_rounded, widget.startTime),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // الزر بتصميم عصري
                  ElevatedButton(
                    onPressed: widget.isLive ? widget.onJoin : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isLive ? const Color(0xFF102A43) : Colors.grey.shade100,
                      foregroundColor: widget.isLive ? Colors.white : Colors.grey.shade400,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.isLive ? "انضم للحصة الآن" : "بانتظار المعلم",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        if (widget.isLive) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
