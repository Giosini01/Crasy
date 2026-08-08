import 'package:app_incontri/core/widgets/placeholder_page_scaffold.dart';
import 'package:flutter/material.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPageScaffold(
      eyebrow: 'Camera',
      title: 'La Daily nascera qui, senza galleria e senza upload.',
      description:
          'Questa base prepara il punto di cattura in-app. La logica reale '
          'della fotocamera arrivera nel task dedicato.',
    );
  }
}
