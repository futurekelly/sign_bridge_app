// CallScreen (Phase 3)
// Reads CallArgs from route to decide whether to act as CALLER or CALLEE.
// Shows the generated call ID so the caller can share it with the peer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../controllers/call_controller.dart';
import '../widgets/call_controls.dart';
import 'home_screen.dart' show CallArgs, CallRole;

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as CallArgs?;

    return ChangeNotifierProvider(
      create: (_) {
        final c = CallController();
        // Kick off correct flow once provider is ready.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (args == null || args.role == CallRole.caller) {
            c.startAsCaller();
          } else {
            c.startAsCallee(args.callId!);
          }
        });
        return c;
      },
      child: const _CallView(),
    );
  }
}

class _CallView extends StatelessWidget {
  const _CallView();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallController>();
    final webrtc = controller.webrtc;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video background
            Positioned.fill(
              child: _RemoteView(renderer: webrtc.remoteRenderer),
            ),

            // Local floating preview
            Positioned(
              top: 16,
              right: 16,
              child: _LocalPreview(renderer: webrtc.localRenderer),
            ),

            // Top bar
            Positioned(
              top: 12,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      await controller.endCall();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  _StatusPill(state: controller.state),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Call ID banner (visible while waiting for peer)
            if (controller.callId != null && webrtc.remoteRenderer.srcObject == null)
              Positioned(
                top: 70,
                left: 16,
                right: 16,
                child: _CallIdBanner(callId: controller.callId!),
              ),

            // Error
            if (controller.state == CallState.error)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    controller.errorMessage ?? 'Unknown error',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Bottom controls
            Align(
              alignment: Alignment.bottomCenter,
              child: CallControls(
                isMuted: controller.isMuted,
                onToggleMute: controller.toggleMute,
                onSwitchCamera: controller.switchCamera,
                onEndCall: () async {
                  await controller.endCall();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Call ID banner with copy-to-clipboard ──
class _CallIdBanner extends StatelessWidget {
  final String callId;
  const _CallIdBanner({required this.callId});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.share, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            const Text('Call ID:',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                callId,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: callId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Call ID copied')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Remote view ──
class _RemoteView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  const _RemoteView({required this.renderer});

  @override
  Widget build(BuildContext context) {
    if (renderer.srcObject == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white24),
            SizedBox(height: 16),
            Text('Waiting for peer to join...',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return RTCVideoView(renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
  }
}

// ── Local preview ──
class _LocalPreview extends StatelessWidget {
  final RTCVideoRenderer renderer;
  const _LocalPreview({required this.renderer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: RTCVideoView(
        renderer,
        mirror: true,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      ),
    );
  }
}

// ── Status pill ──
class _StatusPill extends StatelessWidget {
  final CallState state;
  const _StatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;
    switch (state) {
      case CallState.idle:
        label = 'Idle'; color = Colors.grey; break;
      case CallState.connecting:
        label = 'Connecting…'; color = Colors.orange; break;
      case CallState.inCall:
        label = 'In Call'; color = Colors.greenAccent; break;
      case CallState.ended:
        label = 'Ended'; color = Colors.grey; break;
      case CallState.error:
        label = 'Error'; color = Colors.redAccent; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}