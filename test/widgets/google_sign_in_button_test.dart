import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kronio_app/widgets/google_sign_in_button.dart';

void main() {
  testWidgets('el boton muestra el texto de Google', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GoogleSignInButton())),
    );

    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  // Sin endpoint en el backend el boton no puede autenticar. El aviso evita que
  // el usuario pulse y no pase nada.
  testWidgets('al pulsarlo avisa que aun no esta disponible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GoogleSignInButton())),
    );

    await tester.tap(find.text('Continuar con Google'));
    await tester.pump();

    expect(
      find.text('El inicio de sesion con Google todavia no esta disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('el separador muestra su etiqueta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AuthSeparator())),
    );

    expect(find.text('o continua con'), findsOneWidget);
  });
}
