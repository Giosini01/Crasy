import 'package:crasy/core/services/share/invite_friend.dart';
import 'package:crasy/core/theme/app_palette.dart';
import 'package:crasy/core/theme/app_spacing.dart';
import 'package:crasy/core/widgets/app_background.dart';
import 'package:crasy/features/friends/data/repositories/contacts_repository.dart';
import 'package:crasy/features/friends/presentation/providers/friends_providers.dart';
import 'package:crasy/features/friends/presentation/widgets/suggested_friend_row.dart';
import 'package:crasy/features/friends/presentation/widgets/suggested_problem.dart';
import 'package:crasy/features/profile/presentation/providers/user_profile_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **Tutta la rubrica, divisa in due.**
///
/// Sopra chi CRASY ce l'ha gia': si segue da qui, senza aprire niente. Sotto
/// tutti gli altri, con il tasto per invitarli — ed e' la meta' che prima non
/// esisteva. Un'app che si gioca con gli amici, aperta da qualcuno i cui amici
/// non ci sono, non ha niente da offrirgli: l'elenco si chiudeva dicendo
/// "nessuno dei tuoi contatti e' ancora qui", che e' vero e inutile.
///
/// **I nomi non escono dal telefono.** Al server vanno solo i numeri, e la
/// risposta dice quali di quei numeri hanno un profilo. Chi non ha CRASY resta
/// un nome scritto in questa schermata e in nessun altro posto: non si e'
/// iscritto a niente, e tenerne traccia sarebbe roba che nessuno ci ha dato.
class FindFriendsPage extends ConsumerStatefulWidget {
  const FindFriendsPage({super.key});

  @override
  ConsumerState<FindFriendsPage> createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends ConsumerState<FindFriendsPage> {
  /// Chi e' gia' stato invitato in questa sessione.
  ///
  /// Si tiene a mente e basta: aprendo WhatsApp non c'e' modo di sapere se il
  /// messaggio e' stato mandato davvero, quindi segnarlo per sempre vorrebbe
  /// dire marcare come invitato chi ha solo aperto e chiuso la chat.
  final _invitati = <String>{};

  @override
  void initState() {
    super.initState();

    // Si cerca appena si arriva: ci si entra toccando "trova i tuoi amici",
    // che e' gia' la richiesta. Chiedere un secondo tocco su un elenco vuoto
    // sarebbe far ripetere una cosa appena detta.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(suggestedFriendsProvider).valueOrNull == null) {
        ref.read(suggestedFriendsProvider.notifier).cerca();
      }
    });
  }

  Future<void> _invita(Contatto chi) async {
    setState(() => _invitati.add(chi.numero));

    await InviteFriend.suWhatsApp(
      context,
      numero: chi.numero,
      username:
          ref.read(currentUserProfileProvider).valueOrNull?.username ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final stato = ref.watch(suggestedFriendsProvider);
    final rubrica = stato.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Trova i tuoi amici'),
      ),
      body: AppBackground(
        child: RefreshIndicator(
          color: palette.accent,
          onRefresh: () => ref.read(suggestedFriendsProvider.notifier).cerca(),
          child: _corpo(rubrica, stato),
        ),
      ),
    );
  }

  Widget _corpo(RubricaTrovata? rubrica, AsyncValue<RubricaTrovata?> stato) {
    final palette = context.palette;

    if (stato.hasError) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          SuggestedProblem(
            errore: stato.error,
            onRiprova: () =>
                ref.read(suggestedFriendsProvider.notifier).cerca(),
          ),
        ],
      );
    }

    // Null vuol dire "non ancora cercato", che non e' una rubrica vuota: vedi
    // il guasto che diceva "nessuno" prima ancora di guardare.
    if (rubrica == null) {
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        if (rubrica.suCrasy.isNotEmpty) ...[
          _Titolo(
            testo: 'SONO GIÀ QUI',
            quanti: rubrica.suCrasy.length,
            colore: palette.accent,
          ),
          const SizedBox(height: AppSpacing.md),
          for (final chi in rubrica.suCrasy) SuggestedFriendRow(suggested: chi),
          const SizedBox(height: AppSpacing.xl),
        ],
        if (rubrica.daInvitare.isNotEmpty) ...[
          _Titolo(
            testo: 'INVITALI',
            quanti: rubrica.daInvitare.length,
            colore: palette.textFaint,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Questi contatti CRASY non ce l\'hanno. Il messaggio lo scrivi tu '
            'su WhatsApp: noi non mandiamo niente a nessuno.',
            style: context.texts.bodySmall?.copyWith(color: palette.textFaint),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final chi in rubrica.daInvitare)
            _RigaDaInvitare(
              contatto: chi,
              invitato: _invitati.contains(chi.numero),
              onInvita: () => _invita(chi),
            ),
        ],
        if (rubrica.vuota)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Text(
              'In rubrica non c\'è nessun numero da confrontare.',
              style: context.texts.bodyMedium?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ),
      ],
    );
  }
}

class _Titolo extends StatelessWidget {
  const _Titolo({
    required this.testo,
    required this.quanti,
    required this.colore,
  });

  final String testo;
  final int quanti;
  final Color colore;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          testo,
          style: context.texts.labelSmall?.copyWith(
            color: colore,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$quanti',
          style: context.texts.labelSmall?.copyWith(color: colore),
        ),
      ],
    );
  }
}

/// Un contatto che CRASY non ce l'ha: nome, e il tasto per invitarlo.
///
/// **Niente faccia e niente numero.** La foto del contatto non ce l'abbiamo —
/// dalla rubrica prendiamo solo quello che serve — e il numero scritto sotto
/// il nome non aggiunge niente a chi sta guardando la propria rubrica: la sa
/// gia', e vederla scritta in un'app fa l'effetto opposto a quello che serve.
class _RigaDaInvitare extends StatelessWidget {
  const _RigaDaInvitare({
    required this.contatto,
    required this.invitato,
    required this.onInvita,
  });

  final Contatto contatto;
  final bool invitato;
  final VoidCallback onInvita;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final iniziale = contatto.nome.isEmpty
        ? '?'
        : contatto.nome.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Text(
              iniziale,
              style: context.texts.titleMedium?.copyWith(
                color: palette.textFaint,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              contatto.nome,
              style: context.texts.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Contornato e non pieno: il rosso pieno sta sul tasto di chi e' gia'
          // qui — quello porta dentro l'app, questo porta fuori. Due gesti
          // diversi non devono avere lo stesso peso.
          OutlinedButton(
            onPressed: invitato ? null : onInvita,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accent,
              side: BorderSide(color: invitato ? palette.line : palette.accent),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(invitato ? 'Invitato' : 'Invita'),
          ),
        ],
      ),
    );
  }
}
