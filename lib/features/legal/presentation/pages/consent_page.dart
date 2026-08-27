import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_radius.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/brand_mark.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/core/widgets/inline_banner.dart';
import 'package:crasy/features/legal/presentation/controllers/consent_controller.dart';
import 'package:crasy/features/legal/presentation/widgets/legal_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// L'ultima porta prima di entrare: cosa accetti, una cosa alla volta.
///
/// ## Perche' non c'e' un solo "Accetto tutto"
///
/// Perche' non sarebbe valido. Il GDPR chiede che il consenso sia **specifico**:
/// chi accetta le regole del servizio non sta accettando la pubblicita'
/// personalizzata, e mettere le due cose sotto la stessa spunta non rende
/// valida la prima — rende **invalide tutte e due**. Un bottone solo sembra piu'
/// gentile e costa molto piu' caro.
///
/// ## E perche' le facoltative nascono spente
///
/// Una casella gia' spuntata non e' un consenso: e' una distrazione sfruttata.
/// Il consenso dev'essere un gesto attivo, e deve essere possibile **rifiutarlo
/// senza perdere niente** — se rifiutare la pubblicita' chiudesse la porta,
/// quel consenso non sarebbe libero, quindi non varrebbe.
///
/// Qui infatti si entra spuntando solo le quattro obbligatorie, e le altre due
/// si possono lasciare dove sono per sempre.
class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key});

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  final Set<LegalConsent> _checked = {};

  /// Vero quando si e' provato a proseguire senza aver spuntato tutto.
  ///
  /// Prima di quel momento non si segna niente in rosso: aprire una schermata
  /// che ti dice gia' che hai sbagliato, quando non hai ancora toccato niente,
  /// e' una sgridata immeritata.
  bool _tried = false;

  bool get _canContinue => LegalConsent.mandatory.every(_checked.contains);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final saving = ref.watch(consentControllerProvider);

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              const CrasyHeader(),
              const SizedBox(height: AppSpacing.xl),
              const DisplayTitle('Prima di iniziare'),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Qui girano soldi veri, quindi ci sono delle regole. '
                'Leggile: sono corte.',
                style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),

              for (final consent in LegalConsent.mandatory)
                _ConsentRow(
                  consent: consent,
                  checked: _checked.contains(consent),
                  missing: _tried && !_checked.contains(consent),
                  onChanged: (value) => _toggle(consent, value),
                ),

              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(child: Divider(color: palette.line)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      'FACOLTATIVI',
                      style: texts.labelSmall?.copyWith(
                        color: palette.textFaint,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: palette.line)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // **Detto a chiare lettere che si puo' dire di no.** Un
              // facoltativo che non si capisce essere facoltativo viene spuntato
              // per prudenza, e un consenso dato per prudenza non e' libero.
              Text(
                'Queste due puoi lasciarle stare: entri lo stesso, e l\'app '
                'funziona uguale.',
                style: texts.bodySmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.md),

              for (final consent in LegalConsent.optional)
                _ConsentRow(
                  consent: consent,
                  checked: _checked.contains(consent),
                  missing: false,
                  onChanged: (value) => _toggle(consent, value),
                ),

              if (_tried && !_canContinue) ...[
                const SizedBox(height: AppSpacing.md),
                const InlineBanner(
                  message:
                      'Per entrare servono le prime quattro. Le altre due no.',
                ),
              ],
              if (saving.hasError) ...[
                const SizedBox(height: AppSpacing.md),
                const InlineBanner(
                  message:
                      'Non siamo riusciti a salvare le tue scelte. Controlla '
                      'la connessione e riprova.',
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              CrasyButton(
                label: 'Continua',
                loading: saving.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Versione dei documenti: ${LegalTexts.version}',
                textAlign: TextAlign.center,
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(LegalConsent consent, bool value) {
    setState(() {
      if (value) {
        _checked.add(consent);
      } else {
        _checked.remove(consent);
      }
    });
  }

  Future<void> _submit() async {
    if (!_canContinue) {
      setState(() => _tried = true);

      return;
    }

    // Il router si accorge da solo che la versione accettata e' quella di
    // adesso e porta avanti: qui non c'e' nessuna navigazione da fare a mano.
    await ref
        .read(consentControllerProvider.notifier)
        .accept(
          marketing: _checked.contains(LegalConsent.marketing),
          profiling: _checked.contains(LegalConsent.profiling),
        );
  }
}

/// Una riga: la spunta, cosa stai accettando, e il modo di leggerlo per esteso.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.consent,
    required this.checked,
    required this.missing,
    required this.onChanged,
  });

  final LegalConsent consent;
  final bool checked;

  /// Vero quando manca e serviva: si segna in rosso solo dopo che qualcuno ha
  /// provato a proseguire.
  final bool missing;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final document = consent.document;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        // **Si spunta toccando tutta la riga**, non il quadratino da venti
        // punti: su un telefono quel quadratino si manca, e chi lo manca due
        // volte pensa che l'app non risponda.
        onTap: () => onChanged(!checked),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Box(checked: checked, missing: missing),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consent.label,
                    style: texts.titleMedium?.copyWith(
                      color: missing ? palette.accent : palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    consent.explanation,
                    style: texts.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                  if (document != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    GestureDetector(
                      onTap: () => showLegalDocument(context, document),
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        'LEGGI IL TESTO',
                        style: texts.labelSmall?.copyWith(
                          color: palette.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Il quadratino. Quadrato e non tondo: un tondo vuol dire "scegline una", un
/// quadrato vuol dire "sono indipendenti", ed e' esattamente il punto.
class _Box extends StatelessWidget {
  const _Box({required this.checked, required this.missing});

  final bool checked;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bordo = missing ? palette.accent : palette.line;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: checked ? palette.accent : Colors.transparent,
          border: Border.all(color: checked ? palette.accent : bordo),
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: checked
            ? Icon(Icons.check_rounded, size: 16, color: palette.onAccent)
            : null,
      ),
    );
  }
}
