import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crasy/features/friends/domain/entities/suggested_friend.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  /// **Si prende dal proprio numero verificato**, non dalla lingua del
  /// telefono. Prima era la lingua: un italiano con il telefono in inglese si
  /// vedeva attaccare `+1` a tutta la rubrica, e non trovava nessuno. Solo se
  /// il numero non c'e' si guarda il paese del telefono, e poi l'Italia.
  static String get _prefisso {
    final mio = FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

    if (mio.startsWith('+')) {
      for (final codice in _codiciPaese) {
        if (mio.startsWith(codice)) {
          return codice;
        }
      }
    }

    final parti = Platform.localeName.split(RegExp('[_-]'));
    final paese = parti.length > 1 ? parti.last.toUpperCase() : 'IT';

    return const {
          'IT': '+39',
          'FR': '+33',
          'DE': '+49',
          'ES': '+34',
          'GB': '+44',
          'CH': '+41',
          'AT': '+43',
          'BE': '+32',
          'NL': '+31',
          'PT': '+351',
          'SM': '+378',
          'US': '+1',
        }[paese] ??
        '+39';
  }

  /// I prefissi riconosciuti nel proprio numero, dai piu' lunghi ai piu'
  /// corti: `+378` (San Marino) va provato prima di `+37`.
  static const _codiciPaese = [
    '+378',
    '+351',
    '+352',
    '+353',
    '+355',
    '+356',
    '+385',
    '+386',
    '+387',
    '+30',
    '+31',
    '+32',
    '+33',
    '+34',
    '+36',
    '+39',
    '+40',
    '+41',
    '+43',
    '+44',
    '+45',
    '+46',
    '+47',
    '+48',
    '+49',
    '+7',
    '+1',
  ];

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
      final paese = prefisso ?? _prefisso;

      if (testo.length > 10 && testo.startsWith(paese.substring(1))) {
        // **Prefisso scritto senza il piu'**: `39 347 1234567`. Un numero
        // italiano ha dieci cifre, quindi un "39" davanti a dieci cifre e' il
        // paese, non l'inizio del numero.
        testo = '+$testo';
      } else {
        // Lo zero iniziale dei fissi: in Italia **resta** (+39 06…, +39
        // 081…), negli altri paesi davanti al prefisso internazionale cade.
        final senzaZero = paese != '+39' && testo.startsWith('0')
            ? testo.substring(1)
            : testo;

        testo = '$paese$senzaZero';
      }
    }

    final cifre = testo.substring(1);

    // Sotto le otto cifre non e' un numero raggiungibile dall'estero: e'
    // un'emergenza, un servizio, o un errore di battitura.
    if (cifre.length < 8 || cifre.length > 15) {
      return null;
    }

    return testo;
  }

  /// Chiede il permesso e legge la rubrica.
  ///
  /// **Il nome resta sul telefono.** Al server va solo il numero: i nomi
  /// servono qui, per scrivere "Invita Marco" invece di "Invita
  /// +393331234567", e non hanno nessuna ragione di viaggiare. Chi non ha
  /// CRASY non si e' iscritto a niente, e il suo nome in un nostro database
  /// sarebbe roba che nessuno ci ha dato il permesso di tenere.
  Future<List<Contatto>> _rubrica() async {
    final permesso = await FlutterContacts.permissions.request(
      PermissionType.read,
    );

    // **Su iPhone si puo' dare mezzo permesso.** Dal diciotto si scelgono i
    // contatti da condividere uno per uno, e chi lo fa non ha detto di no: ha
    // detto "solo questi". Trattarlo come un rifiuto vorrebbe dire mostrargli
    // la schermata sbagliata dopo che ha appena acconsentito.
    if (permesso != PermissionStatus.granted &&
        permesso != PermissionStatus.limited) {
      throw ContattiNegati(
        perSempre:
            permesso == PermissionStatus.permanentlyDenied ||
            permesso == PermissionStatus.restricted,
      );
    }

    // Si chiedono **solo i numeri**: e' il permesso che serve alla funzione, e
    // i nomi, le email e gli indirizzi non entrano nemmeno in memoria.
    final contatti = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );

    // Per numero e non per contatto: la stessa persona compare due volte in
    // rubrica — casa e cellulare — e comparirebbe due volte nell'elenco.
    final perNumero = <String, Contatto>{};

    for (final contatto in contatti) {
      for (final telefono in contatto.phones) {
        final pulito = normalizza(telefono.number);

        if (pulito != null) {
          perNumero.putIfAbsent(
            pulito,
            () => Contatto(
              nome: (contatto.displayName ?? '').trim(),
              numero: pulito,
            ),
          );
        }
      }
    }

    final numeri = perNumero.keys;

    // Permesso dato, ma niente da confrontare: rubrica vuota, o su iPhone
    // "solo alcuni contatti" con zero scelti. Dirgli "attiva il permesso"
    // quando il permesso e' gia' attivo lo manda a cercare un interruttore
    // che non c'e'.
    if (numeri.isEmpty) {
      throw const RubricaVuota();
    }

    return perNumero.values.toList();
  }

  /// Apre le impostazioni dell'app: dopo un "no" definitivo il telefono non
  /// ripropone piu' la domanda, e l'unica strada e' l'interruttore li'.
  static Future<void> apriImpostazioni() =>
      FlutterContacts.permissions.openSettings();

  /// I profili CRASY che corrispondono a un numero in rubrica.
  ///
  /// Lancia [ContattiNegati] se il permesso non c'e': chiamare e ricevere una
  /// lista vuota non distinguerebbe "nessuno dei tuoi amici e' qui" da "non ci
  /// hai fatto guardare", e sono due cose che vanno dette in modo diverso.
  Future<RubricaTrovata> suggeriti() async {
    // **Dal browser non si puo', e va detto invece che fallire.**
    //
    // Una pagina web non ha una rubrica da leggere: il pacchetto non risponde
    // proprio, e la chiamata moriva prima di partire lasciando a schermo
    // "qualcosa non ha funzionato" — che fa sembrare rotta una cosa che sul
    // telefono funziona benissimo.
    if (kIsWeb) {
      throw const SoloDalTelefono();
    }

    final rubrica = await _rubrica();
    final numeri = [for (final contatto in rubrica) contatto.numero];

    // Il nome con cui ogni numero e' salvato, da riattaccare a chi torna dal
    // server: la risposta porta il numero, non il nome, perche' il nome non e'
    // mai partito.
    final perNome = {
      for (final contatto in rubrica) contatto.numero: contatto.nome,
    };

    // **A pezzi da duemila.** Il server ne accetta al massimo tanti per volta,
    // e una rubrica piu' grande faceva fallire tutta la ricerca con un errore
    // generico: proprio chi ha piu' contatti non trovava nessuno.
    final perId = <String, SuggestedFriend>{};
    final suCrasy = <String>{};

    for (var da = 0; da < numeri.length; da += 2000) {
      final fino = da + 2000 < numeri.length ? da + 2000 : numeri.length;
      final risposta = await _functions
          .httpsCallable('trovaDallaRubrica')
          .call<Map<String, dynamic>>({'numeri': numeri.sublist(da, fino)});

      final trovati = risposta.data['trovati'] as List<dynamic>? ?? const [];

      for (final trovato in trovati.whereType<Map<Object?, Object?>>()) {
        final numero = trovato['numero'] as String? ?? '';

        final chi = SuggestedFriend(
          userId: trovato['userId'] as String? ?? '',
          username: trovato['username'] as String? ?? '',
          displayName: trovato['displayName'] as String? ?? '',
          photoUrl: trovato['photoUrl'] as String? ?? '',
          stato: SuggestedStato.leggi(trovato['stato'] as String?),
          numero: numero,
          // **Il nome torna a riattaccarsi al numero da cui era partito.**
          //
          // Qui c'era il buco: il nome della rubrica veniva letto, usato per la
          // meta' di gente da invitare, e perso per chi stava su CRASY — il
          // server rimanda il numero, ma la riga non tornava piu' a chiedere al
          // telefono come si chiamava. Il risultato era un elenco di nomi utente
          // in cui non si riconosceva nessuno.
          //
          // Il viaggio e' tutto locale: il nome non e' mai uscito da qui.
          nomeInRubrica: perNome[numero] ?? '',
        );

        if (chi.userId.isNotEmpty) {
          perId[chi.userId] = chi;
          suCrasy.add(chi.numero);
        }
      }
    }

    // **Quelli che restano sono quelli da invitare.** Si tolgono i numeri che
    // hanno trovato qualcuno, e quello che avanza e' gente che CRASY non ce
    // l'ha: ordinati per nome, perche' si scorre cercando una persona.
    final mancanti = [
      for (final contatto in rubrica)
        if (!suCrasy.contains(contatto.numero) && contatto.nome.isNotEmpty)
          contatto,
    ]..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

    return RubricaTrovata(suCrasy: perId.values.toList(), daInvitare: mancanti);
  }
}

/// Una riga della rubrica del telefono. **Non esce mai da questo telefono.**
class Contatto {
  const Contatto({required this.nome, required this.numero});

  final String nome;

  /// In forma internazionale: e' quella con cui si apre WhatsApp.
  final String numero;
}

/// Il risultato di una passata sulla rubrica: chi c'e' gia' e chi manca.
class RubricaTrovata {
  const RubricaTrovata({this.suCrasy = const [], this.daInvitare = const []});

  final List<SuggestedFriend> suCrasy;
  final List<Contatto> daInvitare;

  bool get vuota => suCrasy.isEmpty && daInvitare.isEmpty;
}

/// Non ci ha fatto guardare la rubrica.
class ContattiNegati implements Exception {
  const ContattiNegati({this.perSempre = false});

  /// Il telefono non fara' piu' la domanda: serve l'interruttore nelle
  /// impostazioni.
  final bool perSempre;
}

/// Ci ha fatto guardare, ma in rubrica non c'e' nessun numero da confrontare.
class RubricaVuota implements Exception {
  const RubricaVuota();
}

/// Ci si prova dal browser, dove una rubrica non esiste.
class SoloDalTelefono implements Exception {
  const SoloDalTelefono();
}
