import 'dart:ui';
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
  
  bool _isMicEnabled = false;
  bool _isCamEnabled = false;
  bool _isHandRaised = false;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
  }

  Future<void> _connectToRoom() async {
    try {
      final token = await LiveKitService().getRoomToken(widget.roomName, widget.userName);
      
      if (token == null) {
        setState(() { _errorMessage = "فشل في الحصول على توكن الدخول"; _isLoading = false; });
        return;
      }

      final room = Room();
      // إعدادات لتقليل زمن التأخير (Latency)
      await room.connect('wss://learning-system-07wdu0v6.livekit.cloud', token, 
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultVideoPublishOptions: VideoPublishOptions(simulcast: true),
        )
      );
      
      if (widget.userName.contains('Teacher')) {
        await room.localParticipant?.setCameraEnabled(true);
        await room.localParticipant?.setMicrophoneEnabled(true);
        if (mounted) setState(() { _isMicEnabled = true; _isCamEnabled = true; });
      }

      setState(() { _room = room; _isLoading = false; });
      
    } catch (e) {
      setState(() { _errorMessage = "خطأ في الاتصال: $e"; _isLoading = false; });
    }
  }

  void _toggleMic() async {
    if (_room == null) return;
    final newState = !_isMicEnabled;
    await _room!.localParticipant?.setMicrophoneEnabled(newState);
    setState(() => _isMicEnabled = newState);
  }

  void _toggleCamera() async {
    if (_room == null) return;
    final newState = !_isCamEnabled;
    await _room!.localParticipant?.setCameraEnabled(newState);
    setState(() => _isCamEnabled = newState);
  }

  void _toggleHandRaise() {
    setState(() => _isHandRaised = !_isHandRaised);
    // إرسال إشارة لبقية المشاركين (يمكن تطويرها عبر DataChannel لاحقاً)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isHandRaised ? "قمت برفع يدك للمشاركة ✋" : "أنزلت يدك"),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _room?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C10),
      body: _isLoading 
          ? _buildModernLoading()
          : _errorMessage != null
            ? _buildErrorView()
            : Stack(
                children: [
                  // خلفية متدرجة فخمة
                  _buildBackground(),
                  
                  // عرض المشاركين بتصميم Grid ذكي
                  if (_room != null) ParticipantGrid(room: _room!),
                  
                  // شريط العنوان العلوي (Glassmorphism)
                  _buildHeader(),

                  // شريط التحكم السفلي (Floating)
                  _buildBottomControls(),
                ],
              ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.5,
          colors: [Color(0xFF1C1F26), Color(0xFF0B0C10)],
        ),
      ),
    );
  }

  Widget _buildModernLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
          const SizedBox(height: 20),
          Text("جاري تحضير القاعة التعليمية...", style: TextStyle(color: Colors.blue.shade100, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(IconlyBold.danger, color: Colors.red, size: 50),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("رجوع"))
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 50,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.white.withOpacity(0.05),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.sensors, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("بث مباشر • ${_room?.remoteParticipants.length ?? 0} مشارك", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(35),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(35),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: _isMicEnabled ? IconlyBold.voice : IconlyBold.voice_2,
                    color: _isMicEnabled ? Colors.white12 : Colors.red.withOpacity(0.7),
                    onPressed: _toggleMic,
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: _isCamEnabled ? IconlyBold.video : IconlyBold.hide,
                    color: _isCamEnabled ? Colors.white12 : Colors.red.withOpacity(0.7),
                    onPressed: _toggleCamera,
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.back_hand_rounded,
                    color: _isHandRaised ? Colors.orange : Colors.white12,
                    onPressed: _toggleHandRaise,
                  ),
                  const SizedBox(width: 30),
                  _buildActionButton(
                    icon: IconlyBold.call_missed,
                    color: Colors.red,
                    onPressed: () => Navigator.pop(context),
                    isBig: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed, bool isBig = false}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(50),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.all(isBig ? 18 : 14),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: isBig ? 30 : 22),
      ),
    );
  }
}

class ParticipantGrid extends StatelessWidget {
  final Room room;
  const ParticipantGrid({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final List<Participant> allParticipants = [
          ?room.localParticipant,
          ...room.remoteParticipants.values,
        ];

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 140, 20, 140),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
          ),
          itemCount: allParticipants.length,
          itemBuilder: (context, index) {
            final participant = allParticipants[index];
            final videoTrack = participant.videoTrackPublications.isEmpty 
                ? null 
                : participant.videoTrackPublications.first.track as VideoTrack?;
            
            final bool isSpeaking = participant.isSpeaking;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isSpeaking ? Colors.blue : Colors.white.withOpacity(0.05),
                  width: 3,
                ),
                boxShadow: isSpeaking ? [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 20)] : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Stack(
                  children: [
                    if (videoTrack != null)
                      VideoTrackRenderer(videoTrack, fit: VideoViewFit.contain)
                    else
                      Container(
                        color: const Color(0xFF1A1D24),
                        child: Center(
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.blue.withOpacity(0.05),
                            child: Text(
                              participant.identity.isNotEmpty ? participant.identity[0].toUpperCase() : "?",
                              style: const TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    
                    // شريط معلومات المشارك (Blur)
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: Colors.black45,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    participant.identity == room.localParticipant?.identity ? "أنت" : participant.identity,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                if (isSpeaking)
                                  const Icon(Icons.graphic_eq_rounded, color: Colors.blue, size: 16)
                                else if (!participant.isMicrophoneEnabled())
                                  const Icon(Icons.mic_off_rounded, color: Colors.red, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
