// LearningScreen — sign language learning resources with categories,
// favorites, search, and download/open functionality.
// Fully localized (EN / SW).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../data/models/learning_resource.dart';
import '../../data/repositories/learning_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final _repo = LearningRepository();
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  List<LearningResource> _filtered = [];

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    var items = _repo.getAll();

    if (_selectedCategory != 'All') {
      items = items.where((r) => r.category == _selectedCategory).toList();
    }

    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      items = items
          .where((r) =>
              r.title.toLowerCase().contains(query) ||
              r.description.toLowerCase().contains(query))
          .toList();
    }

    setState(() => _filtered = items);
  }

  List<String> get _categories => ['All', ..._repo.categories];

  Future<void> _openResource(LearningResource resource) async {
    final uri = Uri.tryParse(resource.pdfUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      final a11y = context.read<AccessibilityController>();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(a11y.t('common.error'))));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a11y = context.watch<AccessibilityController>();

    return Scaffold(
      appBar: AppBar(title: Text(a11y.t('learning.title'))),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: Container(
              decoration:
                  AppTheme.neumorphic(context, radius: AppRadius.xl),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: a11y.t('learning.search'),
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
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md),
                ),
              ),
            ),
          ),

          // ── Category Chips ──
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return GestureDetector(
                  onTap: () {
                    _selectedCategory = cat;
                    _applyFilters();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : theme.dividerColor,
                      ),
                    ),
                    child: Text(cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: selected ? AppColors.primary : null,
                        )),
                  ),
                );
              },
            ),
          ),

          // ── Resource List ──
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.menu_book,
                            size: 64,
                            color: theme.textTheme.bodySmall?.color),
                        const SizedBox(height: 12),
                        Text(a11y.t('history.no_results'),
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _ResourceCard(
                      resource: _filtered[i],
                      isFavorite: _repo.isFavorite(_filtered[i].id),
                      openLabel: a11y.t('learning.open_pdf'),
                      onOpen: () => _openResource(_filtered[i]),
                      onToggleFavorite: () {
                        _repo.toggleFavorite(_filtered[i].id);
                        setState(() {});
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final LearningResource resource;
  final bool isFavorite;
  final String openLabel;
  final VoidCallback onOpen;
  final VoidCallback onToggleFavorite;

  const _ResourceCard({
    required this.resource,
    required this.isFavorite,
    required this.openLabel,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppTheme.neumorphic(context, radius: AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(resource.icon,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(resource.title,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(resource.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(resource.category,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w500,
                          )),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    icon: Icon(
                      isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color:
                          isFavorite ? AppColors.error : Colors.grey,
                      size: 20,
                    ),
                    onPressed: onToggleFavorite,
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(Icons.open_in_new,
                      size: 16,
                      color: theme.textTheme.bodySmall?.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
