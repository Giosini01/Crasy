import 'package:crasy/core/services/share/instagram_story.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Come si condivide: la Storia con il marchio, o la foto da sola.
enum ModoStoria { crasy, soloFoto }

/// **Il segno di Instagram**, disegnato: un quadrato arrotondato, un cerchio,
/// un punto. Nessun file e nessuna libreria in piu' per tre forme.
class IconaInstagram extends StatelessWidget {
  const IconaInstagram({this.size = 24, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _Glifo(color ?? IconTheme.of(context).color ?? Colors.white),
      ),
    );
  }
}

class _Glifo extends CustomPainter {
  _Glifo(this.colore);

  final Color colore;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final tratto = Paint()
      ..color = colore
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.09;

    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(s * 0.1, s * 0.1, s * 0.8, s * 0.8),
          Radius.circular(s * 0.24),
        ),
        tratto,
      )
      ..drawCircle(Offset(s * 0.5, s * 0.5), s * 0.19, tratto)
      ..drawCircle(
        Offset(s * 0.71, s * 0.29),
        s * 0.055,
        Paint()..color = colore,
      );
  }

  @override
  bool shouldRepaint(_Glifo vecchio) => vecchio.colore != colore;
}

/// **Condividere una propria foto su Instagram Stories.**
///
/// Si sceglie come, si prepara l'immagine, si copia il link, si apre
/// Instagram. Ogni intoppo — niente rete, foto illeggibile, Instagram assente
/// — finisce in una riga che dice cosa e' successo, mai in un silenzio.
Future<void> condividiSuInstagram(
  BuildContext context,
  ChallengeEntry entry, {
  required String userId,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final box = context.findRenderObject() as RenderBox?;
  final origine = box == null
      ? null
      : box.localToGlobal(Offset.zero) & box.size;

  void dillo(String testo) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(testo), behavior: SnackBarBehavior.floating),
    );

  final modo = await ModalSheet.show<ModoStoria>(
    context: context,
    builder: (_) => const _SceltaDelModo(),
  );

  if (modo == null || !context.mounted) {
    return;
  }

  // Il velo mentre si prepara: scaricare e comporre richiede un secondo o due.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) =>
        const PopScope(canPop: false, child: Center(child: FiammaCheGira())),
  );

  Uint8List immagine;
  String tipo;

  try {
    final foto = await InstagramStory.scarica(entry.mediaUrl);

    if (modo == ModoStoria.crasy) {
      final logo = await rootBundle.load(
        'assets/brand/crasy-wordmark-dark.png',
      );

      immagine = await componiLaStoria(foto, logo.buffer.asUint8List());
      tipo = 'image/png';
    } else {
      immagine = foto;
      tipo = InstagramStory.tipoDi(foto);
    }

    // Il link prima di partire: in Instagram basta incollarlo nello sticker.
    await Clipboard.setData(
      ClipboardData(
        text: InstagramStory.link(
          challengeId: entry.challengeId,
          entryId: entry.id,
          challengeTitle: entry.challengeTitle,
          authorName: entry.authorName,
          userId: userId,
        ),
      ),
    );
  } on ErroreStoria catch (errore) {
    navigator.pop();
    dillo(errore.messaggio);

    return;
  } on Object {
    navigator.pop();
    dillo('Non siamo riusciti a preparare la Storia. Riprova.');

    return;
  }

  navigator.pop();

  if (await InstagramStory.apriLeStorie(immagine, tipo)) {
    return;
  }

  // Le Storie non si aprono da sole: senza l'ID di Meta, o senza Instagram.
  // Resta la condivisione del telefono, con l'immagine gia' pronta.
  if (!await InstagramStory.instagramInstallato()) {
    dillo(
      'Instagram non è installato: puoi salvare l\'immagine o mandarla '
      'altrove.',
    );
  }

  try {
    await InstagramStory.condividiAltrove(immagine, tipo, origine: origine);
  } on Object {
    dillo('La condivisione non si è aperta. Riprova.');
  }
}

class _SceltaDelModo extends StatefulWidget {
  const _SceltaDelModo();

  @override
  State<_SceltaDelModo> createState() => _SceltaDelModoState();
}

class _SceltaDelModoState extends State<_SceltaDelModo> {
  var _modo = ModoStoria.crasy;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    Widget voce(ModoStoria modo, String titolo, String sotto, IconData icona) {
      final scelta = _modo == modo;

      return GestureDetector(
        onTap: () => setState(() => _modo = modo),
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scelta ? palette.accentTint : null,
            border: Border.all(color: scelta ? palette.accent : palette.line),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(icona, color: palette.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titolo, style: texts.titleMedium),
                    Text(
                      sotto,
                      style: texts.bodySmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                scelta
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: scelta ? palette.accent : palette.textFaint,
              ),
            ],
          ),
        ),
      );
    }

    return ModalSheet(
      title: 'Condividi su Instagram',
      confirmLabel: 'Apri Instagram',
      onConfirm: () => Navigator.of(context).pop(_modo),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          voce(
            ModoStoria.crasy,
            'Story CRASY',
            'La tua foto, con il logo piccolo in fondo.',
            Icons.auto_awesome_rounded,
          ),
          voce(
            ModoStoria.soloFoto,
            'Solo foto',
            'La foto com\'è, senza niente intorno.',
            Icons.photo_rounded,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.link_rounded, size: 18, color: palette.textSecondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Il link a CRASY lo copiamo noi. In Instagram tocca '
                  'l\'icona degli sticker, scegli «Link» e incolla.',
                  style: texts.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
