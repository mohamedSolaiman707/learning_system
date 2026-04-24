import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../widgets/next_class_card.dart';
import '../widgets/upcoming_class_item.dart';
import '../../video_room/video_room_screen.dart';

class StudentHomeTab extends StatelessWidget {
  const StudentHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("الرئيسية"),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(IconlyLight.notification),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "مرحباً، أحمد",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            NextClassCard(
              subject: "اللغة العربية",
              teacher: "أ. محمد علي",
              startTime: "10:00 AM",
              isLive: true,
              onJoin: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VideoRoomScreen(
                      title: "حصة اللغة العربية",
                      roomName: "arabic_class_101", // اسم الغرفة
                      userName: "Ahmed_Student",    // اسم الطالب (يفضل جلبه من الـ Profile)
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "إحصائياتي",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildProgressCard(
                    context,
                    title: "الحضور",
                    percent: 0.85,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildProgressCard(
                    context,
                    title: "الواجبات",
                    percent: 0.60,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "حصص اليوم",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(onPressed: () {}, child: const Text("الكل")),
              ],
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return const UpcomingClassItem(
                  subject: "الرياضيات",
                  teacher: "أ. سارة محمود",
                  time: "12:30 PM",
                  duration: "45 دقيقة",
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, {required String title, required double percent, required Color color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircularPercentIndicator(
              radius: 40.0,
              lineWidth: 8.0,
              percent: percent,
              center: Text("${(percent * 100).toInt()}%"),
              progressColor: color,
              backgroundColor: color.withOpacity(0.1),
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
