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

    // --- لوجيك "التقريب الذكي" (Proximity Sorting) ---
    // نقوم بترتيب المشاركين بحيث يظهر الأهم للمدرس في الأعلى:
    // 1. من يرفع يده حالياً.
    // 2. من لديه سؤال لم يُجب عليه.
    // 3. الترتيب الأبجدي.
    if (participants.isNotEmpty) {
      participants.sort((a, b) {
        bool handA = controller.remoteHandStates[a.identity] ?? false;
        bool handB = controller.remoteHandStates[b.identity] ?? false;
        if (handA && !handB) return -1;
        if (!handA && handB) return 1;

        bool hasQuestionA = controller.questions.any((q) => q['senderId'] == a.identity && !(q['is_answered'] ?? false));
        bool hasQuestionB = controller.questions.any((q) => q['senderId'] == b.identity && !(q['is_answered'] ?? false));
        if (hasQuestionA && !hasQuestionB) return -1;
        if (!hasQuestionA && hasQuestionB) return 1;

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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.people_outline, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("الحضور", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Cairo')),
              Text("$count مشارك نشط الآن", style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
            ],
          ),
          const Spacer(),
          IconButton(onPressed: controller.toggleParticipants, icon: const Icon(Icons.close_rounded, color: Colors.grey)),
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
                    icon: Icons.grid_view_rounded,
                    color: Colors.blue,
                    onTap: () => _showBreakoutDialog(context, controller),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: "تقرير الغياب",
                    icon: Icons.picture_as_pdf_rounded,
                    color: Colors.red.shade600,
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
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
    final bool hasPendingQuestion = controller.questions.any((q) => q['senderId'] == participant.identity && !(q['is_answered'] ?? false));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.withOpacity(0.05) : (handRaised ? Colors.orange.withOpacity(0.03) : Colors.transparent),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isMe ? Colors.blue.shade100 : (handRaised ? Colors.orange.shade100 : Colors.transparent)),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: isMe ? Colors.blue : Colors.grey.shade100,
              child: Text((participant.name.isNotEmpty ? participant.name[0] : "?").toUpperCase(), 
                   style: TextStyle(color: isMe ? Colors.white : Colors.blue.shade900, fontWeight: FontWeight.bold)),
            ),
            if (isSpotlight)
              Positioned(right: 0, bottom: 0, child: Icon(Icons.star, size: 14, color: Colors.amber.shade700)),
          ],
        ),
        title: Text(
          isMe ? "أنت (أنا)" : (participant.name.isNotEmpty ? participant.name : "طالب"),
          style: TextStyle(fontWeight: isMe || handRaised ? FontWeight.bold : FontWeight.normal, fontFamily: 'Cairo', fontSize: 14),
        ),
        subtitle: Row(
          children: [
            if (handRaised) _buildMiniBadge("يرفع يده ✋", Colors.orange),
            if (hasPendingQuestion) ...[
              if (handRaised) const SizedBox(width: 4),
              _buildMiniBadge("لديه سؤال ❓", Colors.blue),
            ]
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off, 
                 color: participant.isMicrophoneEnabled() ? Colors.green : Colors.red, size: 18),
            if (controller.isTeacher && !isMe) _buildTeacherMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    );
  }

  Widget _buildTeacherMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.grey),
      onSelected: (val) {
        if (val == 'mute') controller.muteParticipant(participant.identity, participant.isMicrophoneEnabled());
        if (val == 'kick') controller.kickParticipant(participant.identity);
        if (val == 'spotlight') controller.setSpotlight(controller.spotlightUserId == participant.identity ? null : participant.identity);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'mute', child: Text(participant.isMicrophoneEnabled() ? "كتم الصوت" : "تفعيل الصوت", style: const TextStyle(fontFamily: 'Cairo'))),
        PopupMenuItem(value: 'spotlight', child: Text(controller.spotlightUserId == participant.identity ? "إلغاء التمييز" : "تمييز المشارك", style: const TextStyle(fontFamily: 'Cairo'))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'kick', child: Text("استبعاد", style: TextStyle(color: Colors.red, fontFamily: 'Cairo'))),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
        child: Column(
          children: [
            if (isLoading) const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.shade100)),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(child: Text("غرف التقسيم مفعلة (${controller.breakoutTimeLeft ~/ 60} د)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Cairo'))),
          TextButton(onPressed: controller.endBreakoutRooms, child: const Text("إنهاء", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
