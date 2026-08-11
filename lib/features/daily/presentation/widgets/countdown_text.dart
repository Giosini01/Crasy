import 'dart:async';

import 'package:app_incontri/core/utils/app_date_utils.dart';
import 'package:flutter/material.dart';

/// Tempo mancante a [target], aggiornato ogni secondo.
///
/// Il battito vive qui e non in un provider: cosi' a ricostruirsi sessanta
/// volte al minuto e' questo solo testo, non la schermata che lo contiene.
class CountdownText extends StatefulWidget {
  const CountdownText({required this.target, this.style, super.key});

  final DateTime target;
  final TextStyle? style;

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
      setState(() {
        _remaining = _remainingTo(widget.target);
      });
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

    setState(() {
      _remaining = _remainingTo(widget.target);
    });
  }

  static Duration _remainingTo(DateTime target) {
    final remaining = target.difference(DateTime.now());

    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      AppDateUtils.formatCountdown(_remaining),
      style: widget.style ?? Theme.of(context).textTheme.displaySmall,
    );
  }
}
