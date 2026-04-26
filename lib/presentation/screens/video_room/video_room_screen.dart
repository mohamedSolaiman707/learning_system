import 'dart:async';
import 'dart:convert';
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

class _VideoRoomScreenState extends State<VideoRoomScreen> with TickerProviderStateMixin {
  Room? _room;
  bool _isLoading = true;
  String? _errorMessage;
  
  bool _isMicEnabled = false;
  bool _isCamEnabled = false;
  bool _isHandRaised = false;
  bool _isChatOpen = false;
  bool _isScreenSharing = false;
  
  final _messageController = TextEditingController();
  final _chatScrollController = ScrollController();
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _messages = [];
  Timer? _chatTimer;
  
  final Map<String, bool> _remoteHandStates = {};
  final List<Widget> _reactionParticles = [];

  @override
  void initState() {
    super.initState();
    _connectToRoom();
    _chatTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_isChatOpen) _fetchMessages(showLoading: false);
    });
  }

  Future<void> _connectToRoom() async {
    try {
      final token = await LiveKitService().getRoomToken(widget.roomName, widget.userName);
      if (token == null) throw "فشل الحصول على التوكن";

      final room = Room();
      
      final listener = room.createListener();
      listener.on<DataReceivedEvent>((event) {
        final decoded = utf8.decode(event.data);
        final data = jsonDecode(decoded);
        if (data['type'] == 'hand_raise') {
          setState(() => _remoteHandStates[event.participant!.identity] = data['value']);
        } else if (data['type'] == 'reaction') {
          _showReactionEffect(data['value']);
        }
      });

      await room.connect('wss://learning-system-07wdu0v6.livekit.cloud', token, 
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true)
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

  void _sendData(Map<String, dynamic> data) async {
    if (_room == null) return;
    final bytes = utf8.encode(jsonEncode(data));
    await _room!.localParticipant?.publishData(bytes);
  }

  void _toggleHand() {
    final newState = !_isHandRaised;
    setState(() => _isHandRaised = newState);
    _sendData({'type': 'hand_raise', 'value': newState});
  }

  void _sendReaction(String emoji) {
    _sendData({'type': 'reaction', 'value': emoji});
    _showReactionEffect(emoji);
  }

  void _showReactionEffect(String emoji) {
    if (!mounted) return;
    final key = UniqueKey();
    setState(() {
      _reactionParticles.add(
        _FloatingEmoji(key: key, emoji: emoji, onFinished: () {
          if (mounted) setState(() => _reactionParticles.removeWhere((w) => w.key == key));
        })
      );
    });
  }

  Future<void> _toggleScreenShare() async {
    if (_room == null) return;
    try {
      final newState = !_isScreenSharing;
      await _room!.localParticipant?.setScreenShareEnabled(newState);
      setState(() => _isScreenSharing = newState);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("مشاركة الشاشة: $e")));
    }
  }

  Future<void> _fetchMessages({bool showLoading = true}) async {
    try {
      final response = await supabase.from('messages').select()
          .eq('room_name', widget.roomName).order('created_at', ascending: true);
      if (mounted) setState(() { _messages = List<Map<String, dynamic>>.from(response); });
    } catch (e) { debugPrint("Chat error: $e"); }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final content = _messageController.text;
    _messageController.clear();
    setState(() {
      _messages.add({'user_name': widget.userName, 'content': content, 'is_temp': true});
    });
    await supabase.from('messages').insert({'room_name': widget.roomName, 'user_name': widget.userName, 'content': content});
  }

  @override
  void dispose() {
    _room?.disconnect();
    _chatTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: _isLoading 
          ? _buildModernLoading()
          : Stack(
              children: [
                if (_room != null) ParticipantGrid(room: _room!, remoteHands: _remoteHandStates, localHand: _isHandRaised),
                ..._reactionParticles,
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
          const Text("جاري تحضير القاعة التعليمية...", style: TextStyle(color: Colors.white, fontSize: 14)),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white10)),
            child: Row(
              children: [
                const Icon(Icons.circle, color: Colors.red, size: 8),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                _buildReactionBtn("❤️"),
                _buildReactionBtn("👏"),
                _buildReactionBtn("🔥"),
                const SizedBox(width: 8),
                IconButton(icon: Icon(IconlyLight.chat, color: _isChatOpen ? Colors.blue : Colors.white70), onPressed: () => setState(() => _isChatOpen = !_isChatOpen)),
                IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionBtn(String emoji) {
    return InkWell(
      onTap: () => _sendReaction(emoji),
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text(emoji, style: const TextStyle(fontSize: 20))),
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
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) => _buildMessageBubble(_messages[i]),
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
          Text(msg['user_name'] ?? "", style: TextStyle(color: isMe ? Colors.blue : Colors.grey, fontSize: 10)),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: isMe ? Colors.blue : Colors.white10, borderRadius: BorderRadius.circular(12)),
            child: Text(msg['content'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 13)),
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
          Expanded(child: TextField(
            controller: _messageController, 
            style: const TextStyle(color: Colors.black), 
            decoration: InputDecoration(
              hintText: "اكتب...", 
              filled: true, 
              fillColor: Colors.white, 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
            ),
            onSubmitted: (_) => _sendMessage(),
          )),
          IconButton(onPressed: _sendMessage, icon: const Icon(IconlyBold.send, color: Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 40, left: 0, right: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCircleBtn(_isMicEnabled ? IconlyBold.voice : IconlyBold.voice_2, _isMicEnabled ? Colors.white12 : Colors.red, () async {
            await _room?.localParticipant?.setMicrophoneEnabled(!_isMicEnabled);
            setState(() => _isMicEnabled = !_isMicEnabled);
          }),
          const SizedBox(width: 16),
          _buildCircleBtn(_isCamEnabled ? IconlyBold.video : IconlyBold.hide, _isCamEnabled ? Colors.white12 : Colors.red, () async {
            await _room?.localParticipant?.setCameraEnabled(!_isCamEnabled);
            setState(() => _isCamEnabled = !_isCamEnabled);
          }),
          const SizedBox(width: 16),
          _buildCircleBtn(Icons.back_hand, _isHandRaised ? Colors.orange : Colors.white12, _toggleHand),
          const SizedBox(width: 16),
          _buildCircleBtn(Icons.screen_share, _isScreenSharing ? Colors.green : Colors.white12, _toggleScreenShare),
          const SizedBox(width: 32),
          _buildCircleBtn(IconlyBold.call_missed, Colors.red, () => Navigator.pop(context), isLarge: true),
        ],
      ),
    );
  }

  Widget _buildCircleBtn(IconData icon, Color color, VoidCallback onTap, {bool isLarge = false}) {
    return InkWell(onTap: onTap, child: Container(padding: EdgeInsets.all(isLarge ? 18 : 14), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icon, color: Colors.white, size: isLarge ? 30 : 22)));
  }
}

