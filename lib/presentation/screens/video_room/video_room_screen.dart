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
  final bool isTeacher;

  const VideoRoomScreen({
    super.key, 
    required this.title,
    required this.roomName,
    required this.userName,
    this.isTeacher = false,
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
  bool _isParticipantsOpen = false;
  bool _isPollsOpen = false;
  bool _isScreenSharing = false;
  bool _isChatLocked = false;

  // Poll State
  Map<String, dynamic>? _activePoll;
  Map<String, int> _pollResults = {};
  String? _myVote;
  
  final _messageController = TextEditingController();
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _messages = [];
  Timer? _chatTimer;
  
  final Map<String, bool> _remoteHandStates = {};
  final List<Widget> _reactionParticles = [];

  @override
  void initState() {
    super.initState();
    _connectToRoom();
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isChatOpen) _fetchMessages();
    });
  }

  Future<void> _connectToRoom() async {
    try {
      final token = await LiveKitService().getRoomToken(widget.roomName, widget.userName);
      if (token == null) throw "فشل الحصول على تصريح الدخول (Token)";

      final room = Room();
      final listener = room.createListener();
      
      listener.on<DataReceivedEvent>((event) {
        final decoded = utf8.decode(event.data);
        final data = jsonDecode(decoded);
        
        if (data['type'] == 'poll_create') {
          setState(() {
            _activePoll = data['poll'];
            _pollResults = { for (var item in data['poll']['options']) item : 0 };
            _myVote = null;
            _isPollsOpen = true;
          });
        } else if (data['type'] == 'poll_vote') {
          setState(() {
            final option = data['option'];
            _pollResults[option] = (_pollResults[option] ?? 0) + 1;
          });
        } else if (data['type'] == 'hand_raise') {
          setState(() => _remoteHandStates[event.participant!.identity] = data['value']);
        } else if (data['type'] == 'reaction') {
          _showReactionEffect(data['value']);
        } else if (data['type'] == 'control_mic' && (data['target'] == widget.userName || data['target'] == null)) {
          if (!widget.isTeacher) {
            _room?.localParticipant?.setMicrophoneEnabled(data['value']);
            setState(() => _isMicEnabled = data['value']);
          }
        } else if (data['type'] == 'control_chat') {
          setState(() => _isChatLocked = data['value']);
        }
      });

      await room.connect('wss://learning-system-07wdu0v6.livekit.cloud', token);
      
      if (widget.isTeacher) {
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

  void _createPoll(String question, List<String> options) {
    final pollData = {
      'question': question,
      'options': options,
      'creator': widget.userName,
    };
    _sendData({'type': 'poll_create', 'poll': pollData});
    setState(() {
      _activePoll = pollData;
      _pollResults = { for (var item in options) item : 0 };
    });
  }

  void _submitVote(String option) {
    if (_myVote != null) return;
    _sendData({'type': 'poll_vote', 'option': option});
    setState(() {
      _myVote = option;
      _pollResults[option] = (_pollResults[option] ?? 0) + 1;
    });
  }

  void _showReactionEffect(String emoji) {
    if (!mounted) return;
    final key = UniqueKey();
    setState(() {
      _reactionParticles.add(_FloatingEmoji(key: key, emoji: emoji, onFinished: () {
        if (mounted) setState(() => _reactionParticles.removeWhere((w) => w.key == key));
      }));
    });
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await supabase.from('messages').select().eq('room_name', widget.roomName).order('created_at', ascending: true).limit(50);
      if (mounted) setState(() { _messages = List<Map<String, dynamic>>.from(response); });
    } catch (e) { debugPrint("Chat error: $e"); }
  }

  void _sendMessage() async {
    if (_isChatLocked && !widget.isTeacher) return;
    if (_messageController.text.isEmpty) return;
    final content = _messageController.text;
    _messageController.clear();
    try {
      await supabase.from('messages').insert({'room_name': widget.roomName, 'user_name': widget.userName, 'content': content});
      _fetchMessages();
    } catch (e) { debugPrint("Insert error: $e"); }
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
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (_room != null) ParticipantLayout(
                  room: _room!, 
                  remoteHands: _remoteHandStates, 
                  localHand: _isHandRaised,
                  isTeacher: widget.isTeacher,
                  onControlMic: (id, val) => _sendData({'type': 'control_mic', 'target': id, 'value': val}),
                ),
                ..._reactionParticles,
                if (_isChatOpen) _buildChatPanel(),
                if (_isParticipantsOpen) _buildParticipantsPanel(),
                if (_isPollsOpen) _buildPollsPanel(),
                _buildTopBar(),
                _buildBottomControls(),
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
                Expanded(child: Text(widget.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                IconButton(icon: Icon(IconlyLight.graph, color: _isPollsOpen ? Colors.blue : Colors.white70), onPressed: () => setState(() { _isPollsOpen = !_isPollsOpen; _isChatOpen = false; _isParticipantsOpen = false; })),
                IconButton(icon: Icon(IconlyLight.user_1, color: _isParticipantsOpen ? Colors.blue : Colors.white70), onPressed: () => setState(() { _isParticipantsOpen = !_isParticipantsOpen; _isChatOpen = false; _isPollsOpen = false; })),
                IconButton(icon: Icon(IconlyLight.chat, color: _isChatOpen ? Colors.blue : Colors.white70), onPressed: () => setState(() { _isChatOpen = !_isChatOpen; _isParticipantsOpen = false; _isPollsOpen = false; })),
                IconButton(icon: const Icon(Icons.logout_rounded, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPollsPanel() {
    return Positioned(
      top: 110, right: 20, bottom: 120,
      child: Container(
        width: 300,
        decoration: BoxDecoration(color: const Color(0xFF1C1F26).withOpacity(0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(16), child: Text("التصويت المباشر", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            if (_activePoll == null && widget.isTeacher) _buildPollCreator(),
            if (_activePoll != null) _buildActivePoll(),
            if (_activePoll == null && !widget.isTeacher) const Center(child: Text("لا يوجد تصويت حالياً", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildPollCreator() {
    final qController = TextEditingController();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(controller: qController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "السؤال...", hintStyle: TextStyle(color: Colors.grey))),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: () => _createPoll(qController.text, ["نعم", "لا", "غير متأكد"]), child: const Text("بدء التصويت")),
        ],
      ),
    );
  }

  Widget _buildActivePoll() {
    int total = _pollResults.values.fold(0, (sum, val) => sum + val);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_activePoll!['question'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...(_activePoll!['options'] as List).map((opt) {
            double percent = total == 0 ? 0 : (_pollResults[opt] ?? 0) / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _submitVote(opt),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(opt, style: TextStyle(color: _myVote == opt ? Colors.blue : Colors.white70, fontSize: 13)),
                        Text("${(percent * 100).toInt()}%", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: percent, backgroundColor: Colors.white10, color: _myVote == opt ? Colors.blue : Colors.blue.withOpacity(0.3)),
                  ],
                ),
              ),
            );
          }),
          if (widget.isTeacher) ...[
             const SizedBox(height: 16),
             TextButton(onPressed: () => setState(() => _activePoll = null), child: const Text("إنهاء التصويت", style: TextStyle(color: Colors.red))),
          ]
        ],
      ),
    );
  }

  Widget _buildParticipantsPanel() {
    final participants = [if (_room?.localParticipant != null) _room!.localParticipant!, ..._room?.remoteParticipants.values ?? []];
    return Positioned(
      top: 110, right: 20, bottom: 120,
      child: Container(
        width: 280,
        decoration: BoxDecoration(color: const Color(0xFF1C1F26).withOpacity(0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
        child: ListView.builder(
          itemCount: participants.length,
          itemBuilder: (context, i) {
            final p = participants[i];
            return ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.white10, radius: 15),
              title: Text(p.identity, style: const TextStyle(color: Colors.white, fontSize: 13)),
              trailing: Icon(p.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off, color: p.isMicrophoneEnabled() ? Colors.green : Colors.red, size: 16),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return Positioned(
      top: 110, right: 20, bottom: 120,
      child: Container(
        width: 300,
        decoration: BoxDecoration(color: const Color(0xFF1C1F26).withOpacity(0.95), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white10)),
        child: Column(
          children: [
            Expanded(child: ListView.builder(itemCount: _messages.length, itemBuilder: (context, i) => _buildMessageBubble(_messages[i]))),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                Expanded(child: TextField(controller: _messageController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "دردشة...", hintStyle: TextStyle(color: Colors.grey)))),
                IconButton(onPressed: _sendMessage, icon: const Icon(IconlyBold.send, color: Colors.blue)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    bool isMe = msg['user_name'] == widget.userName;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
        Text(msg['user_name'] ?? "", style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isMe ? Colors.blue : Colors.white10, borderRadius: BorderRadius.circular(12)), child: Text(msg['content'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 12))),
      ]),
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
          _buildCircleBtn(Icons.back_hand, _isHandRaised ? Colors.orange : Colors.white12, () {
             final newState = !_isHandRaised;
             setState(() => _isHandRaised = newState);
             _sendData({'type': 'hand_raise', 'value': newState});
          }),
          const SizedBox(width: 16),
          _buildCircleBtn(Icons.screen_share, _isScreenSharing ? Colors.green : Colors.white12, () async {
            final newState = !_isScreenSharing;
            await _room?.localParticipant?.setScreenShareEnabled(newState);
            setState(() => _isScreenSharing = newState);
          }),
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

class ParticipantLayout extends StatelessWidget {
  final Room room;
  final Map<String, bool> remoteHands;
  final bool localHand;
  final bool isTeacher;
  final Function(String, bool) onControlMic;

  const ParticipantLayout({super.key, required this.room, required this.remoteHands, required this.localHand, required this.isTeacher, required this.onControlMic});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: room,
      builder: (context, _) {
        final participants = [if (room.localParticipant != null) room.localParticipant!, ...room.remoteParticipants.values];
        TrackPublication? screenSharePub;
        for (var p in participants) {
          final pub = p.videoTrackPublications.where((pub) => pub.source == TrackSource.screenShareVideo).firstOrNull;
          if (pub?.track != null) { screenSharePub = pub; break; }
        }

        return Column(
          children: [
            const SizedBox(height: 120),
            if (screenSharePub != null)
              Expanded(flex: 4, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green, width: 2), color: Colors.black), clipBehavior: Clip.antiAlias, child: VideoTrackRenderer(screenSharePub.track as VideoTrack, fit: VideoViewFit.contain)))),
            Expanded(
              flex: 2,
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: screenSharePub != null ? 3 : 2, childAspectRatio: 1.0, mainAxisSpacing: 10, crossAxisSpacing: 10),
                itemCount: participants.length,
                itemBuilder: (context, i) {
                  final p = participants[i];
                  final bool isLocal = room.localParticipant != null && p.identity == room.localParticipant!.identity;
                  final bool isHandUp = isLocal ? localHand : (remoteHands[p.identity] ?? false);
                  final cameraPub = p.videoTrackPublications.where((pub) => pub.source == TrackSource.camera).firstOrNull;
                  VideoTrack? cameraTrack = cameraPub?.track as VideoTrack?;

                  return Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), border: Border.all(color: p.isSpeaking ? Colors.blue : (isHandUp ? Colors.orange : Colors.white10), width: 2)),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        if (cameraTrack != null) VideoTrackRenderer(cameraTrack, fit: VideoViewFit.cover)
                        else Container(color: Colors.black, child: const Center(child: Icon(IconlyBold.profile, color: Colors.white24, size: 30))),
                        if (isHandUp) Positioned(top: 8, right: 8, child: const Icon(Icons.back_hand, color: Colors.orange, size: 16)),
                        if (isTeacher && !isLocal) Positioned(top: 5, left: 5, child: GestureDetector(onTap: () => onControlMic(p.identity, !p.isMicrophoneEnabled()), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: (p.isMicrophoneEnabled() ? Colors.green : Colors.red).withOpacity(0.8), shape: BoxShape.circle), child: Icon(p.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off, color: Colors.white, size: 14)))),
                        Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), color: Colors.black45, child: Text(isLocal ? "أنت" : p.identity, style: const TextStyle(color: Colors.white, fontSize: 10)))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 100),
          ],
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
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _controller.forward().then((_) => widget.onFinished());
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(bottom: 100 + (_controller.value * 500), left: 100 + (_controller.value * 50), child: Opacity(opacity: 1 - _controller.value, child: Text(widget.emoji, style: const TextStyle(fontSize: 40))));
      },
    );
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
}
