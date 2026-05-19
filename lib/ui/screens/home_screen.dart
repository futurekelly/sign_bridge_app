// HomeScreen — redesigned with neumorphic cards, role badge,
// recent calls section, and bottom navigation.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../controllers/theme_controller.dart';
import '../../core/constants.dart';
import '../../core/enums.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../data/models/recent_call.dart';
import '../../data/repositories/recent_calls_repository.dart';
import '../../services/auth/auth_service.dart';
import '../widgets/role_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  final _recentRepo = RecentCallsRepository();
  String _displayName = '';
  String _shortId = '';
  bool _loaded = false;
  List<RecentCall> _recentCalls = [];
  int _currentNav = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadRecentCalls();
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

  void _loadRecentCalls() {
    setState(() => _recentCalls = _recentRepo.getAll());
  }

  void _onNavTap(int index) {
    switch (index) {
      case 0: break; // already home
      case 1: Navigator.pushNamed(context, AppRoutes.history); break;
      case 2: Navigator.pushNamed(context, AppRoutes.learning); break;
      case 3: Navigator.pushNamed(context, AppRoutes.settings); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a11y = context.watch<AccessibilityController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Theme',
            icon: Icon(context.watch<ThemeController>().icon),
            onPressed: () => context.read<ThemeController>().toggleTheme(),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNav,
        onTap: _onNavTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'Learn'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Welcome + Role ──
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, $_displayName 👋',
                          style: theme.textTheme.headlineMedium),
                      const SizedBox(height: 4),
                      Text('Start an inclusive video call with real-time translation.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                RoleBadge(role: a11y.role),
              ],
            ),

            // ── User ID ──
            if (_loaded && _shortId.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _UserIdCard(shortId: _shortId),
            ],

            const SizedBox(height: AppSpacing.lg),

            // ── Action Cards ──
            _ActionCard(
              icon: Icons.add_call,
              title: 'Create Call',
              subtitle: 'Start a new call and share the ID',
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(context, AppRoutes.call,
                  arguments: const CallArgs(role: CallRole.caller)),
            ),
            const SizedBox(height: AppSpacing.md),

            _ActionCard(
              icon: Icons.call_received,
              title: 'Join Call',
              subtitle: 'Enter a call ID to join',
              color: AppColors.secondary,
              onTap: () => _promptJoin(context),
            ),

            // ── Recent Calls ──
            if (_recentCalls.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(Icons.history, size: 18, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Recent Calls', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await _recentRepo.clear();
                      _loadRecentCalls();
                    },
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              ...(_recentCalls.take(5).map((call) => _RecentCallTile(
                    call: call,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.call,
                        arguments: CallArgs(role: CallRole.callee, callId: call.callId)),
                    onDelete: () async {
                      await _recentRepo.delete(call.callId);
                      _loadRecentCalls();
                    },
                  ))),
            ],

            const SizedBox(height: AppSpacing.md),

            _ActionCard(
              icon: Icons.history,
              title: 'Translation History',
              subtitle: 'View past conversations',
              color: AppColors.accent,
              onTap: () => Navigator.pushNamed(context, AppRoutes.history),
            ),
            const SizedBox(height: AppSpacing.md),

            _ActionCard(
              icon: Icons.menu_book,
              title: 'Learning Resources',
              subtitle: 'Sign language guides & materials',
              color: AppColors.warning,
              onTap: () => Navigator.pushNamed(context, AppRoutes.learning),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Future<void> _promptJoin(BuildContext context) async {
    final controller = TextEditingController();
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Join Call'),
        content: SingleChildScrollView(
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Call ID',
              hintText: 'Paste the call ID here',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Join'),
          ),
        ],
      ),
    );
    if (id != null && id.isNotEmpty && context.mounted) {
      Navigator.pushNamed(context, AppRoutes.call,
          arguments: CallArgs(role: CallRole.callee, callId: id));
    }
  }
}

// ── User ID Card ──
class _UserIdCard extends StatelessWidget {
  final String shortId;
  const _UserIdCard({required this.shortId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppTheme.neumorphic(context, radius: AppRadius.md),
      child: Row(
        children: [
          const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Text('Your ID:', style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 13)),
          const SizedBox(width: 8),
          Text(shortId, style: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16,
            fontFamily: 'monospace', color: AppColors.primary, letterSpacing: 1.5)),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: shortId));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User ID copied!'), duration: Duration(seconds: 2)));
              }
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy, size: 18, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Card (neumorphic) ──
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({
    required this.icon, required this.title,
    required this.subtitle, required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.neumorphic(context, radius: AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg - 4),
          child: Row(
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent Call Tile ──
class _RecentCallTile extends StatelessWidget {
  final RecentCall call;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _RecentCallTile({required this.call, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(call.callId),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Icon(Icons.delete, color: AppColors.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: AppTheme.neumorphic(context, radius: AppRadius.md),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.call, color: AppColors.primary, size: 18),
          ),
          title: Text(
            call.partnerName ?? 'Call ${call.callId.substring(0, 6)}...',
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(_formatAgo(call.timestamp),
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          trailing: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 14),
            onPressed: onTap,
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  String _formatAgo(String iso) {
    try {
      final t = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(t);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return iso; }
  }
}