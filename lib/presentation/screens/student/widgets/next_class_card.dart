import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';

class NextClassCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "الحصة القادمة",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Colors.white, size: 8),
                      SizedBox(width: 4),
                      Text(
                        "مباشر",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(IconlyLight.profile, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                teacher,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Spacer(),
              const Icon(IconlyLight.time_circle, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                startTime,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: isLive ? onJoin : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: isLive ? Colors.white : Colors.white24,
              foregroundColor: isLive ? Theme.of(context).primaryColor : Colors.white70,
              elevation: 0,
            ),
            child: const Text("دخول الحصة"),
          ),
        ],
      ),
    );
  }
}
