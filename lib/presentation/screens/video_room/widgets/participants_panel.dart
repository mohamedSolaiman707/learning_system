import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class ParticipantsPanel extends StatelessWidget {
  const ParticipantsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final participants = controller.room?.remoteParticipants.values.toList() ?? [];
    final localParticipant = controller.room?.localParticipant;

    if (participants.isNotEmpty) {
      participants.sort((a, b) {
        bool handA = controller.remoteHandStates[a.identity] ?? false;
        bool handB = controller.remoteHandStates[b.identity] ?? false;
        if (handA && !handB) return -1;
        if (!handA && handB) return 1;
        return (a.name ?? "").compareTo(b.name ?? "");
      });
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildHeader(controller, participants.length + (localParticipant != null ? 1 : 0)),
          
          if (controller.isTeacher) _buildGlobalControls(controller),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (localParticipant != null)
                  _ParticipantTile(participant: localParticipant, controller: controller, isMe: true),
                const Divider(height: 32),
                ...participants.map((p) => _ParticipantTile(participant: p, controller: controller)),
              ],
            ),
          ),
          if (controller.isTeacher) _buildTeacherActions(context, controller),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoRoomController controller, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          IconButton(onPressed: controller.toggleParticipants, icon: const Icon(Icons.close_rounded, color: Colors.black)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("المشاركين", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Cairo')),
              Text("$count مشارك في القاعة", style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalControls(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildQuickToggle(
            label: "كتم الجميع",
            icon: Icons.mic_off,
            color: Colors.green,
            isActive: controller.isAllMuted,
            onTap: () => controller.muteAllParticipants(!controller.isAllMuted),
          ),
          _buildQuickToggle(
            label: "كاميرا الجميع",
            icon: Icons.videocam_off,
            color: Colors.green,
            isActive: controller.isCamLocked,
            onTap: () => controller.disableAllCameras(!controller.isCamLocked),
          ),
          _buildQuickToggle(
            label: "قفل الشات",
            icon: Icons.chat_bubble_outline,
            color: Colors.green,
            isActive: controller.isChatLocked,
            onTap: controller.toggleChatLock,
          ),
          _buildQuickToggle(
            label: "قفل السبورة",
            icon: Icons.edit_note,
            color: Colors.green,
            isActive: controller.isWhiteboardLocked,
            onTap: controller.toggleWhiteboardLock,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickToggle({required String label, required IconData icon, required Color color, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive ? Colors.red.withOpacity(0.1) : color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? Colors.red : color, size: 24),
          ),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildTeacherActions(BuildContext context, VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Column(
        children: [
          if (controller.isBreakoutActive)
            _BreakoutStatus(controller: controller)
          else
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: "غرف التقسيم",
                    icon: Icons.group_work_rounded,
                    color: const Color(0xFF102A43),
                    onTap: () => _showBreakoutDialog(context, controller),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: "تنزيل الغياب",
                    icon: Icons.picture_as_pdf_rounded,
                    color: Colors.red.shade700,
                    isLoading: controller.isProcessing,
                    onTap: () => controller.downloadAttendanceReport(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _showBreakoutDialog(BuildContext context, VideoRoomController controller) {
    int groupCount = 2;
    double duration = 10;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDS) => Container(
          padding: const EdgeInsets.all(30),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("إعداد مجموعات العمل", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'Cairo')),
              const SizedBox(height: 20),
              _buildSettingRow("عدد المجموعات", "$groupCount", () => groupCount > 2 ? setDS(() => groupCount--) : null, () => groupCount < 8 ? setDS(() => groupCount++) : null),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("المدة الزمنية", style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  Text("${duration.toInt()} دقيقة", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                ],
              ),
              Slider(value: duration, min: 5, max: 30, divisions: 5, activeColor: Colors.blue, onChanged: (v) => setDS(() => duration = v)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF102A43), minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () { controller.startBreakoutRooms(groupCount, duration.toInt()); Navigator.pop(context); },
                child: const Text("بدء الجلسات الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingRow(String title, String val, VoidCallback onRemove, VoidCallback onAdd) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        Row(children: [
          IconButton(onPressed: onRemove, icon: const Icon(Icons.remove_circle_outline, color: Colors.blue)),
          Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline, color: Colors.blue)),
        ]),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final VideoRoomController controller;
  final bool isMe;

  const _ParticipantTile({required this.participant, required this.controller, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    final bool handRaised = controller.remoteHandStates[participant.identity] ?? false;
    final bool isSpotlight = controller.spotlightUserId == participant.identity;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (controller.isTeacher && !isMe) _buildTeacherMenu(context),
          if (participant.isMicrophoneEnabled() == false) 
             const Icon(Icons.mic_off, color: Colors.red, size: 16),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isMe ? "أ. ${controller.userName}" : (participant.name.isNotEmpty ? participant.name : "طالب"),
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
              ),
              if (isMe) const Text("أنت", style: TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'Cairo')),
              if (handRaised) const Text("يرفع يده ✋", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
            ],
          ),
          const SizedBox(width: 15),
          Stack(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: isMe ? const Color(0xFF102A43) : Colors.grey.shade200,
                child: Text(
                  (participant.identity.contains("teacher") ? "أ" : (participant.name.isNotEmpty ? participant.name[0] : "س")).toUpperCase(), 
                   style: TextStyle(color: isMe ? Colors.white : Colors.black, fontWeight: FontWeight.bold)
                ),
              ),
              if (isSpotlight)
                Positioned(right: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.star, size: 14, color: Colors.amber.shade700))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (val) {
        if (val == 'mute') controller.muteParticipant(participant.identity, participant.isMicrophoneEnabled());
        if (val == 'cam') controller.disableParticipantCamera(participant.identity, participant.isCameraEnabled());
        if (val == 'kick') controller.kickParticipant(participant.identity);
        if (val == 'spotlight') controller.setSpotlight(controller.spotlightUserId == participant.identity ? null : participant.identity);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'mute', 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(participant.isMicrophoneEnabled() ? "كتم الصوت" : "تفعيل الصوت", style: const TextStyle(fontFamily: 'Cairo')),
              const SizedBox(width: 10),
              const Icon(Icons.mic, size: 18),
            ],
          )
        ),
        PopupMenuItem(
          value: 'cam', 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(participant.isCameraEnabled() ? "تعطيل الكاميرا" : "تفعيل الكاميرا", style: const TextStyle(fontFamily: 'Cairo')),
              const SizedBox(width: 10),
              const Icon(Icons.videocam, size: 18),
            ],
          )
        ),
        PopupMenuItem(
          value: 'spotlight', 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(controller.spotlightUserId == participant.identity ? "إلغاء التمييز" : "تمييز المشارك", style: const TextStyle(fontFamily: 'Cairo')),
              const SizedBox(width: 10),
              const Icon(Icons.star_outline, size: 18),
            ],
          )
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'kick', 
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("طرد من القاعة", style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
              const SizedBox(width: 10),
              const Icon(Icons.gavel_rounded, color: Colors.red, size: 18),
            ],
          )
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon, required this.color, this.isLoading = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color, 
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ],
        ),
      ),
    );
  }
}

class _BreakoutStatus extends StatelessWidget {
  final VideoRoomController controller;
  const _BreakoutStatus({required this.controller});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.shade100)),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text("غرف التقسيم مفعلة (${controller.breakoutTimeLeft ~/ 60} د)", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: controller.endBreakoutRooms, 
            child: const Text("إنهاء", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))
          ),
        ],
      ),
    );
  }
}
