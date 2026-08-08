import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:flutter/material.dart';

class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPageScaffold(
      eyebrow: 'Match',
      title: 'Connessioni reciproche, senza contatori o classifiche.',
      description:
          'Questa area ospitera i match e in seguito all\'accesso alla chat, '
          'mantenendo l\'esperienza pulita e privata.',
    );
  }
}
