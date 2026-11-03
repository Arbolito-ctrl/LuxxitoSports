import 'package:flutter/material.dart';

/// Paleta "Claro deportivo" de Luxxito Sports: fondos neutros cálidos,
/// texto casi negro y un único acento verde césped.
class LuxxitoColors {
  LuxxitoColors._();

  static const Color fondo = Color(0xFFF5F5F4);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color superficieAlta = Color(0xFFF0EFED);
  static const Color borde = Color(0xFFE7E5E4);

  static const Color primario = Color(0xFF15803D);
  static const Color primarioSuave = Color(0xFFDCFCE7);
  static const Color secundario = Color(0xFF0369A1);
  static const Color nocturno = Color(0xFF6D28D9);

  static const Color exito = Color(0xFF15803D);
  static const Color advertencia = Color(0xFFB45309);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF0369A1);

  static const Color texto = Color(0xFF1C1917);
  static const Color textoSecundario = Color(0xFF57534E);
  static const Color textoTenue = Color(0xFF8A8580);
}

ThemeData buildLuxxitoTheme() {
  final base = ThemeData(
    brightness: Brightness.light,
    useMaterial3: true,
    colorScheme: const ColorScheme.light(
      primary: LuxxitoColors.primario,
      onPrimary: Colors.white,
      secondary: LuxxitoColors.secundario,
      surface: LuxxitoColors.superficie,
      onSurface: LuxxitoColors.texto,
      error: LuxxitoColors.error,
    ),
  );

  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: LuxxitoColors.borde),
  );

  return base.copyWith(
    scaffoldBackgroundColor: LuxxitoColors.fondo,
    textTheme: base.textTheme.apply(
      bodyColor: LuxxitoColors.texto,
      displayColor: LuxxitoColors.texto,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: LuxxitoColors.superficie,
      foregroundColor: LuxxitoColors.texto,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      shadowColor: LuxxitoColors.borde,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: LuxxitoColors.texto,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: LuxxitoColors.superficie,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: LuxxitoColors.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LuxxitoColors.superficie,
      labelStyle: const TextStyle(color: LuxxitoColors.textoSecundario),
      hintStyle: const TextStyle(color: LuxxitoColors.textoTenue),
      prefixIconColor: LuxxitoColors.textoTenue,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      focusedBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: LuxxitoColors.primario, width: 1.5),
      ),
      errorBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: LuxxitoColors.error),
      ),
      focusedErrorBorder: bordeCampo.copyWith(
        borderSide: const BorderSide(color: LuxxitoColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LuxxitoColors.primario,
        foregroundColor: Colors.white,
        disabledBackgroundColor: LuxxitoColors.superficieAlta,
        disabledForegroundColor: LuxxitoColors.textoTenue,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LuxxitoColors.texto,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: LuxxitoColors.borde),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: LuxxitoColors.primario),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: LuxxitoColors.primario,
      foregroundColor: Colors.white,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: LuxxitoColors.superficie,
      selectedColor: LuxxitoColors.texto,
      side: const BorderSide(color: LuxxitoColors.borde),
      labelStyle: const TextStyle(color: LuxxitoColors.texto, fontSize: 13),
      secondaryLabelStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: LuxxitoColors.primarioSuave,
        selectedForegroundColor: LuxxitoColors.primario,
        foregroundColor: LuxxitoColors.textoSecundario,
        side: const BorderSide(color: LuxxitoColors.borde),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: LuxxitoColors.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: const TextStyle(
        color: LuxxitoColors.texto,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: const TextStyle(
        color: LuxxitoColors.textoSecundario,
        fontSize: 14,
        height: 1.4,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LuxxitoColors.superficie,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: LuxxitoColors.superficie,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: LuxxitoColors.textoSecundario,
      textColor: LuxxitoColors.texto,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LuxxitoColors.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: LuxxitoColors.primarioSuave,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.normal,
          color: states.contains(WidgetState.selected)
              ? LuxxitoColors.primario
              : LuxxitoColors.textoSecundario,
        ),
      ),
    ),
    dividerTheme: const DividerThemeData(color: LuxxitoColors.borde, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: LuxxitoColors.primario,
    ),
  );
}
