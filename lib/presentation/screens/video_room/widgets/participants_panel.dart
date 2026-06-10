import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../video_room_controller.dart';

class ParticipantsPanel extends StatefulWidget {
  const ParticipantsPanel({super.key});

  @override
  State<ParticipantsPanel> createState() => _ParticipantsPanelState();
}

class _ParticipantsPanelState extends State<ParticipantsPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            _buildHeader(controller, participants.length + (localParticipant != null ? 1 : 0)),
            
            if (controller.isTeacher) ...[
              TabBar(
                controller: _tabController,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "القائمة"),
                  Tab(text: "توزيع المقاعد"),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildParticipantsList(context, controller, localParticipant, participants),
                    _buildSeatingGrid(context, controller),
                  ],
                ),
              ),
            ] else
              Expanded(
                child: _buildParticipantsList(context, controller, localParticipant, participants),
              ),

            if (controller.isTeacher) _buildTeacherActions(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantsList(BuildContext context, VideoRoomController controller, LocalParticipant? localParticipant, List<RemoteParticipant> participants) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 10),
        if (controller.isTeacher) _buildWallControls(context, controller),
        if (localParticipant != null)
          _ParticipantTile(participant: localParticipant, controller: controller, isMe: true),
        const Divider(height: 32),
        ...participants.map((p) => _ParticipantTile(participant: p, controller: controller)),
      ],
    );
  }

  Widget _buildSeatingGrid(BuildContext context, VideoRoomController controller) {
    final seats = controller.seats;
    if (seats.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("سحب وإفلات الطالب لتغيير مكانه", 
            style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildZoneColumn(controller, "اليمين", "right"),
              const SizedBox(width: 8),
              _buildZoneColumn(controller, "الوسط", "center"),
              const SizedBox(width: 8),
              _buildZoneColumn(controller, "اليسار", "left"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneColumn(VideoRoomController controller, String label, String zoneKey) {
    final zoneSeats = controller.seats.where((s) => s['zone'] == zoneKey).toList();
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
          const SizedBox(height: 12),
          ...zoneSeats.map((seat) {
            final int seatNum = seat['seat_number'];
            final String? studentId = seat['student_id'];
            final String? studentName = seat['student_name'];
            final bool isOccupied = studentId != null && studentId.isNotEmpty;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DragTarget<int>(
                onWillAcceptWithDetails: (details) => details.data != seatNum,
                onAcceptWithDetails: (details) {
                  controller.moveSeat(details.data, seatNum);
                },
                builder: (context, candidateData, rejectedData) {
                  final bool isCandidate = candidateData.isNotEmpty;
                  
                  Widget seatWidget = Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCandidate ? Colors.blue.withOpacity(0.2) : (isOccupied ? Colors.blue.withOpacity(0.05) : Colors.grey.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCandidate ? Colors.blue : (isOccupied ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.2)),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          isOccupied ? (studentName ?? "طالب") : "مقعد $seatNum",
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isOccupied ? Colors.black87 : Colors.grey,
                            fontSize: 10,
                            fontWeight: isOccupied ? FontWeight.bold : FontWeight.normal,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        if (isOccupied)
                          const Icon(Icons.drag_indicator, size: 14, color: Colors.blue),
                      ],
                    ),
                  );

                  if (isOccupied) {
                    return Draggable<int>(
                      data: seatNum,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(studentName ?? "", 
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Cairo')),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: seatWidget),
                      child: seatWidget,
                    );
                  }

                  return seatWidget;
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildWallControls(BuildContext context, VideoRoomController controller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.desktop_windows_rounded, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text(
                "شاشات عرض الفصل (Wall Display)",
                style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildZoneControl(context, controller, 'right', 'اليمنى'),
              _buildZoneControl(context, controller, 'center', 'الوسطى'),
              _buildZoneControl(context, controller, 'left', 'اليسرى'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZoneControl(BuildContext context, VideoRoomController controller, String zone, String label) {
    final String baseUrl = Uri.base.origin;
    final String wallUrl = "$baseUrl/#/wall-display?sessionId=${controller.sessionId}&zone=$zone&roomName=${controller.roomName}";

    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.open_in_new_rounded, color: Colors.blue, size: 22),
          onPressed: () => launchUrl(Uri.parse(wallUrl)),
          tooltip: "فتح في تبويب جديد",
        ),
        Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: wallUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("تم نسخ رابط الشاشة بنجاح", style: TextStyle(fontFamily: 'Cairo')),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text("نسخ الرابط", style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(VideoRoomController controller, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("المشاركين", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Cairo', color: Colors.black)),
              Text("$count مشارك في القاعة", style: const TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Cairo')),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: controller.toggleParticipants, 
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.black, size: 20)
            )
          ),
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
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
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
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
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
                Positioned(left: 0, bottom: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.star, size: 14, color: Colors.amber.shade700))),
            ],
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? "أ. ${controller.userName} (أنت)" : (participant.name.isNotEmpty ? participant.name : "طالب"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
                ),
                if (handRaised) 
                  const Text("يرفع يده ✋", style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                if (participant.isMicrophoneEnabled() == false)
                  const Text("الميكروفون مغلق", style: TextStyle(color: Colors.red, fontSize: 11, fontFamily: 'Cairo')),
              ],
            ),
          ),
          if (controller.isTeacher && !isMe) _buildTeacherMenu(context),
        ],
      ),
    );
  }

  Widget _buildTeacherMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.grey),
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
            children: [
              const Icon(Icons.mic_none_rounded, size: 20),
              const SizedBox(width: 12),
              Text(participant.isMicrophoneEnabled() ? "كتم الصوت" : "تفعيل الصوت", style: const TextStyle(fontFamily: 'Cairo')),
            ],
          )
        ),
        PopupMenuItem(
          value: 'cam', 
          child: Row(
            children: [
              const Icon(Icons.videocam_outlined, size: 20),
              const SizedBox(width: 12),
              Text(participant.isCameraEnabled() ? "تعطيل الكاميرا" : "تفعيل الكاميرا", style: const TextStyle(fontFamily: 'Cairo')),
            ],
          )
        ),
        PopupMenuItem(
          value: 'spotlight', 
          child: Row(
            children: [
              const Icon(Icons.star_outline_rounded, size: 20),
              const SizedBox(width: 12),
              Text(controller.spotlightUserId == participant.identity ? "إلغاء التمييز" : "تمييز المشارك", style: const TextStyle(fontFamily: 'Cairo')),
            ],
          )
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'kick', 
          child: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text("طرد من القاعة", style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
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
