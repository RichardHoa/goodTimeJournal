import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_model.dart';
import '../theme/app_theme.dart';

class MoneyTransactionScreen extends StatefulWidget {
  final bool isMoneyIn;
  final FinanceTransaction? existingTransaction;

  const MoneyTransactionScreen({
    super.key,
    required this.isMoneyIn,
    this.existingTransaction,
  });

  @override
  State<MoneyTransactionScreen> createState() => _MoneyTransactionScreenState();
}

class _MoneyTransactionScreenState extends State<MoneyTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<String> _accounts = FinanceProvider.liquidAccounts;
  late String _selectedAccount;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _noteFocusNode = FocusNode();
  
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
    _amountFocusNode.dispose();
    _noteFocusNode.dispose();
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
            color: isEditing ? null : actionColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: actionColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: actionColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.isMoneyIn
                              ? Icons.add_circle_outline_rounded
                              : Icons.remove_circle_outline_rounded,
                          color: isDark ? const Color(0xFF0D0B14) : Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'Update Transaction Details'
                                  : (widget.isMoneyIn
                                      ? 'Record Incoming Cashflow'
                                      : 'Record Outgoing Cashflow'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Specify account, amount, and reason',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account Selection
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

                // AMOUNT BOX
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
                  focusNode: _amountFocusNode,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(_noteFocusNode);
                  },
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

                // REASON BOX IMMEDIATELY BELOW AMOUNT BOX (Tight 12px vertical spacing)
                const SizedBox(height: 12),
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
                  focusNode: _noteFocusNode,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(18),
                    alignLabelWithHint: true,
                    hintText: 'Enter reason or note...',
                  ),
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
