import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../content/store_content.dart';
import '../theme/app_colors.dart';
import '../widgets/brand_header.dart';

/// Pantalla de contenido largo: "Sobre nosotros", "Politica de privacidad" y
/// "Terminos y condiciones".
///
/// Reemplaza al dialogo que antes abria cada enlace del footer. El dialogo
/// decia que la seccion no estaba disponible; esta pantalla muestra el texto
/// completo y deja que el usuario lo lea y vuelva.
///
/// El texto viene de `lib/content/store_content.dart`. Va compilado en la app
/// porque el backend no expone endpoints de contenido estatico.
class ContentScreen extends StatelessWidget {
  const ContentScreen({super.key, required this.document});

  final ContentDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: const BrandHeader(logoSize: 24, showName: false),
        title: Text(document.title),
      ),
      body: ListView(
        // `padding` en vez de `Padding` para que el ultimo pixel de la ultima
        // linea siga siendo desplazable.
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            document.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.update,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Actualizado: ${document.updatedAt}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _IntroBlock(text: document.intro),
          const SizedBox(height: 24),

          for (final section in document.sections) ...[
            _SectionBlock(section: section),
            const SizedBox(height: 20),
          ],

          // Aviso honesto: el texto es una base tecnica y no un documento
          // legal aprobado. Ocultarlo seria peor que decirlo.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppConfig.hasCompleteLegalData
                        ? 'Este documento describe el tratamiento de tus datos '
                              'en Kronio Market. Para ejercer tus derechos '
                              'escribe a ${AppConfig.supportEmail}.'
                        : 'Texto informativo de la tienda. Este documento esta '
                              'pendiente de completar con los datos de la '
                              'empresa, por lo que no sustituye el aviso legal '
                              'definitivo.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
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

class _IntroBlock extends StatelessWidget {
  const _IntroBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final ContentSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        // Los parrafos van separados por `\n\n` en el origen; aqui se
        // convierten en espacios reales entre bloques.
        for (final paragraph in section.body.split('\n\n'))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              paragraph,
              style: const TextStyle(fontSize: 14, height: 1.55),
            ),
          ),
      ],
    );
  }
}
