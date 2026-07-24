import 'package:flutter/material.dart';

class AppFormPage extends StatelessWidget {
  const AppFormPage({
    super.key,
    required this.title,
    required this.accent,
    required this.child,
    this.actions,
  });

  final String title;
  final Color accent;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(false),
          icon: const Icon(Icons.close),
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth > 640
                ? 640.0
                : constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(color: accent, width: 3),
                      left: constraints.maxWidth > 640
                          ? BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            )
                          : BorderSide.none,
                      right: constraints.maxWidth > 640
                          ? BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            )
                          : BorderSide.none,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.16),
                        blurRadius: 32,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: FocusTraversalGroup(child: child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AppFormHeader extends StatelessWidget {
  const AppFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AppFormActionBar extends StatelessWidget {
  const AppFormActionBar({
    super.key,
    required this.accent,
    required this.saveLabel,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
    this.canSave = true,
  });

  final Color accent;
  final String saveLabel;
  final bool isSaving;
  final bool canSave;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 12 : 18,
            12,
            compact ? 12 : 18,
            compact ? 12 : 18,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onCancel,
                  child: const Text(
                    'Cancel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: isSaving || !canSave ? null : onSave,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: isSaving
                      ? Semantics(
                          label: 'Saving',
                          child: const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    isSaving ? 'Saving...' : saveLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

EdgeInsets appFormContentPadding(BuildContext context) {
  final horizontal = MediaQuery.sizeOf(context).width < 360 ? 12.0 : 18.0;
  return EdgeInsets.fromLTRB(horizontal, 10, horizontal, 18);
}
