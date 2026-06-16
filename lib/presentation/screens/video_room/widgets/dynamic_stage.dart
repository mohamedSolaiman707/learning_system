import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';
import '../utils/classroom_participant_utils.dart';
import '../video_room_controller.dart';
import 'participant_grid.dart';
import 'whiteboard_panel.dart';

/// Dynamic multi-source stage for the student view.
/// Renders active channels in a responsive grid or pinned layout.
class DynamicStage extends StatelessWidget {
  final VideoRoomController controller;
  const DynamicStage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Selector<VideoRoomController, String>(
      selector: (_, c) => c.multiSourceKey,
      builder: (context, _, __) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            controller,
            if (controller.room != null) controller.room!,
          ]),
          builder: (context, _) {
            final activeChannels = controller.activeChannels;
            if (activeChannels.isEmpty) return const _WaitingPlaceholder();

            final participants = ClassroomParticipantUtils.allFromRoom(
              controller.room,
            );
            final sourceMap = ClassroomParticipantUtils.resolveMultiSource(
              participants: participants,
              activeChannels: activeChannels,
            );

            final pinnedChannel = controller.pinnedChannel;

            if (pinnedChannel != null && activeChannels.length > 1) {
              return _PinnedLayout(
                controller: controller,
                sourceMap: sourceMap,
                pinnedChannel: pinnedChannel,
                activeChannels: activeChannels,
              );
            }

            return _GridLayout(
              controller: controller,
              sourceMap: sourceMap,
              activeChannels: activeChannels,
            );
          },
        );
      },
    );
  }
}

// ─── Grid Layout ───

class _GridLayout extends StatelessWidget {
  final VideoRoomController controller;
  final Map<String, Participant?> sourceMap;
  final Set<String> activeChannels;

  const _GridLayout({
    required this.controller,
    required this.sourceMap,
    required this.activeChannels,
  });

  @override
  Widget build(BuildContext context) {
    final channels = activeChannels.toList();
    final count = channels.length;

    if (count == 0) return const _WaitingPlaceholder();

    if (count == 1) {
      return _buildSingleTile(channels[0]);
    }

    if (count == 2) {
      return _buildSplitLayout(channels);
    }

    // 3 or 4 sources → 2×2 grid
    return _buildGridLayout(channels);
  }

