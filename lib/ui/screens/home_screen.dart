// HomeScreen (Phase 6)
// Shows welcome message with username, short user ID, and
// Create Call / Join Call / History actions.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../services/auth/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  String _displayName = '';
  String _shortId = '';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _auth.getDisplayName();
    final shortId = await _auth.getShortId();
    if (mounted) {
      setState(() {
        _displayName = name ?? 'User';
        _shortId = shortId ?? '';
        _loaded = true;
      });
    }
  }

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
              await _auth.signOut();
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
            const SizedBox(height: 16),

            // ── Welcome message with username ──
            Text(
              'Welcome, $_displayName 👋',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Start an inclusive video call with real-time sign and speech translation.',
              style: TextStyle(color: AppTheme.textMuted),
            ),

            // ── Short user ID (copyable) ──
            if (_loaded && _shortId.isNotEmpty) ...[
              const SizedBox(height: 16),
              _UserIdCard(shortId: _shortId),
            ],

            const SizedBox(height: 24),

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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join Call'),
        // FIX Issue 2: wrap in SingleChildScrollView to prevent
        // "bottom overflowed by X pixels" when keyboard opens.
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Call ID',
                  hintText: 'Paste the call ID here',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
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

// ── User ID display card ──
class _UserIdCard extends StatelessWidget {
  final String shortId;
  const _UserIdCard({required this.shortId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined,
              color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          const Text(
            'Your ID:',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 8),
          Text(
            shortId,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              fontFamily: 'monospace',
              color: AppTheme.primary,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: shortId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User ID copied!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, size: 18, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable action card ──
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