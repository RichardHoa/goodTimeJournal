import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static const String appGroupId = 'group.com.goodtimejournal.mixapp';
  static const String androidWidget2x2Name = 'FinanceWidgetProvider';
  static const String androidWidget4x4Name = 'FinanceWidget4x4Provider';

  /// Initialize home_widget configuration
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } catch (e) {
      debugPrint('WidgetService init error: $e');
    }
  }

  /// Update the displayed liquid balance on Android home screen widgets
  static Future<void> updateWidgetData(double totalLiquidBalance) async {
    try {
      final formatter = NumberFormat('#,##0.##', 'en_US');
      final formattedBalance = '${formatter.format(totalLiquidBalance)} k';

      await HomeWidget.saveWidgetData<String>('total_balance', formattedBalance);
      await HomeWidget.updateWidget(
        name: androidWidget2x2Name,
        androidName: androidWidget2x2Name,
      );
      await HomeWidget.updateWidget(
        name: androidWidget4x4Name,
        androidName: androidWidget4x4Name,
      );
    } on MissingPluginException {
      // Ignored in unit tests where native channels are unmocked
    } catch (e) {
      debugPrint('Error updating home widget balance data: $e');
    }
  }

  /// Retrieve payload URI from widget launch if app was launched via widget button
  static Future<Uri?> getInitiallyLaunchedUri() async {
    try {
      return await HomeWidget.initiallyLaunchedFromHomeWidget();
    } catch (e) {
      debugPrint('Error fetching initially launched widget URI: $e');
      return null;
    }
  }

  /// Stream widget launch URIs (when app is opened from widget while backgrounded or active)
  static Stream<Uri?> get widgetLaunchedStream => HomeWidget.widgetClicked;
}
