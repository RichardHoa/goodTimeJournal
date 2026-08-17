import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/finance_provider.dart';
import 'providers/settings_provider.dart';
import 'services/widget_service.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
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
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'mixApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const MainShellScreen(),
    );
  }
}
