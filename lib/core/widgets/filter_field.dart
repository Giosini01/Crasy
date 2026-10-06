import 'package:crasy/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// **Il campo per cercare dentro un elenco che si ha gia' in mano.**
///
/// Non e' la lente dell'app: quella interroga il server e cerca fra tutti.
/// Questo filtra righe che sono gia' sullo schermo — i propri amici, chi ti
/// segue, chi segui — e per questo non ha un ritardo, non ha uno stato di
/// attesa e non puo' sbagliare. Si scrive e la lista si accorcia.
///
/// ## Perche' serve, e non e' una comodita'
///
/// Con dieci amici un elenco si guarda. Con trecento no: scorrere trecento
/// facce per trovarne una **e' piu' lavoro che riscrivere il nome**, e chi ha
/// trecento amici e' esattamente la persona che usa l'app di piu'. Senza un
/// campo come questo, la funzione peggiora man mano che l'app funziona.
///
/// Compare **solo quando serve**: sotto una certa quantita' di righe un campo
/// di ricerca e' un ingombro sopra una lista che si legge tutta in un colpo.
/// Vedi [quandoServe].
///
/// ## Lo stesso filetto di tutti gli altri
///
/// Un filetto sotto e nient'altro, come il campo della lente e come tutti i
/// campi di CRASY: una casella col fondo grigio e gli angoli tondi, qui,
/// sarebbe l'unica dell'app.
class FilterField extends StatefulWidget {
  const FilterField({required this.hint, required this.onChanged, super.key});

  /// Cosa si sta cercando: "Cerca fra i tuoi amici", "Cerca chi segui".
  final String hint;

  final ValueChanged<String> onChanged;

  /// **Da quante righe in su un campo di ricerca si guadagna il posto.**
  ///
  /// Otto: quante ne stanno su uno schermo. Fin li' la riga che si cerca e' gia'
  /// davanti agli occhi, e un campo sopra l'elenco sarebbe una cosa in piu' da
  /// leggere per arrivare a una cosa che si vedeva gia'.
  static bool quandoServe(int righe) => righe > 8;

  @override
  State<FilterField> createState() => _FilterFieldState();
}

class _FilterFieldState extends State<FilterField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pulisci() {
    _controller.clear();
    widget.onChanged('');
    // La tastiera se ne va con il testo: pulire il campo vuol dire "ho finito di
    // cercare", non "ricomincio da capo".
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      // **Non si prende il fuoco da sola.** Si arriva su queste schermate per
      // guardare un elenco, non per scrivere: una tastiera che salta su da sola
      // copre meta' delle righe che uno era venuto a vedere.
      autofocus: false,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.none,
      style: context.texts.bodyLarge,
      onChanged: (valore) {
        // `setState` per la crocetta, che c'e' solo quando c'e' del testo.
        setState(() {});
        widget.onChanged(valore);
      },
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        prefixIconConstraints: const BoxConstraints(minWidth: 32),
        suffixIcon: _controller.text.isEmpty
            ? null
            : GestureDetector(
                onTap: _pulisci,
                child: const Icon(Icons.close_rounded, size: 18),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 28),
      ),
    );
  }
}

/// Se [testo] contiene quello che si sta cercando.
///
/// Senza maiuscole e senza spazi ai bordi: chi cerca "Marco" deve trovare
/// "marco", e un nome incollato dalla rubrica si porta dietro uno spazio che non
/// deve far sparire la riga.
///
/// **Contiene, non comincia per.** Cercando "rossi" si trova "marco.rossi": i
/// nomi utente sono spesso nome piu' cognome attaccati, e un filtro che guarda
/// solo l'inizio non trova mai niente per cognome.
bool combacia(String testo, String cerca) {
  final pulito = cerca.trim().toLowerCase();

  return pulito.isEmpty || testo.toLowerCase().contains(pulito);
}
