import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/constants.dart';
import 'providers/auth_provider.dart';
import 'providers/seat_map_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'widgets/inactivity_watcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  final authProvider = AuthProvider();
  await authProvider.initAuth();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => SeatMapProvider()),
      ],
      child: const SeatMapApp(),
    ),
  );
}

class SeatMapApp extends StatelessWidget {
  const SeatMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppConstants.navigatorKey,
      title: 'SeatMap Internal',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return InactivityWatcher(child: child ?? const SizedBox());
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          primary: AppConstants.primaryColor,
          secondary: AppConstants.secondaryColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppConstants.backgroundColor,
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return auth.isAuthenticated ? const MainNavigation() : const LoginScreen();
        },
      ),
    );
  }
}
