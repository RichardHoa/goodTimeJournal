import 'package:flutter/material.dart';
import '../providers/finance_provider.dart';

/// The symbol for an account: its bank's logo, or a wallet for Cash.
class AccountIcon extends StatelessWidget {
  final String account;
  final double size;

  const AccountIcon(this.account, {super.key, this.size = 20});

  static const Map<String, String> _assets = {
    'VCB': 'assets/bank_icons/vcb.png',
    'MB': 'assets/bank_icons/mb.png',
    'Techcombank': 'assets/bank_icons/techcombank.png',
    FinanceProvider.mbInvestment: 'assets/bank_icons/mb.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[account];
    if (asset == null) {
      return Icon(
        account == 'Cash' ? Icons.account_balance_wallet_rounded : Icons.account_balance_rounded,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return Image.asset(asset, width: size, height: size, filterQuality: FilterQuality.medium);
  }
}
