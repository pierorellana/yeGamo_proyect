import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/design_system/yg_tokens.dart';

/// Tema claro «Bosque claro» del prototipo yeGamo.
abstract final class YegamoTheme {
  static ThemeData light({bool reduceMotion = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: YgColors.cypress,
      brightness: Brightness.light,
    ).copyWith(
      primary: YgColors.moss,
      onPrimary: Colors.white,
      secondary: YgColors.cypress,
      onSecondary: Colors.white,
      surface: YgColors.surface,
      onSurface: YgColors.text,
      error: YgColors.clay,
      onError: Colors.white,
      outline: YgColors.borderStrong,
    );
    // El prototipo usa la fuente del sistema en Apple (SF Pro) y Geist como
    // respaldo en el resto de plataformas.
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final base = ThemeData(
      fontFamily: apple ? null : 'Geist',
      brightness: Brightness.light,
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: YgColors.page,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _NoTransitionBuilder(),
          TargetPlatform.iOS: _NoTransitionBuilder(),
          TargetPlatform.macOS: _NoTransitionBuilder(),
          TargetPlatform.windows: _NoTransitionBuilder(),
          TargetPlatform.linux: _NoTransitionBuilder(),
        },
      ),
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: YgColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: YgColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: YgColors.divider,
        space: 1,
        thickness: 1,
      ),
      textTheme: base.textTheme
          .copyWith(
            displayLarge: YgText.heroTime,
            headlineMedium: YgText.largeTitle,
            headlineSmall: YgText.title2,
            titleLarge: YgText.title2,
            titleMedium: YgText.sub,
            titleSmall: YgText.sub,
            bodyLarge: YgText.body,
            bodyMedium: YgText.secondary,
            bodySmall: YgText.meta,
            labelLarge: YgText.bodyStrong,
            labelMedium: YgText.meta,
            labelSmall: YgText.overline,
          )
          .apply(fontFamily: apple ? null : 'Geist'),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(YgSize.touch, YgSize.buttonMd),
          backgroundColor: YgColors.moss,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          textStyle: YgText.bodyStrong,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(YgSize.touch, YgSize.buttonMd),
          foregroundColor: YgColors.moss,
          backgroundColor: YgColors.fill,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          textStyle: YgText.bodyStrong,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: YgColors.cypress,
          textStyle: YgText.bodyStrong.copyWith(fontSize: 14),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hintStyle: TextStyle(color: YgColors.cedar, fontWeight: FontWeight.w500),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: YgColors.cypress,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: YgColors.moss,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }

  /// Alias conservado para llamadas previas al rediseño.
  static ThemeData dark({bool reduceMotion = false}) =>
      light(reduceMotion: reduceMotion);
}

class _NoTransitionBuilder extends PageTransitionsBuilder {
  const _NoTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}
