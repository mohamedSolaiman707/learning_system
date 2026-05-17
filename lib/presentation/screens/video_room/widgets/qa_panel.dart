import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class QAPanel extends StatefulWidget {
  const QAPanel({super.key});

  @override
  State<QAPanel> createState() => _QAPanelState();
}

class _QAPanelState extends State<QAPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildHeader(controller),
          Expanded(
            child: controller.questions.isEmpty
                ? const Center(child: Text("لا يوجد أسئلة حالياً", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: controller.questions.length,
                    itemBuilder: (context, index) {
                      final q = controller.questions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(q['text'] ?? '', style: const TextStyle(fontSize: 14)),
                          subtitle: Text("من: ${q['from']}", style: const TextStyle(fontSize: 10)),
                          trailing: const Icon(Icons.question_answer, size: 16, color: Colors.blue),
                        ),
                      );
                    },
                  ),
          ),
          _buildInput(controller),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("الأسئلة والأجوبة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(icon: const Icon(Icons.close), onPressed: controller.toggleQA),
        ],
      ),
    );
  }

  Widget _buildInput(VideoRoomController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "اسأل سؤالاً...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  controller.sendData({
                    'type': 'new_question',
                    'from': controller.userName,
                    'text': _controller.text,
                  });
                  _controller.clear();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
