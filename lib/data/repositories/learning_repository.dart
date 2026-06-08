// LearningRepository — provides curated sign language learning resources.
// Favorites are persisted in Hive.

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/learning_resource.dart';

class LearningRepository {
  Box get _settingsBox => Hive.box('app_settings');

  // ── Favorites (persisted as a list of IDs) ──

  Set<String> getFavoriteIds() {
    final raw = _settingsBox.get('favoriteResources', defaultValue: <String>[]);
    if (raw is List) return raw.cast<String>().toSet();
    return {};
  }

  Future<void> toggleFavorite(String resourceId) async {
    final faves = getFavoriteIds();
    if (faves.contains(resourceId)) {
      faves.remove(resourceId);
    } else {
      faves.add(resourceId);
    }
    await _settingsBox.put('favoriteResources', faves.toList());
  }

  bool isFavorite(String resourceId) => getFavoriteIds().contains(resourceId);

  // ── Curated Resources ──

  List<LearningResource> getAll() => _resources;

  List<LearningResource> getByCategory(String category) =>
      _resources.where((r) => r.category == category).toList();

  List<LearningResource> getFavorites() {
    final ids = getFavoriteIds();
    return _resources.where((r) => ids.contains(r.id)).toList();
  }

  List<String> get categories =>
      _resources.map((r) => r.category).toSet().toList()..sort();

  // ── Hardcoded resource catalog ──
  static const List<LearningResource> _resources = [
    LearningResource(
      id: 'tsl_basics',
      title: 'Tanzanian Sign Language Basics',
      description: 'Introduction to Lugha ya Alama ya Tanzania (LAT) — foundational signs.',
      pdfUrl: 'https://share.google/dxH2kkFRMGz0c7Y1g',
      category: 'Regional',
      icon: Icons.language,
    ),
    LearningResource(
      id: 'asl_alphabet',
      title: 'ASL Alphabet Guide',
      description: 'Learn all 26 letters of the American Sign Language alphabet with illustrations.',
      pdfUrl: 'https://www.nidcd.nih.gov/sites/default/files/Documents/health/hearing/NIDCD-ASL-Fingerspelling.pdf',
      category: 'Alphabet',
      icon: Icons.abc,
    ),
    LearningResource(
      id: 'common_phrases',
      title: 'Common Sign Language Phrases',
      description: '50 essential everyday phrases in sign language for beginners.',
      pdfUrl: 'https://www.startasl.com/wp-content/uploads/StartASL-American-Sign-Language-Guide.pdf',
      category: 'Common Phrases',
      icon: Icons.chat_bubble_outline,
    ),
    LearningResource(
      id: 'greetings',
      title: 'Greetings & Introductions',
      description: 'How to greet people, introduce yourself, and make small talk in sign language.',
      pdfUrl: 'https://www.lifeprint.com/asl101/pages-layout/greetings.htm',
      category: 'Greetings',
      icon: Icons.waving_hand,
    ),
    LearningResource(
      id: 'emergency_signs',
      title: 'Emergency Signs',
      description: 'Critical signs for emergency situations: help, danger, call police, hospital.',
      pdfUrl: 'https://www.nidcd.nih.gov/health/american-sign-language',
      category: 'Emergency',
      icon: Icons.emergency,
    ),
    LearningResource(
      id: 'numbers',
      title: 'Numbers & Counting',
      description: 'Sign language numbers 1-100, counting techniques, and number-related phrases.',
      pdfUrl: 'https://www.lifeprint.com/asl101/pages-layout/numbers.htm',
      category: 'Numbers',
      icon: Icons.pin,
    ),
    LearningResource(
      id: 'family_signs',
      title: 'Family & Relationships',
      description: 'Signs for family members, relationships, and describing people.',
      pdfUrl: 'https://www.lifeprint.com/asl101/pages-layout/family.htm',
      category: 'Common Phrases',
      icon: Icons.family_restroom,
    ),
    LearningResource(
      id: 'medical_signs',
      title: 'Medical & Health Signs',
      description: 'Essential medical vocabulary: symptoms, body parts, doctor visits.',
      pdfUrl: 'https://www.nidcd.nih.gov/health/american-sign-language',
      category: 'Emergency',
      icon: Icons.local_hospital,
    ),
  ];
}
