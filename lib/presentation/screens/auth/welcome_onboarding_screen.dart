// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:smooth_page_indicator/smooth_page_indicator.dart';
// import '../../../core/providers/auth_provider.dart';
// import '../../../core/routes/app_routes.dart';
// import '../../../core/utils/responsive.dart';
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
//   bool _isLastPage = false;
//
//   final List<Map<String, String>> _onboardingData = [
//     {
//       'title': 'أهلاً بك في EduConnect',
//       'description': 'منصتك المتكاملة للتعليم عن بعد والتفاعل الحي مع المعلمين والزملاء في بيئة ذكية.',
//       'icon': '👋',
//       'color': '0xFF102A43',
//     },
//     {
//       'title': 'قاعات افتراضية متطورة',
//       'description': 'بث مباشر عالي الجودة مع أدوات تفاعلية: سبورة ذكية، شات لحظي، ومشاركة شاشة.',
//       'icon': '🎥',
//       'color': '0xFF243B53',
//     },
//     {
//       'title': 'متابعة دقيقة للمستوى',
//       'description': 'تقارير حضور تلقائية، اختبارات قصيرة، وتقييم مستمر لمستوى التحصيل الدراسي.',
//       'icon': '📊',
//       'color': '0xFF334E68',
//     },
//   ];
//
//   void _onFinish() {
//     context.read<AuthProvider>().completeOnboarding();
//     Navigator.pushReplacementNamed(context, AppRoutes.login);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final bool isDesktop = Responsive.isDesktop(context);
//     final size = MediaQuery.of(context).size;
//
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         children: [
//           // Background Decoration
//           Positioned(
//             top: -100,
//             right: -100,
//             child: Container(
//               width: 300,
//               height: 300,
//               decoration: BoxDecoration(
//                 color: const Color(0xFF102A43).withOpacity(0.05),
//                 shape: BoxShape.circle,
//               ),
//             ),
//           ),
//
//           Column(
//             children: [
//               Expanded(
//                 child: PageView.builder(
//                   controller: _pageController,
//                   onPageChanged: (index) {
//                     setState(() => _isLastPage = index == _onboardingData.length - 1);
//                   },
//                   itemCount: _onboardingData.length,
//                   itemBuilder: (context, index) => _buildPage(index, isDesktop, size),
//                 ),
//               ),
//
//               // Bottom Section
//               Padding(
//                 padding: EdgeInsets.symmetric(
//                   horizontal: isDesktop ? size.width * 0.1 : 30,
//                   vertical: 40,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     // Indicator
//                     SmoothPageIndicator(
//                       controller: _pageController,
//                       count: _onboardingData.length,
//                       effect: const ExpandingDotsEffect(
//                         activeDotColor: Color(0xFF102A43),
//                         dotColor: Color(0xFFD9E2EC),
//                         dotHeight: 8,
//                         dotWidth: 8,
//                         expansionFactor: 4,
//                       ),
//                     ),
//
//                     // Next/Start Button
//                     ElevatedButton(
//                       onPressed: () {
//                         if (_isLastPage) {
//                           _onFinish();
//                         } else {
//                           _pageController.nextPage(
//                             duration: const Duration(milliseconds: 500),
//                             curve: Curves.easeInOut,
//                           );
//                         }
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF102A43),
//                         foregroundColor: Colors.white,
//                         padding: EdgeInsets.symmetric(
//                           horizontal: _isLastPage ? 40 : 25,
//                           vertical: 18,
//                         ),
//                         shape: RoundedRectangleBorder(
//                           borderRadius: BorderRadius.circular(18),
//                         ),
//                         elevation: 5,
//                         shadowColor: const Color(0xFF102A43).withOpacity(0.3),
//                       ),
//                       child: AnimatedSwitcher(
//                         duration: const Duration(milliseconds: 200),
//                         child: Text(
//                           _isLastPage ? 'ابدأ رحلتك الآن' : 'التالي',
//                           key: ValueKey(_isLastPage),
//                           style: const TextStyle(
//                             fontFamily: 'Cairo',
//                             fontWeight: FontWeight.w900,
//                             fontSize: 16,
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//
//           // Skip Button
//           if (!_isLastPage)
//             Positioned(
//               top: 50,
//               left: 20,
//               child: TextButton(
//                 onPressed: _onFinish,
//                 child: const Text(
//                   'تخطي',
//                   style: TextStyle(
//                     fontFamily: 'Cairo',
//                     color: Colors.blueGrey,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPage(int index, bool isDesktop, Size size) {
//     final item = _onboardingData[index];
//
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: isDesktop ? size.width * 0.2 : 40),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           // Icon/Illustration Area
//           Container(
//             padding: const EdgeInsets.all(40),
//             decoration: BoxDecoration(
//               color: Color(int.parse(item['color']!)).withOpacity(0.1),
//               shape: BoxShape.circle,
//             ),
//             child: Text(
//               item['icon']!,
//               style: TextStyle(fontSize: isDesktop ? 120 : 80),
//             ),
//           ),
//           SizedBox(height: isDesktop ? 60 : 40),
//
//           // Title
//           Text(
//             item['title']!,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: isDesktop ? 42 : 28,
//               fontWeight: FontWeight.w900,
//               fontFamily: 'Cairo',
//               color: const Color(0xFF102A43),
//               height: 1.2,
//             ),
//           ),
//           const SizedBox(height: 20),
//
//           // Description
//           Text(
//             item['description']!,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: isDesktop ? 20 : 16,
//               fontFamily: 'Cairo',
//               color: Colors.blueGrey.shade600,
//               height: 1.6,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
