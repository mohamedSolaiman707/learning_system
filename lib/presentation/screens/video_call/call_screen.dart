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
      backgroundColor: const Color(0xFF101214), // لون خلفية أغمق وأكثر احترافية
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildMainContent(),
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
              color: Colors.red.withOpacity(0.9),
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
              Text(widget.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("غرفة: ${widget.roomName}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
          const Spacer(),
          const Icon(IconlyLight.user_1, color: Colors.white70, size: 20),
          const SizedBox(width: 5),
          const Text("12 مشارك", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 15),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // في حالة الشاشات الكبيرة، نضع المعلم في المنتصف بشكل بارز
        return Column(
          children: [
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: _buildParticipantCard(true, isMain: true),
              ),
            ),
            const SizedBox(height: 10),
            // شريط صغير للمشاركين الآخرين (الطلاب)
            SizedBox(
              height: constraints.maxHeight * 0.18,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: 8,
                itemBuilder: (context, index) => Container(
                  width: (constraints.maxHeight * 0.18) * 1.5,
                  margin: const EdgeInsets.only(left: 10, bottom: 5),
                  child: _buildParticipantCard(false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticipantCard(bool isTeacher, {bool isMain = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
        border: isTeacher ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5) : null,
        boxShadow: isMain ? [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, spreadRadius: 2)
        ] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // خلفية محاكاة للفيديو
          Container(
            color: const Color(0xFF1A1C1E),
            child: Center(
              child: Opacity(
                opacity: 0.1,
                child: Icon(isTeacher ? Icons.person : Icons.school, size: isMain ? 100 : 40, color: Colors.white),
              ),
            ),
          ),
          
          // علامة المعلم في الزاوية العلوية (كما في الصورة)
          if (isTeacher)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("المعلم", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    SizedBox(width: 4),
                    Icon(Icons.star, color: Colors.white, size: 10),
                  ],
                ),
              ),
            ),

          // اسم المشارك في الأسفل
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isTeacher ? "أ. محمد علي" : "طالب ${DateTime.now().millisecond % 100}",
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
          
          // أيقونة المايك إذا كان مغلقاً
          if (isTeacher && !_isMicOn)
            const Positioned(
              top: 12,
              left: 12,
              child: CircleAvatar(
                backgroundColor: Colors.red,
                radius: 14,
                child: Icon(Icons.mic_off, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideChat() {
    return Container(
      width: 320,
      margin: const EdgeInsets.only(left: 15, top: 0, bottom: 20, right: 15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2124),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(IconlyLight.chat, color: Colors.blue, size: 20),
                SizedBox(width: 10),
                Text("الدردشة العامة", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          const Expanded(child: Center(child: Text("مرحباً بك في الدردشة", style: TextStyle(color: Colors.grey, fontSize: 13)))),
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: "اكتب رسالتك...",
                hintStyle: const TextStyle(color: Colors.grey),
                fillColor: Colors.white.withOpacity(0.05),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            onTap: () => setState(() => _isMicOn = !_isMicOn),
            icon: _isMicOn ? IconlyBold.voice : Icons.mic_off,
            color: _isMicOn ? Colors.white.withOpacity(0.1) : Colors.red.withOpacity(0.8),
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () => setState(() => _isCameraOn = !_isCameraOn),
            icon: _isCameraOn ? IconlyBold.video : Icons.videocam_off,
            color: _isCameraOn ? Colors.white.withOpacity(0.1) : Colors.red.withOpacity(0.8),
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () {},
            icon: IconlyBold.discovery,
            color: Colors.white.withOpacity(0.1),
            label: "مشاركة",
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () => setState(() => _isChatOpen = !_isChatOpen),
            icon: IconlyBold.chat,
            color: _isChatOpen ? Colors.blue : Colors.white.withOpacity(0.1),
          ),
          const SizedBox(width: 40),
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
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: isEndCall ? 60 : 50,
            height: isEndCall ? 60 : 50,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: isEndCall ? 30 : 22),
          ),
        ),
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ),
      ],
    );
  }
}
