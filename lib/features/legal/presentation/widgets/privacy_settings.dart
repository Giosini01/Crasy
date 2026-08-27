import 'package:crasy/core/legal/legal_documents.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/modal_sheet.dart';
import 'package:crasy/features/legal/presentation/controllers/consent_controller.dart';
import 'package:crasy/features/legal/presentation/widgets/legal_sheet.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Privacy e consensi, dal proprio profilo.
///
/// **Esiste perche' la legge lo impone, e sarebbe giusto anche se non lo
/// imponesse.** Il GDPR chiede che revocare un consenso sia facile quanto
/// darlo: se per darlo basta una spunta e per toglierlo bisogna scrivere una
/// email e aspettare, quel consenso non e' mai stato libero.
///
/// Qui i due facoltativi si spengono con lo stesso gesto con cui si erano
/// accesi, e i tre documenti si rileggono senza uscire dall'app.
Future<void> showPrivacySettings(BuildContext context) {
  return ModalSheet.show<void>(
    context: context,
    builder: (sheetContext) => ModalSheet(
      title: 'PRIVACY E CONSENSI',
      confirmLabel: 'Chiudi',
      onConfirm: () => Navigator.of(sheetContext).pop(),
      child: const _PrivacySettings(),
    ),
  );
}

class _PrivacySettings extends ConsumerWidget {
  const _PrivacySettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final texts = context.texts;
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final saving = ref.watch(consentControllerProvider).isLoading;

    if (profile == null) {
      return const SizedBox.shrink();
    }

    Future<void> cambia({bool? marketing, bool? profiling}) {
      return ref
          .read(consentControllerProvider.notifier)
          .accept(
            marketing: marketing ?? profile.marketingConsent,
            profiling: profiling ?? profile.profilingConsent,
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'I DOCUMENTI',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.xs),
        for (final consent in LegalConsent.mandatory)
          if (consent.document case final documento?)
            _DocumentRow(title: documento.title, document: documento),

        const SizedBox(height: AppSpacing.lg),
        Text(
          'LE TUE SCELTE',
          style: texts.labelSmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.xs),
        _Switch(
          consent: LegalConsent.marketing,
          value: profile.marketingConsent,
          enabled: !saving,
          onChanged: (value) => cambia(marketing: value),
        ),
        _Switch(
          consent: LegalConsent.profiling,
          value: profile.profilingConsent,
          enabled: !saving,
          onChanged: (value) => cambia(profiling: value),
        ),

        const SizedBox(height: AppSpacing.lg),
        // **La prova di cosa e' stato accettato, e quando.** Non e' un dettaglio
        // da nascondere: e' il dato che rende verificabile tutto il resto, e chi
        // lo cerca ha il diritto di trovarlo senza chiederlo a nessuno.
        Text(
          profile.legalAcceptedAt == null
              ? 'Documenti accettati: versione ${profile.legalVersion}.'
              : 'Documenti accettati il '
                    '${_giorno(profile.legalAcceptedAt!)}, '
                    'versione ${profile.legalVersion}.',
          style: texts.bodySmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Per accedere ai tuoi dati, correggerli o cancellarli scrivi al '
          'contatto indicato nell\'informativa.',
          style: texts.bodySmall?.copyWith(color: palette.textFaint),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  static String _giorno(DateTime quando) =>
      '${quando.day.toString().padLeft(2, '0')}/'
      '${quando.month.toString().padLeft(2, '0')}/${quando.year}';
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.title, required this.document});

  final String title;
  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showLegalDocument(context, document),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(child: Text(title, style: context.texts.bodyMedium)),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: context.palette.textFaint,
            ),
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.consent,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final LegalConsent consent;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(consent.label, style: context.texts.bodyMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  consent.explanation,
                  style: context.texts.bodySmall?.copyWith(
                    color: palette.textFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch.adaptive(
            value: value,
            activeThumbColor: palette.accent,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
