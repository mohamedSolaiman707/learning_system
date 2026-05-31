import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:intl/intl.dart' as intl;
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
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (room == null) return const SizedBox.shrink();

    // جلب جميع المشاركين
    final List<Participant> allParticipants = [
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    // فلترة البحث
    var filteredParticipants = allParticipants.where((p) {
      final name = (p.name ?? p.identity).toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    // تطوير UX: ترتيب المشاركين (المتحدثون أولاً، ثم رافعو الأيدي، ثم البقية)
    filteredParticipants.sort((a, b) {
      final aHand = controller.remoteHandStates[a.identity] ?? false;
      final bHand = controller.remoteHandStates[b.identity] ?? false;
      if (aHand && !bHand) return -1;
      if (!aHand && bHand) return 1;
      if (a.isSpeaking && !b.isSpeaking) return -1;
      return 0;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile 
          ? const BorderRadius.vertical(top: Radius.circular(35)) 
          : const BorderRadius.only(topLeft: Radius.circular(35)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, spreadRadius: 5)],
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
                    itemBuilder: (context, index) {
                      final p = filteredParticipants[index];
                      return _ParticipantTile(participant: p, controller: controller);
                    },
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
          Icon(Icons.search_off_rounded, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("لا يوجد نتائج للبحث", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHeader(VideoRoomController controller, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade50))),
      child: Row(
        children: [
          const Icon(Icons.people_alt_rounded, color: Colors.blueAccent, size: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: "بحث عن اسم الطالب...",
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.blueAccent),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildGlobalPermissions(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.white]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("تحكم سريع بالصلاحيات", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PermissionItem(icon: Icons.chat_bubble_rounded, label: "الدردشة", isLocked: controller.isChatLocked, onTap: controller.toggleChatLock),
              _PermissionItem(icon: Icons.edit_document, label: "السبورة", isLocked: controller.isWhiteboardLocked, onTap: controller.toggleWhiteboardLock),
              _PermissionItem(icon: Icons.screen_share_rounded, label: "المشاركة", isLocked: controller.isScreenShareLocked, onTap: controller.toggleScreenShareLock),
            ],
          ),
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
              Expanded(
                child: _QuickActionButton(
                  label: controller.isAllMuted ? "فتح الصوت" : "كتم الكل",
                  icon: controller.isAllMuted ? Icons.mic_rounded : Icons.mic_off_rounded,
                  color: controller.isAllMuted ? Colors.green : Colors.redAccent,
                  onTap: () => controller.muteAllParticipants(!controller.isAllMuted),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionButton(
                  label: "إنزال الأيدي",
                  icon: Icons.front_hand_rounded,
                  color: Colors.amber.shade700,
                  onTap: controller.lowerAllHands,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _QuickActionButton(
            label: controller.isBreakoutActive ? "إنهاء مجموعات العمل" : "بدء مجموعات عمل (Breakout)",
            icon: controller.isBreakoutActive ? Icons.stop_circle_rounded : Icons.grid_view_rounded,
            color: controller.isBreakoutActive ? Colors.red : Colors.purple,
            isFullWidth: true,
            onTap: () {
              if (controller.isBreakoutActive) {
                controller.endBreakoutRooms();
              } else {
                _showBreakoutDialog(context, controller);
              }
            },
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
        builder: (context, setDS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text("تقسيم الفصل"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("اختر عدد المجموعات التي تريد توزيع الطلاب عليها عشوائياً:", style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _circleIconButton(Icons.remove, () => count > 2 ? setDS(() => count--) : null),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Text("$count", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.purple)),
                  ),
                  _circleIconButton(Icons.add, () => count < 6 ? setDS(() => count++) : null),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("إلغاء")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () { controller.startBreakoutRooms(count); Navigator.pop(context); },
              child: const Text("بدء التوزيع", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.purple, size: 20),
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isLocked;
  final VoidCallback onTap;

  const _PermissionItem({required this.icon, required this.label, required this.isLocked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isLocked ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: isLocked ? Colors.redAccent : Colors.green, width: 1.5),
            ),
            child: Icon(icon, color: isLocked ? Colors.redAccent : Colors.green, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isFullWidth;

  const _QuickActionButton({required this.label, required this.icon, required this.color, required this.onTap, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
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
    final bool isSpotlight = controller.spotlightUserId == participant.identity;
    
    // تطوير UX: نظام رفع اليد المتقدم
    final handData = controller.handRaiseQueue.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item!['identity'] == participant.identity,
      orElse: () => null,
    );
    final bool handRaised = handData != null;
    final int handPriority = handRaised ? controller.handRaiseQueue.indexOf(handData) + 1 : 0;
    final String timeWait = handRaised ? _getWaitTime(handData['time']) : "";

    String displayName = participant.name ?? participant.identity;
    if (displayName.length > 25) displayName = "${displayName.substring(0, 22)}...";

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _buildAvatar(displayName, isSpeaking, isSpotlight, handRaised, handPriority, isMe),
      title: Row(
        children: [
          Expanded(child: Text(displayName, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.w600, fontSize: 15))),
          _buildSignalIcon(participant.connectionQuality),
        ],
      ),
      subtitle: Row(
        children: [
          Text(isMe ? "أنت" : "طالب", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          if (handRaised && controller.isTeacher) ...[
            const SizedBox(width: 8),
            Text("• ينتظر منذ $timeWait", style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCamOn ? Icons.videocam_rounded : Icons.videocam_off_rounded, size: 20, color: isCamOn ? Colors.blue : Colors.grey.shade300),
          const SizedBox(width: 12),
          Icon(isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded, size: 20, color: isMicOn ? Colors.green : Colors.redAccent),
          if (controller.isTeacher && !isMe) ...[
            const SizedBox(width: 8),
            _buildActionMenu(context),
          ],
        ],
      ),
    );
  }

  String _getWaitTime(DateTime? time) {
    if (time == null) return "";
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes > 0) return "${diff.inMinutes} د";
    return "${diff.inSeconds} ث";
  }

  Widget _buildAvatar(String name, bool isSpeaking, bool isSpotlight, bool handRaised, int priority, bool isMe) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSpotlight ? Colors.purple : (isSpeaking ? Colors.green : Colors.transparent),
              width: 2.5,
            ),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: isMe ? Colors.blue.shade50 : Colors.grey.shade100,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?", style: TextStyle(color: isMe ? Colors.blue : Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ),
        if (handRaised)
          Positioned(
            right: -5, top: -5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.front_hand_rounded, color: Colors.white, size: 12),
                  if (priority > 0)
                    Text("$priority", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        if (isSpotlight)
          const Positioned(left: -2, bottom: -2, child: Icon(Icons.star_rounded, color: Colors.purple, size: 20)),
      ],
    );
  }

  Widget _buildSignalIcon(ConnectionQuality quality) {
    IconData icon = Icons.signal_cellular_alt_rounded;
    Color color = Colors.green;
    if (quality == ConnectionQuality.poor) { color = Colors.orange; }
    else if (quality == ConnectionQuality.lost) { icon = Icons.signal_cellular_connected_no_internet_0_bar_rounded; color = Colors.red; }
    return Tooltip(message: "جودة الاتصال", child: Icon(icon, size: 14, color: color));
  }

  Widget _buildActionMenu(BuildContext context) {
    final bool isMicOn = participant.isMicrophoneEnabled();
    final bool handRaised = controller.remoteHandStates[participant.identity] ?? false;
    final bool isSpotlight = controller.spotlightUserId == participant.identity;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded, size: 22, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (v) {
        if (v == 'mute') controller.muteParticipant(participant.identity, isMicOn);
        if (v == 'lower') controller.lowerParticipantHand(participant.identity);
        if (v == 'kick') controller.kickParticipant(participant.identity);
        if (v == 'spotlight') controller.setSpotlight(isSpotlight ? null : participant.identity);
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'spotlight', child: Row(children: [Icon(isSpotlight ? Icons.star_outline_rounded : Icons.star_rounded, color: Colors.purple, size: 20), const SizedBox(width: 12), Text(isSpotlight ? "إلغاء التركيز" : "تسليط الضوء")])),
        PopupMenuItem(value: 'mute', child: Row(children: [Icon(isMicOn ? Icons.mic_off_rounded : Icons.mic_rounded, size: 20), const SizedBox(width: 12), Text(isMicOn ? "كتم الصوت" : "تفعيل الصوت")])),
        if (handRaised)
          const PopupMenuItem(value: 'lower', child: Row(children: [Icon(Icons.front_hand_rounded, color: Colors.orange, size: 20), const SizedBox(width: 12), Text("إنزال اليد")])),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'kick', child: Row(children: [Icon(Icons.person_remove_rounded, color: Colors.redAccent, size: 20), const SizedBox(width: 12), Text("طرد الطالب", style: TextStyle(color: Colors.redAccent))])),
      ],
    );
  }
}
