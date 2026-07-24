import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_lock_controller.dart';
import '../../core/daily_reminder_controller.dart';
import '../../core/theme_mode_controller.dart';
import '../../data/category_store.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/widgets/app_dialogs.dart';
import '../../shared/widgets/app_state_widgets.dart';
import '../../shared/widgets/aurora_background.dart';

Future<void> showSettingsSheet({
  required BuildContext context,
  required String? email,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => SettingsSheet(email: email),
    ),
  );
}

class SettingsSheet extends ConsumerStatefulWidget {
  const SettingsSheet({super.key, required this.email});

  final String? email;

  @override
  ConsumerState<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<SettingsSheet> {
  final _incomeController = TextEditingController();
  final _expenseController = TextEditingController();
  final _store = CategoryStore();

  List<String> _incomeCategories = const [];
  List<String> _expenseCategories = const [];
  final Set<CategoryKind> _updatingKinds = {};
  bool _isLoading = true;
  String? _error;
  String? _incomeInputError;
  String? _expenseInputError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _incomeController.dispose();
    _expenseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final income = await _store.loadCustom(CategoryKind.income);
      final expense = await _store.loadCustom(CategoryKind.expense);
      if (!mounted) return;
      setState(() {
        _incomeCategories = income;
        _expenseCategories = expense;
        _isLoading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Could not load settings. ${error.toString()}';
      });
    }
  }

  Future<void> _add(CategoryKind kind) async {
    if (_updatingKinds.contains(kind)) return;
    final controller = kind == CategoryKind.income
        ? _incomeController
        : _expenseController;
    final category = controller.text.trim();
    if (category.isEmpty) return;

    final categories = kind == CategoryKind.income
        ? _incomeCategories
        : _expenseCategories;
    final exists = categories.any(
      (item) => item.toLowerCase() == category.toLowerCase(),
    );
    if (exists) {
      setState(() => _setInputError(kind, 'This category already exists.'));
      return;
    }

    setState(() {
      _updatingKinds.add(kind);
      _error = null;
    });

    try {
      await _store.addCustom(kind, category);
      if (!mounted) return;
      controller.clear();
      _setInputError(kind, null);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not save category. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _updatingKinds.remove(kind));
    }
  }

  void _setInputError(CategoryKind kind, String? message) {
    if (kind == CategoryKind.income) {
      _incomeInputError = message;
    } else {
      _expenseInputError = message;
    }
  }

  Future<void> _delete(CategoryKind kind, String category) async {
    if (_updatingKinds.contains(kind)) return;
    final confirmed = await showAppDestructiveConfirmation(
      context: context,
      title: 'Delete Category?',
      message: 'Remove "$category" from your custom categories?',
      confirmLabel: 'Delete Category',
      icon: Icons.label_off_outlined,
    );

    if (!mounted || !confirmed) return;
    setState(() {
      _updatingKinds.add(kind);
      _error = null;
    });

    try {
      await _store.deleteCustom(kind, category);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Could not delete category. ${error.toString()}');
    } finally {
      if (mounted) setState(() => _updatingKinds.remove(kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Text('Settings'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AuroraBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth < 360 ? 12.0 : 18.0;
                return Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    key: const ValueKey('settings-workspace'),
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: ListView(
                      key: const ValueKey('settings-scroll-view'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        14,
                        horizontal,
                        24,
                      ),
                      children: [
                        _SettingsHeader(email: widget.email),
                        const SizedBox(height: 14),
                        _AppearanceSection(
                          themeMode: ref.watch(themeModeProvider),
                          onChanged: (mode) => ref
                              .read(themeModeProvider.notifier)
                              .setThemeMode(mode),
                        ),
                        const SizedBox(height: 14),
                        const _SecuritySection(),
                        const SizedBox(height: 18),
                        if (_isLoading)
                          const _SettingsLoadingState()
                        else ...[
                          if (_error != null) ...[
                            _SettingsError(message: _error!),
                            const SizedBox(height: 12),
                          ],
                          LayoutBuilder(
                            builder: (context, sectionConstraints) {
                              final income = _CategorySettingsSection(
                                sectionKey: 'income',
                                title: 'Income Categories',
                                subtitle:
                                    'Defaults stay available automatically',
                                icon: Icons.south_west,
                                color: AppTheme.neonEmerald,
                                controller: _incomeController,
                                categories: _incomeCategories,
                                emptyText: 'No custom income categories yet',
                                inputError: _incomeInputError,
                                isUpdating: _updatingKinds.contains(
                                  CategoryKind.income,
                                ),
                                onInputChanged: () {
                                  if (_incomeInputError == null) return;
                                  setState(() => _incomeInputError = null);
                                },
                                onAdd: () => _add(CategoryKind.income),
                                onDelete: (category) =>
                                    _delete(CategoryKind.income, category),
                              );
                              final expense = _CategorySettingsSection(
                                sectionKey: 'expense',
                                title: 'Expense Categories',
                                subtitle: 'Use these in expenses and budgets',
                                icon: Icons.north_east,
                                color: AppTheme.neonRose,
                                controller: _expenseController,
                                categories: _expenseCategories,
                                emptyText: 'No custom expense categories yet',
                                inputError: _expenseInputError,
                                isUpdating: _updatingKinds.contains(
                                  CategoryKind.expense,
                                ),
                                onInputChanged: () {
                                  if (_expenseInputError == null) return;
                                  setState(() => _expenseInputError = null);
                                },
                                onAdd: () => _add(CategoryKind.expense),
                                onDelete: (category) =>
                                    _delete(CategoryKind.expense, category),
                              );

                              if (sectionConstraints.maxWidth < 760) {
                                return Column(
                                  children: [
                                    income,
                                    const SizedBox(height: 14),
                                    expense,
                                  ],
                                );
                              }

                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: income),
                                  const SizedBox(width: 14),
                                  Expanded(child: expense),
                                ],
                              );
                            },
                          ),
                        ],
                      ],
                    ),
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

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF162447), Color(0xFF0D1220)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorderStrong),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.neonViolet, AppTheme.neonCyan],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.neonViolet.withValues(alpha: 0.4),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.tune, color: Color(0xFF04231A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal categories',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  email ?? 'Signed in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.themeMode, required this.onChanged});

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.neonCyan.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(
        Icons.dark_mode_outlined,
        color: AppTheme.neonCyan,
        size: 18,
      ),
    );

    final labels = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Appearance',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          'Choose dark or light for the whole app',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final toggle = SegmentedButton<ThemeMode>(
      key: const ValueKey('settings-theme-mode-toggle'),
      segments: const [
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined, size: 16),
          label: Text('Dark'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined, size: 16),
          label: Text('Light'),
        ),
      ],
      selected: {
        themeMode == ThemeMode.light ? ThemeMode.light : ThemeMode.dark,
      },
      onSelectionChanged: (selection) => onChanged(selection.first),
      showSelectedIcon: false,
    );

    return Card(
      elevation: 8,
      shadowColor: AppTheme.neonCyan.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      Expanded(child: labels),
                    ],
                  ),
                  const SizedBox(height: 12),
                  toggle,
                ],
              );
            }

            return Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(child: labels),
                const SizedBox(width: 10),
                toggle,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SecuritySection extends ConsumerWidget {
  const _SecuritySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final reminder = ref.watch(dailyReminderProvider);

    return Card(
      elevation: 8,
      shadowColor: AppTheme.neonViolet.withValues(alpha: 0.25),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.neonViolet.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: AppTheme.neonViolet,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security & Reminders',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Protect the app and remember to log daily',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _SecurityToggleRow(
              switchKey: const ValueKey('settings-app-lock-toggle'),
              icon: Icons.fingerprint,
              title: 'App lock',
              subtitle: lock.isSupported
                  ? 'Require your fingerprint, face, or PIN to open the app'
                  : 'No screen lock is set up on this device, so this is unavailable',
              value: lock.enabled,
              enabled: lock.isSupported,
              onChanged: (value) =>
                  ref.read(appLockProvider.notifier).setEnabled(value),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            _SecurityToggleRow(
              switchKey: const ValueKey('settings-daily-reminder-toggle'),
              icon: Icons.notifications_active_outlined,
              title: 'Daily reminder',
              subtitle: reminder.enabled
                  ? 'Reminding you at ${reminder.time.format(context)} every day'
                  : "Get a nudge to log today's spending",
              value: reminder.enabled,
              enabled: true,
              onChanged: (value) async {
                final granted = await ref
                    .read(dailyReminderProvider.notifier)
                    .setEnabled(value);
                if (!granted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notification permission was denied. Enable it in your phone settings to use reminders.',
                      ),
                    ),
                  );
                }
              },
            ),
            if (reminder.enabled) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('settings-reminder-time-button'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: reminder.time,
                    );
                    if (picked != null) {
                      await ref
                          .read(dailyReminderProvider.notifier)
                          .setTime(picked);
                    }
                  },
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text('Remind me at ${reminder.time.format(context)}'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SecurityToggleRow extends StatelessWidget {
  const _SecurityToggleRow({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? AppTheme.neonViolet
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(
          key: switchKey,
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _SettingsLoadingState extends StatelessWidget {
  const _SettingsLoadingState();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return const Column(
            children: [
              AppSkeletonBox(height: 210),
              SizedBox(height: 14),
              AppSkeletonBox(height: 210),
            ],
          );
        }

        return const Row(
          children: [
            Expanded(child: AppSkeletonBox(height: 210)),
            SizedBox(width: 14),
            Expanded(child: AppSkeletonBox(height: 210)),
          ],
        );
      },
    );
  }
}

class _SettingsError extends StatelessWidget {
  const _SettingsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppInlineNotice(
      icon: Icons.error_outline,
      message: message,
      color: AppTheme.neonRose,
    );
  }
}

