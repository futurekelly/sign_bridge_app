// AiStatusIndicator — animated pill showing current AI pipeline state.

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/enums.dart';
import '../../core/spacing.dart';

class AiStatusIndicator extends StatefulWidget {
  final Stream<AiStatus> statusStream;
  const AiStatusIndicator({super.key, required this.statusStream});

  @override
  State<AiStatusIndicator> createState() => _AiStatusIndicatorState();
}

class _AiStatusIndicatorState extends State<AiStatusIndicator>
    with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  AiStatus _status = AiStatus.idle;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _sub = widget.statusStream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      if (s == AiStatus.listening || s == AiStatus.recognizing) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _label();
    final color = _color();

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final pulse = _pulseCtrl.value * 0.5 + 0.5;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: color.withValues(alpha: 0.5 * pulse)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: pulse),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        );
      },
    );
  }

  String _label() {
    switch (_status) {
      case AiStatus.idle: return 'AI Idle';
      case AiStatus.listening: return 'Listening';
      case AiStatus.recognizing: return 'Recognizing';
      case AiStatus.processing: return 'Processing';
      case AiStatus.error: return 'AI Error';
    }
  }

  Color _color() {
    switch (_status) {
      case AiStatus.idle: return Colors.grey;
      case AiStatus.listening: return Colors.greenAccent;
      case AiStatus.recognizing: return Colors.lightBlueAccent;
      case AiStatus.processing: return Colors.amberAccent;
      case AiStatus.error: return Colors.redAccent;
    }
  }
}
