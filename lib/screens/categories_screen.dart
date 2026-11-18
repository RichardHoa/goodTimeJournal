import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/finance_model.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/category_picker.dart';
import '../widgets/swipe_to_delete.dart';

/// Money In and Money Out Categories, each in creation order: add, tap to
/// rename, swipe left to delete.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const List<TransactionType> _types = [TransactionType.moneyOut, TransactionType.moneyIn];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _types.length,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Categories', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.2)),
            bottom: const TabBar(tabs: [Tab(text: 'Money Out'), Tab(text: 'Money In')]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showNewCategoryDialog(context, _types[DefaultTabController.of(context).index]),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add category'),
          ),
          body: TabBarView(children: [for (final type in _types) _CategoryList(type: type)]),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  final TransactionType type;

  const _CategoryList({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    final provider = context.watch<FinanceProvider>();
    final categories = provider.categoriesFor(type);
    final direction = type == TransactionType.moneyIn ? 'Money In' : 'Money Out';

    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No $direction categories yet. Tap "Add category" to make one.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: muted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        Text('Tap to rename · swipe left to delete', style: TextStyle(fontSize: 12, color: muted)),
        const SizedBox(height: 10),
        for (final category in categories) ...[
          _buildRow(context, provider, category, muted),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, FinanceProvider provider, Category category, Color muted) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final used = provider.categoryUsage(category.id);
    final usedLabel = used == 1 ? '1 record' : '$used records';

    return SwipeToDelete(
      key: ValueKey('category-${category.id}'),
      title: 'Delete "${category.name}"?',
      message: '${used == 0 ? 'No records use it.' : 'Used by $usedLabel, which will become Uncategorized.'} '
          'It will be moved to Trash; restoring it within ${FinanceProvider.trashRetention.inDays} days '
          'gives it back to those records.',
      onDelete: () => context.read<FinanceProvider>().deleteCategory(category.id),
      child: Material(
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showDialog<String>(
            context: context,
            builder: (ctx) => CategoryNameDialog(type: type, category: category),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.label_outline_rounded, color: theme.colorScheme.primary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(usedLabel, style: TextStyle(fontSize: 12.5, color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
