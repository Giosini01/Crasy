import 'dart:async';

import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/challenges/presentation/providers/challenge_providers.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Riaccendere le notifiche, da dentro l'app.**
///
/// ## Perche' serviva una schermata apposta
///
/// Su venticinque persone, venti non avevano **nessun telefono registrato** per
/// ricevere le notifiche: la campanella dentro l'app si riempiva e il telefono
/// restava muto. Quasi tutte erano ferme nello stesso punto — il permesso del
/// sistema non era mai stato ne' dato ne' rifiutato — e l'app, che quella
/// domanda la fa una volta sola durante la presentazione, non gliela avrebbe
/// rifatta mai piu'.
///
/// Senza un posto da cui riprovare, quelle persone erano perse per sempre. Non
/// per una loro scelta: per un momento sbagliato.
///
/// ## Cosa fa, a seconda di come sta messo il permesso
///
/// **Mai risposto.** E' il caso di quasi tutti, ed e' il piu' facile: si tocca e
/// compare il riquadro del sistema. Niente spiegazioni lunghe prima — la
/// spiegazione sta nella riga che si e' appena letta per arrivare qui.
///
/// **Gia' acceso.** Non c'e' niente da fare e lo si dice, invece di mostrare un
/// tasto che non cambia niente. Si riprova comunque la registrazione del
/// telefono: il permesso c'e' ma il recapito puo' essersi perso — app
/// reinstallata, telefono nuovo — ed e' esattamente il caso che nessuno
/// scoprirebbe da solo.
///
/// **Rifiutato.** Qui l'app non puo' piu' chiedere niente: il sistema non
/// ripropone quel riquadro a chi ha gia' detto no. L'unica strada sono le
/// impostazioni del telefono, e si scrive dove andare invece di mandare a
/// cercare.
Future<void> showNotificationsSetting(BuildContext context) {
  return ModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => const _Notifiche(),
  );
}

class _Notifiche extends ConsumerStatefulWidget {
  const _Notifiche();

  @override
  ConsumerState<_Notifiche> createState() => _NotificheState();
}

class _NotificheState extends ConsumerState<_Notifiche> {
  AuthorizationStatus? _stato;
  bool _lavorando = false;

  @override
  void initState() {
    super.initState();
    unawaited(_leggi());
  }

  Future<void> _leggi() async {
    try {
      final adesso = await FirebaseMessaging.instance.getNotificationSettings();

      if (mounted) {
        setState(() => _stato = adesso.authorizationStatus);
      }
    } on Object {
      // Senza Firebase — nelle prove, sul web — resta null e si mostra la riga
      // neutra: meglio non dire niente che dire una cosa sbagliata.
    }
  }

  /// Chiede il permesso e **registra subito il telefono**.
  ///
  /// Le due cose insieme e non solo la prima: dare il permesso senza registrare
  /// il recapito lascia esattamente la situazione di prima — il sistema dice di
  /// si' e le notifiche non arrivano lo stesso. E' la meta' che mancava.
  Future<void> _accendi() async {
    setState(() => _lavorando = true);

    try {
      final userId = ref.read(currentUserIdProvider);
      final registro = ref.read(pushRegistryProvider);

      if (userId != null && registro != null) {
        await registro.register(userId, chiedi: true);
      }
    } on Object {
      // L'esito si legge rileggendo lo stato qui sotto: un errore qui non ha
      // niente da raccontare che quella lettura non dica meglio.
    }

    await _leggi();

    if (mounted) {
      setState(() => _lavorando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final stato = _stato;
    final accese =
        stato == AuthorizationStatus.authorized ||
        stato == AuthorizationStatus.provisional;
    final rifiutate = stato == AuthorizationStatus.denied;

    return ModalSheet(
      title: 'NOTIFICHE',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(context).pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            accese
                ? 'Sono accese. Ti avvisiamo quando qualcuno mette una fiamma '
                      'sulla tua foto, ti commenta, ti sfida o ti chiede '
                      'l\'amicizia.'
                : rifiutate
                ? 'Sono spente, e da qui non possiamo riaccenderle: il telefono '
                      'non ripropone la domanda a chi ha già risposto di no.'
                : 'Sono spente. Senza, una sfida arriva e non lo sai: la scopri '
                      'riaprendo l\'app, spesso quando è già scaduta.',
            style: texts.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          if (rifiutate)
            Text(
              'Si riaccendono dalle impostazioni del telefono: cerca CRASY '
              'nell\'elenco delle app, apri Notifiche e consenti.',
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            )
          else if (!accese)
            FilledButton(
              onPressed: _lavorando ? null : _accendi,
              style: FilledButton.styleFrom(
                backgroundColor: palette.accentDeep,
                foregroundColor: palette.onAccent,
              ),
              child: Text(_lavorando ? 'Un attimo…' : 'Accendi le notifiche'),
            )
          else
            // **Anche con il permesso acceso c'e' un tasto**, e non e' inutile:
            // il permesso sta sul telefono, il recapito sta sul nostro server, e
            // i due si possono separare — app reinstallata, telefono cambiato,
            // registrazione fallita in silenzio. Questo rimette il recapito.
            TextButton(
              onPressed: _lavorando ? null : _accendi,
              child: Text(
                _lavorando ? 'Un attimo…' : 'NON ARRIVANO? TOCCA QUI',
                style: texts.labelSmall?.copyWith(color: palette.accent),
              ),
            ),
        ],
      ),
    );
  }
}
