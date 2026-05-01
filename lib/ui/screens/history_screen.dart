// lib/ui/screens/history_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/routes.dart';
import '../../data/models/translation_message.dart';
import '../../data/repositories/history_repository.dart';
import 'home_screen.dart' show CallArgs, CallRole;

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = HistoryRepository();
  late List<TranslationMessage> _items;

  @override
  void initState() {
    super.initState();
    _items = _repo.getAll();
  }

  Future<void> _refresh() async {
    setState(() => _items = _repo.getAll());
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to delete all translation history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.clear();
      await _refresh();
    }
  }

  /// Creates a new call as caller — "Call Again" from history.
  void _startNewCall() {
    Navigator.pushNamed(
      context,
      AppRoutes.call,
      arguments: const CallArgs(role: CallRole.caller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Translation History'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      // FAB for quick "New Call" from history screen
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewCall,
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_call, color: Colors.white),
        label: const Text('New Call', style: TextStyle(color: Colors.white)),
      ),
      body: _items.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 80), // room for FAB
                itemCount: _items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => _HistoryTile(
                  msg: _items[i],
                  onCallAgain: _startNewCall,
                ),
              ),
            ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TranslationMessage msg;
  final VoidCallback onCallAgain;
  const _HistoryTile({required this.msg, required this.onCallAgain});

  @override
  Widget build(BuildContext context) {
    final isGesture = msg.source == 'gesture';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isGesture
            ? AppTheme.primary.withOpacity(0.15)
            : AppTheme.secondary.withOpacity(0.15),
        child: Icon(
          isGesture ? Icons.sign_language : Icons.record_voice_over,
          color: isGesture ? AppTheme.primary : AppTheme.secondary,
        ),
      ),
      title: Text(msg.text.replaceAll('_', ' '),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${msg.source} • ${msg.language} • ${_formatTime(msg.timestamp)}'
        '${msg.fromPeer ? " • from peer" : ""}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (msg.gifKey != null)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(Icons.gif_box, color: AppTheme.textMuted, size: 20),
            ),
          // "Call Again" quick action
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onCallAgain,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call,
                  color: AppTheme.primary, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final t = DateTime.parse(iso).toLocal();
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off,
                size: 72, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text('No translation history yet',
                style: TextStyle(
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            SizedBox(height: 6),
            Text('Run a call to generate translation entries.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}