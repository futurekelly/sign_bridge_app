// SettingsScreen — profile, role selection, theme, accessibility prefs.
// Uses neumorphic section cards for a modern premium feel.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/theme_controller.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../services/auth/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService();
  String _displayName = '';
  String _shortId = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await _auth.getDisplayName();
    final id = await _auth.getShortId();
    if (mounted) {
      setState(() {
        _displayName = name ?? 'User';
        _shortId = id ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeCtrl = context.watch<ThemeController>();
    final a11yCtrl = context.watch<AccessibilityController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Profile Section ──
          _SectionCard(
            title: 'Profile',
            icon: Icons.person_outline,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(_displayName, style: theme.textTheme.titleMedium),
                subtitle: _shortId.isNotEmpty
                    ? Text('ID: $_shortId',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: theme.textTheme.bodySmall?.color,
                        ))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Accessibility Role ──
          _SectionCard(
            title: 'Accessibility Role',
            icon: Icons.accessibility_new,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select your communication role to personalise the experience.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.deaf,
                          label: Text('Deaf'),
                          icon: Icon(Icons.sign_language),
                        ),
                        ButtonSegment(
                          value: UserRole.hearing,
                          label: Text('Hearing'),
                          icon: Icon(Icons.hearing),
                        ),
                        ButtonSegment(
                          value: UserRole.both,
                          label: Text('Both'),
                          icon: Icon(Icons.accessibility_new),
                        ),
                      ],
                      selected: {a11yCtrl.role},
                      onSelectionChanged: (selected) {
                        a11yCtrl.setRole(selected.first);
                      },
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Theme ──
          _SectionCard(
            title: 'Appearance',
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                leading: Icon(themeCtrl.icon),
                title: const Text('Theme'),
                subtitle: Text(themeCtrl.label),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode, size: 18),
                    ),
                  ],
                  selected: {themeCtrl.themeMode},
                  onSelectionChanged: (s) => themeCtrl.setThemeMode(s.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Caption Settings ──
          _SectionCard(
            title: 'Captions & Subtitles',
            icon: Icons.subtitles_outlined,
            children: [
              SwitchListTile(
                title: const Text('Enable Captions'),
                subtitle: const Text('Show real-time subtitles during calls'),
                value: a11yCtrl.captionsEnabled,
                onChanged: a11yCtrl.setCaptionsEnabled,
                activeColor: AppColors.primary,
              ),
              ListTile(
                title: const Text('Caption Font Size'),
                subtitle: Slider(
                  value: a11yCtrl.captionFontSize,
                  min: 12,
                  max: 28,
                  divisions: 8,
                  label: '${a11yCtrl.captionFontSize.round()}',
                  onChanged: a11yCtrl.setCaptionFontSize,
                  activeColor: AppColors.primary,
                ),
                trailing: Text(
                  '${a11yCtrl.captionFontSize.round()}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Notifications ──
          _SectionCard(
            title: 'Notifications',
            icon: Icons.notifications_outlined,
            children: [
              SwitchListTile(
                title: const Text('Visual Notifications'),
                subtitle: const Text('Use vibration and flash instead of audio alerts'),
                value: a11yCtrl.visualNotifications,
                onChanged: a11yCtrl.setVisualNotifications,
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── About ──
          _SectionCard(
            title: 'About',
            icon: Icons.info_outline,
            children: [
              const ListTile(
                title: Text('SignBridge'),
                subtitle: Text('AI-Based Two-Way Sign Language Recognition\n& Speech Translation'),
              ),
              ListTile(
                title: const Text('Version'),
                subtitle: const Text('1.0.0'),
                trailing: Icon(Icons.verified,
                    color: AppColors.primary.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Neumorphic-style section card ──
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: AppTheme.neumorphic(context, radius: AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
