import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../video_room_controller.dart';

class QAPanel extends StatefulWidget {
  const QAPanel({super.key});

  @override
  State<QAPanel> createState() => _QAPanelState();
}

class _QAPanelState extends State<QAPanel> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _send(VideoRoomController controller) {
    if (_controller.text.trim().isNotEmpty) {
      controller.sendQuestion(_controller.text.trim());
      _controller.clear();
      FocusScope.of(context).unfocus();
      _tabController.animateTo(2); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VideoRoomController>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          _buildHeader(controller),
          _buildTabs(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildQuestionList(controller, _getSortedQuestions(controller, "all")),
                _buildQuestionList(controller, _getSortedQuestions(controller, "popular")),
                _buildQuestionList(controller, _getSortedQuestions(controller, "mine")),
              ],
            ),
          ),
          _buildInput(controller),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getSortedQuestions(VideoRoomController controller, String type) {
    List<Map<String, dynamic>> list = List.from(controller.questions);
    if (type == "mine") return list.where((q) => q['from'] == controller.userName).toList();
    if (type == "popular") list = list.where((q) => (q['upvotes'] ?? 0) > 0).toList();
    
    list.sort((a, b) {
      if (a['id'] == controller.spotlightedQuestionId) return -1;
      if (b['id'] == controller.spotlightedQuestionId) return 1;

      // لوجيك "التقريب" للمدرس: الطالب الذي يرفع يده يقفز للأعلى
      if (controller.isTeacher) {
        bool handA = controller.remoteHandStates[a['senderId']] ?? false;
        bool handB = controller.remoteHandStates[b['senderId']] ?? false;
        if (handA && !handB) return -1;
        if (!handA && handB) return 1;
      }

      // لوجيك "التقريب" للطالب: سؤاله دائماً الأول
      final bool isMeA = a['from'] == controller.userName;
      final bool isMeB = b['from'] == controller.userName;
      if (isMeA && !isMeB) return -1;
      if (!isMeA && isMeB) return 1;

      return (b['upvotes'] ?? 0).compareTo(a['upvotes'] ?? 0);
    });
    return list;
  }

  Widget _buildQuestionList(VideoRoomController controller, List<Map<String, dynamic>> questions) {
    if (questions.isEmpty) return _buildEmptyState();
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final q = questions[index];
        final bool isTopThree = index < 3; // لتحديد ما إذا كان السؤال في "منطقة الرؤية"

        return _QuestionCard(
          q: q,
          isMe: q['from'] == controller.userName,
          isAnswered: q['is_answered'] ?? false,
          isSpotlighted: q['id'] == controller.spotlightedQuestionId,
          isHandRaised: controller.remoteHandStates[q['senderId']] ?? false,
          isTopInQueue: isTopThree,
          controller: controller,
          pulseAnimation: _pulseController,
        );
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 45, padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(15)),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
        labelColor: Colors.blue.shade700, unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'Cairo'),
        tabs: const [Tab(text: "الكل"), Tab(text: "الأكثر تفاعلاً"), Tab(text: "أسئلتي")],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.auto_awesome_motion_outlined, size: 70, color: Colors.grey.shade200),
      const SizedBox(height: 16),
      Text("لا توجد أسئلة هنا حالياً", style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontFamily: 'Cairo')),
    ]));
  }

  Widget _buildHeader(VideoRoomController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
      child: Row(children: [
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("ساحة النقاش", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, fontFamily: 'Cairo')),
          Text("تواصل مباشرة مع الأستاذ", style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Cairo')),
        ]),
        const Spacer(),
        IconButton(onPressed: controller.toggleQA, icon: const Icon(Icons.close_rounded, color: Colors.grey), style: IconButton.styleFrom(backgroundColor: Colors.grey.shade50))
      ]),
    );
  }

  Widget _buildInput(VideoRoomController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 35),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100))),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _controller,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14),
          decoration: InputDecoration(
            hintText: "اسأل الأستاذ شيئاً...",
            filled: true, fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          onSubmitted: (_) => _send(controller),
        )),
        const SizedBox(width: 12),
        GestureDetector(onTap: () => _send(controller), child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Colors.blue, Colors.blueAccent]), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
        )),
      ]),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Map<String, dynamic> q;
  final bool isMe;
  final bool isAnswered;
  final bool isSpotlighted;
  final bool isHandRaised;
  final bool isTopInQueue;
  final VideoRoomController controller;
  final Animation<double> pulseAnimation;

  const _QuestionCard({
    required this.q, required this.isMe, required this.isAnswered, 
    required this.isSpotlighted, required this.isHandRaised, 
    required this.isTopInQueue, required this.controller, required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              if (isMe || isSpotlighted) BoxShadow(
                color: (isMe ? Colors.blue : Colors.orange).withOpacity(0.2 * pulseAnimation.value),
                blurRadius: 15 * pulseAnimation.value,
                spreadRadius: 2 * pulseAnimation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: isMe ? LinearGradient(
            colors: [Colors.blue.shade50, Colors.white, Colors.blue.shade50.withOpacity(0.3)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ) : null,
          color: isSpotlighted ? Colors.orange.shade50 : (isAnswered ? Colors.green.shade50 : Colors.white),
          border: Border.all(
            color: isSpotlighted ? Colors.orange.shade300 : (isMe ? Colors.blue.shade300 : (isHandRaised ? Colors.amber.shade400 : Colors.grey.shade100)),
            width: (isMe || isSpotlighted) ? 2.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Stack(
            children: [
              if (isMe) Positioned(top: 0, right: 0, child: _buildMeBadge()),
              if (isHandRaised && !isMe) Positioned(top: 0, right: 0, child: _buildPriorityBadge()),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _buildAvatar(),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isMe ? "أنت (صاحب السؤال)" : q['from'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: isMe ? Colors.blue.shade900 : Colors.black87)),
                      if (isAnswered) Text("تمت الإجابة ✅", style: TextStyle(color: Colors.green.shade700, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ])),
                    if (isHandRaised) const Icon(Icons.back_hand, color: Colors.amber, size: 16),
                  ]),
                  const SizedBox(height: 15),
                  Text(q['text'], style: TextStyle(fontSize: 15, color: Colors.black.withOpacity(0.8), height: 1.6, fontFamily: 'Cairo')),
                  const SizedBox(height: 20),
                  Row(children: [
                    _buildVoteBtn(),
                    const Spacer(),
                    if (isMe && isTopInQueue) _buildVisibilityIndicator(),
                    if (controller.isTeacher) ...[
                       _buildActionBtn(isAnswered ? "تمت الإجابة" : "إجابة", isAnswered ? Colors.grey : Colors.green, Icons.check, () => controller.markQuestionAsAnswered(q['id'])),
                       const SizedBox(width: 8),
                       _buildActionBtn(isSpotlighted ? "إنهاء" : "تركيز", Colors.orange, Icons.wb_incandescent, () => controller.toggleQuestionSpotlight(q['id'])),
                    ]
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isMe ? Colors.blue : Colors.grey.shade200, width: 2)),
      child: CircleAvatar(radius: 15, backgroundColor: isMe ? Colors.blue : Colors.blue.shade50, child: Text(q['from'][0].toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.blue))),
    );
  }

  Widget _buildMeBadge() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: const BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15))), child: const Text("سؤالي ⚡", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')));
  }

  Widget _buildPriorityBadge() {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: const BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15))), child: const Text("أولوية تفاعلية 🔥", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')));
  }

  Widget _buildVisibilityIndicator() {
    return const Row(children: [
      Icon(Icons.visibility, color: Colors.blue, size: 14),
      SizedBox(width: 4),
      Text("المدرس يرى سؤالك الآن", style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
    ]);
  }

  Widget _buildVoteBtn() {
    final bool hasVotes = (q['upvotes'] ?? 0) > 0;
    return InkWell(onTap: () => controller.upvoteQuestion(q['id']), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: hasVotes ? Colors.blue.shade50 : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)), child: Row(children: [
      Icon(Icons.arrow_upward, size: 14, color: hasVotes ? Colors.blue : Colors.grey),
      const SizedBox(width: 4),
      Text("${q['upvotes'] ?? 0}", style: TextStyle(color: hasVotes ? Colors.blue : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
    ])));
  }

  Widget _buildActionBtn(String label, Color color, IconData icon, VoidCallback onTap) {
    return ElevatedButton.icon(onPressed: onTap, icon: Icon(icon, size: 12), label: Text(label, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo', fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }
}
