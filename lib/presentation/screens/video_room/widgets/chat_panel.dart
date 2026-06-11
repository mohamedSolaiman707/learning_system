import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  Map<String, dynamic>? _replyingTo;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.select<VideoRoomController, ({
      List<Map<String, dynamic>> messages,
      bool isChatLocked,
      bool isTeacher,
      String userName,
    })>((c) => (
      messages: c.messages,
      isChatLocked: c.isChatLocked,
      isTeacher: c.isTeacher,
      userName: c.userName,
    ));
    final controller = context.read<VideoRoomController>();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          _buildHeader(context, controller),
          Expanded(
            child: data.messages.isEmpty 
              ? const Center(child: Text("لا توجد رسائل بعد", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  key: const PageStorageKey('chat_list'),
                  reverse: true, 
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: data.messages.length,
                  itemBuilder: (context, index) {
                    final msg = data.messages[index];
                    final isMe = msg['user_name'] == data.userName;
                    
                    return _MessageBubble(
                      key: ValueKey(msg['created_at'] ?? index),
                      userName: msg['user_name'] ?? 'مشارك',
                      text: msg['content'] ?? '',
                      isMe: isMe,
                      time: _formatTime(msg['created_at']),
                      replyTo: msg['reply_to'],
                      onReply: (m) => setState(() => _replyingTo = m),
                    );
                  },
                ),
          ),
          if (data.isChatLocked && !data.isTeacher)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text("الدردشة مقفلة من قبل المدرس", style: TextStyle(color: Colors.red, fontSize: 12)),
            )
          else
            Column(
              children: [
                if (_replyingTo != null) _buildReplyPreview(),
                _buildInput(controller),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: const Border(left: BorderSide(color: Colors.blue, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "رداً على: ${_replyingTo!['user_name']}",
                  style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  _replyingTo!['content'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt.toString()).toLocal();
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return '';
    }
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
      controller.sendMessage(_controller.text.trim(), replyTo: _replyingTo);
      _controller.clear();
      setState(() => _replyingTo = null);
      _scrollToBottom();
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final String userName;
  final String text;
  final bool isMe;
  final String time;
  final Map<String, dynamic>? replyTo;
  final Function(Map<String, dynamic>)? onReply;

  const _MessageBubble({
    super.key,
    required this.userName,
    required this.text,
    required this.isMe,
    required this.time,
    this.replyTo,
    this.onReply,
  });

  Widget _buildCopyIcon(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "تم نسخ الرسالة ✅",
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          ),
        );
      },
      child: const Icon(
        Icons.copy_rounded,
        size: 14,
        color: Colors.grey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "تم نسخ الرسالة ✅",
              style: TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          ),
        );
      },
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 300) {
            onReply?.call({
              'user_name': userName,
              'content': text,
            });
          }
        },
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
            margin: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isMe) ...[
                  _buildCopyIcon(context),
                  const SizedBox(width: 4),
                ],
                Flexible(
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (replyTo != null) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue.shade700 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                  border: const Border(left: BorderSide(color: Colors.blue, width: 3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      replyTo!['user_name'],
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isMe ? Colors.white70 : Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      replyTo!['content'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isMe ? Colors.white60 : Colors.black45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Text(text, style: TextStyle(color: isMe ? Colors.white : Colors.black, fontSize: 14)),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(time, style: TextStyle(fontSize: 8, color: isMe ? Colors.white70 : Colors.black54)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMe) ...[
                  const SizedBox(width: 4),
                  _buildCopyIcon(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
