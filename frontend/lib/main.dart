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
import 'package:smart_mess/theme/app_tokens.dart';
import 'package:smart_mess/utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_GB';
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    logError('[Main] Firebase init error: $e');
  }
  runApp(const SmartMessApp());
}

class SmartMessApp extends StatelessWidget {
  const SmartMessApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      error: AppColors.danger,
      background: AppColors.background,
      surface: AppColors.surface,
      surfaceVariant: AppColors.surfaceAlt,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineSubtle,
      onPrimary: Colors.white,
      onSecondary: AppColors.ink,
      onSurface: AppColors.ink,
      onBackground: AppColors.ink,
    );
    final baseTextTheme = ThemeData.light().textTheme;
    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        height: 1.45,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        height: 1.45,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    ).apply(
      fontFamily: 'SpaceGrotesk',
      bodyColor: AppColors.ink,
      displayColor: AppColors.primary,
    );
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
          colorScheme: colorScheme,
          fontFamily: 'SpaceGrotesk',
          textTheme: textTheme,
          scaffoldBackgroundColor: Colors.transparent,
          disabledColor: AppColors.inkMuted.withValues(alpha: 0.6),
          hintColor: AppColors.inkMuted,
          appBarTheme: AppBarTheme(
            backgroundColor: colorScheme.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            titleTextStyle: const TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
          ),
          cardTheme: CardThemeData(
            color: colorScheme.surface,
            elevation: 10,
            shadowColor: colorScheme.primary.withValues(alpha: 0.14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.secondary,
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.primary,
              side: BorderSide(color: colorScheme.primary, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: colorScheme.surface,
            hintStyle: TextStyle(color: AppColors.inkMuted),
            labelStyle: TextStyle(color: AppColors.inkMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide(color: colorScheme.outline),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide(color: colorScheme.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.md),
              borderSide: BorderSide(color: colorScheme.secondary, width: 1.6),
            ),
            floatingLabelStyle: TextStyle(color: colorScheme.primary),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: colorScheme.surfaceVariant,
            labelStyle: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(color: colorScheme.outlineVariant),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
          tabBarTheme: TabBarThemeData(
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicator: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.secondary, width: 3),
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.secondary.withValues(alpha: 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: colorScheme.primary,
            contentTextStyle: const TextStyle(color: Colors.white),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm)),
            behavior: SnackBarBehavior.floating,
          ),
          progressIndicatorTheme: ProgressIndicatorThemeData(
            color: colorScheme.secondary,
          ),
          dividerTheme: DividerThemeData(
            color: AppColors.outlineSubtle,
            thickness: 1,
          ),
          bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: AppColors.surface,
            modalBackgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadii.xl),
              ),
            ),
            showDragHandle: true,
          ),
          listTileTheme: ListTileThemeData(
            iconColor: AppColors.primary,
            textColor: AppColors.ink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
          iconTheme: const IconThemeData(
            size: AppSizes.iconMd,
            color: AppColors.primary,
          ),
          iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.inkMuted,
            showUnselectedLabels: true,
          ),
        ),
        builder: (context, child) {
          final themedChild = Container(
            decoration: const BoxDecoration(
              gradient: AppGradients.surface,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -120,
                  right: -80,
                  child: IgnorePointer(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withValues(alpha: 0.16),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -140,
                  left: -60,
                  child: IgnorePointer(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
                if (child != null)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, animatedChild) {
                        return Opacity(
                          opacity: value,
                          child: animatedChild,
                        );
                      },
                      child: child,
                    ),
                  ),
              ],
            ),
          );
          return themedChild;
        },
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

