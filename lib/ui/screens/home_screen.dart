// HomeScreen (Phase 3)
// Adds Create Call / Join Call flow.
// Create Call → starts a call as CALLER and shows the callId to share.
// Join Call   → prompts for an existing callId.

import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/auth/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Text('Welcome 👋',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Start an inclusive video call with real-time sign and speech translation.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 32),

            _ActionCard(
              icon: Icons.add_call,
              title: 'Create Call',
              subtitle: 'Start a new call and share the ID',
              color: AppTheme.primary,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.call,
                arguments: const CallArgs(role: CallRole.caller),
              ),
            ),
            const SizedBox(height: 16),

            _ActionCard(
              icon: Icons.call_received,
              title: 'Join Call',
              subtitle: 'Enter a call ID to join',
              color: AppTheme.secondary,
              onTap: () => _promptJoin(context),
            ),
            const SizedBox(height: 16),

            _ActionCard(
              icon: Icons.history,
              title: 'Translation History',
              subtitle: 'View past conversations',
              color: Colors.purple,
              onTap: () => Navigator.pushNamed(context, AppRoutes.history),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promptJoin(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Join Call'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Call ID',
            hintText: 'Paste the call ID here',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );

    if (id != null && id.isNotEmpty && context.mounted) {
      Navigator.pushNamed(
        context,
        AppRoutes.call,
        arguments: CallArgs(role: CallRole.callee, callId: id),
      );
    }
  }
}

// ── Route arguments for CallScreen ──
enum CallRole { caller, callee }

class CallArgs {
  final CallRole role;
  final String? callId; // required for callee
  const CallArgs({required this.role, this.callId});
}

// ── Reusable card ──
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}