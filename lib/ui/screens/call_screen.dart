// CallScreen (Phase 6)
// Shows WebRTC video call with Call ID banner, remote/local video,
// and controls. Uses controller state for all rendering decisions.

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

class _CallView extends StatefulWidget {
  const _CallView();

  @override
  State<_CallView> createState() => _CallViewState();
}

class _CallViewState extends State<_CallView> {
  bool _isEnding = false;

  Future<void> _handleEndCall(CallController controller) async {
    if (_isEnding) return; // guard against double-tap
    setState(() => _isEnding = true);

    await controller.endCall();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallController>();

    // If the call has ended (e.g. from dispose), stop rendering WebRTC views.
    if (controller.state == CallState.ended) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.call_end, color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                const Text('Call Ended',
                    style: TextStyle(color: Colors.white54, fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final webrtc = controller.webrtc;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Remote video background
            Positioned.fill(
              child: _RemoteView(
                renderer: webrtc.remoteRenderer,
                isConnected: controller.remoteConnected,
              ),
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
                    onPressed: () => _handleEndCall(controller),
                  ),
                  const Spacer(),
                  _StatusPill(state: controller.state),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Call ID banner (visible while waiting for peer)
            if (controller.callId != null && !controller.remoteConnected)
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
                onEndCall: () => _handleEndCall(controller),
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
      color: Colors.black.withOpacity(0.7),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.link, color: Colors.white70, size: 16),
                SizedBox(width: 6),
                Text(
                  'Share this Call ID with your peer:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      callId,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: callId));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Call ID copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.copy, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
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
  final bool isConnected;
  const _RemoteView({required this.renderer, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    if (!isConnected) {
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