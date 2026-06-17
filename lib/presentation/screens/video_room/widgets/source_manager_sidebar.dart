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

    final List<Map<String, dynamic>> sourceChannels = [
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
    ];

    return Container(
      width: 210,
      color: const Color(0xFF16171B),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildSidebarHeader("مصادر البث"),
          const SizedBox(height: 10),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                        ...sourceChannels.map((ch) {
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

                          return _SourceCard(
                            channelId: channelId,
                            label: ch['label'] as String,
                            icon: ch['icon'] as IconData,
                            participant: participant,
                            isActive: controller.isChannelActive(channelId),
                            isPinned: controller.pinnedChannel == channelId,
                            controller: controller,
                          );
                        }),

                        // Teacher Tools Section (The ones from your image)
                        if (controller.isTeacher) ...[
                          const SizedBox(height: 24),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 12),
                          _buildSidebarHeader("أدوات القاعة"),
                          const SizedBox(height: 12),
                          
                          // Room Publisher Tool
                          _ToolCard(
                            label: "كمبيوتر القاعة",
                            desc: "افتح الرابط لبدء بث الكاميرات",
                            icon: Icons.computer_rounded,
                            color: Colors.green,
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.roomPublisher,
                              arguments: {
                                'roomName': controller.roomName,
                                'sessionId': controller.sessionId ?? '',
                              },
                            ),
                          ),
                          
                          // Wall Display Tool
                          _ToolCard(
                            label: "شاشات عرض القاعة",
                            desc: "رؤية وجوه الطلاب في القاعة",
                            icon: Icons.tv_rounded,
                            color: Colors.blue,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: controller.screenZones.map((zone) => 
                                InkWell(
                                  onTap: () => Navigator.of(context).pushNamed(
                                    AppRoutes.wallDisplay,
                                    arguments: {
                                      'sessionId': controller.sessionId ?? '',
                                      'zone': zone,
                                      'roomName': controller.roomName,
                                    },
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      "شاشة ${zone.split('_')[1]}",
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Cairo'
                                      ),
                                    ),
                                  ),
                                )
                              ).toList(),
                            ),
                          ),
                        ],
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

  Widget _buildSidebarHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
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

class _ToolCard extends StatelessWidget {
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? child;

  const _ToolCard({
    required this.label,
    required this.desc,
    required this.icon,
    required this.color,
    this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ),
                    if (onTap != null)
                      const Icon(Icons.open_in_new_rounded, color: Colors.white24, size: 14),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 8,
                    fontFamily: 'Cairo',
                  ),
                ),
                if (child != null) ...[
                  const SizedBox(height: 12),
                  child!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
