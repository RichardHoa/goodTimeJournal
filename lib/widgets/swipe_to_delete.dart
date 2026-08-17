import 'package:flutter/material.dart';

/// Ask the user to confirm a destructive action. Resolves to true only on
/// Confirm; dismissing the dialog counts as Cancel.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Swipe end-to-start to delete [child], after a confirmation dialog.
/// Cancelling slides the child back exactly as it was.
class SwipeToDelete extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onDelete;
  final Widget child;

  /// [key] must identify the item, since the swiped widget leaves the list.
  const SwipeToDelete({
    required Key super.key,
    required this.title,
    required this.message,
    required this.onDelete,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDestructive(context, title: title, message: message),
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded, color: error),
      ),
      child: child,
    );
  }
}
