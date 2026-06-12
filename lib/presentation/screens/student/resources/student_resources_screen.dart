// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:url_launcher/url_launcher.dart';
//
// class StudentResourcesScreen extends StatefulWidget {
//   final String sessionId;
//   final String subjectName;
//
//   const StudentResourcesScreen({
//     super.key,
//     required this.sessionId,
//     required this.subjectName,
//   });
//
//   @override
//   State<StudentResourcesScreen> createState() => _StudentResourcesScreenState();
// }
//
// class _StudentResourcesScreenState extends State<StudentResourcesScreen> {
//   final supabase = Supabase.instance.client;
//   List<Map<String, dynamic>> _resources = [];
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadResources();
//   }
//
//   Future<void> _loadResources() async {
//     setState(() => _isLoading = true);
//     try {
//       final response = await supabase
//           .from('resources')
//           .select()
//           .eq('session_id', widget.sessionId)
//           .order('created_at', ascending: false);
//       setState(() {
//         _resources = List<Map<String, dynamic>>.from(response);
//         _isLoading = false;
//       });
//     } catch (e) {
//       debugPrint("Error: $e");
//       setState(() => _isLoading = false);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FB),
//       appBar: AppBar(
//         title: Text("مكتبة: ${widget.subjectName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
//         backgroundColor: Colors.white,
//         elevation: 0,
//         iconTheme: const IconThemeData(color: Colors.black),
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
//           : _resources.isEmpty
//               ? _buildEmptyState()
//               : ListView.builder(
//                   padding: const EdgeInsets.all(20),
//                   itemCount: _resources.length,
//                   itemBuilder: (context, index) {
//                     final res = _resources[index];
//                     return Container(
//                       margin: const EdgeInsets.only(bottom: 12),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
//                       ),
//                       child: ListTile(
//                         leading: _buildFileIcon(res['file_type']),
//                         title: Text(res['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
//                         subtitle: Text("${res['file_type']?.toString().toUpperCase()} • ${res['created_at'].toString().split('T')[0]}", style: const TextStyle(fontSize: 12)),
//                         trailing: IconButton(
//                           icon: const Icon(Icons.download_outlined, color: Colors.blue),
//                           onPressed: () => launchUrl(Uri.parse(res['file_url'])),
//                         ),
//                       ),
//                     );
//                   },
//                 ),
//     );
//   }
//
//   Widget _buildFileIcon(String? type) {
//     IconData icon = Icons.description_outlined;
//     Color color = Colors.blue;
//     if (type == 'pdf') { icon = Icons.picture_as_pdf_outlined; color = Colors.red; }
//     return Container(
//       padding: const EdgeInsets.all(8),
//       decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
//       child: Icon(icon, color: color, size: 24),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.folder_open_outlined, size: 60, color: Colors.grey.shade300),
//           const SizedBox(height: 16),
//           const Text("لا توجد ملفات متوفرة حالياً", style: TextStyle(color: Colors.grey)),
//         ],
//       ),
//     );
//   }
// }
