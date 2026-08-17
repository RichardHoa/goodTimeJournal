import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/journal_provider.dart';
import 'providers/finance_provider.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JournalProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
      ],
      child: const MixApp(),
    ),
  );
}

class MixApp extends StatelessWidget {
  const MixApp({super.key});

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context);

    return MaterialApp(
      title: 'mixApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: journalProvider.themeMode,
      home: const MainShellScreen(),
    );
  }
}
