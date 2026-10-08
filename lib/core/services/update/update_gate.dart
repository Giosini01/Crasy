import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crasy/core/services/firebase/firebase_providers.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/services/firebase/firebase_bootstrap_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// **Cosa dice il server sulla versione che serve.**
///
/// Un documento solo, `config/app`, scritto a mano dalla console di Firebase:
///
/// - `minBuild` (numero): sotto questa build l'app si ferma e chiede di
///   aggiornare. E' il numero che TestFlight mostra fra parentesi, `1.0.4 (163)`.
/// - `url` (testo, facoltativo): dove porta il tasto. Senza, apre TestFlight.
/// - `messaggio` (testo, facoltativo): la frase sotto il titolo.
///
/// Per far comparire il popup basta alzare `minBuild`. Per toglierlo, abbassarlo.
class UpdateRequirement {
  const UpdateRequirement({required this.minBuild, this.url, this.messaggio});

  factory UpdateRequirement.fromMap(Map<String, dynamic>? data) {
    final minimo = data?['minBuild'];
    final url = data?['url'];
    final messaggio = data?['messaggio'];

    return UpdateRequirement(
      minBuild: minimo is num ? minimo.toInt() : 0,
      url: url is String && url.isNotEmpty ? url : null,
      messaggio: messaggio is String && messaggio.isNotEmpty ? messaggio : null,
    );
  }

  final int minBuild;
  final String? url;
  final String? messaggio;
}

final updateRequirementProvider = StreamProvider<UpdateRequirement>((ref) {
  // Sul web l'app si aggiorna da sola ricaricando la pagina, e senza Firebase
  // non c'e' nessuno a cui chiedere.
  if (kIsWeb || !ref.watch(firebaseBootstrapResultProvider).isConfigured) {
    return Stream.value(const UpdateRequirement(minBuild: 0));
  }

  return ref
      .watch(firebaseFirestoreProvider)
      .collection('config')
      .doc('app')
      .snapshots()
      .map((snapshot) => UpdateRequirement.fromMap(snapshot.data()))
      // Un errore di lettura non deve mai fermare l'app: si lascia passare.
      .handleError((Object _) {});
});

final installedBuildProvider = FutureProvider<int>((ref) async {
  final info = await PackageInfo.fromPlatform();

  return int.tryParse(info.buildNumber) ?? 0;
});

/// **Il muro davanti a una versione troppo vecchia.**
///
/// Sta sopra l'app come il sipario dell'apertura, e per la stessa ragione: e'
/// montato fuori dal navigatore, quindi non e' un dialogo che si chiude con il
/// tasto indietro. Finche' la build installata e' sotto `minBuild`, sotto non
/// si tocca niente.
///
/// Quando qualcosa non si sa — il documento non c'e', la lettura fallisce, il
/// numero non si legge — si lascia passare. Bloccare qualcuno per un dubbio
/// sarebbe peggio di lasciargli una versione vecchia.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final richiesta = ref.watch(updateRequirementProvider).valueOrNull;
    final installata = ref.watch(installedBuildProvider).valueOrNull;

    final vecchia =
        richiesta != null &&
        installata != null &&
        installata > 0 &&
        installata < richiesta.minBuild;

    if (!vecchia) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(child: _Muro(richiesta: richiesta)),
      ],
    );
  }
}

class _Muro extends StatelessWidget {
  const _Muro({required this.richiesta});

  final UpdateRequirement richiesta;

  /// Apre l'app TestFlight sul telefono, dove c'e' il tasto AGGIORNA.
  static const _testFlight = 'itms-beta://';

  Future<void> _apri() async {
    final indirizzo = Uri.parse(richiesta.url ?? _testFlight);

    try {
      await launchUrl(indirizzo, mode: LaunchMode.externalApplication);
    } on Object catch (_) {
      // Niente da fare: il messaggio sopra dice comunque cosa fare a mano.
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Material(
      color: palette.background,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.local_fire_department_rounded,
                size: 72,
                color: palette.accent,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                "C'È UNA VERSIONE NUOVA",
                textAlign: TextAlign.center,
                style: texts.displaySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                richiesta.messaggio ??
                    'Questa versione di CRASY non è più supportata. '
                        'Aggiornala per continuare a giocare: apri TestFlight '
                        'e tocca AGGIORNA.',
                textAlign: TextAlign.center,
                style: texts.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              CrasyButton(label: 'Aggiorna', onPressed: _apri),
            ],
          ),
        ),
      ),
    );
  }
}
