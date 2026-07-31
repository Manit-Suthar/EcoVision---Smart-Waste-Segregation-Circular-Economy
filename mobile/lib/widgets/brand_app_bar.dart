import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? leading;
  final List<Widget>? actions;
  final Color backgroundColor;
  final PreferredSizeWidget? bottom;

  const BrandAppBar({
    super.key,
    this.leading,
    this.actions,
    this.backgroundColor = Colors.transparent,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      leading: leading,
      actions: actions,
      iconTheme: const IconThemeData(color: Colors.black87),
      centerTitle: true,
      bottom: bottom,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.eco, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text(
            'EcoVision',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 26,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
