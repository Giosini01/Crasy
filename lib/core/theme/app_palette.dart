import 'package:crasy/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Token semantici del tema: le schermate leggono da qui, mai da [AppColors].
///
/// Non esistono token per ombre, gradienti o livelli di superficie, e la loro
/// assenza e' voluta: a separare le cose in CRASY sono lo **spazio vuoto** e,
/// dove proprio serve, un filetto da mezzo pixel. Una card con l'ombra e' gia'
/// un'altra app.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surfaceMuted,
    required this.line,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.accent,
    required this.accentDeep,
    required this.accentTint,
    required this.onAccent,
  });

  /// Fondo pagina, ed e' anche il fondo di tutto il resto: non c'e' una
  /// superficie "sopra" perche' non ci sono schede.
  final Color background;

  /// Riempimenti tenui: il rettangolo che tiene il posto di una foto, i campi
  /// di testo, le tracce di progresso.
  final Color surfaceMuted;

  final Color line;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;

  /// L'unico colore. Premio, fiamma, stato attivo. Nient'altro.
  final Color accent;

  /// Lo stesso fuoco piu' in fondo, da usare **solo** come riempimento sotto
  /// del testo bianco: il bottone principale. Su tutto il resto va [accent].
  final Color accentDeep;

  /// Velo dello stesso rosso, per il fondo di cio' che e' selezionato.
  final Color accentTint;

  /// Il colore del testo che poggia su [accentDeep].
  final Color onAccent;

  /// Gli errori prendono lo stesso rosso dell'accento.
  ///
  /// Non e' pigrizia: un secondo rosso "da errore" accanto al rosso del marchio
  /// darebbe due rossi leggermente diversi nella stessa schermata, che e'
  /// esattamente il tipo di sciatteria che si nota senza saper dire perche'.
  Color get danger => accent;

  static const light = AppPalette(
    background: AppColors.paper,
    surfaceMuted: AppColors.paperMuted,
    line: AppColors.line,
    textPrimary: AppColors.ink,
    textSecondary: AppColors.inkSoft,
    textFaint: AppColors.inkFaint,
    accent: AppColors.crasyRed,
    accentDeep: AppColors.crasyRedDeep,
    accentTint: AppColors.crasyRedTint,
    onAccent: AppColors.paper,
  );

  @override
  AppPalette copyWith({
    Color? background,
    Color? surfaceMuted,
    Color? line,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? accent,
    Color? accentDeep,
    Color? accentTint,
    Color? onAccent,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      line: line ?? this.line,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textFaint: textFaint ?? this.textFaint,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentTint: accentTint ?? this.accentTint,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) {
      return this;
    }

    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      line: Color.lerp(line, other.line, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// Token di colore del tema corrente.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  TextTheme get texts => Theme.of(this).textTheme;
}
