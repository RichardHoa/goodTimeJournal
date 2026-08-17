import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_model.dart';
import '../theme/app_theme.dart';

class MoneyTransactionModal extends StatefulWidget {
  final bool isMoneyIn;
  final FinanceTransaction? existingTransaction;

  const MoneyTransactionModal({
    super.key,
    required this.isMoneyIn,
    this.existingTransaction,
  });

  @override
  State<MoneyTransactionModal> createState() => _MoneyTransactionModalState();
}

class _MoneyTransactionModalState extends State<MoneyTransactionModal> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _accounts = FinanceProvider.liquidAccounts;
  late String _selectedAccount;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _convertedVndPreview = '';

  @override
  void initState() {
    super.initState();
    final editTx = widget.existingTransaction;
    if (editTx != null) {
      _selectedAccount = _accounts.contains(editTx.account) ? editTx.account : _accounts[0];
      final amountVal = editTx.amount;
      _amountController.text = amountVal.toStringAsFixed(amountVal.truncateToDouble() == amountVal ? 0 : 2);
      _selectedDate = editTx.date;
      _noteController.text = editTx.note;
    } else {
      _selectedAccount = _accounts[0];
    }
    _amountController.addListener(_updateVndPreview);
    _updateVndPreview();
  }

  void _updateVndPreview() {
    final rawText = _amountController.text.trim().replaceAll(',', '.');
    final parsed = double.tryParse(rawText);
    if (parsed != null && parsed > 0) {
      final fullVnd = parsed * 1000;
      final formatter = NumberFormat('#,###', 'en_US');
      setState(() {
        _convertedVndPreview = '= ${formatter.format(fullVnd)} VND';
      });
    } else {
      if (_convertedVndPreview.isNotEmpty) {
        setState(() {
          _convertedVndPreview = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateVndPreview);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final rawText = _amountController.text.trim().replaceAll(',', '.');
      final amount = double.tryParse(rawText) ?? 0.0;
      final note = _noteController.text.trim();
      final provider = Provider.of<FinanceProvider>(context, listen: false);

      if (widget.existingTransaction != null) {
        provider.updateTransaction(
          id: widget.existingTransaction!.id,
          newAccount: _selectedAccount,
          newAmount: amount,
          newDate: _selectedDate,
          newNote: note,
        );
      } else if (widget.isMoneyIn) {
        provider.recordMoneyIn(
          account: _selectedAccount,
          amount: amount,
          date: _selectedDate,
          note: note,
        );
      } else {
        provider.recordMoneyOut(
          account: _selectedAccount,
          amount: amount,
          date: _selectedDate,
          note: note,
        );
      }

      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isEditing = widget.existingTransaction != null;
    final title = isEditing
        ? 'Edit Transaction'
        : (widget.isMoneyIn ? 'Money In (+)' : 'Money Out (-)');
    final actionColor = isEditing
        ? theme.colorScheme.primary
        : (widget.isMoneyIn ? theme.colorScheme.primary : theme.colorScheme.secondary);

    final actionContainerColor = actionColor.withValues(alpha: 0.12);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: actionContainerColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.isMoneyIn
                                ? Icons.add_circle_outline_rounded
                                : Icons.remove_circle_outline_rounded,
                            color: actionColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: actionColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Account Dropdown Selector
                Text(
                  widget.isMoneyIn ? 'Destination Account' : 'Source Account',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAccount,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.account_balance_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  items: _accounts.map((acc) {
                    return DropdownMenuItem(
                      value: acc,
                      child: Text(acc),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedAccount = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),

                // Amount Field
                Text(
                  'Amount (in k VND)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.attach_money_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    suffixText: 'k VND',
                    helperText: _convertedVndPreview.isNotEmpty ? _convertedVndPreview : null,
                    helperStyle: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please enter an amount';
                    }
                    final rawText = val.trim().replaceAll(',', '.');
                    final parsed = double.tryParse(rawText);
                    if (parsed == null || parsed <= 0) {
                      return 'Please enter a valid positive number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Date Picker Field
                Text(
                  'Transaction Date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.calendar_today_rounded,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(_selectedDate),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Multi-Line Reason / Description Field
                Text(
                  'Reason / Description',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _noteController,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(18),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 28),

                // Action Submit Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: isDark ? const Color(0xFF0D0B14) : Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submit,
                  icon: Icon(
                    isEditing
                        ? Icons.check_circle_outline_rounded
                        : (widget.isMoneyIn ? Icons.add_rounded : Icons.remove_rounded),
                    size: 22,
                  ),
                  label: Text(
                    isEditing
                        ? 'Save Changes'
                        : (widget.isMoneyIn ? 'Record Money In' : 'Record Money Out'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
