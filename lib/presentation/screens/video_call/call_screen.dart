import 'package:flutter/material.dart';
import '../../../core/utils/responsive.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomName;
  final String subject;
  final bool isTeacher;

  const VideoCallScreen({
    super.key,
    required this.roomName,
    required this.subject,
    this.isTeacher = true, // افتراضياً معلم لأغراض العرض، يمكن تغييرها عند الاستدعاء
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMicOn = true;
  bool _isCameraOn = true;
  bool _isChatOpen = false;

  // حالات التحكم الجماعي (للمعلم)
  bool _isAllMuted = false;
  bool _isAllVideoOff = false;
  bool _isChatLocked = false;
  bool _isWhiteboardLocked = false;

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2124),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("إعدادات وتحكم القاعة", 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isTeacher) ...[
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text("تحكم المعلم (للجميع)", 
                      style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  ),
                  const SizedBox(height: 10),
                  _buildDialogToggle("كتم صوت الجميع", _isAllMuted, (val) {
                    setDialogState(() => _isAllMuted = val);
                    setState(() => _isAllMuted = val);
                    // هنا يتم استدعاء اللوجيك البرمجي لإرسال الأمر للسيرفر
                  }),
                  _buildDialogToggle("إيقاف كاميرات الجميع", _isAllVideoOff, (val) {
                    setDialogState(() => _isAllVideoOff = val);
                    setState(() => _isAllVideoOff = val);
                  }),
                  _buildDialogToggle("قفل الدردشة", _isChatLocked, (val) {
                    setDialogState(() => _isChatLocked = val);
                    setState(() => _isChatLocked = val);
                  }),
                  _buildDialogToggle("قفل السبورة", _isWhiteboardLocked, (val) {
                    setDialogState(() => _isWhiteboardLocked = val);
                    setState(() => _isWhiteboardLocked = val);
                  }),
                  const Divider(color: Colors.white10),
                ],
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.blue),
                  title: const Text("معلومات الغرفة", style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Cairo')),
                  subtitle: Text(widget.roomName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh, color: Colors.blue),
                  title: const Text("تحديث الاتصال", style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Cairo')),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogToggle(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Cairo')),
      value: value,
      activeColor: Colors.blue,
      contentPadding: EdgeInsets.zero,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101214),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.subject, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              Text("غرفة: ${widget.roomName}", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.person, color: Colors.white70, size: 20),
          const SizedBox(width: 5),
          const Text("12 مشارك", style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 15),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              flex: 8,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(15, 5, 15, 10),
                child: _buildParticipantCard(true, isMain: true),
              ),
            ),
            SizedBox(
              height: constraints.maxHeight * 0.16,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 15),
                itemCount: 8,
                itemBuilder: (context, index) => Container(
                  width: (constraints.maxHeight * 0.16) * 1.5,
                  margin: const EdgeInsets.only(left: 10, bottom: 8),
                  child: _buildParticipantCard(false, studentIndex: index),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParticipantCard(bool isTeacher, {bool isMain = false, int? studentIndex}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2F33),
        borderRadius: BorderRadius.circular(12),
        border: isTeacher ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5) : null,
        boxShadow: isMain ? [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 15, spreadRadius: 2)
        ] : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: const Color(0xFF1A1C1E),
            child: Center(
              child: Opacity(
                opacity: 0.1,
                child: Icon(isTeacher ? Icons.person : Icons.school, size: isMain ? 100 : 40, color: Colors.white),
              ),
            ),
          ),
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
                isTeacher ? "أ. محمد علي" : "طالب ${studentIndex ?? 0}",
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
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
                Icon(Icons.chat_outlined, color: Colors.blue, size: 20),
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
              enabled: !_isChatLocked || widget.isTeacher,
              decoration: InputDecoration(
                hintText: _isChatLocked && !widget.isTeacher ? "الدردشة مقفلة" : "اكتب رسالتك...",
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
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildControlButton(
            onTap: () => setState(() => _isMicOn = !_isMicOn),
            icon: _isMicOn ? Icons.mic : Icons.mic_off,
            color: _isMicOn ? Colors.white.withOpacity(0.1) : Colors.red.withOpacity(0.8),
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () => setState(() => _isCameraOn = !_isCameraOn),
            icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
            color: _isCameraOn ? Colors.white.withOpacity(0.1) : Colors.red.withOpacity(0.8),
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () {},
            icon: Icons.screen_share,
            color: Colors.white.withOpacity(0.1),
            label: "مشاركة",
          ),
          const SizedBox(width: 15),
          _buildControlButton(
            onTap: () => setState(() => _isChatOpen = !_isChatOpen),
            icon: _isChatOpen ? Icons.chat : Icons.chat_outlined,
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
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0, 2))
              ],
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
