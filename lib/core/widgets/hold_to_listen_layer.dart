import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HoldToListenLayer extends StatefulWidget {
  final Widget child;
  final Duration holdDuration;
  final Future<void> Function() onTriggered;
  final bool enabled;
  final double cancelMoveDistance;

  const HoldToListenLayer({
    super.key,
    required this.child,
    required this.onTriggered,
    this.holdDuration = const Duration(seconds: 2),
    this.enabled = true,
    this.cancelMoveDistance = 24,
  });

  @override
  State<HoldToListenLayer> createState() => _HoldToListenLayerState();
}

class _HoldToListenLayerState extends State<HoldToListenLayer> {
  Timer? _timer;
  int? _pointerId;
  Offset? _startPosition;
  bool _fired = false;

  void _cancelHold() {
    _timer?.cancel();
    _timer = null;
    _pointerId = null;
    _startPosition = null;
    _fired = false;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    if (_pointerId != null) return;

    _pointerId = event.pointer;
    _startPosition = event.position;
    _fired = false;

    _timer?.cancel();
    _timer = Timer(widget.holdDuration, () async {
      if (!mounted || _fired || !widget.enabled) return;
      _fired = true;
      HapticFeedback.mediumImpact();
      await widget.onTriggered();
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_pointerId != event.pointer) return;
    final start = _startPosition;
    if (start == null) return;

    final dx = event.position.dx - start.dx;
    final dy = event.position.dy - start.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance > widget.cancelMoveDistance) {
      _cancelHold();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pointerId != event.pointer) return;
    _cancelHold();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_pointerId != event.pointer) return;
    _cancelHold();
  }

  @override
  void dispose() {
    _cancelHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}