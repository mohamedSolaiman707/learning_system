import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import '../../../core/utils/responsive.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomName;
  final String subject;

  const VideoCallScreen({
    super.key, 
    required this.roomName, 
    required this.subject
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isChatOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildVideoGrid(),
                  ),
                  if (_isChatOpen && !Responsive.isMobile(context))
                    _buildSideChat(),
                ],
              ),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.white, size: 12),
                SizedBox(width: 5),
                Text("مباشر", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text("غرفة: ${widget.roomName}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(IconlyLight.user_1, color: Colors.white),
            onPressed: () {},
          ),
          const Text("12 مشارك", style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = Responsive.isDesktop(context) ? 3 : (Responsive.isTablet(context) ? 2 : 1);
        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemCount: 6, // محاكاة لعدد المشاركين
          itemBuilder: (context, index) => _buildParticipantCard(index == 0),
        );
      },
    );
  }

  Widget _buildParticipantCard(bool isMe) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(16),
        border: isMe ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Stack(
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isMe ? "أنت (المعلم)" : "طالب ${DateTime.now().millisecond}",
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          if (isMe && !_isMicOn)
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.mic_off, color: Colors.red, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildSideChat() {
    return Container(
      width: 300,
      margin: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(15),
            child: Text("الدردشة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const Divider(color: Colors.white10),
          const Expanded(child: Center(child: Text("لا توجد رسائل بعد", style: TextStyle(color: Colors.grey)))),
          Padding(
            padding: const EdgeInsets.all(10),
            child: TextField(
              decoration: InputDecoration(
                hintText: "اكتب رسالتك...",
                fillColor: Colors.white.withOpacity(0.05),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            onTap: () => setState(() => _isMicOn = !_isMicOn),
            icon: _isMicOn ? IconlyBold.voice : IconlyBold.voice_2,
            color: _isMicOn ? Colors.white24 : Colors.red,
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () => setState(() => _isCameraOn = !_isCameraOn),
            icon: _isCameraOn ? IconlyBold.video : Icons.videocam_off,
            color: _isCameraOn ? Colors.white24 : Colors.red,
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () {},
            icon: IconlyBold.discovery,
            color: Colors.white24,
            label: "مشاركة",
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () => setState(() => _isChatOpen = !_isChatOpen),
            icon: IconlyBold.chat,
            color: _isChatOpen ? Colors.blue : Colors.white24,
          ),
          const SizedBox(width: 30),
          _buildControlButton(
            onTap: () => Navigator.pop(context),
            icon: Icons.call_end,
            color: Colors.red,
            isEndCall: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    String? label,
    bool isEndCall = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(isEndCall ? 18 : 12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: isEndCall ? 30 : 24),
          ),
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
      ],
    );
  }
}
