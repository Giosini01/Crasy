import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/features/friends/domain/entities/suggested_friend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// **La rubrica del telefono, e chi di quei numeri sta su CRASY.**
///
/// Il pezzo delicato di tutta la funzione sta qui, in due righe che non si
/// vedono: **dalla rubrica esce solo il numero**. Non il nome, non l'email, non
/// la nota "dentista". Chi non ha CRASY non lascia traccia da nessuna parte, e
/// non e' una gentilezza — sono persone che non si sono mai iscritte a niente,
/// e trattare i loro dati richiederebbe un permesso che nessuno ci ha dato.
///
/// Il confronto lo fa il server, perche' il segreto con cui i numeri diventano
/// impronte non puo' stare dentro i telefoni: vedi `functions/rubrica.js`.
class ContactsRepository {
  const ContactsRepository(this._functions);

  final FirebaseFunctions _functions;

  /// Il prefisso da mettere davanti ai numeri scritti senza.
  ///
  /// Quasi nessuno salva i numeri in forma internazionale: in rubrica c'e'
  /// `347 1234567`, non `+39 347 1234567`. Senza un prefisso da attaccare, il
  /// novanta per cento dei contatti non verrebbe riconosciuto — e la sezione
  /// sembrerebbe rotta a chi ha decine di amici sull'app.
  ///
  /// Si prende dal paese del telefono. Se non si capisce, l'Italia: e' dove
  /// sono tutti quelli che usano CRASY oggi, e tirare a indovinare qui e'
  /// meglio che rinunciare.
  static String get _prefisso {
    final paese = Platform.localeName.split('_').length > 1
        ? Platform.localeName.split('_')[1].toUpperCase()
        : 'IT';

    return const {
          'IT': '+39',
          'FR': '+33',
          'DE': '+49',
          'ES': '+34',
          'GB': '+44',
          'CH': '+41',
          'US': '+1',
        }[paese] ??
        '+39';
  }

  /// Il numero come lo si manda al server: solo cifre, con il paese davanti.
  ///
  /// Restituisce null per tutto quello che numero di telefono non e' — e ce
  /// n'e' parecchio in una rubrica vera: numeri brevi dei servizi, interni
  /// aziendali, appunti finiti nel campo sbagliato.
  static String? normalizza(String grezzo, {String? prefisso}) {
    var testo = grezzo.replaceAll(RegExp(r'[^\d+]'), '');

    if (testo.isEmpty) {
      return null;
    }

    // `0039` e `+39` sono lo stesso prefisso scritto come si faceva una volta.
    if (testo.startsWith('00')) {
      testo = '+${testo.substring(2)}';
    }

    if (!testo.startsWith('+')) {
      // Lo zero iniziale e' quello dei fissi scritti alla vecchia maniera:
      // davanti al prefisso internazionale non ci va.
      final senzaZero = testo.startsWith('0') ? testo.substring(1) : testo;

      testo = '${prefisso ?? _prefisso}$senzaZero';
    }

    final cifre = testo.substring(1);

    // Sotto le otto cifre non e' un numero raggiungibile dall'estero: e'
    // un'emergenza, un servizio, o un errore di battitura.
    if (cifre.length < 8 || cifre.length > 15) {
      return null;
    }

    return testo;
  }

  /// Chiede il permesso e legge i numeri. Lista vuota se l'utente dice di no.
  Future<List<String>> _numeriInRubrica() async {
    final permesso = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    // **Su iPhone si puo' dare mezzo permesso.** Dal diciotto si scelgono i
    // contatti da condividere uno per uno, e chi lo fa non ha detto di no: ha
    // detto "solo questi". Trattarlo come un rifiuto vorrebbe dire mostrargli
    // la schermata sbagliata dopo che ha appena acconsentito.
    if (permesso != PermissionStatus.granted &&
        permesso != PermissionStatus.limited) {
      return const [];
    }

    // Si chiedono **solo i numeri**: e' il permesso che serve alla funzione, e
    // i nomi, le email e gli indirizzi non entrano nemmeno in memoria.
    final contatti = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    final numeri = <String>{};

    for (final contatto in contatti) {
      for (final telefono in contatto.phones) {
        final pulito = normalizza(telefono.number);

        if (pulito != null) {
          numeri.add(pulito);
        }
      }
    }

    return numeri.toList();
  }

  /// I profili CRASY che corrispondono a un numero in rubrica.
  ///
  /// Lancia [ContattiNegati] se il permesso non c'e': chiamare e ricevere una
  /// lista vuota non distinguerebbe "nessuno dei tuoi amici e' qui" da "non ci
  /// hai fatto guardare", e sono due cose che vanno dette in modo diverso.
  Future<List<SuggestedFriend>> suggeriti() async {
    // **Dal browser non si puo', e va detto invece che fallire.**
    //
    // Una pagina web non ha una rubrica da leggere: il pacchetto non risponde
    // proprio, e la chiamata moriva prima di partire lasciando a schermo
    // "qualcosa non ha funzionato" — che fa sembrare rotta una cosa che sul
    // telefono funziona benissimo.
    if (kIsWeb) {
      throw const SoloDalTelefono();
    }

    final numeri = await _numeriInRubrica();

    if (numeri.isEmpty) {
      throw const ContattiNegati();
    }

    final risposta = await _functions
        .httpsCallable('trovaDallaRubrica')
        .call<Map<String, dynamic>>({'numeri': numeri});

    final trovati = risposta.data['trovati'] as List<dynamic>? ?? const [];

    return <SuggestedFriend>[
      for (final trovato in trovati.whereType<Map<Object?, Object?>>())
        SuggestedFriend(
          userId: trovato['userId'] as String? ?? '',
          username: trovato['username'] as String? ?? '',
          displayName: trovato['displayName'] as String? ?? '',
          photoUrl: trovato['photoUrl'] as String? ?? '',
        ),
    ]..removeWhere((chi) => chi.userId.isEmpty);
  }
}

/// Non ci ha fatto guardare la rubrica — o l'ha svuotata.
class ContattiNegati implements Exception {
  const ContattiNegati();
}

/// Ci si prova dal browser, dove una rubrica non esiste.
class SoloDalTelefono implements Exception {
  const SoloDalTelefono();
}
