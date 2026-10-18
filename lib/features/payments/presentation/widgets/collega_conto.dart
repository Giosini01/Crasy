import 'dart:async';

import 'package:crasy/core/theme/app_colors.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/features/payments/domain/entities/prize_status.dart';
import 'package:crasy/features/payments/presentation/pages/payout_details_page.dart';
import 'package:crasy/features/payments/presentation/providers/payments_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Prima della prima gara con dei soldi, il conto per riceverli.**
///
/// I premi non restano su CRASY: vanno su un conto Stripe a nome di chi vince.
/// Quel conto si apre una volta, e il momento giusto per chiederlo e' questo —
/// quando uno sta per giocare per dei soldi veri. Non all'iscrizione, dove
/// chiedere un IBAN a chi viene per le sfide gratis vorrebbe dire perderlo.
///
/// Torna `true` se si puo' andare avanti. Altrimenti spiega cosa serve, lo fa
/// fare, e torna `false`: la registrazione si finisce sulla pagina di Stripe, e
/// poi si riprova.
///
/// **Basta aver compilato il modulo, non serve che Stripe abbia finito di
/// verificare.** Prima si aspettava che il conto potesse gia' ricevere soldi,
/// e la verifica puo' durare ore: chi tornava dalla pagina di Stripe restava
/// fuori dalla gara per cui si era appena registrato. Se vince prima che la
/// verifica finisca, il premio lo tiene CRASY per lui e passa sul suo conto
/// appena e' pronto — e' scritto nei termini, al punto 5.
///
/// **E un guasto nostro non tiene fuori nessuno.** Se il server non risponde
/// o i conti non si possono aprire, si gioca lo stesso: il conto si chiede
/// alla prossima gara, o al primo prelievo.
Future<bool> assicuratiIlConto(BuildContext context, WidgetRef ref) async {
  if (!paymentsEnabled) {
    return true;
  }

  if (ref.read(contoProntoProvider).valueOrNull == true) {
    return true;
  }

  final payments = ref.read(paymentsServiceProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);

  // **Chi torna dalla pagina di Stripe e' quasi sempre gia' pronto**, ma la
  // copia sul profilo non lo sa ancora: si chiede al server prima di
  // rispiegargli tutto da capo.
  try {
    final stato = await _conLaFiamma(context, payments.statoConto);

    if (stato.pronto || stato.compilato) {
      return true;
    }
  } on Object {
    // Se non si riesce a chiedere, si va avanti come se non fosse collegato:
    // il peggio che succede e' rivedere la spiegazione.
  }

  if (!context.mounted) {
    return false;
  }

  final vuole = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.palette.background,
    builder: (context) => const _Spiegazione(),
  );

  if (vuole != true || !context.mounted) {
    return false;
  }

  final dati = ref.read(payoutDetailsProvider).valueOrNull;

  if (dati == null || !dati.isComplete) {
    final fatto = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const PayoutDetailsPage()));

    if (fatto != true || !context.mounted) {
      return false;
    }
  }

  try {
    final pronto = await _conLaFiamma(context, payments.startPayoutOnboarding);

    if (pronto) {
      return true;
    }
  } on Object {
    // Il guasto e' nostro, non suo: si gioca lo stesso.
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Non siamo riusciti ad aprire il conto: puoi giocare lo stesso, te '
          'lo richiediamo più avanti.',
        ),
      ),
    );

    return true;
  }

  messenger?.showSnackBar(
    const SnackBar(
      content: Text(
        'Ultimo passo su Stripe: conferma i tuoi dati, poi torna qui e '
        'scatta.',
      ),
      duration: Duration(seconds: 6),
    ),
  );

  return false;
}

