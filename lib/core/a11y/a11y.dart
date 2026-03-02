import 'package:flutter/material.dart';

class A11y {
  static Semantics bigAction({
    required String label,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      child: child,
    );
  }
}