import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ويدجت موحد لأي صفحة لسه هنطورها - Favorite / Map / Reports
class ComingSoonPlaceholder extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onMenuTap;
  final String message;

  const ComingSoonPlaceholder({
    super.key,
    required this.title,
    required this.icon,
    required this.onMenuTap,
    this.message = 'This page will be developed in the next step',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            border: Border(bottom: BorderSide(color: AppColors.borderGrey)),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.menu_rounded, color: AppColors.textDark),
                  onPressed: onMenuTap,
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 42, color: AppColors.primaryBlue),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
