import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class PollPanel extends StatelessWidget {
  const PollPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final poll = controller.activePoll;

    if (poll == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("تصويت مباشر", style: TextStyle(fontWeight: FontWeight.bold)),
              if (controller.isTeacher)
                IconButton(
                  icon: const Icon(Icons.stop_circle, color: Colors.red),
                  onPressed: () => controller.sendData({'type': 'poll_end'}),
                ),
            ],
          ),
          const Divider(),
          Text(poll['question'], style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          ...poll['options'].map<Widget>((option) {
            final votes = controller.pollResults[option] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.black,
                  elevation: 0,
                ),
                onPressed: () => controller.sendData({'type': 'poll_vote', 'option': option}),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(option),
                    Text("$votes صوت"),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
