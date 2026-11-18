import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_model.dart';
import '../providers/finance_provider.dart';

/// Ask for a name and add a Category of [type]. Resolves to the new
/// Category's id, or null when cancelled.
Future<String?> showNewCategoryDialog(BuildContext context, TransactionType type) {
  return showDialog<String>(context: context, builder: (ctx) => CategoryNameDialog(type: type));
}

/// Add a Category of [type], or rename [category] when given. Pops with the
/// Category's id on success.
class CategoryNameDialog extends StatefulWidget {
  final TransactionType type;
  final Category? category;

  const CategoryNameDialog({super.key, required this.type, this.category});

  @override
  State<CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<CategoryNameDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.category?.name ?? '');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final provider = context.read<FinanceProvider>();
    final name = _controller.text;
    final category = widget.category;
    final error = category == null
        ? await provider.addCategory(name: name, type: widget.type)
        : await provider.renameCategory(category.id, name);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final key = name.trim().toLowerCase();
    final saved = provider.categoriesFor(widget.type).firstWhere((c) => c.name.toLowerCase() == key);
    Navigator.of(context).pop(saved.id);
  }

  @override
  Widget build(BuildContext context) {
    final isMoneyIn = widget.type == TransactionType.moneyIn;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.category == null
          ? (isMoneyIn ? 'New Money In category' : 'New Money Out category')
          : 'Rename category'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: isMoneyIn ? 'Name, e.g. Salary' : 'Name, e.g. Food', errorText: _error),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

/// A dropdown of [type]'s Categories plus Uncategorized, with "+ New
/// category" at the end to add one without leaving the form.
class CategoryPicker extends StatefulWidget {
  final TransactionType type;
  final String? value;
  final ValueChanged<String?> onChanged;

  const CategoryPicker({super.key, required this.type, required this.value, required this.onChanged});

  @override
  State<CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends State<CategoryPicker> {
  static const String _newCategory = '__new_category__';

  /// Bumped to rebuild the dropdown, so a cancelled "+ New category" stops
  /// showing as selected.
  int _resets = 0;

  @override
  Widget build(BuildContext context) {
    final type = widget.type;
    final value = widget.value;
    final theme = Theme.of(context);
    final categories = context.watch<FinanceProvider>().categoriesFor(type);
    // A Category deleted meanwhile reads as Uncategorized.
    final selected = categories.any((c) => c.id == value) ? value : null;

    return DropdownButtonFormField<String?>(
      // Rebuild with the new value after "+ New category" adds one.
      key: ValueKey('category-$selected-$_resets'),
      initialValue: selected,
      isExpanded: true,
      decoration: const InputDecoration(prefixIcon: Icon(Icons.label_outline_rounded)),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Uncategorized')),
        for (final c in categories)
          DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
        DropdownMenuItem<String?>(
          value: _newCategory,
          child: Row(
            children: [
              Icon(Icons.add_rounded, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('New category', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      onChanged: (id) async {
        if (id != _newCategory) {
          widget.onChanged(id);
          return;
        }
        final created = await showNewCategoryDialog(context, type);
        if (!mounted) return;
        // Cancelled: keep the previous choice.
        setState(() => _resets++);
        widget.onChanged(created ?? selected);
      },
    );
  }
}
