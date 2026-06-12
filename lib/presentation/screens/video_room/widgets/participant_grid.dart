import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/responsive.dart';
import '../video_room_controller.dart';

class ParticipantGrid extends StatelessWidget {
  const ParticipantGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<VideoRoomController, Room?>(
      selector: (_, c) => c.room,
      builder: (context, room, _) {
        if (room == null) {
          return const Center(child: CircularProgressIndicator(color: Colors.blue));
        }

        return ListenableBuilder(
          listenable: room,
          builder: (context, _) {
            final controller = context.read<VideoRoomController>();
            final isTeacher = controller.isTeacher;
            final selectedChannel = controller.selectedChannel;

            final List<Participant> allParticipants = [
              if (room.localParticipant != null) room.localParticipant!,
              ...room.remoteParticipants.values,
            ];

            Participant? screenSharingParticipant;
            try {
              screenSharingParticipant = allParticipants.firstWhere((p) => p.isScreenShareEnabled());
            } catch (_) {}

            if (!isTeacher) {
              return _buildStudentLayout(context, allParticipants, screenSharingParticipant, selectedChannel);
            }

            // --- منطق المدرس (Video Wall Mode) ---
            return _buildTeacherVideoWall(context, controller, allParticipants, screenSharingParticipant);
          },
        );
      },
    );
  }

  // واجهة الطالب التقليدية
  Widget _buildStudentLayout(BuildContext context, List<Participant> allParticipants, Participant? screenSharingParticipant, String selectedChannel) {
    final controller = context.read<VideoRoomController>();
    final teacherParticipant = allParticipants.where((p) => p.identity.toLowerCase().contains('teacher')).firstOrNull;
    final channelParticipant = allParticipants.where((p) => p.identity.contains(selectedChannel)).firstOrNull;

    if (screenSharingParticipant != null) {
      return _buildHybridStudentLayout(context, screenSharingParticipant, channelParticipant);
    }

    final mainToDisplay = channelParticipant ?? teacherParticipant;
    if (mainToDisplay != null) {
      return GestureDetector(
        onTap: () => controller.cycleRoomCamera(),
        child: ParticipantTile(
            key: ValueKey("student_main_${mainToDisplay.identity}"),
            participant: mainToDisplay,
            isMainStage: true
        ),
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
          SizedBox(height: 16),
          Text("في انتظار المدرس أو بث القاعة...", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16)),
        ],
      ),
    );
  }

  // واجهة المدرس (Video Wall) المبنية على المقاعد
  Widget _buildTeacherVideoWall(BuildContext context, VideoRoomController controller, List<Participant> allParticipants, Participant? screenSharingParticipant) {
    final isDesktop = Responsive.isDesktop(context);
    final seats = controller.seats;

    if (seats.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.blue));
    }

    // تقسيم الشاشة لو كان هناك مشاركة شاشة أو سبورة
    return Row(
      children: [
        if (screenSharingParticipant != null || controller.isWhiteboardOpen)
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: screenSharingParticipant != null 
                  ? ParticipantTile(participant: screenSharingParticipant, isMainStage: true, forceShowScreen: true)
                  : const SizedBox(), // السبورة تظهر من الـ Stack في الـ Screen
              ),
            ),
          ),
        
        Expanded(
          flex: 3,
          child: Column(
            children: [
              // رأسية الـ Video Wall
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: Colors.black26,
                child: Row(
                  children: [
                    const Icon(Icons.grid_view_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 10),
                    const Text("جدار الفيديو (توزيع المقاعد الذكي)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo', fontSize: 14)),
                    const Spacer(),
                    Text("${allParticipants.length} مشاركين متصلين", style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Cairo')),
                  ],
                ),
              ),
              
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isDesktop ? 4 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: seats.length,
                  itemBuilder: (context, index) {
                    final seat = seats[index];
                    final String? studentId = seat['student_id'];
                    
                    // البحث عن الطالب في قائمة المشاركين الفعليين (LiveKit)
                    Participant? participant;
                    if (studentId != null) {
                      try {
                        participant = allParticipants.firstWhere(
                          (p) => p.identity.startsWith(studentId)
                        );
                      } catch (_) {}
                    }

                    if (participant != null) {
                      return ParticipantTile(
                        key: ValueKey("seat_${seat['id']}_${participant.identity}"),
                        participant: participant,
                        isMainStage: false,
                        displayName: seat['student_name'] ?? participant.name,
                      );
                    } else {
                      // مقعد فارغ (Free Seat) كما في صورة العميل
                      return _buildEmptySeat(seat['seat_number'], seat['student_name']);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySeat(int number, String? assignedName) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B1F),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline_rounded, color: Colors.white.withOpacity(0.1), size: 30),
          const SizedBox(height: 8),
          Text(
            assignedName ?? "مقعد فارغ",
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'Cairo'),
          ),
          Text(
            "مقعد $number",
            style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 9, fontFamily: 'Cairo'),
          ),
        ],
      ),
    );
  }

  Widget _buildHybridStudentLayout(BuildContext context, Participant screenPart, Participant? camPart) {
    final bool isDesktop = Responsive.isDesktop(context);
    final controller = context.read<VideoRoomController>();

    return Stack(
      children: [
        Positioned.fill(
          child: ParticipantTile(
            key: ValueKey("student_main_screen_${screenPart.identity}"),
            participant: screenPart,
            isMainStage: true,
            forceShowScreen: true,
          ),
        ),
        if (camPart != null)
          Positioned(
            top: isDesktop ? 40 : 20,
            right: 20,
            child: GestureDetector(
              onTap: () => controller.cycleRoomCamera(),
              child: Container(
                width: isDesktop ? 280 : 140,
                height: isDesktop ? 160 : 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withOpacity(0.5), width: 2),
                  boxShadow: [const BoxShadow(color: Colors.black54, blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ParticipantTile(
                    key: ValueKey("student_side_cam_${camPart.identity}"),
                    participant: camPart,
                    isMainStage: false,
                    forceShowScreen: false,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool isMainStage;
  final bool? forceHandRaised;
  final bool? forceShowScreen;
  final String? displayName;

  const ParticipantTile({
    super.key,
    required this.participant,
    required this.isMainStage,
    this.forceHandRaised,
    this.forceShowScreen,
    this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    bool isHandRaised = forceHandRaised ?? false;
    if (forceHandRaised == null) {
      try {
        isHandRaised = context.select<VideoRoomController, bool>(
              (c) => c.remoteHandStates[participant.identity] ?? false,
        );
      } catch (_) {}
    }

    final isSpotlighted = context.select<VideoRoomController, bool>(
          (c) => c.spotlightUserId == participant.identity,
    );

    return ListenableBuilder(
      listenable: participant,
      builder: (context, _) {
        final bool isMe = participant is LocalParticipant;
        final bool isTeacher = participant.identity.toLowerCase().contains('teacher');
        final bool isRoomCam = participant.identity.contains('room-cam-');
        final bool isSpeaking = participant.isSpeaking;

        String nameToShow = displayName ?? participant.name ?? "";
        if (nameToShow.isEmpty) {
          nameToShow = participant.identity.replaceAll("teacher_", "").split('_').first;
        }
        if (nameToShow.isEmpty) nameToShow = "مشارك";

        VideoTrack? activeVideoTrack;
        bool isScreen = false;

        if (forceShowScreen == true) {
          final pub = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
          if (pub != null && (isMe || pub.subscribed)) activeVideoTrack = pub.track as VideoTrack?;
          isScreen = true;
        } else if (forceShowScreen == false) {
          final pub = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
          if (pub != null && (isMe || pub.subscribed)) activeVideoTrack = pub.track as VideoTrack?;
          isScreen = false;
        } else {
          final screenPub = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
          if (screenPub != null && (isMe || screenPub.subscribed) && screenPub.track != null) {
            activeVideoTrack = screenPub.track as VideoTrack?;
            isScreen = true;
          } else {
            final camPub = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
            if (camPub != null && (isMe || camPub.subscribed) && camPub.track != null) {
              activeVideoTrack = camPub.track as VideoTrack?;
            }
          }
        }

        final bool hasVideo = activeVideoTrack != null && (isScreen || participant.isCameraEnabled());

        return AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            borderRadius: isMainStage ? BorderRadius.zero : BorderRadius.circular(12),
            color: const Color(0xFF0F1014),
            border: isMainStage 
              ? null 
              : Border.all(
                  color: isSpotlighted ? Colors.amber : (isSpeaking ? Colors.greenAccent : Colors.white.withOpacity(0.05)),
                  width: (isSpotlighted || isSpeaking) ? 3 : 1,
                ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: hasVideo
                      ? VideoTrackRenderer(
                          activeVideoTrack!,
                          fit: VideoViewFit.contain,
                          mirrorMode: isMe ? VideoViewMirrorMode.mirror : VideoViewMirrorMode.off,
                          key: ValueKey(activeVideoTrack.sid),
                        )
                      : _buildAvatar(nameToShow, isMainStage),
                ),
              ),

              if (isSpotlighted)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.amber.withOpacity(0.1), Colors.transparent, Colors.black.withOpacity(0.4)],
                      ),
                    ),
                  ),
                ),

              Positioned(bottom: 10, left: 10, child: _buildNameLabel(nameToShow, isMe, participant.isMicrophoneEnabled(), isScreen)),

              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandRaised) _buildCircleIcon(Icons.front_hand, Colors.orange),
                    if (isHandRaised) const SizedBox(width: 8),
                    if (isSpotlighted) _buildBadge("مشاركة مميزة", Colors.amber.shade700, Icons.star),
                    if (isSpotlighted) const SizedBox(width: 8),
                    if (isRoomCam) _buildBadge(nameToShow, Colors.teal, Icons.videocam)
                    else if (isTeacher) _buildBadge(isScreen ? "شاشة المعلم" : "المعلم", Colors.blueAccent, isScreen ? Icons.desktop_windows : Icons.school),
                  ],
                ),
              ),

              if (isSpeaking && !isScreen) Positioned(bottom: 10, right: 10, child: _AudioVisualizer()),
              if (isSpeaking) Positioned(top: 0, left: 0, right: 0, child: Container(height: 3, color: Colors.greenAccent)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, bool isMain) {
    String initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
    return Container(
      color: const Color(0xFF0F1014),
      child: Center(
        child: CircleAvatar(
          radius: isMain ? 50 : 25,
          backgroundColor: Colors.blueAccent.withOpacity(0.1),
          child: Text(initial, style: TextStyle(color: Colors.blueAccent, fontSize: isMain ? 36 : 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildNameLabel(String name, bool isMe, bool isMicOn, bool isScreen) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.black26,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isScreen) ...[
                Icon(isMicOn ? Icons.mic : Icons.mic_off, color: isMicOn ? Colors.white70 : Colors.redAccent, size: 12),
                const SizedBox(width: 4),
              ],
              Flexible(child: Text(isMe ? "$name (أنت)" : (isScreen ? "شاشة $name" : name), style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'Cairo'), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        ],
      ),
    );
  }

  Widget _buildCircleIcon(IconData icon, Color color) {
    return Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: 12));
  }
}

class _AudioVisualizer extends StatefulWidget {
  @override
  State<_AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<_AudioVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [0.2, 0.8, 0.4, 0.7, 0.3];
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_heights.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 2,
              height: 12 * (_heights[index] * _controller.value + 0.2),
              decoration: BoxDecoration(color: Colors.greenAccent, borderRadius: BorderRadius.circular(1)),
            );
          }),
        );
      },
    );
  }
}
