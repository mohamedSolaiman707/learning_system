import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({super.key});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    
    return Container(
      // تم إزالة العرض الثابت هنا ليعتمد على الأب
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildHeader(context, controller),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: controller.messages.length,
              itemBuilder: (context, index) {
                final msg = controller.messages[index];
                final isMe = msg['user_id'] == controller.userId;
                return _MessageBubble(
                  userName: msg['user_name'] ?? 'Unknown',
                  text: msg['message_text'] ?? '',
                  isMe: isMe,
                  time: msg['created_at'] != null 
                    ? DateTime.parse(msg['created_at']).toLocal().toString().substring(11, 16)
                    : '',
                );
              },
            ),
          ),
          if (controller.isChatLocked && !controller.isTeacher)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("الدردشة مقفلة من قبل المدرس", style: TextStyle(color: Colors.red, fontSize: 12)),
            )
          else
            _buildInput(controller),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("الدردشة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: controller.toggleChat,
          ),
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
                hintText: "اكتب رسالة...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
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
      controller.sendMessage(_controller.text.trim());
      _controller.clear();
      _scrollToBottom();
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final String userName;
  final String text;
  final bool isMe;
  final String time;

  const _MessageBubble({
    required this.userName,
    required this.text,
    required this.isMe,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(userName, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(15),
                  topRight: const Radius.circular(15),
                  bottomLeft: Radius.circular(isMe ? 15 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(time, style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
