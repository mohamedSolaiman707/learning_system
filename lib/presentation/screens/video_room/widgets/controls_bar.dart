import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class ControlsBar extends StatelessWidget {
  const ControlsBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12, horizontal: 12),
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ControlButton(
                icon: controller.isMicEnabled ? Icons.mic : Icons.mic_off,
                color: controller.isMicEnabled ? Colors.white10 : Colors.redAccent,
                onPressed: controller.toggleMic,
              ),
              _ControlButton(
                icon: controller.isCamEnabled ? Icons.videocam : Icons.videocam_off,
                color: controller.isCamEnabled ? Colors.white10 : Colors.redAccent,
                onPressed: controller.toggleCam,
              ),
              
              // زر ردود الفعل (Reactions)
              _ReactionButton(controller: controller),

              if (controller.isTeacher)
                _ControlButton(
                  icon: controller.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                  onPressed: controller.toggleScreenShare,
                  color: controller.isScreenSharing ? Colors.blue.withValues(alpha: 0.3) : Colors.white10,
                  iconColor: controller.isScreenSharing ? Colors.blue : Colors.white,
                ),
                
              _ControlButton(
                icon: Icons.front_hand,
                onPressed: controller.toggleHand,
                color: controller.isHandRaised ? Colors.yellow.withValues(alpha: 0.3) : Colors.white10,
                iconColor: controller.isHandRaised ? Colors.yellow : Colors.white,
              ),
              _ControlButton(
                icon: Icons.chat_bubble_outline,
                onPressed: controller.toggleChat,
                color: controller.isChatOpen ? Colors.blue.withValues(alpha: 0.3) : Colors.white10,
                iconColor: controller.isChatOpen ? Colors.blue : Colors.white,
              ),
              _ControlButton(
                icon: Icons.question_answer_outlined,
                onPressed: controller.toggleQA,
                color: controller.isQAOpen ? Colors.orange.withValues(alpha: 0.3) : Colors.white10,
                iconColor: controller.isQAOpen ? Colors.orange : Colors.white,
              ),
              _ControlButton(
                icon: Icons.edit_note,
                onPressed: controller.toggleWhiteboard,
                color: controller.isWhiteboardOpen ? Colors.green.withValues(alpha: 0.3) : Colors.white10,
                iconColor: controller.isWhiteboardOpen ? Colors.green : Colors.white,
              ),
              if (controller.isTeacher)
                _ControlButton(
                  icon: Icons.people_outline,
                  onPressed: controller.toggleParticipants,
                  color: controller.isParticipantsOpen ? Colors.purple.withValues(alpha: 0.3) : Colors.white10,
                  iconColor: controller.isParticipantsOpen ? Colors.purple : Colors.white,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final VideoRoomController controller;
  const _ReactionButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: PopupMenuButton<String>(
        offset: const Offset(0, -250),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_reaction_outlined, color: Colors.white),
        onSelected: (emoji) => controller.sendReaction(emoji),
        itemBuilder: (context) => [
          _buildEmojiItem('👏'),
          _buildEmojiItem('👍'),
          _buildEmojiItem('❤️'),
          _buildEmojiItem('😂'),
          _buildEmojiItem('😮'),
          _buildEmojiItem('🎉'),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildEmojiItem(String emoji) {
    return PopupMenuItem(
      value: emoji,
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final Color iconColor;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white10,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: color,
        shape: const CircleBorder(),
        child: IconButton(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          icon: Icon(icon, color: iconColor, size: 22),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
