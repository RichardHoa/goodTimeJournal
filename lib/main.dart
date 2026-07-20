import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/journal_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => JournalProvider(),
      child: const GoodTimeJournalApp(),
    ),
  );
}

class GoodTimeJournalApp extends StatelessWidget {
  const GoodTimeJournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final journalProvider = Provider.of<JournalProvider>(context);

    return MaterialApp(
      title: 'goodTimeJournal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: journalProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
