import 'package:flutter/material.dart';

class ViewersButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const ViewersButton({super.key, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.remove_red_eye, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(
                "$count",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
