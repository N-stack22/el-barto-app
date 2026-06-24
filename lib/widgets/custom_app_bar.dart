import 'package:flutter/material.dart';

import 'logo_widget.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.actions,
    this.logoSize = 34,
  });

  final List<Widget>? actions;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LogoWidget(size: logoSize),
          const SizedBox(width: 8),
          const Text(
            'El Barto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
      centerTitle: true,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
