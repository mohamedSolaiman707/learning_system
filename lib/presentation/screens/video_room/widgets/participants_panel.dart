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
    if (room == null) return const SizedBox.shrink();

    final List<Participant> allParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    var filteredParticipants = allParticipants.where((p) {
      final name = (p.name ?? p.identity).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        children: [
          _buildHeader(controller, allParticipants.length),

          if (controller.isTeacher && controller.isBreakoutActive)
            _buildBreakoutMonitoring(controller),

          if (!controller.isBreakoutActive || !controller.isTeacher) ...[
            _buildSearchField(),
            if (controller.isTeacher) _buildGlobalPermissions(controller),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: filteredParticipants.length,
                itemBuilder: (context, index) => _ParticipantTile(
                  participant: filteredParticipants[index],
                  controller: controller,
                ),
              ),
            ),
          ],

          if (controller.isTeacher)
            _buildTeacherQuickActions(controller, context),
        ],
      ),
    );
  }

  Widget _buildBreakoutMonitoring(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "مراقبة المجموعات النشطة",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF102A43),
                ),
              ),
              Text(
                "المتبقي: ${controller.breakoutTimeLeft ~/ 60}:${(controller.breakoutTimeLeft % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.breakoutGroups.length,
              itemBuilder: (context, index) {
                int groupNum = controller.breakoutGroups.keys.elementAt(index);
                List<String> students = controller.breakoutGroups[groupNum]!;
                bool isCurrentRoom =
                    controller.room?.name ==
                    "${controller.roomName}_group_$groupNum";

                return Container(
                  width: 160,
                  margin: const EdgeInsets.only(left: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentRoom
                        ? const Color(0xFF102A43)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isCurrentRoom
                          ? Colors.transparent
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "مجموعة $groupNum",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCurrentRoom ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView(
                          children: students
                              .map(
                                (s) => Text(
                                  "• $s",
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isCurrentRoom
                                        ? Colors.white70
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isCurrentRoom
                            ? null
                            : () => controller.joinBreakoutRoom(groupNum),
                        style: TextButton.styleFrom(
                          backgroundColor: isCurrentRoom
                              ? Colors.white24
                              : Colors.blue.withOpacity(0.1),
                          minimumSize: const Size(double.infinity, 30),
                        ),
                        child: Text(
                          isCurrentRoom ? "أنت هنا" : "انضمام",
                          style: TextStyle(
                            fontSize: 11,
                            color: isCurrentRoom ? Colors.white : Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoRoomController controller, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Color(0xFF102A43)),
          const SizedBox(width: 12),
          Text(
            "المشاركون ($count)",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: controller.toggleParticipants,
          ),
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
          hintText: "بحث...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalPermissions(VideoRoomController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PermissionToggle(
            icon: Icons.chat_outlined,
            label: "الدردشة",
            isLocked: controller.isChatLocked,
            onTap: controller.toggleChatLock,
          ),
          _PermissionToggle(
            icon: Icons.edit_outlined,
            label: "السبورة",
            isLocked: controller.isWhiteboardLocked,
            onTap: controller.toggleWhiteboardLock,
          ),
          _PermissionToggle(
            icon: Icons.screen_share_outlined,
            label: "المشاركة",
            isLocked: controller.isScreenShareLocked,
            onTap: controller.toggleScreenShareLock,
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherQuickActions(
    VideoRoomController controller,
    BuildContext context,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: "كتم الكل",
                  icon: Icons.mic_off,
                  color: Colors.red,
                  onTap: () => controller.muteAllParticipants(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: "إنزال الأيدي",
                  icon: Icons.front_hand,
                  color: Colors.orange,
                  onTap: controller.lowerAllHands,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: controller.isBreakoutActive
                ? "إنهاء المجموعات"
                : "تقسيم المجموعات (Breakout)",
            icon: Icons.grid_view_rounded,
            color: controller.isBreakoutActive
                ? Colors.red
                : const Color(0xFF102A43),
            isFullWidth: true,
            onTap: () {
              if (controller.isBreakoutActive) {
                controller.endBreakoutRooms();
              } else {
                _showBreakoutSettings(context, controller);
              }
            },
          ),
        ],
      ),
    );
  }

  void _showBreakoutSettings(
    BuildContext context,
    VideoRoomController controller,
  ) {
    int groupCount = 2;
    double duration = 10;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDS) => Container(
          padding: const EdgeInsets.all(32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "إعدادات غرف التقسيم",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF102A43),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "عدد المجموعات",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () =>
                        groupCount > 2 ? setDS(() => groupCount--) : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30),
                    child: Text(
                      "$groupCount",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        groupCount < 8 ? setDS(() => groupCount++) : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "المدة (دقيقة)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "${duration.toInt()} د",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Slider(
                value: duration,
                min: 5,
                max: 30,
                divisions: 5,
                activeColor: const Color(0xFF102A43),
                onChanged: (v) => setDS(() => duration = v),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102A43),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  controller.startBreakoutRooms(groupCount, duration.toInt());
                  Navigator.pop(context);
                },
                child: const Text(
                  "بدء التقسيم الآن",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLocked;
  final VoidCallback onTap;
  const _PermissionToggle({
    required this.icon,
    required this.label,
    required this.isLocked,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, color: isLocked ? Colors.red : Colors.green),
          onPressed: onTap,
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        minimumSize: Size(isFullWidth ? double.infinity : 0, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    final bool handRaised =
        controller.remoteHandStates[participant.identity] ?? false;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isMe ? const Color(0xFF102A43) : Colors.grey.shade200,
        child: Text(
          participant.name?[0] ?? "?",
          style: TextStyle(color: isMe ? Colors.white : Colors.black),
        ),
      ),
      title: Text(
        participant.name ?? participant.identity,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (handRaised)
            const Icon(Icons.front_hand, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Icon(
            participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
            color: participant.isMicrophoneEnabled()
                ? Colors.green
                : Colors.red,
            size: 18,
          ),
        ],
      ),
    );
  }
}