class ParticipantGrid extends StatelessWidget {
  final Room room;
  final Map<String, bool> remoteHands;
  final bool localHand;
  const ParticipantGrid({super.key, required this.room, required this.remoteHands, required this.localHand});

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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, mainAxisSpacing: 15, crossAxisSpacing: 15),
          itemCount: participants.length,
          itemBuilder: (context, i) {
            final p = participants[i];
            final bool isLocal = room.localParticipant != null && p.identity == room.localParticipant!.identity;
            final bool isHandUp = isLocal ? localHand : (remoteHands[p.identity] ?? false);
            final videoTrack = p.videoTrackPublications.isEmpty ? null : p.videoTrackPublications.first.track as VideoTrack?;
            
            return AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: p.isSpeaking ? Colors.blue : (isHandUp ? Colors.orange : Colors.white10), width: 3),
                boxShadow: p.isSpeaking ? [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 15)] : [],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (videoTrack != null) VideoTrackRenderer(videoTrack, fit: VideoViewFit.contain)
                  else Container(color: Colors.black, child: const Center(child: Icon(IconlyBold.profile, color: Colors.white24, size: 45))),
                  
                  if (isHandUp) Positioned(top: 12, right: 12, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle), child: const Icon(Icons.back_hand, color: Colors.white, size: 18))),

                  Positioned(bottom: 12, left: 12, right: 12, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), color: Colors.black45, child: Row(children: [Expanded(child: Text(isLocal ? "أنت" : p.identity, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))), if (p.isSpeaking) const Icon(Icons.graphic_eq, color: Colors.blue, size: 16)]))),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FloatingEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onFinished;
  const _FloatingEmoji({super.key, required this.emoji, required this.onFinished});

  @override
  State<_FloatingEmoji> createState() => _FloatingEmojiState();
}

class _FloatingEmojiState extends State<_FloatingEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _startX;

  @override
  void initState() {
    super.initState();
    _startX = 100.0 + (DateTime.now().millisecond % 200);
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _controller.forward().then((_) => widget.onFinished());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double progress = _controller.value;
        return Positioned(
          bottom: 100 + (progress * 500),
          left: _startX + (progress * 50 * (progress % 2 == 0 ? 1 : -1)),
          child: Opacity(opacity: 1 - progress, child: Text(widget.emoji, style: const TextStyle(fontSize: 40))),
        );
      },
    );
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}
