import 'package:crasy/features/onboarding/presentation/utils/onboarding_validators.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Com'e' andata la verifica di un nome utente.
///
/// **Tre stati e non due**, e il terzo e' quello che rende utile la cosa: se il
/// nome e' preso, la risposta non e' "no" ma "no, e questi tre sono liberi".
/// Un divieto senza alternativa costringe a inventare, provare, sbagliare e
/// riprovare — tre giri per arrivare dove si poteva arrivare subito.
class UsernameCheck {
  const UsernameCheck({required this.free, this.suggestions = const []});

  /// Il nome chiesto e' libero.
  final bool free;

  /// Se e' occupato: nomi simili che non lo sono. Al massimo tre.
  final List<String> suggestions;
}

/// Dice se un nome utente e' gia' di qualcuno.
///
/// ## Una lettura sola, non cinque
///
/// Il nome chiesto e i candidati alternativi si cercano **insieme**, con una
/// richiesta unica: Firestore accetta di cercare fra un elenco di valori, e
/// chiedere quattro volte "e questo?" costerebbe quattro letture per ogni
/// tasto premuto.
///
/// ## Quello che questo controllo non e'
///
/// **Non e' una prenotazione.** Fra il momento in cui dice "libero" e il
/// momento in cui il profilo viene salvato, quel nome puo' essere preso da
/// qualcun altro: sono due istanti diversi, e nessuna lettura puo' coprire il
/// tempo che passa in mezzo. Serve a far scegliere bene, non a garantire.
///
/// L'unicita' vera si ottiene in un modo solo — una collezione in cui il nome
/// **e'** il nome del documento, cosi' che il database rifiuti il secondo
/// arrivato — e quello e' un lavoro a se', da fare prima di aprire al
/// pubblico. Finche' non c'e', due persone possono chiamarsi uguale se premono
/// "salva" nello stesso secondo.
final usernameCheckProvider = FutureProvider.autoDispose
    .family<UsernameCheck, String>((ref, richiesto) async {
      final nome = richiesto.trim().toLowerCase();

      // Un nome che non passa nemmeno il controllo di forma non si va a
      // cercare: il campo ha gia' il suo errore, e una richiesta al database
      // per sapere se "ab" e' libero e' una richiesta buttata.
      if (OnboardingValidators.validateUsername(nome) != null) {
        return const UsernameCheck(free: false);
      }

      // Non si parte alla prima lettera: si aspetta che chi scrive si fermi.
      // Senza, ogni tasto premuto e' una lettura, e scrivere "martina" ne
      // costerebbe sette per sapere una cosa sola.
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final candidati = [nome, ..._alternative(nome)];
      final presi = await ref
          .read(userProfileRepositoryProvider)
          .takenUsernames(candidati);

      if (!presi.contains(nome)) {
        return const UsernameCheck(free: true);
      }

      return UsernameCheck(
        free: false,
        suggestions: [
          for (final candidato in candidati.skip(1))
            if (!presi.contains(candidato)) candidato,
        ].take(3).toList(),
      );
    });

/// Tre modi di dire quasi lo stesso nome.
///
/// Sono costruiti sul nome chiesto e non a caso: chi voleva chiamarsi `marco`
/// e si vede proporre `utente_8471` non prende nessuna delle due strade, torna
/// indietro e ci pensa. `marco.1`, `marco_` e `marcoo` sono ancora il suo nome.
///
/// Restano dentro il limite di lunghezza: un suggerimento che il campo poi
/// rifiuta e' peggio di nessun suggerimento.
List<String> _alternative(String nome) {
  final spazio = OnboardingValidators.usernameMaxLength - nome.length;

  return [
    if (spazio >= 2) '$nome.1',
    if (spazio >= 1) '${nome}_',
    if (spazio >= 1) '$nome${nome[nome.length - 1]}',
    if (spazio >= 3) '$nome.99',
  ];
}
