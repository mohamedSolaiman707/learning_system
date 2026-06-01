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

    // جلب وترتيب المشاركين (المتحدثون ورافعو الأيدي أولاً)
    final List<Participant> allParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    var filteredParticipants = allParticipants.where((p) {
      final name = (p.name ?? p.identity).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    filteredParticipants.sort((a, b) {
      final aHand = controller.remoteHandStates[a.identity] ?? false;
      final bHand = controller.remoteHandStates[b.identity] ?? false;
      if (aHand && !bHand) return -1;
      if (!aHand && bHand) return 1;
      if (a.isSpeaking && !b.isSpeaking) return -1;
      return 0;
    });

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(35), topRight: Radius.circular(35)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Column(
        children: [
          _buildHeader(controller, allParticipants.length),
          _buildSearchField(),
          if (controller.isTeacher) _buildGlobalPermissions(controller),
          
          Expanded(
            child: filteredParticipants.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredParticipants.length,
                    itemBuilder: (context, index) => _ParticipantTile(
                      participant: filteredParticipants[index], 
                      controller: controller
                    ),
                  ),
          ),
          
          if (controller.isTeacher) _buildTeacherQuickActions(controller, context),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا يوجد نتائج للبحث", style: TextStyle(color: Colors.grey)),
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
          Text("المشاركون ($count)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 18, color: Colors.grey),
            ),
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
          hintText: "بحث عن طالب...",
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildGlobalPermissions(VideoRoomController controller) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _PermissionToggle(icon: Icons.chat_bubble_outline_rounded, label: "الدردشة", isLocked: controller.isChatLocked, onTap: controller.toggleChatLock),
          _PermissionToggle(icon: Icons.edit_note_rounded, label: "السبورة", isLocked: controller.isWhiteboardLocked, onTap: controller.toggleWhiteboardLock),
          _PermissionToggle(icon: Icons.screen_share_outlined, label: "المشاركة", isLocked: controller.isScreenShareLocked, onTap: controller.toggleScreenShareLock),
        ],
      ),
    );
  }

  Widget _buildTeacherQuickActions(VideoRoomController controller, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _ActionButton(
                label: controller.isAllMuted ? "فتح الصوت" : "كتم الكل", 
                icon: controller.isAllMuted ? Icons.mic_rounded : Icons.mic_off_rounded, 
                color: controller.isAllMuted ? Colors.green : Colors.red, 
                onTap: () => controller.muteAllParticipants(!controller.isAllMuted)
              )),
              const SizedBox(width: 12),
              Expanded(child: _ActionButton(
                label: "إنزال الأيدي", 
                icon: Icons.front_hand_rounded, 
                color: Colors.orange, 
                onTap: controller.lowerAllHands
              )),
            ],
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: controller.isBreakoutActive ? "إنهاء المجموعات" : "بدء تقسيم المجموعات (Breakout)",
            icon: Icons.grid_view_rounded,
            color: const Color(0xFF102A43),
            isFullWidth: true,
            onTap: () => controller.isBreakoutActive ? controller.endBreakoutRooms() : _showBreakoutSettings(context, controller),
          ),
        ],
      ),
    );
  }

  void _showBreakoutSettings(BuildContext context, VideoRoomController controller) {
    int groupCount = 2;
    double duration = 10;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDS) => Container(
          padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const Text("إعدادات غرف التقسيم", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF102A43))),
              const SizedBox(height: 12),
              const Text("قم بتوزيع الطلاب لمجموعات صغيرة لتعزيز التفاعل الجماعي.", style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 32),
              const Text("عدد المجموعات", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _countBtn(Icons.remove, () => groupCount > 2 ? setDS(() => groupCount--) : null),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text("$groupCount", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold))),
                  _countBtn(Icons.add, () => groupCount < 8 ? setDS(() => groupCount++) : null),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("مدة النقاش", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("${duration.toInt()} دقيقة", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: duration, min: 5, max: 30, divisions: 5,
                activeColor: const Color(0xFF102A43),
                onChanged: (v) => setDS(() => duration = v),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF102A43),
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: () {
                  controller.startBreakoutRooms(groupCount, duration.toInt());
                  Navigator.pop(context);
                },
                child: const Text("بدء التقسيم العشوائي الآن", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF102A43)),
      ),
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLocked;
  final VoidCallback onTap;
  const _PermissionToggle({required this.icon, required this.label, required this.isLocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isLocked ? Colors.red : Colors.green).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isLocked ? Colors.red : Colors.green, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;
  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap, this.isFullWidth = false});

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
        minimumSize: Size(isFullWidth ? double.infinity : 0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final bool isSpotlight = controller.spotlightUserId == participant.identity;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildAvatar(isSpeaking, isSpotlight, handRaised, isMe),
      title: Row(
        children: [
          Expanded(child: Text(participant.name ?? participant.identity, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.w600, fontSize: 15))),
          _buildSignalIcon(participant.connectionQuality),
        ],
      ),
      subtitle: Text(isMe ? "أنت" : (controller.isTeacher ? "طالب" : ""), style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCamOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, size: 18, color: isCamOn ? Colors.blue : Colors.grey.shade300),
          const SizedBox(width: 8),
          Icon(isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded, size: 18, color: isMicOn ? Colors.green : Colors.red),
          if (controller.isTeacher && !isMe) ...[
            const SizedBox(width: 4),
            _buildActionMenu(context),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isSpeaking, bool isSpotlight, bool handRaised, bool isMe) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: isSpotlight ? Colors.purple : (isSpeaking ? Colors.green : Colors.transparent), width: 2),
          ),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: isMe ? const Color(0xFF102A43) : Colors.grey.shade200,
            child: Text(participant.name?[0].toUpperCase() ?? "?", style: TextStyle(color: isMe ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
          ),
        ),
        if (handRaised)
          const Positioned(right: -4, top: -4, child: CircleAvatar(radius: 8, backgroundColor: Colors.orange, child: Icon(Icons.front_hand, color: Colors.white, size: 10))),
        if (isSpotlight)
          const Positioned(left: -4, bottom: -4, child: Icon(Icons.star_rounded, color: Colors.purple, size: 16)),
      ],
    );
  }

  Widget _buildSignalIcon(ConnectionQuality quality) {
    Color color = Colors.green;
    if (quality == ConnectionQuality.poor) color = Colors.orange;
    else if (quality == ConnectionQuality.lost) color = Colors.red;
    return Icon(Icons.signal_cellular_alt_rounded, size: 12, color: color);
  }

  Widget _buildActionMenu(BuildContext context) {
    final bool isMicOn = participant.isMicrophoneEnabled();
    final bool handRaised = controller.remoteHandStates[participant.identity] ?? false;
    final bool isSpotlight = controller.spotlightUserId == participant.identity;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (v) {
        if (v == 'mute') controller.muteParticipant(participant.identity, isMicOn);
        if (v == 'kick') controller.kickParticipant(participant.identity);
        if (v == 'spotlight') controller.setSpotlight(isSpotlight ? null : participant.identity);
        if (v == 'lower' && handRaised) controller.lowerParticipantHand(participant.identity);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'spotlight', child: Row(children: [Icon(isSpotlight ? Icons.star_outline_rounded : Icons.star_rounded, size: 18), const SizedBox(width: 8), Text(isSpotlight ? "إلغاء التمييز" : "تمييز الطالب")])),
        PopupMenuItem(value: 'mute', child: Row(children: [Icon(isMicOn ? Icons.mic_off_rounded : Icons.mic_rounded, size: 18), const SizedBox(width: 8), Text(isMicOn ? "كتم الصوت" : "تفعيل الصوت")])),
        if (handRaised) const PopupMenuItem(value: 'lower', child: Row(children: [Icon(Icons.front_hand_rounded, size: 18), const SizedBox(width: 8), Text("إنزال اليد")])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'kick', child: Row(children: [Icon(Icons.person_remove_rounded, color: Colors.red, size: 18), const SizedBox(width: 8), const Text("طرد من القاعة", style: TextStyle(color: Colors.red))])),
      ],
    );
  }
}
