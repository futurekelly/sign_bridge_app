// CallControls — bottom action bar for the CallScreen.
// Pure presentational widget; receives callbacks from CallController.

import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  final bool isMuted;
  final VoidCallback onToggleMute;
  final VoidCallback onSwitchCamera;
  final VoidCallback onEndCall;

  const CallControls({
    super.key,
    required this.isMuted,
    required this.onToggleMute,
    required this.onSwitchCamera,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32, left: 24, right: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _CircleBtn(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            label: isMuted ? 'Unmute' : 'Mute',
            color: isMuted ? Colors.orange : Colors.white24,
            onTap: onToggleMute,
          ),
          _CircleBtn(
            icon: Icons.call_end,
            label: 'End',
            color: Colors.redAccent,
            onTap: onEndCall,
          ),
          _CircleBtn(
            icon: Icons.cameraswitch,
            label: 'Switch',
            color: Colors.white24,
            onTap: onSwitchCamera,
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}