// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../../../core/providers/auth_provider.dart';
// import '../../../core/routes/app_routes.dart';
//
// class WelcomeOnboardingScreen extends StatefulWidget {
//   const WelcomeOnboardingScreen({super.key});
//
//   @override
//   State<WelcomeOnboardingScreen> createState() => _WelcomeOnboardingScreenState();
// }
//
// class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;
//
//   final List<Map<String, String>> _onboardingData = [
//     {
//       'title': 'أهلاً بك في EduConnect',
//       'description': 'منصتك المتكاملة للتعليم عن بعد والتفاعل الحي مع المعلمين.',
//       'icon': '👋',
//     },
//     {
//       'title': 'قاعات افتراضية ذكية',
//       'description': 'استمتع بجلسات فيديو عالية الجودة مع أدوات تفاعلية مثل السبورة البيضاء.',
//       'icon': '🎥',
//     },
//     {
//       'title': 'متابعة الحضور والغياب',
//       'description': 'نظام آلي لتسجيل الحضور وتوليد تقارير PDF فورية.',
//       'icon': '📊',
//     },
//   ];
//
//   void _onFinish() {
//     // إبلاغ الـ Provider أن المستخدم أتم الجولة
//     context.read<AuthProvider>().completeOnboarding();
//     // الانتقال للمنصة
//     Navigator.pushReplacementNamed(context, AppRoutes.studentHome);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: PageView.builder(
//                 controller: _pageController,
//                 onPageChanged: (index) => setState(() => _currentPage = index),
//                 itemCount: _onboardingData.length,
//                 itemBuilder: (context, index) => _buildPage(index),
//               ),
//             ),
//             _buildBottomBar(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPage(int index) {
//     final item = _onboardingData[index];
//     return Padding(
//       padding: const EdgeInsets.all(40.0),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Text(item['icon']!, style: const TextStyle(fontSize: 80)),
//           const SizedBox(height: 40),
//           Text(
//             item['title']!,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontSize: 28,
//               fontWeight: FontWeight.bold,
//               fontFamily: 'Cairo',
//               color: Color(0xFF1A1C1E),
//             ),
//           ),
//           const SizedBox(height: 20),
//           Text(
//             item['description']!,
//             textAlign: TextAlign.center,
//             style: const TextStyle(
//               fontSize: 18,
//               fontFamily: 'Cairo',
//               color: Colors.grey,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildBottomBar() {
//     return Padding(
//       padding: const EdgeInsets.all(30.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Row(
//             children: List.generate(
//               _onboardingData.length,
//               (index) => AnimatedContainer(
//                 duration: const Duration(milliseconds: 300),
//                 margin: const EdgeInsets.only(right: 5),
//                 height: 8,
//                 width: _currentPage == index ? 24 : 8,
//                 decoration: BoxDecoration(
//                   color: _currentPage == index ? Colors.blue : Colors.grey.shade300,
//                   borderRadius: BorderRadius.circular(4),
//                 ),
//               ),
//             ),
//           ),
//
//           ElevatedButton(
//             onPressed: () {
//               if (_currentPage == _onboardingData.length - 1) {
//                 _onFinish();
//               } else {
//                 _pageController.nextPage(
//                   duration: const Duration(milliseconds: 300),
//                   curve: Curves.easeIn,
//                 );
//               }
//             },
//             style: ElevatedButton.styleFrom(
//               padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
//             ),
//             child: Text(
//               _currentPage == _onboardingData.length - 1 ? 'ابدأ الآن' : 'التالي',
//               style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
