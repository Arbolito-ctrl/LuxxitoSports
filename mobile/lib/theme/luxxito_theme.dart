import 'package:flutter/material.dart';

/// Paleta oficial de Luxxito Sports (azul noche + verde esmeralda).
class LuxxitoColors {
  LuxxitoColors._();

  static const Color fondo = Color(0xFF0F172A);
  static const Color superficie = Color(0xFF1E293B);
  static const Color superficieAlta = Color(0xFF273449);
  static const Color borde = Color(0x1FFFFFFF);

  static const Color primario = Color(0xFF10B981);
  static const Color primarioOscuro = Color(0xFF064E3B);
  static const Color secundario = Color(0xFF38BDF8);
  static const Color nocturno = Color(0xFF8B5CF6);

  static const Color exito = Color(0xFF10B981);
  static const Color advertencia = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF87171);
  static const Color info = Color(0xFF38BDF8);

  static const Color texto = Colors.white;
  static const Color textoSecundario = Color(0xB3FFFFFF);
  static const Color textoTenue = Color(0x73FFFFFF);
}

ThemeData buildLuxxitoTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: const ColorScheme.dark(
      primary: LuxxitoColors.primario,
      onPrimary: Colors.black,
      secondary: LuxxitoColors.secundario,
      surface: LuxxitoColors.superficie,
      error: LuxxitoColors.error,
    ),
  );

  final bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: LuxxitoColors.borde),
  );

  return base.copyWith(
    scaffoldBackgroundColor: LuxxitoColors.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: LuxxitoColors.fondo,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardThemeData(
      color: LuxxitoColors.superficie,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LuxxitoColors.borde),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LuxxitoColors.superficie,
      labelStyle: const TextStyle(color: LuxxitoColors.textoSecundario),
      hintStyle: const TextStyle(color: LuxxitoColors.textoTenue),
      prefixIconColor: LuxxitoColors.primario,
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
        foregroundColor: Colors.black,
        disabledBackgroundColor: LuxxitoColors.superficieAlta,
        minimumSize: const Size(0, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: Colors.white24),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: LuxxitoColors.primario),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: LuxxitoColors.superficie,
      selectedColor: LuxxitoColors.primario,
      side: const BorderSide(color: LuxxitoColors.borde),
      labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
      secondaryLabelStyle: const TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      checkmarkColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: LuxxitoColors.superficie,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: const TextStyle(
        color: LuxxitoColors.textoSecundario,
        fontSize: 14,
        height: 1.4,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: LuxxitoColors.superficie,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LuxxitoColors.superficie,
      indicatorColor: LuxxitoColors.primario.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.bold
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
