// LearningResource — model for sign language learning materials.
// Not persisted in Hive (resources are hardcoded); only favorites are persisted.

import 'package:flutter/material.dart';

class LearningResource {
  final String id;
  final String title;
  final String description;
  final String pdfUrl;
  final String category;
  final IconData icon;

  const LearningResource({
    required this.id,
    required this.title,
    required this.description,
    required this.pdfUrl,
    required this.category,
    this.icon = Icons.menu_book,
  });
}
