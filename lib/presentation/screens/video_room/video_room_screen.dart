import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconly/iconly.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  bool _isChatOpen = false;
  final _messageController = TextEditingController();
  final supabase = Supabase.instance.client;

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

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final content = _messageController.text;
    _messageController.clear();
    await supabase.from('messages').insert({
      'room_name': widget.roomName,
      'user_name': widget.userName,
      'content': content,
    });
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
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: _isLoading 
          ? _buildModernLoading()
          : _errorMessage != null
            ? _buildErrorView()
            : Stack(
                children: [
                  if (_room != null) ParticipantGrid(room: _room!),
                  
                  if (_isChatOpen) _buildChatPanel(),

                  _buildTopBar(),

                  _buildBottomControls(),
                ],
              ),
    );
  }

  Widget _buildModernLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.blue, strokeWidth: 2),
          const SizedBox(height: 24),
          Text("جاري تحضير القاعة التعليمية...", style: TextStyle(color: Colors.blue.shade100, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(IconlyBold.danger, color: Colors.red, size: 60),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("العودة للرئيسية"))
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 40, left: 20, right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.red, size: 10),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                IconButton(
                  icon: Icon(IconlyLight.chat, color: _isChatOpen ? Colors.blue : Colors.white70),
                  onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
                ),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return Positioned(
      top: 110, right: 20, bottom: 120,
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F26).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text("الدردشة الحية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            Expanded(
              child: StreamBuilder(
                stream: supabase.from('messages').stream(primaryKey: ['id']).eq('room_name', widget.roomName).order('created_at', ascending: true),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final messages = snapshot.data!;
                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) => _buildMessageBubble(messages[i]),
                  );
                },
              ),
            ),
            _buildChatInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isMe = msg['user_name'] == widget.userName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(msg['user_name'], style: TextStyle(color: isMe ? Colors.blue : Colors.grey, fontSize: 10)),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe ? Colors.blue : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(msg['content'], style: const TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInput() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "اكتب رسالة...",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          IconButton(onPressed: _sendMessage, icon: const Icon(IconlyBold.send, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40, left: 20, right: 20,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(
                    icon: _isMicEnabled ? IconlyBold.voice : IconlyBold.voice_2,
                    color: _isMicEnabled ? Colors.white12 : Colors.red.withOpacity(0.8),
                    onPressed: _toggleMic,
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: _isCamEnabled ? IconlyBold.video : IconlyBold.hide,
                    color: _isCamEnabled ? Colors.white12 : Colors.red.withOpacity(0.8),
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
        child: Icon(icon, color: Colors.white, size: isBig ? 32 : 22),
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
        final List<Participant> participants = [
          if (room.localParticipant != null) room.localParticipant!,
          ...room.remoteParticipants.values
        ];

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 140, 20, 140),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.82,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
          ),
          itemCount: participants.length,
          itemBuilder: (context, i) {
            final p = participants[i];
            final track = p.videoTrackPublications.isEmpty 
                ? null 
                : p.videoTrackPublications.first.track as VideoTrack?;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: p.isSpeaking ? Colors.blue.shade400 : Colors.white.withOpacity(0.08),
                  width: 3,
                ),
                boxShadow: p.isSpeaking ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 25)] : [],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (track != null) 
                    VideoTrackRenderer(track, fit: VideoViewFit.contain)
                  else 
                    Container(
                      color: const Color(0xFF1A1D24),
                      child: Center(
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.blue.withOpacity(0.08),
                          child: Text(
                            p.identity.isNotEmpty ? p.identity[0].toUpperCase() : "?",
                            style: const TextStyle(fontSize: 32, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  
                  Positioned(
                    bottom: 12, left: 12, right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          color: Colors.black38,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (room.localParticipant != null && p.identity == room.localParticipant!.identity) ? "أنت" : p.identity,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (p.isSpeaking)
                                const Icon(Icons.graphic_eq_rounded, color: Colors.blue, size: 18)
                              else if (!p.isMicrophoneEnabled())
                                const Icon(Icons.mic_off_rounded, color: Colors.red, size: 16),
                            ],
                          ),
                        ),
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
