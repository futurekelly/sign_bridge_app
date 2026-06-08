// CallScreen — WebRTC video call with role-based overlays.
// GIF panel, captions, AI status adapt based on user role.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../../controllers/call_controller.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/enums.dart';

import '../../core/theme.dart';
import '../widgets/call_controls.dart';
import '../widgets/gif_overlay.dart';
import '../widgets/caption_overlay.dart';
import '../widgets/ai_status_indicator.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as CallArgs?;
    final langCode = context.read<AccessibilityController>().languageCode;

    return ChangeNotifierProvider(
      create: (_) {
        final c = CallController();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (args == null || args.role == CallRole.caller) {
            c.startAsCaller(languageCode: langCode);
          } else {
            c.startAsCallee(args.callId!, languageCode: langCode);
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
    if (_isEnding) return;
    setState(() => _isEnding = true);
    await controller.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CallController>();
    final a11y = context.watch<AccessibilityController>();
    final role = a11y.role;

    // Call ended state
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
                Text(a11y.t('call.ended'),
                    style: const TextStyle(color: Colors.white54, fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(a11y.t('nav.home')),
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
            // Remote video
            Positioned.fill(
              child: _RemoteView(
                renderer: webrtc.remoteRenderer,
                isConnected: controller.remoteConnected,
              ),
            ),

            // Local preview
            Positioned(
              top: 16, right: 16,
              child: _LocalPreview(renderer: webrtc.localRenderer),
            ),

            // Top bar
            Positioned(
              top: 12, left: 8, right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => _handleEndCall(controller),
                  ),
                  const Spacer(),
                  // AI Status indicator
                  AiStatusIndicator(
                    statusStream: controller.translation.statusStream,
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(state: controller.state),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Call ID banner
            if (controller.callId != null && !controller.remoteConnected)
              Positioned(
                top: 70, left: 16, right: 16,
                child: _CallIdBanner(callId: controller.callId!),
              ),

            // Error
            if (controller.state == CallState.error)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    controller.errorMessage ?? 'Unknown error',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // ── Role-based overlays ──

            // GIF overlay (Deaf + Both)
            GifOverlay(
              liveStream: controller.translation.liveResultStream,
              userRole: role,
            ),

            // Caption overlay (Deaf + Both, or if enabled in settings)
            CaptionOverlay(
              liveStream: controller.translation.liveResultStream,
              userRole: role,
              fontSize: a11y.captionFontSize,
              enabled: a11y.captionsEnabled,
            ),

            // Bottom controls
            Align(
              alignment: Alignment.bottomCenter,
              child: CallControls(
                isMuted: controller.isMuted,
                onToggleMute: controller.toggleMute,
                onSwitchCamera: controller.switchCamera,
                onEndCall: () => _handleEndCall(controller),
                userRole: role,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Call ID Banner ──
class _CallIdBanner extends StatelessWidget {
  final String callId;
  const _CallIdBanner({required this.callId});

  @override
  Widget build(BuildContext context) {
    final a11y = context.watch<AccessibilityController>();
    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Icon(Icons.link, color: Colors.white.withValues(alpha: 0.7), size: 16),
              const SizedBox(width: 6),
              Text(a11y.t('call.share_id'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(callId, style: const TextStyle(
                    color: Colors.white, fontFamily: 'monospace',
                    fontSize: 13, letterSpacing: 0.5)),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: callId));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(a11y.t('call.copied')),
                            duration: const Duration(seconds: 2)));
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.copy, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ── Remote View ──
class _RemoteView extends StatelessWidget {
  final RTCVideoRenderer renderer;
  final bool isConnected;
  const _RemoteView({required this.renderer, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final a11y = context.watch<AccessibilityController>();
    if (!isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white24),
            const SizedBox(height: 16),
            Text(a11y.t('call.waiting'),
                style: const TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }
    return RTCVideoView(renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover);
  }
}

// ── Local Preview ──
class _LocalPreview extends StatelessWidget {
  final RTCVideoRenderer renderer;
  const _LocalPreview({required this.renderer});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110, height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24, width: 1),
        color: Colors.black,
      ),
      clipBehavior: Clip.antiAlias,
      child: RTCVideoView(renderer, mirror: true,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
    );
  }
}

// ── Status Pill ──
class _StatusPill extends StatelessWidget {
  final CallState state;
  const _StatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final a11y = context.watch<AccessibilityController>();
    final (label, color) = switch (state) {
      CallState.idle => ('Idle', Colors.grey),
      CallState.connecting => (a11y.t('call.connecting'), Colors.orange),
      CallState.inCall => (a11y.t('call.connected'), Colors.greenAccent),
      CallState.ended => (a11y.t('call.ended'), Colors.grey),
      CallState.error => (a11y.t('call.error'), Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}