import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/core/widgets/crasy_button.dart';
import 'package:crasy/features/auth/presentation/providers/auth_providers.dart';
import 'package:crasy/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **I permessi, spiegati prima di chiederli. Una volta sola, al primo
/// ingresso.**
///
/// Il telefono fa la domanda una volta: chi dice di no non se la vede
/// riproporre, e dice di no quando non sa a cosa serve. Prima il riquadro
/// delle notifiche compariva appena fatto l'accesso, senza una parola. Qui
/// ogni permesso ha la sua riga — cosa, e perche' — e il tasto lo chiede
/// davvero.
///
/// **La fotocamera non si chiede qui.** La chiede il telefono la prima volta
/// che scatti, cioe' nel momento in cui e' ovvio a cosa serve: chiederla
/// adesso vorrebbe dire spendere quella domanda per niente.
class PermissionsPage extends ConsumerStatefulWidget {
  const PermissionsPage({super.key});

  @override
  ConsumerState<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends ConsumerState<PermissionsPage> {
  bool _chiedendo = false;
  bool _chiudendo = false;
  bool? _notifiche;
  bool? _contatti;

  String? get _userId {
    final stato = ref.read(authStateProvider);

    return stato is AuthenticatedAuthState ? stato.user.id : null;
  }

  Future<void> _consenti() async {
    final id = _userId;

    if (id == null || _chiedendo) {
      return;
    }

    setState(() => _chiedendo = true);

    // Una domanda alla volta: il telefono non ne mostra due insieme.
    try {
      await ref.read(pushRegistryProvider)?.register(id, chiedi: true);
      _notifiche = true;
    } on Object {
      _notifiche = false;
    }

    try {
      final esito = await FlutterContacts.permissions.request(
        PermissionType.read,
      );
      _contatti =
          esito == PermissionStatus.granted ||
          esito == PermissionStatus.limited;
    } on Object {
      _contatti = false;
    }

    if (mounted) {
      setState(() => _chiedendo = false);
    }

    await _avanti();
  }

  Future<void> _avanti() async {
    final id = _userId;

    if (id == null || _chiudendo) {
      return;
    }

    setState(() => _chiudendo = true);

    try {
      await ref.read(userProfileRepositoryProvider).markPermissionsSeen(id);
    } on Object {
      // Se la scrittura non riesce si entra lo stesso: rivedere questa
      // schermata e' meglio che restare fuori.
      if (mounted) {
        setState(() => _chiudendo = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;
    final occupato = _chiedendo || _chiudendo;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.page),
            children: [
              Text(
                'PRIMA DI ENTRARE',
                style: texts.labelSmall?.copyWith(color: palette.textFaint),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tre permessi, e a cosa servono',
                style: texts.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Te li chiede il telefono, una volta sola. Puoi cambiarli '
                'quando vuoi dalle impostazioni.',
                style: texts.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Riga(
                icona: Icons.notifications_active_rounded,
                titolo: 'Notifiche',
                perche:
                    'Per sapere quando un amico ti sfida, quando qualcuno '
                    'mette una fiamma sulla tua foto e quando vinci. Senza, '
                    'le sfide scadono prima che tu le veda.',
                esito: _notifiche,
              ),
              _Riga(
                icona: Icons.contacts_rounded,
                titolo: 'Contatti',
                perche:
                    'Per trovare gli amici che sono già su CRASY. Dalla '
                    'rubrica prendiamo solo i numeri, per confrontarli: non '
                    'li salviamo e non scriviamo a nessuno.',
                esito: _contatti,
              ),
              const _Riga(
                icona: Icons.photo_camera_rounded,
                titolo: 'Fotocamera e foto',
                perche:
                    'Per partecipare alle missioni. Te la chiede il '
                    'telefono la prima volta che scatti o scegli una foto.',
              ),
              const SizedBox(height: AppSpacing.xl),
              CrasyButton(
                label: 'Consenti',
                loading: _chiedendo,
                onPressed: occupato ? null : _consenti,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: occupato ? null : _avanti,
                  child: Text(
                    'Più tardi',
                    style: texts.bodyMedium?.copyWith(color: palette.textFaint),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({
    required this.icona,
    required this.titolo,
    required this.perche,
    this.esito,
  });

  final IconData icona;
  final String titolo;
  final String perche;

  /// Com'e' andata la domanda: null se non e' ancora stata fatta.
  final bool? esito;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final texts = context.texts;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icona, color: palette.accent, size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(titolo, style: texts.titleMedium),
                    if (esito != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        esito!
                            ? Icons.check_circle_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 16,
                        color: esito! ? palette.accent : palette.textFaint,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  perche,
                  style: texts.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