class _CategorySettingsSection extends StatelessWidget {
  const _CategorySettingsSection({
    required this.sectionKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.controller,
    required this.categories,
    required this.emptyText,
    required this.inputError,
    required this.isUpdating,
    required this.onInputChanged,
    required this.onAdd,
    required this.onDelete,
  });

  final String sectionKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final TextEditingController controller;
  final List<String> categories;
  final String emptyText;
  final String? inputError;
  final bool isUpdating;
  final VoidCallback onInputChanged;
  final VoidCallback onAdd;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('settings-$sectionKey-section'),
      elevation: 10,
      shadowColor: color.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 28),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${categories.length}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey('settings-$sectionKey-input'),
                        controller: controller,
                        enabled: !isUpdating,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'New category',
                          prefixIcon: Icon(Icons.sell_outlined, color: color),
                          errorText: inputError,
                        ),
                        onChanged: (_) => onInputChanged(),
                        onSubmitted: (_) => onAdd(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filledTonal(
                      key: ValueKey('settings-$sectionKey-add'),
                      tooltip: 'Add category',
                      onPressed: value.text.trim().isEmpty || isUpdating
                          ? null
                          : onAdd,
                      icon: isUpdating
                          ? Semantics(
                              label: 'Updating $title',
                              child: const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            if (categories.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  emptyText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categories.map((category) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth,
                        ),
                        child: InputChip(
                          key: ValueKey('settings-$sectionKey-chip-$category'),
                          label: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: isUpdating
                              ? null
                              : () => onDelete(category),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
