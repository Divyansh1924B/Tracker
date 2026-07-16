import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'core/utils/logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    Logger.error('Flutter Framework Error', details.exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    Logger.error('Platform Async Error', error, stack);
    return true;
  };

  runApp(
    const ProviderScope(
      child: FamilyTrackerApp(),
    ),
  );
}

class FamilyTrackerApp extends ConsumerWidget {
  const FamilyTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Family Tracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
