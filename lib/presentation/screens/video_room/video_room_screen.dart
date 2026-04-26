import 'dart:async';
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
  bool _isChatOpen = false;
  
  final _messageController = TextEditingController();
  final _chatScrollController = ScrollController();
  final supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _messages = [];
  Timer? _chatTimer;

  @override
  void initState() {
    super.initState();
    _connectToRoom();
    // بدء تحديث الشات كل 3 ثوانٍ لضمان التفاعل اللحظي (Polling)
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isChatOpen) _fetchMessages(showLoading: false);
    });
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

  Future<void> _fetchMessages({bool showLoading = true}) async {
    try {
      final response = await supabase
          .from('messages')
          .select()
          .eq('room_name', widget.roomName)
          .order('created_at', ascending: true);
      
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
        });
        // النزول لآخر رسالة تلقائياً
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    } catch (e) {
      debugPrint("Chat fetch error: $e");
    }
  }

  void _sendMessage() async {
    if (_messageController.text.isEmpty) return;
    final content = _messageController.text;
    _messageController.clear();
    
    try {
      await supabase.from('messages').insert({
        'room_name': widget.roomName,
        'user_name': widget.userName,
        'content': content,
      });
      _fetchMessages(showLoading: false); // تحديث فوري بعد الإرسال
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("فشل إرسال الرسالة")));
    }
  }

  @override
  void dispose() {
    _room?.disconnect();
    _chatTimer?.cancel();
    _messageController.dispose();
    _chatScrollController.dispose();
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
              borderRadius: BorderRadius.circular(24),
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
                  onPressed: () {
                    setState(() => _isChatOpen = !_isChatOpen);
                    if (_isChatOpen) _fetchMessages();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                )
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
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("الدردشة الحية", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
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
              onSubmitted: (_) => _sendMessage(),
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
                    onPressed: () async {
                      await _room?.localParticipant?.setMicrophoneEnabled(!_isMicEnabled);
                      setState(() => _isMicEnabled = !_isMicEnabled);
                    },
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: _isCamEnabled ? IconlyBold.video : IconlyBold.hide,
                    color: _isCamEnabled ? Colors.white12 : Colors.red.withOpacity(0.8),
                    onPressed: () async {
                      await _room?.localParticipant?.setCameraEnabled(!_isCamEnabled);
                      setState(() => _isCamEnabled = !_isCamEnabled);
                    },
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
        // تحديد النوع يدوياً لضمان التعرف على الخصائص
        final List<Participant> participants = [
          if (room.localParticipant != null) ?room.localParticipant,
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
                                  (p.identity == room.localParticipant?.identity) ? "أنت" : p.identity,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (p.isSpeaking)
                                const Icon(Icons.graphic_eq_rounded, color: Colors.blue, size: 16)
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
