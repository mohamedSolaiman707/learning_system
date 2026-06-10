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

            if (allParticipants.isEmpty) {
              return const Center(child: Text("في انتظار دخول المشاركين...", style: TextStyle(color: Colors.white70, fontFamily: 'Cairo')));
            }

            // 1. فحص وجود مشاركة شاشة (Screen Share) في القاعة
            Participant? screenSharingParticipant;
            try {
              screenSharingParticipant = allParticipants.firstWhere((p) => p.isScreenShareEnabled());
            } catch (_) {}

            // -------------------------------------------------------
            // منطق الطالب (Student Logic)
            // -------------------------------------------------------
            if (!isTeacher) {
              // البحث عن تراك القناة المختارة (كاميرا اليمين، اليسار، إلخ)
              final channelParticipant = allParticipants.where((p) => p.identity.contains(selectedChannel)).firstOrNull;

              if (screenSharingParticipant != null) {
                // حالة هجينة: مشاركة شاشة + كاميرا القاعة المختارة
                return _buildHybridStudentLayout(context, screenSharingParticipant, channelParticipant);
              } else {
                // الحالة العادية: عرض القناة المختارة فقط ملء الشاشة
                if (channelParticipant != null) {
                  return ParticipantTile(
                    key: ValueKey("channel_${channelParticipant.identity}"), 
                    participant: channelParticipant, 
                    isMainStage: true
                  );
                } else {
                  return const Center(child: Text("جاري تحميل بث القاعة...", style: TextStyle(color: Colors.white, fontFamily: 'Cairo', fontSize: 16)));
                }
              }
            }

            // -------------------------------------------------------
            // منطق المعلم (Teacher Logic)
            // -------------------------------------------------------
            final bool isDesktop = Responsive.isDesktop(context);

            if (controller.isVideoWallMode) {
              int crossAxisCount = isDesktop ? 4 : (Responsive.isTablet(context) ? 3 : 2);
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 16 / 9,
                ),
                itemCount: allParticipants.length,
                itemBuilder: (context, index) => ParticipantTile(participant: allParticipants[index], isMainStage: false),
              );
            }

            Participant? mainParticipant = screenSharingParticipant;
            if (mainParticipant == null) {
              try {
                mainParticipant = allParticipants.firstWhere((p) => p.identity.toLowerCase().contains('teacher'));
              } catch (_) {
                mainParticipant = allParticipants.first;
              }
            }

            final bool isMainSharingScreen = mainParticipant.isScreenShareEnabled();
            final otherParticipants = allParticipants.where((p) {
              if (isMainSharingScreen) return true;
              return p.identity != mainParticipant?.identity;
            }).toList();

            if (isDesktop) return _buildProfessionalDesktopLayout(context, mainParticipant, otherParticipants, isMainSharingScreen);
            return _buildMobileLayout(context, mainParticipant, otherParticipants, isMainSharingScreen);
          },
        );
      },
    );
  }

  // تخطيط هجين للطالب: يرى الشاشة كبيرة والكاميرا صغيرة
  Widget _buildHybridStudentLayout(BuildContext context, Participant screenPart, Participant? camPart) {
    final bool isDesktop = Responsive.isDesktop(context);
    
    return Stack(
      children: [
        // 1. الشاشة المشتركة (كبيرة)
        Positioned.fill(
          child: ParticipantTile(
            key: ValueKey("student_main_screen_${screenPart.identity}"),
            participant: screenPart,
            isMainStage: true,
            forceShowScreen: true,
          ),
        ),
        
        // 2. كاميرا القاعة (نافذة عائمة صغيرة)
        if (camPart != null)
          Positioned(
            top: isDesktop ? 40 : 20,
            right: 20,
            child: Container(
              width: isDesktop ? 280 : 140,
              height: isDesktop ? 160 : 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: ParticipantTile(
                  key: ValueKey("student_side_cam_${camPart.identity}"),
                  participant: camPart,
                  isMainStage: false,
                  forceShowScreen: false, // إجبار عرض الكاميرا
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProfessionalDesktopLayout(BuildContext context, Participant main, List<Participant> others, bool isMainSharingScreen) {
    return Container(
      color: const Color(0xFF0F1014),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 4, 
            child: ParticipantTile(
              key: ValueKey("main_${main.identity}"), 
              participant: main, 
              isMainStage: true,
              forceShowScreen: isMainSharingScreen ? true : null,
            )
          ),
          if (others.isNotEmpty)
            Container(
              width: 240,
              margin: const EdgeInsets.only(left: 16),
              child: ListView.builder(
                itemCount: others.length,
                itemBuilder: (context, index) {
                  final p = others[index];
                  final bool forceCam = isMainSharingScreen && p.identity == main.identity;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AspectRatio(
                      aspectRatio: 16 / 10, 
                      child: ParticipantTile(
                        key: ValueKey("side_${p.identity}"), 
                        participant: p, 
                        isMainStage: false,
                        forceShowScreen: forceCam ? false : null,
                      )
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, Participant main, List<Participant> others, bool isMainSharingScreen) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8), 
            child: ParticipantTile(
              participant: main, 
              isMainStage: true,
              forceShowScreen: isMainSharingScreen ? true : null,
            )
          )
        ),
        if (others.isNotEmpty)
          Container(
            height: 120,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: others.length,
              itemBuilder: (context, index) {
                final p = others[index];
                final bool forceCam = isMainSharingScreen && p.identity == main.identity;
                return Container(
                  width: 160, 
                  margin: const EdgeInsets.only(right: 8), 
                  child: ParticipantTile(
                    participant: p, 
                    isMainStage: false,
                    forceShowScreen: forceCam ? false : null,
                  )
                );
              },
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

  const ParticipantTile({
    super.key,
    required this.participant,
    required this.isMainStage,
    this.forceHandRaised,
    this.forceShowScreen,
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

    return ListenableBuilder(
      listenable: participant,
      builder: (context, _) {
        final bool isMe = participant is LocalParticipant;
        final bool isTeacher = participant.identity.toLowerCase().contains('teacher');
        final bool isRoomCam = participant.identity.contains('roomcam_');

        String displayName = participant.name ?? "";
        if (displayName.isEmpty) {
          displayName = participant.identity.replaceAll("teacher_", "").split('_').first;
        }
        if (displayName.isEmpty) displayName = "مشارك";

        VideoTrack? activeVideoTrack;
        bool isScreen = false;

        if (forceShowScreen == true) {
          final pub = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
          if (pub != null && pub.subscribed) activeVideoTrack = pub.track as VideoTrack?;
          isScreen = true;
        } else if (forceShowScreen == false) {
          final pub = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
          if (pub != null && pub.subscribed) activeVideoTrack = pub.track as VideoTrack?;
          isScreen = false;
        } else {
          final screenPub = participant.videoTrackPublications.where((p) => p.isScreenShare).firstOrNull;
          if (screenPub != null && screenPub.subscribed && screenPub.track != null) {
            activeVideoTrack = screenPub.track as VideoTrack?;
            isScreen = true;
          } else {
            final camPub = participant.videoTrackPublications.where((p) => !p.isScreenShare).firstOrNull;
            if (camPub != null && camPub.subscribed && camPub.track != null) {
              activeVideoTrack = camPub.track as VideoTrack?;
            }
          }
        }

        final bool hasVideo = activeVideoTrack != null && (isScreen || participant.isCameraEnabled());

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(isMainStage ? 20 : 12),
            color: const Color(0xFF1A1B1F),
            border: Border.all(
              color: participant.isSpeaking ? Colors.greenAccent : Colors.white.withOpacity(0.05),
              width: participant.isSpeaking ? 3 : 1,
            ),
            boxShadow: [if (participant.isSpeaking) BoxShadow(color: Colors.greenAccent.withOpacity(0.2), blurRadius: 15)],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: hasVideo
                    ? (isScreen || !isMainStage
                        ? VideoTrackRenderer(activeVideoTrack, fit: VideoViewFit.contain)
                        : Stack(
                            children: [
                              Positioned.fill(child: ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: VideoTrackRenderer(activeVideoTrack, fit: VideoViewFit.cover))),
                              Positioned.fill(child: VideoTrackRenderer(activeVideoTrack!, fit: VideoViewFit.contain)),
                            ],
                          ))
                    : _buildAvatar(displayName, isMainStage),
              ),
              Positioned(bottom: 10, left: 10, child: _buildNameLabel(displayName, isMe, participant.isMicrophoneEnabled(), isScreen)),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHandRaised) _buildCircleIcon(Icons.front_hand, Colors.orange),
                    if (isHandRaised) const SizedBox(width: 8),
                    if (isRoomCam) _buildBadge("كاميرا القاعة", Colors.teal, Icons.videocam)
                    else if (isTeacher) _buildBadge(isScreen ? "شاشة المعلم" : "المعلم", Colors.blueAccent, isScreen ? Icons.desktop_windows : Icons.school),
                  ],
                ),
              ),
              if (participant.isSpeaking) Positioned(top: 0, left: 0, right: 0, child: Container(height: 3, color: Colors.greenAccent)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatar(String name, bool isMain) {
    String initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?";
    return Container(
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2C2D35), Color(0xFF141519)])),
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
