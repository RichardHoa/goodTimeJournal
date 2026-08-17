import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/finance_provider.dart';
import '../models/finance_model.dart';
import '../services/csv_service.dart';
import '../theme/app_theme.dart';
import 'finance_info_screen.dart';
import 'transaction_history_screen.dart';
import 'money_transaction_screen.dart';
import '../widgets/finance_transaction_tile.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  void _navigateToInfoScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FinanceInfoScreen()),
    );
  }

  Future<void> _exportCsv(BuildContext context, FinanceProvider provider) async {
    final csvData = CsvService.exportFinanceToCsv(provider.balances, provider.transactions);
    final file = await CsvService.saveCsvToDownloads(csvData, filenamePrefix: 'mixapp_finance');
    
    if (context.mounted) {
      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV exported successfully to Downloads:\n${file.path}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to export CSV file.'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    }
  }

  void _openTransactionScreen(BuildContext context, bool isMoneyIn) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MoneyTransactionScreen(isMoneyIn: isMoneyIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final financeProvider = Provider.of<FinanceProvider>(context);

    if (financeProvider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'mixApp Finance',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Finance Summary & Accounts',
            onPressed: () => _navigateToInfoScreen(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(context, financeProvider),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visual Header Drawing Section
            _FinanceDrawingHeader(onOpenInfo: () => _navigateToInfoScreen(context)),
            const SizedBox(height: 24),

            // Money In / Money Out Action Buttons Group
            _ActionButtonsGroup(
              onMoneyIn: () => _openTransactionScreen(context, true),
              onMoneyOut: () => _openTransactionScreen(context, false),
            ),
            const SizedBox(height: 28),

            // Transaction History Section Feed
            const _RecentTransactionsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Minimalist Visual Header Drawing replacing the text hero banner
class _FinanceDrawingHeader extends StatelessWidget {
  final VoidCallback onOpenInfo;

  const _FinanceDrawingHeader({required this.onOpenInfo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightPrimaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightPrimary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _FinanceCanvasPainter(
                  primaryColor: theme.colorScheme.primary,
                  secondaryColor: theme.colorScheme.secondary,
                  isDark: isDark,
                ),
              ),
            ),
            Positioned(
              top: 14,
              right: 14,
              child: InkWell(
                onTap: onOpenInfo,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkBg : Colors.white).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Accounts & Balances',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceCanvasPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;
  final bool isDark;

  _FinanceCanvasPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background gradient wave shape
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.7);
    wavePath.quadraticBezierTo(
      size.width * 0.25, size.height * 0.3,
      size.width * 0.5, size.height * 0.6,
    );
    wavePath.quadraticBezierTo(
      size.width * 0.75, size.height * 0.9,
      size.width, size.height * 0.4,
    );
    wavePath.lineTo(size.width, size.height);
    wavePath.lineTo(0, size.height);
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          primaryColor.withValues(alpha: isDark ? 0.2 : 0.15),
          secondaryColor.withValues(alpha: isDark ? 0.08 : 0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(wavePath, wavePaint);

    // Dynamic financial sparkline curve
    final sparkPath = Path();
    sparkPath.moveTo(20, size.height * 0.65);
    sparkPath.cubicTo(
      size.width * 0.2, size.height * 0.25,
      size.width * 0.4, size.height * 0.8,
      size.width * 0.65, size.height * 0.35,
    );

    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(sparkPath, linePaint);

    // Glowing Node Points on Sparkline
    final nodePoints = [
      Offset(20, size.height * 0.65),
      Offset(size.width * 0.2, size.height * 0.38),
      Offset(size.width * 0.4, size.height * 0.68),
      Offset(size.width * 0.65, size.height * 0.35),
    ];

    for (final point in nodePoints) {
      final glowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 6.0, glowPaint);

      final dotPaint = Paint()
        ..color = primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point, 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FinanceCanvasPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.isDark != isDark;
  }
}

/// Primary Money In and Money Out Action Buttons
class _ActionButtonsGroup extends StatelessWidget {
  final VoidCallback onMoneyIn;
  final VoidCallback onMoneyOut;

  const _ActionButtonsGroup({
    required this.onMoneyIn,
    required this.onMoneyOut,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: isDark ? const Color(0xFF0D0B14) : Colors.white,
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
            label: const Text(
              'Money in',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: onMoneyIn,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkPrimaryContainer : AppTheme.lightPrimaryContainer,
              foregroundColor: theme.colorScheme.primary,
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              elevation: 0,
              side: BorderSide(
                color: isDark ? AppTheme.darkBorder : theme.colorScheme.primary.withValues(alpha: 0.25),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
            label: const Text(
              'Money out',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: onMoneyOut,
          ),
        ),
      ],
    );
  }
}

/// Transaction history feed section showing 3 most recent transactions
class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection();

  void _openEditModal(BuildContext context, FinanceTransaction transaction) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => MoneyTransactionScreen(
          isMoneyIn: transaction.type == TransactionType.moneyIn,
          existingTransaction: transaction,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<FinanceProvider>(context);
    final transactions = provider.transactions;
    final recentTransactions = transactions.take(3).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const TransactionHistoryScreen()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all (${transactions.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (transactions.isEmpty)
          const _EmptyStateWidget()
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recentTransactions.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final t = recentTransactions[index];
              return FinanceTransactionTile(
                transaction: t,
                onTap: () => _openEditModal(context, t),
              );
            },
          ),
      ],
    );
  }
}

class _EmptyStateWidget extends StatelessWidget {
  const _EmptyStateWidget();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 42,
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
          ),
          const SizedBox(height: 12),
          const Text(
            'No transactions recorded yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap "Money in" or "Money out" above to log cashflow.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}
