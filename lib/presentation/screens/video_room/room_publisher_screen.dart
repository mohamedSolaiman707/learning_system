import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../../core/services/livekit_service.dart';

class RoomPublisherScreen extends StatefulWidget {
  final String roomName;
  final String sessionId;

  const RoomPublisherScreen({
    super.key,
    required this.roomName,
    required this.sessionId,
  });

  @override
  State<RoomPublisherScreen> createState() => _RoomPublisherScreenState();
}

class _RoomPublisherScreenState extends State<RoomPublisherScreen> {
  Room? _roomRight;
  Room? _roomLeft;
  Room? _roomScreen;
  List<MediaDevice> _cameras = [];
  String? _selectedRight;
  String? _selectedLeft;
  String? _selectedScreen;
  bool _isPublishing = false;
  bool _isConnected = false;
  String _status = "جاري تحميل الكاميرات...";

  @override
  void initState() {
    super.initState();
    _initPublisher();
  }

  Future<void> _initPublisher() async {
    try {
      _cameras = await Hardware.instance.enumerateDevices();
      _cameras = _cameras.where((d) => d.kind == 'videoinput').toList();

      if (_cameras.isNotEmpty) {
        _selectedRight = _cameras[0].deviceId;
      }
      if (_cameras.length >= 2) {
        _selectedLeft = _cameras[1].deviceId;
      }
      if (_cameras.length >= 3) {
        _selectedScreen = _cameras[2].deviceId;
      }

      setState(() {
        _status = "الكاميرات جاهزة للإعداد";
      });
    } catch (e) {
      setState(() {
        _status = "خطأ في تحميل العتاد: $e";
      });
    }
  }

  @override
  void dispose() {
    _roomRight?.disconnect();
    _roomLeft?.disconnect();
    _roomScreen?.disconnect();
    super.dispose();
  }

  Future<void> _startPublishing() async {
    setState(() {
      _isPublishing = true;
      _status = "جاري الاتصال...";
    });

    try {
      // Connect 3 separate rooms with named identities
      await _connectCamera(
        identity: "roomcam_right",
        userName: "room-cam-right",
        deviceId: _selectedRight,
        roomRef: (r) => _roomRight = r,
      );

      await _connectCamera(
        identity: "roomcam_left",
        userName: "room-cam-left",
        deviceId: _selectedLeft,
        roomRef: (r) => _roomLeft = r,
      );

      await _connectCamera(
        identity: "roomcam_screen",
        userName: "room-cam-screen",
        deviceId: _selectedScreen,
        roomRef: (r) => _roomScreen = r,
      );

      setState(() {
        _isConnected = true;
        _status = "✅ البث نشط — الطلاب يشاهدون القاعة";
      });
    } catch (e) {
      setState(() {
        _isPublishing = false;
        _status = "❌ فشل الاتصال: $e";
      });
    }
  }

  Future<void> _connectCamera({
    required String identity,
    required String userName,
    required String? deviceId,
    required Function(Room) roomRef,
  }) async {
    if (deviceId == null) return;

    // Get token from Supabase edge function
    final token = await LiveKitService().getRoomCameraToken(
      roomName: widget.roomName,
      userId: identity,
      cameraName: userName,
    );
    if (token == null) throw Exception("Failed to get token for $userName");

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultVideoPublishOptions: VideoPublishOptions(
          videoEncoding: VideoEncoding(
            maxBitrate: 2000000,
            maxFramerate: 30,
          ),
          simulcast: false,
        ),
      ),
    );

    await room.connect(
      'wss://learning-system-academy-axo5qepz.livekit.cloud',
      token,
    );

    // Publish camera with specific deviceId
    final videoTrack = await LocalVideoTrack.createCameraTrack(
      CameraCaptureOptions(
        deviceId: deviceId,
        params: VideoParametersPresets.h720_169,
      ),
    );

    await room.localParticipant?.publishVideoTrack(videoTrack);
    roomRef(room);
  }

  Future<void> _stopPublishing() async {
    await _roomRight?.disconnect();
    await _roomLeft?.disconnect();
    await _roomScreen?.disconnect();
    _roomRight = null;
    _roomLeft = null;
    _roomScreen = null;
    setState(() {
      _isPublishing = false;
      _isConnected = false;
      _status = "تم إيقاف البث";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1014),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Text(
                  "لوحة تحكم كاميرات القاعة",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Cairo',
                  ),
                ),
                Text(
                  widget.roomName,
                  style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 40),
                Expanded(
                  child: ListView(
                    children: [
                      _buildCameraCard(
                        title: "كاميرا اليمين (room-cam-right)",
                        value: _selectedRight,
                        onChanged: (val) => setState(() => _selectedRight = val),
                      ),
                      _buildCameraCard(
                        title: "كاميرا الشمال (room-cam-left)",
                        value: _selectedLeft,
                        onChanged: (val) => setState(() => _selectedLeft = val),
                      ),
                      _buildCameraCard(
                        title: "شاشة القاعة (room-cam-screen)",
                        value: _selectedScreen,
                        onChanged: (val) => setState(() => _selectedScreen = val),
                      ),
                    ],
                  ),
                ),
                Text(
                  _status,
                  style: const TextStyle(color: Colors.blue, fontFamily: 'Cairo'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPublishing ? Colors.red : Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isPublishing ? _stopPublishing : _startPublishing,
                    child: Text(
                      _isPublishing ? "إيقاف البث" : "بدء البث",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraCard({
    required String title,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      color: const Color(0xFF1A1B1F),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              dropdownColor: const Color(0xFF1A1B1F),
              value: value,
              underline: const SizedBox(),
              items: _cameras.map((cam) {
                return DropdownMenuItem(
                  value: cam.deviceId,
                  child: Text(cam.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
                );
              }).toList(),
              onChanged: _isPublishing ? null : onChanged,
              hint: const Text("اختر الكاميرا", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? "متصل" : "غير متصل",
                  style: TextStyle(color: _isConnected ? Colors.green : Colors.grey, fontSize: 11, fontFamily: 'Cairo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
