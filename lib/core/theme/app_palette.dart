import 'package:app_incontri/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Token semantici del tema: le schermate leggono da qui invece di pescare i
/// colori grezzi, cosi' un cambio di tinta si fa in un posto solo.
///
/// La separazione fra superfici e' affidata alle **ombre**, non ai bordi: su
/// fondo chiaro una scheda bianca con un'ombra bassa galleggia, la stessa
/// scheda con una linea attorno sembra un riquadro di un modulo.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brand,
    required this.brandTint,
    required this.onBrand,
    required this.danger,
  });

  /// Fondo pagina.
  final Color background;

  /// Card e fogli sopra il fondo. E' **piu' chiaro** di [background]: e' quel
  /// mezzo punto di differenza, non un contorno, a staccarli.
  final Color surface;

  /// Riempimenti tenui: input, pillole a riposo, tracce di progresso.
  final Color surfaceMuted;

  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// L'unico viola. Riservato all'azione primaria e agli stati selezionati.
  final Color brand;

  /// Velo dello stesso viola, per il fondo degli elementi attivi.
  final Color brandTint;

  /// Colore del testo che poggia su [brand].
  final Color onBrand;

  final Color danger;

  static const light = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceMuted: AppColors.surfaceMuted,
    border: AppColors.border,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    brand: AppColors.iris,
    brandTint: AppColors.irisTint,
    onBrand: Colors.white,
    danger: AppColors.danger,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? brand,
    Color? brandTint,
    Color? onBrand,
    Color? danger,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      brand: brand ?? this.brand,
      brandTint: brandTint ?? this.brandTint,
      onBrand: onBrand ?? this.onBrand,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) {
      return this;
    }

    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Token di colore del tema corrente.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get texts => Theme.of(this).textTheme;
}
