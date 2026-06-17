import 'package:flutter/material.dart';
import 'package:learning_by_video_call/presentation/screens/video_room/widgets/participant_grid.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../utils/classroom_participant_utils.dart';
import '../video_room_controller.dart';
import '../../../../core/routes/app_routes.dart';

class SourceManagerSidebar extends StatelessWidget {
  const SourceManagerSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.read<VideoRoomController>();

    final List<Map<String, dynamic>> baseChannels = [
      {'id': 'teacher', 'label': 'المعلم', 'icon': Icons.school_rounded},
      {
        'id': 'room-cam-right',
        'label': 'كاميرا 1',
        'icon': Icons.videocam_rounded,
      },
      {
        'id': 'room-cam-left',
        'label': 'كاميرا 2',
        'icon': Icons.videocam_rounded,
      },
      {
        'id': 'room-cam-screen',
        'label': 'الشاشة',
        'icon': Icons.monitor_rounded,
      },
      {'id': 'whiteboard', 'label': 'السبورة', 'icon': Icons.edit_note_rounded},
      // Link for room publisher (computer in the classroom)
      {
        'id': 'room-publisher',
        'label': 'كمبيوتر القاعة',
        'icon': Icons.computer_rounded,
      },
    ];
    // Add screen zones only for teacher
    final List<Map<String, dynamic>> screenChannels = controller.isTeacher
        ? controller.screenZones
              .map(
                (zone) => {
                  'id': zone,
                  'label': 'شاشة ${zone.split('_')[1]}',
                  'icon': Icons.tv_rounded,
                },
              )
              .toList()
        : [];
    final List<Map<String, dynamic>> channels = [
      ...baseChannels,
      ...screenChannels,
    ];

    return Container(
      width: 210,
      color: const Color(0xFF16171B),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            "مصادر البث",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Selector<VideoRoomController, String>(
              selector: (_, c) => c.multiSourceKey,
              builder: (context, _, __) {
                return ListenableBuilder(
                  listenable: controller.room ?? controller,
                  builder: (context, _) {
                    final participants = ClassroomParticipantUtils.allFromRoom(
                      controller.room,
                    );
                    final screenSharer =
                        ClassroomParticipantUtils.findScreenSharingParticipant(
                          participants,
                        );

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        if (screenSharer != null)
                          _SourceCard(
                            channelId: 'screen-share',
                            label: 'مشاركة الشاشة',
                            icon: Icons.screen_share_rounded,
                            participant: screenSharer,
                            isActive: controller.isChannelActive(
                              'screen-share',
                            ),
                            isPinned:
                                controller.pinnedChannel == 'screen-share',
                            controller: controller,
                          ),
                        ...channels.map((ch) {
                          final channelId = ch['id'] as String;
                          final participant = channelId == 'whiteboard'
                              ? null
                              : (channelId == 'teacher'
                                    ? ClassroomParticipantUtils.findTeacher(
                                        participants,
                                      )
                                    : ClassroomParticipantUtils.findChannelParticipant(
                                        participants,
                                        channelId,
                                      ));

                          if (controller.isTeacher &&
                              (channelId.startsWith('screen_') ||
                                  channelId == 'room-publisher')) {
                            // Open in new tab / route for teacher
                            return InkWell(
                              onTap: () {
                                if (channelId == 'room-publisher') {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.roomPublisher,
                                    arguments: {
                                      'roomName': controller.roomName,
                                      'sessionId': controller.sessionId ?? '',
                                    },
                                  );
                                } else {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.wallDisplay,
                                    arguments: {
                                      'sessionId': controller.sessionId ?? '',
                                      'zone': channelId,
                                      'roomName': controller.roomName,
                                    },
                                  );
                                }
                              },
                              child: _SourceCard(
                                channelId: channelId,
                                label: ch['label'] as String,
                                icon: ch['icon'] as IconData,
                                participant: participant,
                                isActive: controller.isChannelActive(channelId),
                                isPinned: controller.pinnedChannel == channelId,
                                controller: controller,
                              ),
                            );
                          } else {
                            return _SourceCard(
                              channelId: channelId,
                              label: ch['label'] as String,
                              icon: ch['icon'] as IconData,
                              participant: participant,
                              isActive: controller.isChannelActive(channelId),
                              isPinned: controller.pinnedChannel == channelId,
                              controller: controller,
                            );
                          }
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final String channelId;
  final String label;
  final IconData icon;
  final Participant? participant;
  final bool isActive;
  final bool isPinned;
  final VideoRoomController controller;

  const _SourceCard({
    required this.channelId,
    required this.label,
    required this.icon,
    this.participant,
    required this.isActive,
    required this.isPinned,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOffline = channelId != 'whiteboard' && participant == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.withOpacity(0.05) : Colors.black26,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isPinned
              ? Colors.amber.withOpacity(0.8)
              : (isActive
                    ? Colors.blue.withOpacity(0.5)
                    : Colors.white.withOpacity(0.05)),
          width: isPinned ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview Area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              children: [
                if (isOffline)
                  Container(
                    color: const Color(0xFF1F2026),
                    child: Center(
                      child: Icon(icon, color: Colors.white10, size: 32),
                    ),
                  )
                else if (channelId == 'whiteboard')
                  Container(
                    color: Colors.white,
                    child: const Center(
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: Colors.blueGrey,
                        size: 32,
                      ),
                    ),
                  )
                else
                  Opacity(
                    opacity: isActive ? 1.0 : 0.4,
                    child: ParticipantTile(
                      key: ValueKey('sidebar_preview_$channelId'),
                      participant: participant!,
                      isMainStage: false,
                      forceShowScreen: channelId == 'screen-share',
                    ),
                  ),

                // Status Overlay
                if (isOffline)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      child: const Center(
                        child: Text(
                          "غير متصل",
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isActive
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    size: 16,
                    color: isActive ? Colors.blue : Colors.white24,
                  ),
                  onPressed: isOffline
                      ? null
                      : () => controller.toggleActiveChannel(channelId),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 16,
                    color: isPinned ? Colors.amber : Colors.white24,
                  ),
                  onPressed: (isOffline || !isActive)
                      ? null
                      : () => controller.pinChannel(channelId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
