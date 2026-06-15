import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'controllers/theme_controller.dart';
import 'providers/language_provider.dart';
import 'views/screens/video_splash_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, child) {
        return Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Medical Master',
              theme: _themeController.lightTheme,
              darkTheme: _themeController.darkTheme,
              themeMode: _themeController.themeMode,

              // Localization
              locale: languageProvider.currentLocale,
              supportedLocales: languageProvider.supportedLocales,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],

              // RTL Support
              builder: (context, child) {
                return Directionality(
                  textDirection: languageProvider.textDirection,
                  child: child!,
                );
              },

              home: const VideoSplashScreen(),
            );
          },
        );
      },
    );
  }
}
