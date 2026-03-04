import 'package:flutter/material.dart';

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const AppIcon(
      this.asset, {
        super.key,
        this.size = 24,
        this.color,
      });

  @override
  Widget build(BuildContext context) {
    return ImageIcon(
      AssetImage(asset),
      size: size,
      color: color,
    );
  }
}