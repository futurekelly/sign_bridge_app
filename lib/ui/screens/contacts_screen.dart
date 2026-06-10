// ContactsScreen — Manage saved contacts with search, add, delete, and quick call options.
// Fully localized (EN / SW). Uses Neumorphic design.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/accessibility_controller.dart';
import '../../core/enums.dart';
import '../../core/theme.dart';
import '../../core/spacing.dart';
import '../../core/routes.dart';
import '../../data/models/contact.dart';
import '../../data/repositories/contacts_repository.dart';
import '../widgets/role_badge.dart';
import '../../services/webrtc/call_manager.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _repo = ContactsRepository();
  final _searchCtrl = TextEditingController();
  List<Contact> _allItems = [];
  List<Contact> _filtered = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _allItems = _repo.getAll();
      _applyFilters();
    });
  }

  void _applyFilters() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filtered = List.from(_allItems);
    } else {
      _filtered = _allItems
          .where((c) =>
              c.name.toLowerCase().contains(query) ||
              c.id.toLowerCase().contains(query))
          .toList();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Add Contact Dialog
  Future<void> _addContact(AccessibilityController a11y) async {
    final nameCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    UserRole selectedRole = UserRole.both;

    final theme = Theme.of(context);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(a11y.t('contacts.add')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: a11y.t('contacts.name'),
                        hintText: a11y.t('contacts.name_hint'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: idCtrl,
                      decoration: InputDecoration(
                        labelText: a11y.t('contacts.id'),
                        hintText: a11y.t('contacts.id_hint'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        a11y.t('contacts.role'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    DropdownButtonFormField<UserRole>(
                      initialValue: selectedRole,
                      items: [
                        DropdownMenuItem(
                          value: UserRole.deaf,
                          child: Text(a11y.t('settings.deaf')),
                        ),
                        DropdownMenuItem(
                          value: UserRole.hearing,
                          child: Text(a11y.t('settings.hearing')),
                        ),
                        DropdownMenuItem(
                          value: UserRole.both,
                          child: Text(a11y.t('settings.both')),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(a11y.t('home.cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final id = idCtrl.text.trim();
                    if (name.isNotEmpty && id.isNotEmpty) {
                      final contact = Contact(
                        id: id,
                        name: name,
                        userRole: selectedRole.value,
                      );
                      _repo.save(contact);
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: Text(a11y.t('contacts.save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      _refresh();
    }
  }

  // Delete Contact Dialog
  Future<void> _deleteContact(Contact contact, AccessibilityController a11y) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(a11y.t('contacts.delete_confirm')),
        content: Text(contact.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(a11y.t('home.cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(a11y.t('common.ok')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.delete(contact.id);
      _refresh();
    }
  }

  // Click Options Sheet
  void _showContactOptions(Contact contact, AccessibilityController a11y) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Text(
                      contact.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${contact.id}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Join existing call hosted by this contact (using their ID as Call ID)
              ListTile(
                leading: const Icon(Icons.call_received, color: AppColors.secondary),
                title: Text(a11y.t('home.join_call')),
                subtitle: Text('Use ID: ${contact.id}'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(
                    context,
                    AppRoutes.call,
                    arguments: CallArgs(role: CallRole.callee, callId: contact.id),
                  );
                },
              ),
              // Start a call directly (dials the contact)
              ListTile(
                leading: const Icon(Icons.add_call, color: AppColors.primary),
                title: Text(a11y.t('home.create_call')),
                subtitle: Text('Call ${contact.name} directly'),
                onTap: () async {
                  Navigator.pop(ctx); // close bottom sheet
                  
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (loadingCtx) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    final calleeUid = await CallManager.instance.resolveSignBridgeId(contact.id);
                    if (calleeUid == null) {
                      if (mounted) {
                        Navigator.pop(context); // close loading indicator
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact not found in database')),
                        );
                      }
                      return;
                    }

                    final callId = await CallManager.instance.initiateCall(calleeUid);
                    if (mounted) {
                      Navigator.pop(context); // close loading indicator
                      Navigator.pushNamed(
                        context,
                        AppRoutes.call,
                        arguments: CallArgs(role: CallRole.caller, callId: callId, peerUid: calleeUid),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context); // close loading indicator
                      final errMsg = e.toString().replaceAll('Exception: ', '').replaceAll('FirebaseException: ', '');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(errMsg)),
                      );
                    }
                  }
                },
              ),
              // Copy User ID
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.grey),
                title: Text(a11y.t('home.id_copied').replaceAll(' copied!', '')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Clipboard.setData(ClipboardData(text: contact.id));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(a11y.t('home.id_copied')),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              // Delete
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: Text(a11y.t('history.clear')),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteContact(contact, a11y);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a11y = context.watch<AccessibilityController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(a11y.t('contacts.title')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addContact(a11y),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text(
          a11y.t('contacts.add'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Container(
              decoration: AppTheme.neumorphic(context, radius: AppRadius.xl),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _applyFilters()),
                decoration: InputDecoration(
                  hintText: a11y.t('learning.search'),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _applyFilters());
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
            ),
          ),

          // Contacts List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          a11y.t('contacts.empty'),
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) {
                      final contact = _filtered[i];
                      final roleEnum = UserRoleX.fromString(contact.userRole);

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        decoration: AppTheme.neumorphic(context, radius: AppRadius.lg),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: 4,
                          ),
                          onTap: () => _showContactOptions(contact, a11y),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              contact.name.isNotEmpty
                                  ? contact.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            contact.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            contact.id,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          ),
                          trailing: RoleBadge(role: roleEnum, compact: true),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
