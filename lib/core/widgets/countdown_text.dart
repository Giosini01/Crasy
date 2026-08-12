import 'dart:async';

import 'package:crasy/core/utils/app_date_utils.dart';
import 'package:flutter/material.dart';

/// Il tempo che manca alla chiusura di una challenge, aggiornato ogni secondo.
///
/// Il battito vive dentro questo widget e non in un provider: cosi' a
/// ricostruirsi sessanta volte al minuto e' una riga di testo, non la schermata
/// che la contiene con dentro le sue foto.
///
/// Sotto l'ora il countdown passa ai secondi e diventa rosso. E' l'unico posto
/// in cui il colore compare senza essere ne' un premio ne' un comando, e se lo
/// merita: e' il momento in cui restano pochi minuti per partecipare.
class CountdownText extends StatefulWidget {
  const CountdownText({
    required this.target,
    this.style,
    this.urgentColor,
    super.key,
  });

  final DateTime target;
  final TextStyle? style;

  /// Il colore da usare nell'ultima ora. Nullo per non cambiare mai colore.
  final Color? urgentColor;

  /// Sotto questa soglia il countdown si considera urgente.
  static const Duration urgentThreshold = Duration(hours: 1);

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = _remainingTo(widget.target);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.target != widget.target) {
      setState(() => _remaining = _remainingTo(widget.target));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) {
      return;
    }

    setState(() => _remaining = _remainingTo(widget.target));
  }

  static Duration _remainingTo(DateTime target) {
    final remaining = target.difference(DateTime.now());

    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _remaining < CountdownText.urgentThreshold;
    final baseStyle = widget.style ?? Theme.of(context).textTheme.labelMedium;
    final urgentColor = widget.urgentColor;

    return Text(
      AppDateUtils.formatTimeLeft(_remaining),
      style: urgent && urgentColor != null
          ? baseStyle?.copyWith(color: urgentColor)
          : baseStyle,
    );
  }
}
