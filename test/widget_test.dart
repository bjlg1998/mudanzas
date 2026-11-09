import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mudanzas/location_picker_page.dart';
import 'package:mudanzas/main.dart';

void main() {
  testWidgets('muestra errores cuando el formulario está vacío', (
    tester,
  ) async {
    await tester.pumpWidget(const MudanzasApp());

    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('inicia y cierra sesión', (tester) async {
    await tester.pumpWidget(const MudanzasApp());

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'usuario@mudanzas.com',
    );
    await tester.enterText(find.byKey(const Key('passwordField')), 'secreto');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('¡Hola!'), findsOneWidget);
    expect(find.text('usuario@mudanzas.com'), findsOneWidget);
    expect(find.text('Nueva mudanza'), findsOneWidget);

    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('crea una solicitud de mudanza con direcciones y vehículo', (
    tester,
  ) async {
    await tester.pumpWidget(const MudanzasApp());

    await tester.enterText(
      find.byKey(const Key('emailField')),
      'usuario@mudanzas.com',
    );
    await tester.enterText(find.byKey(const Key('passwordField')), 'secreto');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('newMoveButton')));
    await tester.pumpAndSettle();

    expect(find.text('Tu recorrido'), findsOneWidget);
    expect(find.text('Motocarro'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('originField')),
      'Calle 100 # 15-20, Bogotá',
    );
    await tester.enterText(
      find.byKey(const Key('destinationField')),
      'Carrera 7 # 72-41, Bogotá',
    );
    final motocarro = find.byKey(const Key('vehicle-motocarro'));
    await tester.ensureVisible(motocarro);
    await tester.pumpAndSettle();
    await tester.tap(motocarro);

    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();

    final continueButton = find.byKey(const Key('continueMoveButton'));
    expect(continueButton, findsOneWidget);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Solicitud preparada'), findsOneWidget);
    final summary = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: summary,
        matching: find.text('Calle 100 # 15-20, Bogotá'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: summary,
        matching: find.text('Carrera 7 # 72-41, Bogotá'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('muestra un selector de mapa compacto con acceso al GPS', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LocationPickerPage(title: 'Punto de destino')),
    );
    await tester.pump();

    expect(find.byKey(const Key('mapSearchField')), findsOneWidget);
    expect(find.byKey(const Key('currentLocationButton')), findsOneWidget);
    expect(find.text('Usar esta ubicación'), findsOneWidget);
  });
}
