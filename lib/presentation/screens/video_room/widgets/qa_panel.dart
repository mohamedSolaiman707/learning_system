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
  final FocusNode _focusNode = FocusNode();

  void _replyTo(String userName) {
    setState(() {
      _controller.text = "@$userName ";
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
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
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(q['from']?[0].toUpperCase() ?? '?', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(q['from'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  const Spacer(),
                                  const Icon(Icons.question_answer_outlined, size: 14, color: Colors.blue),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(q['text'] ?? '', style: const TextStyle(fontSize: 14)),
                              const Divider(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _replyTo(q['from']),
                                    icon: const Icon(Icons.reply, size: 16),
                                    label: const Text("رد", style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.thumb_up_outlined, size: 16),
                                    onPressed: () {
                                      controller.sendReaction("👍");
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: "اسأل سؤالاً أو أجب...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onSubmitted: (_) => _send(controller),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () => _send(controller),
            ),
          ),
        ],
      ),
    );
  }

  void _send(VideoRoomController controller) {
    if (_controller.text.trim().isNotEmpty) {
      controller.sendData({
        'type': 'new_question',
        'from': controller.userName,
        'text': _controller.text.trim(),
      });
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }
}
