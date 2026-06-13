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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = context.read<VideoRoomController>();
      if (ctrl.seats.isEmpty) ctrl.loadAndExpandSeats();
    });
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
        if (controller.isTeacher) ...[
          _buildWallControls(context, controller),
          _buildPublisherLink(context, controller),
        ],
        if (localParticipant != null)
          _ParticipantTile(participant: localParticipant, controller: controller, isMe: true),
        const Divider(height: 32),
        ...participants.map((p) => _ParticipantTile(participant: p, controller: controller)),
      ],
    );
  }

  Widget _buildPublisherLink(BuildContext context, VideoRoomController controller) {
    final String baseUrl = Uri.base.origin;
    final String publisherUrl = "$baseUrl/#/room-publisher?roomName=${controller.roomName}&sessionId=${controller.sessionId}";

    return Container(
      margin: const EdgeInsets.only(top: 0, bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.videocam_rounded, color: Colors.green, size: 18),
            SizedBox(width: 8),
            Text("كمبيوتر القاعة",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 13,
              )),
          ]),
          const SizedBox(height: 8),
          const Text(
            "افتح هذا الرابط على كمبيوتر القاعة لبدء بث الكاميرات",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    publisherUrl,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontFamily: 'Cairo',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.green, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: publisherUrl));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("تم نسخ رابط القاعة ✅", style: TextStyle(fontFamily: 'Cairo')),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeatingGrid(
    BuildContext context,
    VideoRoomController controller,
  ) {
    if (controller.seats.isEmpty) {
      return const Center(
        child: CircularProgressIndicator());
    }

    final zones = controller.screenZones;
    final columnsPerRow = zones.length <= 3 ? zones.length
      : zones.length <= 6 ? 3
      : 4;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                size: 14, color: Colors.blue),
              const SizedBox(width: 6),
              Text(
                "${zones.length} شاشات — "
                "${controller.seatsPerScreen} مقاعد/شاشة",
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 12,
                  color: Colors.blue,
                )),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: 
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columnsPerRow,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.5,
              ),
            itemCount: zones.length,
            itemBuilder: (context, index) {
              final zone = zones[index];
              return _buildScreenColumn(
                controller,
                "شاشة ${index + 1}",
                zone,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScreenColumn(
    VideoRoomController controller,
    String label,
    String zoneKey,
  ) {
    final zoneSeats = controller.seats
      .where((s) => s['zone'] == zoneKey)
      .toList()
      ..sort((a, b) =>
        (a['seat_number'] as int)
          .compareTo(b['seat_number'] as int));

    return Column(
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
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            )),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: zoneSeats.length,
            itemBuilder: (context, index) {
              final seat = zoneSeats[index];
              final int seatNum = seat['seat_number'];
              final String? studentId = seat['student_id'];
              final String? studentName = 
                seat['student_name'];
              final bool isOccupied = 
                studentId != null && 
                studentId.isNotEmpty;

              // Empty seat
              if (!isOccupied) {
                return DragTarget<int>(
                  onWillAcceptWithDetails: (details) =>
                    details.data != seatNum,
                  onAcceptWithDetails: (details) {
                    controller.moveSeat(
                      details.data, seatNum);
                  },
                  builder: (context, candidate, _) {
                    return Container(
                      margin: const EdgeInsets.only(
                        bottom: 8),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: candidate.isNotEmpty
                          ? Colors.blue.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.05),
                        borderRadius: 
                          BorderRadius.circular(10),
                        border: Border.all(
                          color: candidate.isNotEmpty
                            ? Colors.blue
                            : Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment:
                          MainAxisAlignment.center,
                        children: [
                          Icon(
                            candidate.isNotEmpty
                              ? Icons.add_circle
                              : Icons.add_circle_outline,
                            color: candidate.isNotEmpty
                              ? Colors.blue
                              : Colors.grey.shade300,
                            size: 18,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "مقعد $seatNum",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: candidate.isNotEmpty
                                ? Colors.blue
                                : Colors.grey.shade300,
                              fontSize: 9,
                              fontFamily: 'Cairo',
                            )),
                        ],
                      ),
                    );
                  },
                );
              }

              // Occupied seat — draggable
              final seatWidget = Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      studentName ?? "طالب",
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      )),
                    const SizedBox(height: 2),
                    Text(
                      "مقعد $seatNum",
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 8,
                        fontFamily: 'Cairo',
                      )),
                    const Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: Colors.blue,
                    ),
                  ],
                ),
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DragTarget<int>(
                  onWillAcceptWithDetails: (details) =>
                    details.data != seatNum,
                  onAcceptWithDetails: (details) {
                    controller.moveSeat(
                      details.data, seatNum);
                  },
                  builder: (context, candidate, _) {
                    return Draggable<int>(
                      data: seatNum,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 100,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius:
                              BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 8,
                              )
                            ],
                          ),
                          child: Text(
                            studentName ?? "طالب",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.bold,
                            )),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: seatWidget,
                      ),
                      child: candidate.isNotEmpty
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            child: seatWidget,
                          )
                        : seatWidget,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWallControls(
    BuildContext context,
    VideoRoomController controller,
  ) {
    final zones = controller.screenZones;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.blue.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.desktop_windows_rounded,
              color: Colors.blue, size: 18),
            SizedBox(width: 8),
            Text("شاشات عرض القاعة (Wall Display)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
                fontSize: 13,
              )),
          ]),
          const SizedBox(height: 12),
          // Dynamic grid of screen links
          GridView.builder(
            shrinkWrap: true,
            physics: 
              const NeverScrollableScrollPhysics(),
            gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: zones.length <= 4 
                  ? zones.length : 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.5,
              ),
            itemCount: zones.length,
            itemBuilder: (context, index) {
              final zone = zones[index];
              final baseUrl = Uri.base.origin;
              final wallUrl = 
                "$baseUrl/#/wall-display"
                "?sessionId=${controller.sessionId}"
                "&zone=$zone"
                "&roomName=${controller.roomName}";

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: 
                    BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.blue
                      .withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment:
                    MainAxisAlignment.center,
                  children: [
                    Text("شاشة ${index + 1}",
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment:
                        MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.open_in_new_rounded,
                            color: Colors.blue,
                            size: 18),
                          onPressed: () => 
                            launchUrl(
                              Uri.parse(wallUrl)),
                          tooltip: "فتح",
                          padding: EdgeInsets.zero,
                          constraints: 
                            const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Colors.grey,
                            size: 16),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(
                                text: wallUrl));
                            ScaffoldMessenger
                              .of(context)
                              .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "تم نسخ رابط "
                                    "شاشة ${index+1}",
                                    style: const TextStyle(
                                      fontFamily: 'Cairo'
                                    )),
                                  backgroundColor:
                                    Colors.green,
                                  behavior: 
                                    SnackBarBehavior
                                      .floating,
                                ));
                          },
                          padding: EdgeInsets.zero,
                          constraints:
                            const BoxConstraints(),
                          tooltip: "نسخ الرابط",
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
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
                IconButton(
                  icon: const Icon(Icons.tv_rounded,
                    color: Colors.blue),
                  tooltip: "إعداد الشاشات",
                  onPressed: () => _showScreenConfigDialog(
                    context, controller),
                ),
                const SizedBox(width: 8),
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

  void _showScreenConfigDialog(
    BuildContext context,
    VideoRoomController controller,
  ) {
    int screenCount = controller.screenCount;
    int seatsPerScreen = controller.seatsPerScreen;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDS) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
          title: const Text(
            "إعداد شاشات القاعة",
            style: TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            )),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Screen count
              Row(
                mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                children: [
                  const Text("عدد الشاشات",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    )),
                  Row(children: [
                    IconButton(
                      onPressed: screenCount > 1
                        ? () => setDS(() => screenCount--)
                        : null,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.blue)),
                    Text("$screenCount",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                    IconButton(
                      onPressed: screenCount < 20
                        ? () => setDS(() => screenCount++)
                        : null,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue)),
                  ]),
                ],
              ),
              const Divider(),
              // Seats per screen
              Row(
                mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                children: [
                  const Text("طلاب لكل شاشة",
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    )),
                  Row(children: [
                    IconButton(
                      onPressed: seatsPerScreen > 4
                        ? () => setDS(
                            () => seatsPerScreen--)
                        : null,
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.blue)),
                    Text("$seatsPerScreen",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      )),
                    IconButton(
                      onPressed: seatsPerScreen < 16
                        ? () => setDS(
                            () => seatsPerScreen++)
                        : null,
                      icon: const Icon(
                        Icons.add_circle_outline,
                        color: Colors.blue)),
                  ]),
                ],
              ),
              const SizedBox(height: 12),
              // Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment:
                    MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.people_alt_rounded,
                      color: Colors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "إجمالي المقاعد: "
                      "${screenCount * seatsPerScreen} مقعد",
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      )),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("إلغاء",
                style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: 
                    BorderRadius.circular(10)),
              ),
              onPressed: () {
                controller.updateScreenConfig(
                  screenCount: screenCount,
                  seatsPerScreen: seatsPerScreen,
                );
                Navigator.pop(context);
              },
              child: const Text("حفظ وتطبيق",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                ))),
          ],
        ),
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
    final bool hasPen = controller.authorizedStudentId == participant.identity;
    
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
                Row(
                  children: [
                    Text(
                      isMe ? "أ. ${controller.userName} (أنت)" : (participant.name.isNotEmpty ? participant.name : "طالب"),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 16),
                    ),
                    if (hasPen)
                      const Padding(
                        padding: EdgeInsets.only(right: 8.0),
                        child: Icon(Icons.edit_rounded, color: Colors.green, size: 16),
                      ),
                  ],
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
    final bool hasPen = controller.authorizedStudentId == participant.identity;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (val) {
        if (val == 'mute') controller.muteParticipant(participant.identity, participant.isMicrophoneEnabled());
        if (val == 'cam') controller.disableParticipantCamera(participant.identity, participant.isCameraEnabled());
        if (val == 'kick') controller.kickParticipant(participant.identity);
        if (val == 'spotlight') controller.setSpotlight(controller.spotlightUserId == participant.identity ? null : participant.identity);
        if (val == 'pen') controller.grantPenToStudent(hasPen ? null : participant.identity);
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
          value: 'pen', 
          child: Row(
            children: [
              Icon(hasPen ? Icons.edit_off_rounded : Icons.edit_rounded, size: 20, color: hasPen ? Colors.orange : Colors.green),
              const SizedBox(width: 12),
              Text(hasPen ? "سحب القلم" : "إعطاء القلم", style: const TextStyle(fontFamily: 'Cairo')),
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
