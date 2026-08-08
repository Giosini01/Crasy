import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPageScaffold(
      eyebrow: 'Profilo',
      title:
          'Un profilo leggero, pensato per il presente e non per l\'archivio.',
      description:
          'Qui predisponiamo impostazioni e identita utente senza trasformare '
          'l\'app in una vetrina di foto permanenti.',
    );
  }
}
