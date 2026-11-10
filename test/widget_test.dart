import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mudanzas/location_picker_page.dart';
import 'package:mudanzas/main.dart';
import 'package:mudanzas/mis_mudanzas_page.dart';
import 'package:mudanzas/services/auth_service.dart';

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
    expect(find.text('Nueva mudanza'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();

    expect(find.text('usuario@mudanzas.com'), findsOneWidget);
    await tester.tap(find.byKey(const Key('logoutButton')));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  testWidgets('muestra el formulario para crear una cuenta', (tester) async {
    await tester.pumpWidget(const MudanzasApp());

    final registerButton = find.byKey(const Key('toggleRegisterButton'));
    await tester.ensureVisible(registerButton);
    await tester.tap(registerButton);
    await tester.pump();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.byKey(const Key('nameField')), findsOneWidget);
    expect(find.byKey(const Key('confirmPasswordField')), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
    expect(find.text('Acceso protegido con Supabase.'), findsNothing);
  });

  testWidgets('muestra el perfil y el estado vacío de mis mudanzas', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InicioPage(email: 'ana@correo.com', displayName: 'Ana Gómez'),
      ),
    );

    expect(find.text('¡Hola, Ana!'), findsOneWidget);
    await tester.tap(find.byKey(const Key('myMovesButton')));
    await tester.pumpAndSettle();

    expect(find.byType(MisMudanzasPage), findsOneWidget);
    expect(find.text('Aún no tienes mudanzas'), findsOneWidget);
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
    await tester.enterText(
      find.byKey(const Key('moveNotesField')),
      'Tercer piso sin ascensor. Llamar al llegar.',
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
    expect(
      find.descendant(
        of: summary,
        matching: find.text('Tercer piso sin ascensor. Llamar al llegar.'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('closeMoveSummary')));
    await tester.pumpAndSettle();
    expect(find.text('Mis mudanzas'), findsOneWidget);
  });

  testWidgets('muestra una experiencia diferente para el conductor', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: InicioPage(
          email: 'conductor@correo.com',
          displayName: 'Carlos',
          role: AccountRole.driver,
        ),
      ),
    );

    expect(find.text('Ver servicios asignados'), findsOneWidget);
    expect(find.byKey(const Key('newMoveButton')), findsNothing);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Inicio')),
      findsNothing,
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
