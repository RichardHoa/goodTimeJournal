import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../theme/app_theme.dart';

/// Full-page Finance Info & Accounts Management screen with back button.
class FinanceInfoScreen extends StatelessWidget {
  const FinanceInfoScreen({super.key});

  static final NumberFormat _currencyFormatter = NumberFormat('#,###', 'en_US');

  String _formatVnd(double kValue) {
    final double fullVnd = kValue * 1000;
    return '${_currencyFormatter.format(fullVnd)} VND';
  }

  void _openEditFieldDialog(
    BuildContext context,
    FinanceProvider provider,
    String fieldName,
    double currentValue,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _EditAccountDialog(
        fieldName: fieldName,
        currentValue: currentValue,
        onSave: (newValue) {
          provider.updateAccountField(fieldName, newValue);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = Provider.of<FinanceProvider>(context);
    final balances = provider.balances;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Finance',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Accounts & Balances',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Wealth Summary Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightPrimaryContainer,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? AppTheme.darkBorder
                      : AppTheme.lightPrimary.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.stars_rounded,
                          color: theme.colorScheme.secondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Money Left (Available Spending)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _formatVnd(balances.moneyLeft),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Net Worth',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatVnd(balances.totalMoney),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Backup Fund',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatVnd(balances.backupFund),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Accounts & Funds
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Accounts & Funds',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'Tap item to edit',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  _buildEditableAccountRow(
                    context, provider, 'Cash', balances.cash, Icons.payments_outlined, isFirst: true,
                  ),
                  _buildDivider(isDark),
                  _buildEditableAccountRow(
                    context, provider, 'VCB', balances.vcb, Icons.account_balance_outlined,
                  ),
                  _buildDivider(isDark),
                  _buildEditableAccountRow(
                    context, provider, 'MB', balances.mb, Icons.account_balance_rounded,
                  ),
                  _buildDivider(isDark),
                  _buildEditableAccountRow(
                    context, provider, 'Techcombank', balances.techcombank, Icons.credit_card_rounded,
                  ),
                  _buildDivider(isDark),
                  _buildEditableAccountRow(
                    context, provider, 'MB fund', balances.mbFund, Icons.savings_outlined, isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 2: Asset Breakdown
            Text(
              'Asset Breakdown',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkPrimaryContainer.withValues(alpha: 0.5)
                    : AppTheme.lightPrimaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppTheme.darkBorder
                      : AppTheme.lightPrimary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  _buildAssetRow(
                    context,
                    label: 'Total Money',
                    amount: balances.totalMoney,
                    subtitle: 'Sum of all active accounts',
                    isBold: true,
                  ),
                  const SizedBox(height: 14),
                  _buildDivider(isDark),
                  const SizedBox(height: 14),
                  _buildAssetRow(
                    context,
                    label: 'Backup Fund',
                    amount: balances.backupFund,
                    subtitle: 'Tap icon to edit reserve fund',
                    isEditable: true,
                    color: theme.colorScheme.primary,
                    onTap: () => _openEditFieldDialog(
                      context, provider, 'Backup Fund', balances.backupFund,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildDivider(isDark),
                  const SizedBox(height: 14),
                  _buildAssetRow(
                    context,
                    label: 'Money Left',
                    amount: balances.moneyLeft,
                    subtitle: 'Total Money - Backup Fund',
                    isBold: true,
                    color: theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Section 3: App & Asset Credits
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.copyright_rounded,
                    size: 20,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'App Icon Attribution',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'App icon belongs to Good mood icons created by Magnific - Flaticon',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
    );
  }

  Widget _buildEditableAccountRow(
    BuildContext context,
    FinanceProvider provider,
    String name,
    double value,
    IconData icon, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: () => _openEditFieldDialog(context, provider, name, value),
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(20) : Radius.zero,
        bottom: isLast ? const Radius.circular(20) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkPrimaryContainer
                    : AppTheme.lightPrimaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatVnd(value),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: theme.colorScheme.primary.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetRow(
    BuildContext context, {
    required String label,
    required double amount,
    required String subtitle,
    bool isBold = false,
    bool isEditable = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textStyle = TextStyle(
      fontSize: isBold ? 16.5 : 15,
      fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
      color: color ?? theme.textTheme.bodyLarge?.color,
    );

    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: textStyle),
                  if (isEditable) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                ),
              ),
            ],
          ),
          Text(
            _formatVnd(amount),
            style: textStyle,
          ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: content,
    );
  }
}

class _EditAccountDialog extends StatefulWidget {
  final String fieldName;
  final double currentValue;
  final ValueChanged<double> onSave;

  const _EditAccountDialog({
    required this.fieldName,
    required this.currentValue,
    required this.onSave,
  });

  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final v = widget.currentValue;
    _controller = TextEditingController(
      text: v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSave() {
    final rawText = _controller.text.trim().replaceAll(',', '.');
    final newValue = double.tryParse(rawText);
    if (newValue == null || newValue < 0) {
      setState(() {
        _errorText = 'Please enter a valid positive number';
      });
      return;
    }

    widget.onSave(newValue);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Edit ${widget.fieldName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                suffixText: 'k VND',
                errorText: _errorText,
              ),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(90, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onPressed: _handleSave,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
