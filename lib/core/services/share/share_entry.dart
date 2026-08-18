import 'package:crasy/core/constants/app_routes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Mandare una foto fuori da CRASY.
///
/// E' la porta d'ingresso dell'app, non un dettaglio di cortesia. Il giro e'
/// questo: uno partecipa, manda il link a dieci persone, quelle aprono la foto,
/// si registrano per poter accendere la fiamma, e restano. **Chi ha qualcosa in
/// gara ha un motivo vero per portare gente dentro** — non lo fa per farci un
/// favore, lo fa perche' vuole vincere.
///
/// Il link porta alla foto, non alla home: chi lo apre deve vedere subito la
/// cosa di cui gli hanno parlato. Da li' la challenge e' un tocco sotto.
abstract final class ShareEntry {
  /// Dove vive CRASY.
  ///
  /// Sul web si legge l'indirizzo da cui la pagina e' stata aperta, invece di
  /// scriverlo fisso: cosi' un link condiviso da una prova in locale porta alla
  /// prova in locale, e non manda chi lo riceve su un'app diversa da quella che
  /// chi condivide sta guardando.
  static String get origin {
    if (kIsWeb) {
      return Uri.base.origin;
    }

    return 'https://crasy.web.app';
  }

  /// L'indirizzo di una singola partecipazione.
  static String linkTo({required String challengeId, required String entryId}) {
    // Il cancelletto c'e' perche' l'app web usa gli indirizzi con il frammento.
    // Scritto a mano una volta sola qui: e' l'unico posto in cui CRASY compone
    // un indirizzo per il mondo esterno invece che per se stessa.
    return '$origin/#${AppRoutes.challengeDetailOf(challengeId)}'
        '?foto=$entryId';
  }

  /// Apre il pannello di condivisione del telefono.
  ///
  /// Il testo che accompagna il link e' una **richiesta**, non una descrizione:
  /// "guarda la mia foto" non fa fare niente a nessuno, "dammi una fiamma" si'.
  /// Chi condivide sta chiedendo un voto, e la frase deve dire quello.
  static Future<void> send(
    BuildContext context, {
    required String challengeId,
    required String entryId,
    required String challengeTitle,
  }) async {
    final link = linkTo(challengeId: challengeId, entryId: entryId);
    final title = challengeTitle.isEmpty
        ? 'una challenge'
        : '"${challengeTitle.toUpperCase()}"';

    final box = context.findRenderObject() as RenderBox?;

    await SharePlus.instance.share(
      ShareParams(
        text:
            'Sono in gara su CRASY con $title. Aprila e dammi una fiamma: '
            'vince chi ne prende di piu\'.\n\n$link',
        subject: 'La mia foto su CRASY',
        // Su iPad il pannello si aggancia a un punto dello schermo, e senza
        // saperlo il sistema non lo apre affatto.
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}
