// SettingsScreen — profile, role, theme, language, captions, notifications, about.
// Fully localized (EN / SW). Language toggle uses SegmentedButton.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final id = await _auth.getSignBridgeId();
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
    final a11y = context.watch<AccessibilityController>();

    return Scaffold(
      appBar: AppBar(title: Text(a11y.t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // ── Profile ──
          _SectionCard(
            title: a11y.t('settings.profile'),
            icon: Icons.person_outline,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    _displayName.isNotEmpty
                        ? _displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(_displayName,
                    style: theme.textTheme.titleMedium),
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

          // ── Language ──
          _SectionCard(
            title: a11y.t('settings.language'),
            icon: Icons.translate,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a11y.t('settings.language_desc'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'en',
                          label: Text('English'),
                          icon: Icon(Icons.language),
                        ),
                        ButtonSegment(
                          value: 'sw',
                          label: Text('Kiswahili'),
                          icon: Icon(Icons.translate),
                        ),
                      ],
                      selected: {a11y.languageCode},
                      onSelectionChanged: (s) =>
                          a11y.setLanguageCode(s.first),
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
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

          // ── Accessibility Role ──
          _SectionCard(
            title: a11y.t('settings.role'),
            icon: Icons.accessibility_new,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a11y.t('settings.role_desc'),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SegmentedButton<UserRole>(
                      segments: [
                        ButtonSegment(
                          value: UserRole.deaf,
                          label: Text(a11y.t('settings.deaf')),
                          icon: const Icon(Icons.sign_language),
                        ),
                        ButtonSegment(
                          value: UserRole.hearing,
                          label: Text(a11y.t('settings.hearing')),
                          icon: const Icon(Icons.hearing),
                        ),
                        ButtonSegment(
                          value: UserRole.both,
                          label: Text(a11y.t('settings.both')),
                          icon: const Icon(Icons.accessibility_new),
                        ),
                      ],
                      selected: {a11y.role},
                      onSelectionChanged: (s) => a11y.setRole(s.first),
                      style: ButtonStyle(
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
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

          // ── Appearance ──
          _SectionCard(
            title: a11y.t('settings.appearance'),
            icon: Icons.palette_outlined,
            children: [
              ListTile(
                leading: Icon(themeCtrl.icon),
                title: Text(a11y.t('settings.theme')),
                subtitle: Text(themeCtrl.label),
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode, size: 18)),
                    ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto, size: 18)),
                    ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode, size: 18)),
                  ],
                  selected: {themeCtrl.themeMode},
                  onSelectionChanged: (s) =>
                      themeCtrl.setThemeMode(s.first),
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

          // ── Captions ──
          _SectionCard(
            title: a11y.t('settings.captions'),
            icon: Icons.subtitles_outlined,
            children: [
              SwitchListTile(
                title: Text(a11y.t('settings.enable_captions')),
                subtitle: Text(a11y.t('settings.captions_desc')),
                value: a11y.captionsEnabled,
                onChanged: a11y.setCaptionsEnabled,
                activeTrackColor: AppColors.primary,
              ),
              ListTile(
                title: Text(a11y.t('settings.caption_size')),
                subtitle: Slider(
                  value: a11y.captionFontSize,
                  min: 12,
                  max: 28,
                  divisions: 8,
                  label: '${a11y.captionFontSize.round()}',
                  onChanged: a11y.setCaptionFontSize,
                  activeColor: AppColors.primary,
                ),
                trailing: Text(
                  '${a11y.captionFontSize.round()}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Notifications & Alerts ──
          _SectionCard(
            title: a11y.t('settings.notifications'),
            icon: Icons.notifications_outlined,
            children: [
              SwitchListTile(
                title: Text(a11y.t('settings.tts_enabled')),
                subtitle: Text(a11y.t('settings.tts_desc')),
                value: a11y.ttsEnabled,
                onChanged: a11y.setTtsEnabled,
                activeTrackColor: AppColors.primary,
              ),
              SwitchListTile(
                title: Text(a11y.t('settings.vibration')),
                subtitle: Text(a11y.t('settings.vibration_desc')),
                value: a11y.vibrationEnabled,
                onChanged: a11y.setVibrationEnabled,
                activeTrackColor: AppColors.primary,
              ),
              SwitchListTile(
                title: Text(a11y.t('settings.flashlight')),
                subtitle: Text(a11y.t('settings.flashlight_desc')),
                value: a11y.flashlightEnabled,
                onChanged: a11y.setFlashlightEnabled,
                activeTrackColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── About ──
          _SectionCard(
            title: a11y.t('settings.about'),
            icon: Icons.info_outline,
            children: [
              const ListTile(
                title: Text('SignBridge'),
                subtitle: Text(
                    'AI-Based Two-Way Sign Language Recognition\n& Speech Translation'),
              ),
              ListTile(
                title: Text(a11y.t('settings.version')),
                subtitle: const Text('1.0.0'),
                trailing: Icon(Icons.verified,
                    color: AppColors.primary.withValues(alpha: 0.6)),
              ),
              ListTile(
                title: Text(a11y.t('settings.developer')),
                subtitle: Text(a11y.t('settings.developer_name')),
              ),
              ListTile(
                leading: const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                title: Text(a11y.t('settings.contact_support')),
                subtitle: const Text('futurekelly360@gmail.com'),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  final Uri emailUri = Uri(
                    scheme: 'mailto',
                    path: 'futurekelly360@gmail.com',
                    queryParameters: {
                      'subject': 'SignBridge Support & Feedback',
                    },
                  );
                  if (await canLaunchUrl(emailUri)) {
                    await launchUrl(emailUri);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(a11y.t('common.error'))),
                      );
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Neumorphic section card ──
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
