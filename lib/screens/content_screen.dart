import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../content/store_content.dart';
import '../theme/app_colors.dart';

/// Pantalla de contenido largo: "Sobre nosotros", "Política de privacidad" y
/// "Términos y condiciones".
///
/// Reemplaza al diálogo que antes abría cada enlace del footer. El diálogo
/// decía que la sección no estaba disponible; esta pantalla muestra el texto
/// completo y deja que el usuario lo lea y vuelva.
///
/// El texto viene de `lib/content/store_content.dart`. Va compilado en la app
/// porque el backend no expone endpoints de contenido estático.
class ContentScreen extends StatefulWidget {
  const ContentScreen({super.key, required this.document});

  final ContentDocument document;

  @override
  State<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends State<ContentScreen> {
  /// Una clave por sección, para poder saltar a cualquiera desde el índice.
  ///
  /// No se puede usar `ScrollController.animateTo` con un offset calculado
  /// porque no se sabe cuánto mide cada sección hasta que está construida, y el
  /// texto es variable. `Scrollable.ensureVisible` sobre el contexto de la
  /// sección resuelve las dos cosas de una: pide el tamaño real y anima.
  late final List<GlobalKey> _sectionKeys = [
    for (var i = 0; i < widget.document.sections.length; i++) GlobalKey(),
  ];

  void _scrollToSection(int index) {
    final target = _sectionKeys[index].currentContext;
    if (target == null) return;

    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      // Deja la sección pegada bajo el AppBar en vez de pegada al borde de la
      // pantalla, que es donde el usuario espera encontrarla.
      alignment: 0.02,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final document = widget.document;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(document.title),
      ),
      // `SingleChildScrollView` con un `Column`, no un `ListView`.
      //
      // La razón es el índice. `ListView` solo construye lo que está cerca del
      // viewport, así que la clave de la sección 9 de 16 no existe hasta que el
      // usuario llega allá por scroll manual. Tocar esa entrada del índice no
      // hacía nada: `ensureVisible` recibía un `null` y salía en silencio. Es el
      // caso más común, no el borde.
      //
      // Construir todo de una vez no cuesta nada a esta escala: el documento
      // más largo son unos 15 KB de texto. El `ListView` se puso cuando estos
      // documentos eran un párrafo; con treinta apartados el ahorro ya no
      // compensa el bug.
      //
      // El `padding` va en el `SingleChildScrollView` y no en un `Padding` para
      // que el último píxel de la última línea siga siendo desplazable.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 20),

            // Índice. Los documentos llegan con un apartado "Contenido" que en
            // papel sirve para encontrar una cláusula sin leer treinta secciones.
            // En una pantalla larga eso no sirve si el índice no hace nada, así
            // que cada entrada salta a su sección.
            //
            // Se arma desde `document.sections` y no se escribe a mano: un índice
            // desincronizado del cuerpo es peor que no tener índice.
            _ContentsIndex(
              titles: [for (final section in document.sections) section.title],
              onSelect: _scrollToSection,
            ),
            const SizedBox(height: 24),

            for (var i = 0; i < document.sections.length; i++) ...[
              _SectionBlock(
                key: _sectionKeys[i],
                section: document.sections[i],
              ),
              const SizedBox(height: 20),
            ],

            // Aviso honesto: si los datos de la empresa siguen siendo los
            // marcadores de posición, el documento no se puede publicar tal cual.
            // Ocultarlo sería peor que decirlo, porque el usuario leería un NIT
            // de ejemplo creyendo que es el de la empresa.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppConfig.hasCompleteLegalData
                        ? Icons.info_outline
                        : Icons.warning_amber_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppConfig.hasCompleteLegalData
                          ? 'Para ejercer tus derechos escribe a '
                                '${AppConfig.supportEmail}. También puedes '
                                'presentar un reclamo ante la Superintendencia '
                                'de Industria y Comercio en www.sic.gov.co.'
                          : 'Documento pendiente de completar con los datos de la '
                                'empresa. La razón social, el NIT y la dirección '
                                'deben aparecer en su versión definitiva.',
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
      ),
    );
  }
}

/// Índice de contenidos con salto a la sección.
class _ContentsIndex extends StatelessWidget {
  const _ContentsIndex({required this.titles, required this.onSelect});

  final List<String> titles;

  /// Recibe el índice de la sección a la que hay que saltar.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Solo se muestra si hay suficientes secciones para que compense. En un
    // documento de tres apartados, el índice es ruido.
    if (titles.length < 4) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.list_alt_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 6),
              Text(
                'CONTENIDO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < titles.length; i++)
            Builder(
              builder: (context) => TextButton(
                // Padding propio y `shrinkWrap`: el `TextButton.styleFrom` por
                // defecto deja un alto mínimo que hace que treinta entradas
                // ocupen más que el documento.
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 7,
                  ),
                  alignment: Alignment.centerLeft,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => onSelect(i),
                child: Text(
                  titles[i],
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
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
  const _SectionBlock({super.key, required this.section});

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
        // Los párrafos van separados por `\n\n` en el origen; aquí se
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
