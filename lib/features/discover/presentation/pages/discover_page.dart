import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:flutter/material.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPageScaffold(
      eyebrow: 'Per Te',
      title: 'Qui vedrai soltanto chi e presente oggi.',
      description:
          'Il feed pubblico sara guidato dalle Daily attive della giornata, '
          'mai da una galleria permanente.',
    );
  }
}
