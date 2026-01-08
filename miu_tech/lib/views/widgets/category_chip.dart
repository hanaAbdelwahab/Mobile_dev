import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  final String text;
  final String selectedCategory;
  final IconData? icon;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.text,
    required this.selectedCategory,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedCategory == text;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected
                ? const Color.fromARGB(180, 244, 67, 54)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? []
                : const [
                    BoxShadow(
                      color: Color.fromARGB(171, 244, 67, 54),
                      offset: Offset(0, 4),
                      blurRadius: 0.5,
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(180, 244, 67, 54),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                text,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFFE53935),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
