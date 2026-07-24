import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<bool> showAppDestructiveConfirmation({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  IconData icon = Icons.delete_outline,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(icon, color: AppTheme.rose),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.rose,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          icon: Icon(icon),
          label: Text(confirmLabel),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
