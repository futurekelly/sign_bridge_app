// HistoryScreen — redesigned with conversation cards,
// search bar, filter chips, and replay functionality.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../core/routes.dart';
import '../../core/enums.dart';
import '../../data/models/translation_message.dart';
import '../../data/repositories/history_repository.dart';
import '../widgets/conversation_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _repo = HistoryRepository();
  late List<TranslationMessage> _allItems;
  List<TranslationMessage> _filtered = [];
  final _searchCtrl = TextEditingController();
  String _sourceFilter = 'all'; // 'all', 'gesture', 'speech'

  @override
  void initState() {
    super.initState();
    _allItems = _repo.getAll();
    _applyFilters();
  }

  void _applyFilters() {
    var items = List<TranslationMessage>.from(_allItems);

    // Source filter
    if (_sourceFilter == 'gesture') {
      items = items.where((m) => m.source == 'gesture').toList();
    } else if (_sourceFilter == 'speech') {
      items = items.where((m) => m.source == 'speech').toList();
    }

    // Search
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items
          .where((m) => m.text.toLowerCase().contains(query))
          .toList();
    }

    setState(() => _filtered = items);
  }

  Future<void> _refresh() async {
    _allItems = _repo.getAll();
    _applyFilters();
  }

  Future<void> _clear() async {
    final a11y = context.read<AccessibilityController>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(a11y.t('history.clear')),
        content: Text(a11y.t('history.clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(a11y.t('home.cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(a11y.t('common.ok'))),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.clear();
      await _refresh();
    }
  }

  void _startNewCall() {
    Navigator.pushNamed(context, AppRoutes.call,
        arguments: const CallArgs(role: CallRole.caller));
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a11y = context.watch<AccessibilityController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(a11y.t('history.title')),
        actions: [
          if (_allItems.isNotEmpty)
            IconButton(
              tooltip: a11y.t('history.clear'),
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startNewCall,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_call, color: Colors.white),
        label: Text(a11y.t('home.create_call'),
            style: const TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Container(
              decoration: AppTheme.neumorphic(context, radius: AppRadius.xl),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: a11y.t('history.search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _applyFilters();
                          })
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.md),
                ),
              ),
            ),
          ),

          // ── Filter Chips ──
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _FilterChip(
                  label: a11y.t('common.ok') == 'OK' ? 'All' : 'Zote',
                  selected: _sourceFilter == 'all',
                  onTap: () { _sourceFilter = 'all'; _applyFilters(); },
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: a11y.t('history.gesture'),
                  icon: Icons.sign_language,
                  selected: _sourceFilter == 'gesture',
                  onTap: () { _sourceFilter = 'gesture'; _applyFilters(); },
                ),
                const SizedBox(width: AppSpacing.sm),
                _FilterChip(
                  label: a11y.t('history.speech'),
                  icon: Icons.mic,
                  selected: _sourceFilter == 'speech',
                  onTap: () { _sourceFilter = 'speech'; _applyFilters(); },
                ),
                const Spacer(),
                Text('${_filtered.length} items',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),

          // ── List ──
          Expanded(
            child: _filtered.isEmpty
                ? const _EmptyState()
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, 0, AppSpacing.md, 80),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => ConversationCard(
                        msg: _filtered[i],
                        onCallAgain: _startNewCall,
                        onReplay: _filtered[i].gifKey != null
                            ? () => _showGifReplay(_filtered[i])
                            : null,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showGifReplay(TranslationMessage msg) {
    final assetPath = 'assets/gifs/${msg.gifKey}.gif';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Sign: ${msg.text.replaceAll("_", " ")}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  color: AppColors.primary.withValues(alpha: 0.05),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(assetPath, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sign_language, size: 48, color: AppColors.primary),
                          SizedBox(height: 8),
                          Text('GIF not available', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    )),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label, this.icon,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14,
                  color: selected ? AppColors.primary : Colors.grey),
              const SizedBox(width: 4),
            ],
            Text(label, style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? AppColors.primary : null,
            )),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 72,
                color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(height: 16),
            Text(context.read<AccessibilityController>().t('history.empty'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(context.read<AccessibilityController>().t('history.empty_desc'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}