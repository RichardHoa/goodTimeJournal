import 'dart:async';
import 'package:flutter/material.dart';
import '../services/widget_service.dart';
import '../widgets/money_transaction_modal.dart';
import 'finance_screen.dart';
import 'home_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0; // Default tab is Finance tab (0)
  StreamSubscription<Uri?>? _widgetSubscription;
  String? _lastHandledUriString;
  DateTime? _lastHandledTime;

  final List<Widget> _screens = const [
    FinanceScreen(),
    HomeScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initWidgetLaunchHandling();
  }

  @override
  void dispose() {
    _widgetSubscription?.cancel();
    super.dispose();
  }

  void _initWidgetLaunchHandling() {
    // Check initial launch deep-link when app starts from cold
    WidgetService.getInitiallyLaunchedUri().then((uri) {
      if (uri != null) {
        _handleWidgetUri(uri);
      }
    });

    // Listen to deep-links when app is resumed from background or active
    _widgetSubscription = WidgetService.widgetLaunchedStream.listen((uri) {
      if (uri != null) {
        _handleWidgetUri(uri);
      }
    });
  }

  void _handleWidgetUri(Uri uri) {
    final uriString = uri.toString().toLowerCase();
    final isMoneyIn = uriString.contains('money_in');
    final isMoneyOut = uriString.contains('money_out');

    if (!isMoneyIn && !isMoneyOut) return;

    // Debounce duplicateUri trigger within 1 second
    final now = DateTime.now();
    if (_lastHandledUriString == uriString &&
        _lastHandledTime != null &&
        now.difference(_lastHandledTime!).inMilliseconds < 1000) {
      return;
    }

    _lastHandledUriString = uriString;
    _lastHandledTime = now;

    // Switch to Finance tab
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
    }

    // Delay modal trigger slightly to ensure frame & context are fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Close any active dialogs if currently displayed
      Navigator.of(context).popUntil((route) => route.isFirst);

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => MoneyTransactionModal(isMoneyIn: isMoneyIn),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finance',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'mixApp Journal',
          ),
        ],
      ),
    );
  }
}
