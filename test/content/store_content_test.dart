import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/config/app_config.dart';
import 'package:kronio_app/content/store_content.dart';

/// Los documentos legales se compilan dentro de la app, asi que no hay red que
/// los pueda validar en runtime. Estos tests son la red de seguridad: cazan los
/// errores que de verdad rompen el texto cuando alguien edita el archivo.
///
/// El bug mas caro que aparece aqui no es un error de compilacion, es texto
/// corrupto pegado sin querer al escribir. Todos los archivos del proyecto van
/// sin acentos a proposito, asi que cualquier caracter fuera del rango latino
/// es senal de que algo se rompio. Es un bug real, no hipotetico: se colaron
/// varias veces mientras se escribian estos documentos.
void main() {
  /// Los cuatro documentos que el footer puede abrir.
  final documents = <String, ContentDocument>{
    'about': aboutContent,
    'privacy': privacyContent,
    'terms': termsContent,
    'dataTreatment': dataTreatmentContent,
  };

  /// Rangos que no deberian aparecer en ningun documento.
  ///
  /// Van separados para que el mensaje senale el tipo de basura y no solo que
  /// "algo esta mal".
  final suspicious = <String, RegExp>{
    'cirilico o japones': RegExp('[\u0400-\u04FF\u3040-\u30FF\u4E00-\u9FFF]'),
    'arabe o hebreo': RegExp('[\u0590-\u05FF\u0600-\u06FF]'),
    'emoji': RegExp('[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
  };

  /// Texto completo de un documento, para buscar sobre todo junto.
  String fullTextOf(ContentDocument document) => [
    document.title,
    document.intro,
    for (final section in document.sections)
      '${section.title}\n${section.body}',
  ].join('\n');

  group('documentos legales', () {
    test('los cuatro existen y tienen contenido', () {
      expect(documents.keys, hasLength(4));

      for (final entry in documents.entries) {
        final document = entry.value;
        expect(
          document.title.trim(),
          isNotEmpty,
          reason: '${entry.key} sin titulo',
        );
        expect(
          document.updatedAt.trim(),
          isNotEmpty,
          reason: '${entry.key} sin fecha de actualizacion',
        );
        expect(
          document.intro.trim().length,
          greaterThan(60),
          reason: '${entry.key} con intro demasiado corta para servir de algo',
        );
        expect(
          document.sections.length,
          greaterThanOrEqualTo(3),
          reason: '${entry.key} con muy pocas secciones',
        );
      }
    });

    test('ningun documento tiene caracteres corruptos', () {
      for (final entry in documents.entries) {
        final text = fullTextOf(entry.value);

        for (final label in suspicious.keys) {
          final match = suspicious[label]!.firstMatch(text);
          if (match == null) continue;

          // Se muestra el entorno del fallo, no el caracter suelto: un
          // rectangulo replacement no dice nada, "Para nodos reportar" si.
          final start = math.max(0, match.start - 20);
          final end = math.min(text.length, match.end + 20);
          fail(
            '${entry.key} tiene un caracter de tipo "$label": '
            '"${text.substring(start, end)}"',
          );
        }
      }
    });

    test('ninguna seccion queda vacia', () {
      for (final entry in documents.entries) {
        for (final section in entry.value.sections) {
          expect(
            section.title.trim(),
            isNotEmpty,
            reason: '${entry.key} tiene una seccion sin titulo',
          );
          expect(
            section.body.trim(),
            isNotEmpty,
            reason: '${entry.key} / "${section.title}" con cuerpo vacio',
          );
        }
      }
    });

    test('los titulos de seccion no se repiten dentro de un documento', () {
      for (final entry in documents.entries) {
        final titles = entry.value.sections
            .map((section) => section.title.trim())
            .toList();

        expect(
          titles.toSet().length,
          titles.length,
          reason: '${entry.key} repite un titulo de seccion',
        );
      }
    });
  });

  group('datos de empresa sin configurar', () {
    // Un marcador `[pendiente]` es el comportamiento correcto mientras falten
    // los datos: es visible y no miente. Lo que no debe pasar es que el
    // documento afirme tener razon social cuando no la tiene, porque ese texto
    // se leeria como si fuera cierto.
    test('los huecos quedan marcados, no inventados', () {
      final responsable = aboutContent.sections.last;

      expect(responsable.title, 'Responsable del tratamiento');
      expect(responsable.body, contains('[Razon social pendiente'));
      expect(responsable.body, contains(AppConfig.supportEmail));
    });

    test('el aviso de datos nombra al responsable como pendiente', () {
      final body = dataTreatmentContent.sections
          .firstWhere((s) => s.title.startsWith('1.'))
          .body;

      expect(body, contains('[razon social pendiente]'));
      expect(body, contains('[representante pendiente]'));
    });
  });

  group('contenido especifico', () {
    test('los cuatro documentos dicen a quien escribir', () {
      for (final entry in documents.entries) {
        expect(
          fullTextOf(entry.value),
          contains(AppConfig.supportEmail),
          reason: '${entry.key} no dice a quien escribir para ejercer derechos',
        );
      }
    });

    test('el aviso de datos nombra a los terceros que el sistema usa', () {
      final text = fullTextOf(dataTreatmentContent);

      // No son nombres genericos: son los proveedores que el backend usa de
      // verdad. Si alguno se cae del documento, el aviso queda incompleto
      // frente a lo que la app hace en realidad.
      expect(text, contains('Dropi'), reason: 'despacha los pedidos');
      expect(text, contains('Gemini'), reason: 'responde el chatbot');
      expect(text, contains('CloudFront'), reason: 'sirve las imagenes');
    });

    test('los terminos cubren el retracto con los plazos de la ley', () {
      final text = fullTextOf(termsContent);

      expect(
        text,
        contains('Ley 1480'),
        reason: 'debe citar la ley que obliga',
      );
      expect(
        text,
        contains('cinco (5) dias habiles'),
        reason: 'el retracto son 5 dias habiles',
      );
      expect(
        text,
        contains('quince (15) dias habiles'),
        reason: 'el reembolso va en 15 dias habiles',
      );
    });

    test('la privacidad describe los controles que el backend implementa', () {
      final text = fullTextOf(privacyContent);

      expect(text, contains('bcrypt'), reason: 'las contrasenas se cifran asi');
      expect(text, contains('JWT'));
      expect(text, contains('CSRF'));
      expect(
        text,
        contains('cinco intentos fallidos'),
        reason: 'el bloqueo de cuenta va a los 5 intentos',
      );
    });

    test('la privacidad no promete un pago que la app no tenga', () {
      // Guarda contra una regresion concreta: la primera version de estos
      // textos decia que el pago en linea no estaba habilitado, y quedo
      // contradicho por la documentacion del backend, que si tiene checkout con
      // pedidos.
      final text = fullTextOf(privacyContent) + fullTextOf(termsContent);

      expect(text.toLowerCase(), isNot(contains('aun no está')));
      expect(text.toLowerCase(), isNot(contains('todavia no esta habilit')));
      expect(text, contains('Superintendencia de Industria y Comercio'));
    });
  });
}
