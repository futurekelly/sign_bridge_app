// ConversationCard — rich history card with neumorphic styling.

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../data/models/translation_message.dart';


class ConversationCard extends StatelessWidget {
  final TranslationMessage msg;
  final VoidCallback? onReplay;
  final VoidCallback? onCallAgain;

  const ConversationCard({
    super.key,
    required this.msg,
    this.onReplay,
    this.onCallAgain,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGesture = msg.source == 'gesture';
    final sourceColor = isGesture ? AppColors.primary : AppColors.secondary;
    final hasGif = msg.gifKey != null;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: AppTheme.neumorphic(context, radius: AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Source icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: sourceColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    isGesture ? Icons.sign_language : Icons.record_voice_over,
                    color: sourceColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Text + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text.replaceAll('_', ' '),
                        style: theme.textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _MetaChip(
                            icon: isGesture ? Icons.sign_language : Icons.mic,
                            label: msg.source,
                            color: sourceColor,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _MetaChip(
                            icon: Icons.language,
                            label: msg.language.toUpperCase(),
                            color: theme.textTheme.bodySmall?.color ??
                                AppColors.lightTextMuted,
                          ),
                          if (msg.fromPeer) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _MetaChip(
                              icon: Icons.person,
                              label: 'Peer',
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Timestamp
                Text(
                  _formatTime(msg.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),

            // Action row
            if (hasGif || onCallAgain != null) ...[
              const SizedBox(height: AppSpacing.sm),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (hasGif && onReplay != null)
                    _ActionBtn(
                      icon: Icons.replay,
                      label: 'Replay Sign',
                      onTap: onReplay!,
                    ),
                  if (hasGif) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.gif_box,
                              size: 14,
                              color: AppColors.primary.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            msg.gifKey!,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (onCallAgain != null)
                    _ActionBtn(
                      icon: Icons.call,
                      label: 'Call Again',
                      onTap: onCallAgain!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final t = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(t);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) {
        return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      }
      return '${t.day}/${t.month} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
