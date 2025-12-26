import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:smart_mess/providers/unified_auth_provider.dart';
import 'package:smart_mess/screens/splash_screen.dart';
import 'package:smart_mess/screens/student_login_screen.dart';
import 'package:smart_mess/screens/manager_login_screen.dart';
import 'package:smart_mess/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_GB';
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('[Main] Firebase init error: $e');
  }
  runApp(const SmartMessApp());
}

class SmartMessApp extends StatelessWidget {
  const SmartMessApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UnifiedAuthProvider()),
      ],
      child: MaterialApp(
        title: 'SmartMess',
        locale: const Locale('en', 'GB'),
        supportedLocales: const [
          Locale('en', 'GB'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Color(0xFF6200EE),
            brightness: Brightness.light,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Color(0xFF6200EE),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6200EE),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        home: SplashScreen(),
        routes: {
          '/student_login': (context) => StudentLoginScreen(),
          '/manager_login': (context) => ManagerLoginScreen(),
          '/home': (context) => HomeScreen(),
        },
      ),
    );
  }
}