/// **Mentre si aspetta il server, la fiamma sopra tutto.**
///
/// Le due domande che [assicuratiIlConto] fa — a che punto e' il conto, e la
/// pagina di Stripe per registrarlo — possono durare fino a mezzo minuto, e in
/// quel mezzo minuto prima non compariva niente: si toccava "Scatta" o
/// "Preleva" e sembrava un tasto morto. Chi lo ritoccava faceva ripartire
/// tutto da capo.
///
/// **E' un dialogo, non un velo da accendere**, perche' qui c'e' soltanto un
/// `BuildContext`: nessuno stato di una pagina da cambiare. Da dialogo copre
/// anche la barra in cima, ferma i tocchi e, con il divieto che sta dentro
/// [FlameWaiting], anche il tasto indietro.
///
/// **Si toglie sempre**, anche quando il server risponde con un errore: un
/// velo rimasto su e' una schermata che non si tocca e non si chiude piu'.
Future<T> _conLaFiamma<T>(
  BuildContext context,
  Future<T> Function() lavoro,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final velo = DialogRoute<void>(
    context: context,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) => const FlameWaiting(),
    barrierDismissible: false,
    // Lo scuro lo mette gia' `FlameWaiting`: con anche quello del dialogo, lo
    // schermo si farebbe nero il doppio.
    barrierColor: Colors.transparent,
    // Fino ai bordi, barra di stato compresa: come il velo delle pagine.
    useSafeArea: false,
  );

  unawaited(navigator.push(velo));

  try {
    return await lavoro();
  } finally {
    // Si toglie **questo** velo, non quello che sta in cima: se nel frattempo
    // si fosse aperto qualcos'altro sopra, un `pop` chiuderebbe quello. E lo
    // si toglie di colpo, senza dissolvenza: chi chiama accende spesso il suo
    // velo subito dopo, e due veli che si incrociano lampeggiano.
    if (navigator.mounted && velo.isActive) {
      navigator.removeRoute(velo);
    }
  }
}

/// **Cos'e' il conto Stripe, detto con calma prima di aprirlo.**
///
/// Prima diceva "collega il tuo conto": letto da chi sta per mandare una foto,
/// suonava come "dacci accesso alla tua banca", e chi lo leggeva chiudeva.
/// Poi diceva solo "aggiungi l'IBAN", e non si capiva perche' servisse un
/// conto su Stripe. Qui lo si dice per quello che e': **un portafoglio**, lo
/// stesso che poi si ritrova nell'app, dove restano i soldi delle sfide finche'
/// uno non li preleva — e senza il quale non li potrebbe prelevare mai.
///
/// Si legge sia da chi entra nella prima gara con dei soldi sia da chi tocca
/// "Preleva" senza averlo ancora aperto: le frasi valgono per tutti e due.
class _Spiegazione extends StatelessWidget {
  const _Spiegazione();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    // Scorre, se serve: su un telefono basso le tre righe non ci stanno
    // sempre, e un foglio che sborda nasconde proprio il tasto.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(
                    text: 'Per i soldi delle sfide ti serve un portafoglio',
                  ),
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: AppColors.crasyRed),
                  ),
                ],
              ),
              style: texts.headlineMedium?.copyWith(
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const _Rassicura(
              icona: Icons.account_balance_wallet_outlined,
              titolo: 'È il tuo portafoglio virtuale.',
              testo:
                  'Qui si raccolgono i soldi che vinci nelle sfide. È a nome '
                  'tuo, e restano tuoi finché non li prelevi.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _Rassicura(
              icona: Icons.account_balance_outlined,
              titolo: 'È obbligatorio, perché serve a prelevare.',
              testo:
                  'Senza portafoglio i soldi vinti non avrebbero dove stare, '
                  'e non potresti mai mandarli in banca. Per aprirlo bastano '
                  'nome, cognome e IBAN: è lì che arrivano quando prelevi.',
            ),
            const SizedBox(height: AppSpacing.md),
            const _Rassicura(
              icona: Icons.lock_outline_rounded,
              titolo: 'Lo custodisce Stripe.',
              testo:
                  'È il sistema di pagamento usato da milioni di aziende nel '
                  'mondo. E con il tuo IBAN nessuno può prendere soldi dal tuo '
                  'conto in banca: né noi, né nessun altro.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Partecipare resta gratis. Il portafoglio si apre una volta sola '
              'e ci vuole un minuto: alla fine Stripe ti chiede di confermare '
              'chi sei, perché lo chiede la legge a chiunque riceva soldi.',
              style: texts.bodySmall?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            CrasyButton(
              label: 'Apri il portafoglio',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Non ora'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una riga della spiegazione: un segno, la frase che conta, e il perche'.
class _Rassicura extends StatelessWidget {
  const _Rassicura({
    required this.icona,
    required this.titolo,
    required this.testo,
  });

  final IconData icona;
  final String titolo;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icona, size: 19, color: palette.accent),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titolo,
                style: texts.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                testo,
                style: texts.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
