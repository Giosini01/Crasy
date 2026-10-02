import 'package:crasy/core/services/share/share_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Portare qualcuno dentro CRASY.**
///
/// Era l'unica cosa che l'app non sapeva fare: si poteva mandare fuori una
/// missione, si poteva mandare fuori una foto, ma non si poteva dire *"vieni
/// qui"*. Per un'app che vive di amici era il gesto piu' importante, e l'unico
/// modo di farlo era spiegarlo a voce.
///
/// **Il link porta al sito, non allo store.** Sembra un passaggio in piu' ed e'
/// il contrario: un link all'App Store aperto da Android non porta da nessuna
/// parte, e un link a Google Play aperto da iPhone nemmeno. Il sito sa chi sta
/// bussando e manda ognuno dove deve andare — ed e' anche l'unica pagina che,
/// prima di far scaricare qualcosa, spiega cos'e' CRASY a chi non l'ha mai
/// sentita nominare.
///
/// **Il nome di chi invita sta nel messaggio, non nel link.** Un codice di
/// invito vorrebbe dire tenere il conto di chi ha portato chi, cioe' un
/// registro di relazioni che oggi non serve a niente: non c'e' nessun premio
/// da dare a chi porta amici. Il giorno in cui ci sara', si aggiunge — e si
/// aggiunge sapendo perche'.
abstract final class InviteFriend {
  /// Il messaggio, con il link in fondo.
  ///
  /// **Dice cosa si fa, non cos'e'.** "Un social di sfide fotografiche" non fa
  /// scaricare niente a nessuno: si capisce dopo aver installato, che e'
  /// esattamente il momento sbagliato. Una foto, dei soldi veri, un giorno di
  /// tempo — sono tre fatti, e si leggono in tre secondi.
  static String messageFor({String username = ''}) {
    final chi = username.trim().isEmpty ? '' : ' Io sono @${username.trim()}.';

    return 'Vieni su CRASY. Ogni giorno c\'è una sfida: scatti una foto sul '
        'momento, gli altri votano, e chi prende più fiamme si porta via i '
        'soldi in palio.$chi\n\n${ShareEntry.origin}';
  }

  /// Apre il pannello di condivisione, e **se non c'e' copia il messaggio**.
  ///
  /// Stessa strada delle altre due condivisioni: su un browser da computer il
  /// pannello di sistema spesso non esiste, e un tasto che non fa niente e non
  /// dice niente e' peggio di un tasto assente.
  static Future<void> send(BuildContext context, {String username = ''}) async {
    final message = messageFor(username: username);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final box = context.findRenderObject() as RenderBox?;

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: message,
          subject: 'Vieni su CRASY',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );

      if (result.status != ShareResultStatus.unavailable) {
        return;
      }
    } on Object {
      // Si passa agli appunti.
    }

    await Clipboard.setData(ClipboardData(text: message));

    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Invito copiato: incollalo dove vuoi.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// **Apre WhatsApp sulla chat di quel numero, con il messaggio gia' scritto.**
  ///
  /// Si apre la chat e basta: **il messaggio non parte da solo**. Non e' un
  /// limite da aggirare, e' come deve essere — un'app che manda messaggi a nome
  /// tuo ai numeri della tua rubrica e' esattamente la cosa per cui si
  /// disinstalla un'app. L'ultimo tocco lo fa chi invita.
  ///
  /// **Il link porta al sito, non a uno dei due store**, e qui la ragione e'
  /// diversa dal solito: non sappiamo che telefono ha chi riceve. Mandare
  /// l'App Store a un Android, o Google Play a un iPhone, vuol dire mandarlo in
  /// un posto dove non puo' scaricare niente. Il sito lo capisce da solo e
  /// mostra il tasto giusto — ed e' anche l'unica pagina che spiega cos'e'
  /// CRASY prima di chiedere di installarla.
  static Future<void> suWhatsApp(
    BuildContext context, {
    required String numero,
    String username = '',
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    // WhatsApp vuole il numero in cifre, senza il piu' e senza spazi.
    final pulito = numero.replaceAll(RegExp(r'[^0-9]'), '');
    final indirizzo = Uri.parse(
      'https://wa.me/$pulito?text=${Uri.encodeComponent(messageFor(username: username))}',
    );

    try {
      final aperto = await launchUrl(
        indirizzo,
        mode: LaunchMode.externalApplication,
      );

      if (aperto) {
        return;
      }
    } on Object {
      // Si passa agli appunti.
    }

    // **Senza WhatsApp installato il messaggio si copia.** Il tasto deve fare
    // qualcosa comunque: un invito che non parte e non dice niente si legge
    // come un'app rotta, non come un telefono senza WhatsApp.
    await Clipboard.setData(
      ClipboardData(text: messageFor(username: username)),
    );

    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Invito copiato: incollalo dove vuoi.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
