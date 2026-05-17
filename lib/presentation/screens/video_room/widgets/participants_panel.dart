import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import '../video_room_controller.dart';

class ParticipantsPanel extends StatefulWidget {
  const ParticipantsPanel({super.key});

  @override
  State<ParticipantsPanel> createState() => _ParticipantsPanelState();
}

class _ParticipantsPanelState extends State<ParticipantsPanel> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();
    final room = controller.room;
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    if (room == null) return const SizedBox.shrink();

    final List<Participant> allParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    final filteredParticipants = allParticipants.where((p) {
      final name = (p.name ?? p.identity).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filteredParticipants.sort((a, b) {
      bool isATeacher = (a is LocalParticipant && controller.isTeacher);
      bool isBTeacher = (b is LocalParticipant && controller.isTeacher);
      if (isATeacher && !isBTeacher) return -1;
      if (!isATeacher && isBTeacher) return 1;
      if (a.isSpeaking && !b.isSpeaking) return -1;
      if (!a.isSpeaking && b.isSpeaking) return 1;
      bool aHand = controller.remoteHandStates[a.identity] ?? false;
      bool bHand = controller.remoteHandStates[b.identity] ?? false;
      if (aHand && !bHand) return -1;
      if (!aHand && bHand) return 1;
      return (a.name ?? a.identity).compareTo(b.name ?? b.identity);
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile 
          ? const BorderRadius.vertical(top: Radius.circular(25)) 
          : const BorderRadius.only(topLeft: Radius.circular(25)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 15)],
      ),
      child: Column(
        children: [
          _buildHeader(controller, allParticipants.length),
          _buildSearchField(),
          Expanded(
            child: filteredParticipants.isEmpty
                ? const Center(child: Text("لا يوجد نتائج", style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredParticipants.length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                    itemBuilder: (context, index) {
                      final p = filteredParticipants[index];
                      return _ParticipantTile(participant: p, controller: controller);
                    },
                  ),
          ),
          if (controller.isTeacher) _buildTeacherDashboard(controller, room, context),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoRoomController controller, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.blue, size: 22),
          const SizedBox(width: 8),
          Text("المشاركون ($count)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: controller.toggleParticipants),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "بحث عن اسم الطالب...",
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildTeacherDashboard(VideoRoomController controller, Room room, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50.withOpacity(0.5),
        border: Border(top: BorderSide(color: Colors.blue.shade100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DashboardAction(
                  label: "كتم الجميع",
                  icon: Icons.mic_off,
                  color: Colors.red,
                  onTap: () {
                    for (var p in room.remoteParticipants.values) {
                      controller.muteParticipant(p.identity, true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DashboardAction(
                  label: "إنزال الأيدي",
                  icon: Icons.front_hand,
                  color: Colors.orange,
                  onTap: controller.lowerAllHands,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _DashboardAction(
                  label: controller.isChatLocked ? "فتح الدردشة" : "قفل الدردشة",
                  icon: controller.isChatLocked ? Icons.chat : Icons.speaker_notes_off,
                  color: Colors.blue,
                  onTap: controller.toggleChatLock,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DashboardAction(
                  label: controller.isBreakoutActive ? "إنهاء المجموعات" : "مجموعات عمل",
                  icon: controller.isBreakoutActive ? Icons.stop_circle_outlined : Icons.grid_view_rounded,
                  color: controller.isBreakoutActive ? Colors.red : Colors.purple,
                  onTap: () {
                    if (controller.isBreakoutActive) {
                      controller.endBreakoutRooms();
                    } else {
                      _showBreakoutDialog(context, controller);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBreakoutDialog(BuildContext context, VideoRoomController controller) {
    int count = 2;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("تقسيم الطلاب لمجموعات"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("اختر عدد المجموعات المطلوب إنشاءها:"),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: count > 2 ? () => setDialogState(() => count--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text("$count", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: count < 5 ? () => setDialogState(() => count++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              onPressed: () {
                controller.startBreakoutRooms(count);
                Navigator.pop(context);
              },
              child: const Text("تقسيم الآن"),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final VideoRoomController controller;

  const _ParticipantTile({required this.participant, required this.controller});

  @override
  Widget build(BuildContext context) {
    final bool isMe = participant is LocalParticipant;
    final bool isMicOn = participant.isMicrophoneEnabled();
    final bool isCamOn = participant.isCameraEnabled();
    final bool isSpeaking = participant.isSpeaking;
    final bool handRaised = controller.remoteHandStates[participant.identity] ?? false;
    final quality = participant.connectionQuality;

    // محاولة استخراج الاسم من name أو metadata الخاص بـ LiveKit
    String displayName = participant.name ?? participant.identity;
    if (displayName.isEmpty || displayName == "طالب") {
       displayName = participant.identity; // fallback to identity if name is generic
    }

    return ListTile(
      leading: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: isSpeaking ? Colors.green : Colors.transparent, width: 2),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: isMe ? Colors.blue.shade50 : Colors.grey.shade100,
              child: Text(
                displayName.isNotEmpty 
                    ? displayName.substring(0, 1).toUpperCase()
                    : "?",
                style: TextStyle(color: isMe ? Colors.blue : Colors.black87, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (handRaised)
            const Positioned(right: -2, bottom: -2, child: Icon(Icons.front_hand, color: Colors.orange, size: 18)),
        ],
      ),
      title: Row(
        children: [
          Expanded(child: Text(displayName, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis)),
          _buildQualityIcon(quality),
        ],
      ),
      subtitle: Text(isMe && controller.isTeacher ? "مدرس (أنت)" : (isMe ? "طالب (أنت)" : "طالب"), style: const TextStyle(fontSize: 11)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCamOn ? Icons.videocam : Icons.videocam_off, size: 18, color: isCamOn ? Colors.blue : Colors.grey),
          const SizedBox(width: 8),
          Icon(isMicOn ? Icons.mic : Icons.mic_off, size: 18, color: isMicOn ? Colors.green : Colors.red),
          if (controller.isTeacher && !isMe) ...[
            const SizedBox(width: 4),
            _buildActionMenu(context),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityIcon(ConnectionQuality quality) {
    IconData icon = Icons.signal_cellular_alt;
    Color color = Colors.green;
    if (quality == ConnectionQuality.poor) { icon = Icons.signal_cellular_connected_no_internet_4_bar; color = Colors.orange; }
    else if (quality == ConnectionQuality.lost) { icon = Icons.signal_cellular_off; color = Colors.red; }
    return Icon(icon, size: 14, color: color);
  }

  Widget _buildActionMenu(BuildContext context) {
    final bool isMicOn = participant.isMicrophoneEnabled();
    final bool isHandRaised = controller.remoteHandStates[participant.identity] ?? false;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (v) {
        if (v == 'mute') controller.muteParticipant(participant.identity, isMicOn);
        if (v == 'lower') controller.lowerParticipantHand(participant.identity);
        if (v == 'kick') controller.kickParticipant(participant.identity);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'mute', child: Row(children: [Icon(isMicOn ? Icons.mic_off : Icons.mic, size: 18), const SizedBox(width: 8), Text(isMicOn ? "كتم الصوت" : "تفعيل الصوت")])),
        if (isHandRaised)
          const PopupMenuItem(value: 'lower', child: Row(children: [Icon(Icons.front_hand, size: 18), const SizedBox(width: 8), Text("إنزال اليد")])),
        const PopupMenuItem(value: 'kick', child: Row(children: [Icon(Icons.person_remove, size: 18, color: Colors.red), const SizedBox(width: 8), Text("طرد المشارك", style: TextStyle(color: Colors.red))])),
      ],
    );
  }
}
