// HistoryScreen — Phase 1 placeholder.
//
// In Phase 4+ this screen will read from history_repository.dart (Hive)
// and render saved TranslationMessage entries grouped by call session.

import 'package:flutter/material.dart';
import '../../core/theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Translation History')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off,
                  size: 72, color: AppTheme.textMuted),
              SizedBox(height: 16),
              Text(
                'No translation history yet',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'History persistence (Hive) will be added with the AI pipeline phase.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}