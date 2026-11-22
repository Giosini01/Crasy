import 'package:crasy/core/services/share/instagram_story.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/flame_waiting.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/challenges/domain/entities/challenge_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
/// Si prepara la Storia — foto, missione, marchio — e la si fa vedere prima di
/// partire: chi condivide sa cosa pubblichera'. Poi il link negli appunti e
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

  // Il velo mentre si prepara: scaricare e comporre richiede un secondo o due.
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) =>
        const PopScope(canPop: false, child: Center(child: FiammaCheGira())),
  );

  Uint8List storia;

  try {
    final foto = await InstagramStory.scarica(entry.mediaUrl);
    final logo = await rootBundle.load('assets/brand/crasy-wordmark-dark.png');

    storia = await componiLaStoria(
      foto,
      logo.buffer.asUint8List(),
      titolo: entry.challengeTitle,
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

  if (!context.mounted) {
    return;
  }

  final vai = await ModalSheet.show<bool>(
    context: context,
    builder: (_) => _Anteprima(storia: storia),
  );

  if (vai != true) {
    return;
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

  if (await InstagramStory.apriLeStorie(storia)) {
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
    await InstagramStory.condividiAltrove(storia, origine: origine);
  } on Object {
    dillo('La condivisione non si è aperta. Riprova.');
  }
}

/// La Storia pronta, prima di aprire Instagram.
class _Anteprima extends StatelessWidget {
  const _Anteprima({required this.storia});

  final Uint8List storia;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return ModalSheet(
      title: 'La tua Storia',
      confirmLabel: 'Apri Instagram',
      onConfirm: () => Navigator.of(context).pop(true),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.memory(
                storia,
                height: 380,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.link_rounded, size: 18, color: palette.accent),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Il link a CRASY lo copiamo noi. In Instagram tocca '
                  'l\'icona degli sticker, scegli «Link» e incolla: chi '
                  'lo tocca arriva alla tua foto.',
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