  Widget _buildSingleTile(String channelId) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _StageTile(
        key: ValueKey('single_$channelId'),
        channelId: channelId,
        participant: sourceMap[channelId],
        isMainStage: true,
        controller: controller,
      ),
    );
  }

  Widget _buildSplitLayout(List<String> channels) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 2),
            child: _StageTile(
              key: ValueKey('split_${channels[0]}'),
              channelId: channels[0],
              participant: sourceMap[channels[0]],
              isMainStage: true,
              controller: controller,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 2),
            child: _StageTile(
              key: ValueKey('split_${channels[1]}'),
              channelId: channels[1],
              participant: sourceMap[channels[1]],
              isMainStage: true,
              controller: controller,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout(List<String> channels) {
    // Up to 4 tiles in a 2×2 grid
    final topRow = channels.take(2).toList();
    final bottomRow = channels.skip(2).take(2).toList();

    return Column(
      children: [
        Expanded(
          child: Row(
            children: topRow.map((ch) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _StageTile(
                    key: ValueKey('grid_$ch'),
                    channelId: ch,
                    participant: sourceMap[ch],
                    isMainStage: false,
                    controller: controller,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: bottomRow.length == 1
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: bottomRow.map((ch) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: _StageTile(
                    key: ValueKey('grid_$ch'),
                    channelId: ch,
                    participant: sourceMap[ch],
                    isMainStage: false,
                    controller: controller,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Pinned Layout (70/30) ───

class _PinnedLayout extends StatelessWidget {
  final VideoRoomController controller;
  final Map<String, Participant?> sourceMap;
  final String pinnedChannel;
  final Set<String> activeChannels;

  const _PinnedLayout({
    required this.controller,
    required this.sourceMap,
    required this.pinnedChannel,
    required this.activeChannels,
  });

  @override
  Widget build(BuildContext context) {
    final otherChannels =
        activeChannels.where((ch) => ch != pinnedChannel).toList();

    return Row(
      children: [
        // 70% — Pinned source (HIGH quality)
        Expanded(
          flex: 7,
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: _StageTile(
              key: ValueKey('pinned_$pinnedChannel'),
              channelId: pinnedChannel,
              participant: sourceMap[pinnedChannel],
              isMainStage: true,
              controller: controller,
              showPinBadge: true,
            ),
          ),
        ),
        // 30% — Other sources in vertical strip (LOW quality)
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.22,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: otherChannels.length,
            itemBuilder: (context, index) {
              final ch = otherChannels[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _StageTile(
                    key: ValueKey('side_$ch'),
                    channelId: ch,
                    participant: sourceMap[ch],
                    isMainStage: false,
                    controller: controller,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Individual Stage Tile ───

class _StageTile extends StatelessWidget {
  final String channelId;
  final Participant? participant;
  final bool isMainStage;
  final VideoRoomController controller;
  final bool showPinBadge;

  const _StageTile({
    super.key,
    required this.channelId,
    required this.participant,
    required this.isMainStage,
    required this.controller,
    this.showPinBadge = false,
  });

  String get _channelLabel {
    switch (channelId) {
      case 'teacher':
        return 'المعلم';
      case 'room-cam-right':
        return 'كاميرا القاعة 1';
      case 'room-cam-left':
        return 'كاميرا القاعة 2';
      case 'room-cam-screen':
        return 'الشاشة الرئيسية';
      case 'whiteboard':
        return 'السبورة';
      case 'screen-share':
        return 'مشاركة الشاشة';
      default:
        return channelId;
    }
  }

  IconData get _channelIcon {
    switch (channelId) {
      case 'teacher':
        return Icons.school_rounded;
      case 'whiteboard':
        return Icons.edit_note_rounded;
      case 'screen-share':
        return Icons.screen_share_rounded;
      default:
        return Icons.videocam_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Whiteboard: render as a special widget tile
    if (channelId == 'whiteboard') {
      return GestureDetector(
        onDoubleTap: () => controller.pinChannel(channelId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: isMainStage ? BorderRadius.zero : BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              const Positioned.fill(child: WhiteboardPanel()),
              _buildLabel(),
              if (showPinBadge) _buildPinIndicator(),
            ],
          ),
        ),
      );
    }

    // Screen share: render the screen share track
    if (channelId == 'screen-share' && participant != null) {
      return GestureDetector(
        onDoubleTap: () => controller.pinChannel(channelId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1014),
            borderRadius: isMainStage ? BorderRadius.zero : BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: ParticipantTile(
                  key: ValueKey('stage_screen_${participant!.identity}'),
                  participant: participant!,
                  isMainStage: isMainStage,
                  forceShowScreen: true,
                ),
              ),
              _buildLabel(),
              if (showPinBadge) _buildPinIndicator(),
            ],
          ),
        ),
      );
    }

    // Regular video tile (teacher / room cams)
    if (participant == null) {
      return _buildOfflinePlaceholder();
    }

    return GestureDetector(
      onDoubleTap: () => controller.pinChannel(channelId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1014),
          borderRadius: isMainStage ? BorderRadius.zero : BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: ParticipantTile(
                key: ValueKey('stage_${channelId}_${participant!.identity}'),
                participant: participant!,
                isMainStage: isMainStage,
                forceShowScreen: false,
              ),
            ),
            _buildLabel(),
            if (showPinBadge) _buildPinIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflinePlaceholder() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1B1F),
        borderRadius: isMainStage ? BorderRadius.zero : BorderRadius.circular(12),
        border: isMainStage
            ? null
            : Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.videocam_off_rounded,
                color: Colors.white.withOpacity(0.15),
                size: isMainStage ? 48 : 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _channelLabel,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: isMainStage ? 14 : 11,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'غير متصل',
              style: TextStyle(
                color: Colors.white.withOpacity(0.15),
                fontSize: isMainStage ? 12 : 9,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel() {
    return Positioned(
      bottom: 8,
      left: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_channelIcon, color: Colors.white70, size: 12),
                const SizedBox(width: 6),
                Text(
                  _channelLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPinIndicator() {
    return Positioned(
      top: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.9),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.push_pin_rounded, color: Colors.white, size: 11),
            SizedBox(width: 4),
            Text(
              'مثبت',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Waiting Placeholder ───

class _WaitingPlaceholder extends StatelessWidget {
  const _WaitingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'في انتظار المدرس...',
            style: TextStyle(
              color: Colors.white54,
              fontFamily: 'Cairo',
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
