import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/services/livekit_service.dart';

class VideoRoomScreen extends StatefulWidget {
  final String title;
  final String roomName;
  final String userName;

  const VideoRoomScreen({
    super.key, 
    required this.title,
    required this.roomName,
    required this.userName,
  });

  @override
  State<VideoRoomScreen> createState() => _VideoRoomScreenState();
}

class _VideoRoomScreenState extends State<VideoRoomScreen> {
  Room? _room;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    try {
      final token = await LiveKitService().getRoomToken(widget.roomName, widget.userName);
      
      if (token == null) {
        setState(() {
          _errorMessage = "فشل في الحصول على توكن الدخول";
          _isLoading = false;
        });
        return;
      }

      const liveKitUrl = 'wss://learning-system-07wdu0v6.livekit.cloud';
      
      final room = Room();
      await room.connect(liveKitUrl, token);
      
      setState(() {
        _room = room;
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _errorMessage = "حدث خطأ أثناء الاتصال: $e";
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title, style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)))
            : Stack(
                children: [
                  if (_room != null)
                    ParticipantLoop(room: _room!),
                  
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: _buildControls(),
                  ),
                ],
              ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildControlButton(
          icon: IconlyBold.voice,
          color: Colors.white24,
          onPressed: () => _room?.localParticipant?.setMicrophoneEnabled(true),
        ),
        const SizedBox(width: 16),
        _buildControlButton(
          icon: IconlyBold.video,
          color: Colors.white24,
          onPressed: () => _room?.localParticipant?.setCameraEnabled(true),
        ),
        const SizedBox(width: 32),
        _buildControlButton(
          icon: IconlyBold.call_missed,
          color: Colors.red,
          onPressed: () => Navigator.pop(context),
          isEndCall: true,
        ),
      ],
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onPressed, bool isEndCall = false}) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: isEndCall ? 32 : 24),
      ),
    );
  }
}

class ParticipantLoop extends StatelessWidget {
  final Room room;
  const ParticipantLoop({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        // نجمع كل المشاركين (المدرس والطلاب الآخرين)
        final participants = room.remoteParticipants.values.toList();
        
        if (participants.isEmpty) {
          return const Center(
            child: Text("بانتظار دخول المدرس...", style: TextStyle(color: Colors.white54)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1, // عرض فيديو واحد كبير (للمدرس)
            childAspectRatio: 16 / 9,
          ),
          itemCount: participants.length,
          itemBuilder: (context, index) {
            final participant = participants[index];
            return Card(
              color: Colors.grey[900],
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // عرض فيديو المشارك
                  VideoTrackRenderer(
                    participant.videoTrackPublications.firstOrNull?.track as VideoTrack,
                    fit: VideoViewFit.contain,
                  ),
                  // اسم المشارك في الأسفل
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      color: Colors.black54,
                      child: Text(
                        participant.identity ?? "مشارك",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
