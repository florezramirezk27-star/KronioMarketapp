import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/config/app_config.dart';
import 'package:kronio_app/content/store_content.dart';

/// Los documentos legales se compilan dentro de la app, así que no hay red que
/// los pueda validar en runtime. Estos tests son la red de seguridad.
///
/// El bug más caro que aparece aquí no es un error de compilación, es texto
/// corrupto pegado al escribir. A diferencia del resto del proyecto, este
/// archivo sí usa tildes y "ñ" (son documentos legales que se leen en pantalla),
/// lo que abre la puerta a que una codificación se rompa y queden caracteres
/// de otro alfabeto o signos de reemplazo. Ya pasó varias veces.
void main() {
  /// Los tres documentos que el footer puede abrir.
  final documents = <String, ContentDocument>{
    'about': aboutContent,
    'privacy': privacyContent,
    'terms': termsContent,
  };

  /// Rangos que no deberían aparecer en ningún documento.
  final suspicious = <String, RegExp>{
    'cirílico o japonés': RegExp('[\u0400-\u04FF\u3040-\u30FF\u4E00-\u9FFF]'),
    'árabe o hebreo': RegExp('[\u0590-\u05FF\u0600-\u06FF]'),
    'emoji': RegExp('[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
    // El signo de reemplazo es lo que deja un archivo cuando se escribe con
    // una codificación que el lector no entiende. Es el síntoma más difícil de
    // ver a ojo y el más grave: parece un carácter normal.
    'signo de reemplazo': RegExp('\uFFFD'),
  };

  /// Texto completo de un documento, para buscar sobre todo junto.
  String fullTextOf(ContentDocument document) => [
    document.title,
    document.intro,
    for (final section in document.sections)
      '${section.title}\n${section.body}',
  ].join('\n');

  group('documentos legales', () {
    test('los tres existen y tienen contenido', () {
      expect(documents.keys, hasLength(3));

      for (final entry in documents.entries) {
        final document = entry.value;
        expect(
          document.title.trim(),
          isNotEmpty,
          reason: '${entry.key} sin título',
        );
        expect(
          document.updatedAt.trim(),
          isNotEmpty,
          reason: '${entry.key} sin fecha de actualización',
        );
        expect(
          document.intro.trim().length,
          greaterThan(60),
          reason: '${entry.key} con intro demasiado corta para servir de algo',
        );
        expect(
          document.sections.length,
          greaterThanOrEqualTo(4),
          reason: '${entry.key} con muy pocas secciones',
        );
      }
    });

    test('ningún documento tiene caracteres corruptos', () {
      for (final entry in documents.entries) {
        final text = fullTextOf(entry.value);

        for (final label in suspicious.keys) {
          final match = suspicious[label]!.firstMatch(text);
          if (match == null) continue;

          // Se muestra el entorno del fallo, no el carácter suelto: un
          // rectángulo de reemplazo no dice nada, "Para nodos reportar" sí.
          final start = math.max(0, match.start - 20);
          final end = math.min(text.length, match.end + 20);
          fail(
            '${entry.key} tiene un carácter de tipo "$label": '
            '"${text.substring(start, end)}"',
          );
        }
      }
    });

    // Este archivo es el único del proyecto con tildes. Si alguien decide
    // "normalizarlo" y las quita, el documento se degrada a texto que se lee
    // con errores ortográficos, y en un texto legal eso importa.
    test('el texto conserva tildes y la eñe', () {
      for (final entry in documents.entries) {
        expect(
          fullTextOf(entry.value),
          matches(RegExp('[\u00C0-\u00FF]')),
          reason:
              '${entry.key} quedó sin ninguna tilde: parece que las '
              'acentuaciones se perdieron al guardar el archivo',
        );
      }

      // Palabras que solo existen si el acento y la ñ están bien.
      expect(fullTextOf(privacyContent), contains('información'));
      expect(fullTextOf(termsContent), contains('Términos'));
      expect(fullTextOf(termsContent), contains('años'));
    });

    test('ninguna sección queda vacía', () {
      for (final entry in documents.entries) {
        for (final section in entry.value.sections) {
          expect(
            section.title.trim(),
            isNotEmpty,
            reason: '${entry.key} tiene una sección sin título',
          );
          expect(
            section.body.trim(),
            isNotEmpty,
            reason: '${entry.key} / "${section.title}" con cuerpo vacío',
          );
        }
      }
    });

    test('los títulos de sección no se repiten dentro de un documento', () {
      for (final entry in documents.entries) {
        final titles = entry.value.sections
            .map((section) => section.title.trim())
            .toList();

        expect(
          titles.toSet().length,
          titles.length,
          reason: '${entry.key} repite un título de sección',
        );
      }
    });

    // El índice de la pantalla se arma desde `sections`, así que basta con que
    // los títulos no se repitan y no estén vacíos. Esto fija el número de
    // apartados para que un recorte accidental se note en el test.
    test('los documentos legales tienen los apartados completos', () {
      expect(privacyContent.sections, hasLength(18));
      expect(termsContent.sections, hasLength(16));
    });
  });

  group('datos de empresa', () {
    // Los valores por defecto son marcadores de posición. El punto de todo el
    // mecanismo es que no se publiquen como si fueran ciertos.
    test('los marcadores de posición no se muestran como datos', () {
      expect(
        AppConfig.hasCompleteLegalData,
        isFalse,
        reason:
            'si esto falla es porque ya se configuraron los datos reales; '
            'actualiza este test a propósito, no por accidente',
      );

      expect(
        AppConfig.legalOrPending('000.000.000-0'),
        '[pendiente de configurar]',
      );
      expect(
        AppConfig.legalOrPending('+57 (1) 555-1234'),
        '[pendiente de configurar]',
      );
      expect(AppConfig.legalOrPending(''), '[pendiente de configurar]');
    });

    test('un dato real se muestra tal cual', () {
      expect(AppConfig.legalOrPending('900.123.456-7'), '900.123.456-7');
      expect(AppConfig.legalOrPending('+57 300 123 4567'), '+57 300 123 4567');
      expect(AppConfig.legalOrPending('Kronio Market'), 'Kronio Market');
    });

    test('el NIT de ejemplo no aparece en ningún documento', () {
      // `000.000.000-0` es el NIT de ejemplo que aparece en las guías de la SIC.
      // Si aparece en pantalla, se está publicando como dato real.
      for (final entry in documents.entries) {
        expect(
          fullTextOf(entry.value),
          isNot(contains('000.000.000-0')),
          reason: '${entry.key} está mostrando el NIT de ejemplo como real',
        );
        expect(
          fullTextOf(entry.value),
          contains('[pendiente de configurar]'),
          reason: '${entry.key} debería marcar el hueco en vez de callar',
        );
      }
    });
  });

  group('contenido normativo', () {
    test('los tres documentos dicen a quién escribir', () {
      for (final entry in documents.entries) {
        expect(
          fullTextOf(entry.value),
          contains(AppConfig.supportEmail),
          reason: '${entry.key} no dice a quién escribir',
        );
      }
    });

    // Las citas se verificaron contra el texto oficial de cada norma. Si
    // alguien reescribe el documento, el test obliga a volver a mirarlas.
    test('los términos citan las normas que los obligan', () {
      final text = fullTextOf(termsContent);

      expect(text, contains('Ley 1480 de 2011'));
      expect(text, contains('Ley 2439 de 2024'));
      expect(text, contains('Decreto 587 de 2016'));
      // El artículo 50 fue modificado por la Ley 2439 de 2024.
      expect(text, contains('artículo 50'));
    });

    test('los plazos del retracto son los de la ley', () {
      final text = fullTextOf(termsContent);

      // Art. 47 Ley 1480: 5 días hábiles. Art. 3 Ley 2439 de 2024: la
      // devolución en 15 días calendario, no en 30.
      expect(text, contains('cinco (5) días hábiles'));
      expect(text, contains('quince (15) días calendario'));
      expect(
        text,
        isNot(contains('treinta (30) días calendario desde el ejercicio')),
        reason: 'ese plazo cambió con la Ley 2439 de 2024',
      );
      // Art. 4 de la Ley 2439: entrega a más tardar en 30 días calendario.
      expect(text, contains('treinta (30) días calendario'));
    });

    test('los términos declaran el pago contra entrega de forma coherente', () {
      final text = fullTextOf(termsContent);

      expect(text, contains('contra entrega'));
      expect(
        text,
        contains('no procesamos pagos con tarjetas'),
        reason: 'si algún día hay pasarela, esta frase hay que quitarla',
      );

      // El sistema cobra en efectivo al transportador, así que no hay
      // instrumento de pago al que devolverle el dinero. El artículo 5 de la
      // Ley 2439 de 2024 obliga a devolver por el medio que elija el
      // consumidor, y en efectivo ese medio es acordar la forma.
      expect(text, contains('por el medio que usted elija'));
    });

    test('la política cita la Ley 1581 y sus decretos', () {
      final text = fullTextOf(privacyContent);

      expect(text, contains('Ley 1581 de 2012'));
      expect(text, contains('Decreto 1377 de 2013'));
      expect(text, contains('Decreto 1074 de 2015'));
      expect(text, contains('artículo 15 de la Constitución Política'));
    });

    test('la política fija los plazos de consultas y reclamos', () {
      final text = fullTextOf(privacyContent);

      // Art. 14: consultas en 10 días hábiles, prorrogables 5.
      expect(text, contains('diez (10) días hábiles'));
      expect(text, contains('cinco (5) días hábiles adicionales'));
      // Art. 15: reclamos en 15 días hábiles, prorrogables 8.
      expect(text, contains('quince (15) días hábiles'));
      expect(text, contains('ocho (8) días hábiles adicionales'));
    });

    test('la política declara las transferencias internacionales', () {
      final text = fullTextOf(privacyContent);

      expect(text, contains('fuera de Colombia'));
      expect(
        text,
        contains('artículo 26'),
        reason: 'es el artículo que regula la transferencia a terceros países',
      );
      // El chatbot sale del país y eso hay que decirlo, no esconderlo.
      expect(text, contains('Google'));
      expect(text, contains('KronioBot'));
    });

    test('la política separa las cookies del sitio de la app', () {
      // En Android las cookies son del navegador, no de la app. Decir lo
      // contrario sería técnicamente falso y además confunde al titular.
      final text = fullTextOf(privacyContent);

      expect(text, contains('app móvil'));
      expect(text, contains('no utiliza cookies'));
    });
  });
}
