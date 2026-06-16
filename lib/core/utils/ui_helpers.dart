import 'package:flutter/material.dart';
import 'responsive.dart';

class UIHelpers {
  static void showSnackBar(BuildContext context, String message, {bool isError = false, Color? backgroundColor}) {
    final bool isDesktop = Responsive.isDesktop(context);

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Cairo', 
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor ?? (isError ? Colors.red.shade800 : Colors.green.shade800),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.only(
          bottom: 24,
          left: isDesktop ? MediaQuery.of(context).size.width * 0.3 : 20,
          right: isDesktop ? MediaQuery.of(context).size.width * 0.3 : 20,
        ),
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static void showCustomDialog(BuildContext context, {required String title, required String message, VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("إلغاء", style: TextStyle(fontFamily: 'Cairo'))
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onConfirm != null) onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF102A43),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("تأكيد", style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
