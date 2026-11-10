import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'core/backend.dart';
import 'firebase_options.dart';
import 'mis_mudanzas_page.dart';
import 'nueva_mudanza_page.dart';
import 'servicios_disponibles_page.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.initialize();
  }
  await Backend.initialize();
  runApp(const MudanzasApp());
}

class MudanzasApp extends StatelessWidget {
  const MudanzasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mudanzas',
      theme: buildAppTheme(),
      home: _initialPage(),
    );
  }

  Widget _initialPage() {
    if (Backend.isConfigured) {
      final user = AuthService().currentSession?.user;
      if (user != null) {
        return const _SessionGate();
      }
    }
    return const LoginPage();
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return FutureBuilder<AccountRole>(
      future: auth.currentRole(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const LoginPage();
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return InicioPage(
          email: auth.currentUser?.email ?? 'Usuario',
          displayName: auth.displayName,
          avatarUrl: auth.avatarUrl,
          role: snapshot.data!,
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _hidePassword = true;
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _navigating = false;
  AccountRole _selectedRole = AccountRole.customer;
  String? _loginError;
  String? _confirmationEmail;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (Backend.isConfigured) {
      _authSubscription = Backend.client.auth.onAuthStateChange.listen((data) {
        final session = data.session;
        if (session != null && data.event == AuthChangeEvent.signedIn) {
          _openHome(session.user.email ?? 'Usuario');
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _openHome(String email) async {
    if (!mounted || _navigating) return;
    _navigating = true;
    final auth = AuthService();
    AccountRole role = _selectedRole;
    try {
      role = await auth.chooseRole(_selectedRole);
    } catch (_) {
      if (Backend.isConfigured) await auth.signOut();
      if (!mounted) return;
      setState(() {
        _navigating = false;
        _isLoading = false;
        _isGoogleLoading = false;
        _loginError =
            'Esta cuenta ya tiene otro tipo de acceso. Elige el perfil correcto.';
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => InicioPage(
          email: email,
          displayName: auth.displayName,
          avatarUrl: auth.avatarUrl,
          role: role,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    if (Backend.isConfigured) {
      try {
        if (_isRegistering) {
          final response = await AuthService().signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _nameController.text.trim(),
            role: _selectedRole,
          );
          if (response.session == null) {
            if (!mounted) return;
            final email = _emailController.text.trim();
            setState(() {
              _isLoading = false;
              _isRegistering = false;
              _passwordController.clear();
              _confirmPasswordController.clear();
              _loginError = null;
              _confirmationEmail = email;
            });
            return;
          }
        } else {
          await AuthService().signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _loginError = _isRegistering
              ? 'No pudimos crear la cuenta. Revisa los datos o usa otro correo.'
              : 'No pudimos iniciar sesión. Revisa tus datos.';
        });
        return;
      }
    }

    if (!mounted) return;
    _openHome(_emailController.text.trim());
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _loginError = null;
    });
    try {
      final launched = await AuthService().signInWithGoogle();
      if (!launched) throw StateError('No se pudo abrir Google.');
      if (mounted) setState(() => _isGoogleLoading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGoogleLoading = false;
        _loginError = 'No pudimos abrir el acceso con Google.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AppLogo(),
                    const SizedBox(height: 32),
                    if (_confirmationEmail != null)
                      _EmailConfirmationState(
                        email: _confirmationEmail!,
                        onBack: () {
                          setState(() {
                            _confirmationEmail = null;
                            _loginError = null;
                          });
                        },
                      )
                    else ...[
                      Text(
                        _isRegistering ? 'Crea tu cuenta' : 'Bienvenido',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegistering
                            ? 'Regístrate para solicitar tu mudanza'
                            : 'Ingresa tus datos para continuar',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Quiero ingresar como',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<AccountRole>(
                        key: const Key('accountRoleSelector'),
                        segments: const [
                          ButtonSegment(
                            value: AccountRole.customer,
                            icon: Icon(Icons.person_outline),
                            label: Text('Cliente'),
                          ),
                          ButtonSegment(
                            value: AccountRole.driver,
                            icon: Icon(Icons.local_shipping_outlined),
                            label: Text('Conductor'),
                          ),
                        ],
                        selected: {_selectedRole},
                        showSelectedIcon: false,
                        onSelectionChanged: _isLoading || _isGoogleLoading
                            ? null
                            : (roles) {
                                setState(() {
                                  _selectedRole = roles.first;
                                  _loginError = null;
                                });
                              },
                      ),
                      const SizedBox(height: 24),
                      if (_isRegistering) ...[
                        TextFormField(
                          key: const Key('nameField'),
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (!_isRegistering) return null;
                            if ((value?.trim().length ?? 0) < 3) {
                              return 'Ingresa tu nombre completo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        key: const Key('emailField'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          hintText: 'nombre@correo.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Ingresa tu correo';
                          if (!RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(email)) {
                            return 'Ingresa un correo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('passwordField'),
                        controller: _passwordController,
                        obscureText: _hidePassword,
                        textInputAction: _isRegistering
                            ? TextInputAction.next
                            : TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) {
                          if (!_isRegistering) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: () {
                              setState(() => _hidePassword = !_hidePassword);
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }
                          if (value.length < 6) {
                            return 'Debe tener al menos 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      if (_isRegistering) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('confirmPasswordField'),
                          controller: _confirmPasswordController,
                          obscureText: _hidePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Confirmar contraseña',
                            prefixIcon: Icon(Icons.lock_reset_outlined),
                          ),
                          validator: (value) {
                            if (!_isRegistering) return null;
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('loginButton'),
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _isLoading
                              ? (_isRegistering
                                    ? 'Creando cuenta...'
                                    : 'Ingresando...')
                              : (_isRegistering
                                    ? 'Crear cuenta'
                                    : 'Iniciar sesión'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (Backend.isConfigured) ...[
                        const SizedBox(height: 18),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'o continúa con',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          key: const Key('googleLoginButton'),
                          onPressed: _isGoogleLoading || _isLoading
                              ? null
                              : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Text(
                            'G',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4285F4),
                            ),
                          ),
                          label: Text(
                            _isGoogleLoading
                                ? 'Abriendo Google...'
                                : 'Continuar con Google',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      if (_loginError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _loginError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextButton(
                        key: const Key('toggleRegisterButton'),
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _isRegistering = !_isRegistering;
                                  _loginError = null;
                                  _formKey.currentState?.reset();
                                });
                              },
                        child: Text(
                          _isRegistering
                              ? 'Ya tengo una cuenta'
                              : 'Crear una cuenta',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmailConfirmationState extends StatelessWidget {
  const _EmailConfirmationState({required this.email, required this.onBack});

  final String email;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          child: Container(
            width: 82,
            height: 82,
            decoration: const BoxDecoration(
              color: Color(0xFFE4F4EC),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              size: 42,
              color: Color(0xFF168A55),
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Revisa tu correo',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Enviamos un enlace de confirmación a:',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 21, color: AppColors.teal),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Abre el enlace del mensaje para activar tu cuenta. Después podrás volver a la app e iniciar sesión.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        FilledButton.icon(
          key: const Key('backToLoginAfterRegistration'),
          onPressed: onBack,
          icon: const Icon(Icons.login),
          label: const Text('Ir a iniciar sesión'),
        ),
        const SizedBox(height: 10),
        const Text(
          '¿No lo encuentras? Revisa la carpeta de correo no deseado.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33173B57),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_shipping_outlined,
            color: Colors.white,
            size: 46,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Mudanzas',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}

class InicioPage extends StatefulWidget {
  const InicioPage({
    super.key,
    required this.email,
    this.displayName,
    this.avatarUrl,
    this.role = AccountRole.customer,
  });

  final String email;
  final String? displayName;
  final String? avatarUrl;
  final AccountRole role;

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  int _selectedIndex = 0;
  StreamSubscription<String>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.registerCurrentDevice();
    _notificationSubscription = NotificationService.instance.opened.listen(
      _handleNotificationOpen,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService.instance.consumePendingType();
      if (pending != null) _handleNotificationOpen(pending);
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _handleNotificationOpen(String type) {
    if (!mounted || widget.role != AccountRole.driver) return;
    if (type == 'available_move') _openAvailableMoves();
  }

  Future<void> _logout(BuildContext context) async {
    await NotificationService.instance.unregisterCurrentDevice();
    if (Backend.isConfigured) await AuthService().signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['', 'Mis mudanzas', 'Mi cuenta'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 18), child: _BrandMark()),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _HomeDashboard(
            displayName: widget.displayName,
            role: widget.role,
            onNewMove: _openNewMove,
            onShowMoves: () => setState(() => _selectedIndex = 1),
            onShowAvailable: _openAvailableMoves,
          ),
          MisMudanzasPage(embedded: true, role: widget.role),
          _AccountPage(
            email: widget.email,
            displayName: widget.displayName,
            avatarUrl: widget.avatarUrl,
            role: widget.role,
            onLogout: () => _logout(context),
          ),
        ],
      ),
      floatingActionButton:
          _selectedIndex == 2 || widget.role == AccountRole.driver
          ? null
          : FloatingActionButton.extended(
              key: const Key('newMoveButton'),
              onPressed: _openNewMove,
              icon: const Icon(Icons.add),
              label: const Text('Nueva mudanza'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (value) {
          setState(() => _selectedIndex = value);
        },
        destinations: const [
          NavigationDestination(
            key: Key('homeMenuButton'),
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            key: Key('myMovesButton'),
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Mudanzas',
          ),
          NavigationDestination(
            key: Key('accountMenuButton'),
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }

  Future<void> _openNewMove() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const NuevaMudanzaPage()),
    );
    if (created == true && mounted) {
      setState(() => _selectedIndex = 1);
    }
  }

  void _openAvailableMoves() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ServiciosDisponiblesPage()),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mudanzas',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(11),
        ),
        child: const Icon(
          Icons.local_shipping_outlined,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard({
    required this.displayName,
    required this.role,
    required this.onNewMove,
    required this.onShowMoves,
    required this.onShowAvailable,
  });

  final String? displayName;
  final AccountRole role;
  final VoidCallback onNewMove;
  final VoidCallback onShowMoves;
  final VoidCallback onShowAvailable;

  @override
  Widget build(BuildContext context) {
    final firstName = displayName?.trim().split(' ').first;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 112),
            children: [
              Text(
                firstName == null || firstName.isEmpty
                    ? '¡Hola!'
                    : '¡Hola, $firstName!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('¿Qué necesitas hacer hoy?'),
              const SizedBox(height: 22),
              if (role == AccountRole.customer)
                _PrimaryActionCard(onTap: onNewMove)
              else
                _DriverActionCard(onTap: onShowAvailable),
              const SizedBox(height: 28),
              Text(
                'Tus servicios',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: const _IconBox(icon: Icons.inventory_2_outlined),
                  title: Text(
                    role == AccountRole.customer
                        ? 'Mis mudanzas'
                        : 'Servicios asignados',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    role == AccountRole.customer
                        ? 'Consulta solicitudes y estados'
                        : 'Revisa rutas e indicaciones del cliente',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onShowMoves,
                ),
              ),
              if (role == AccountRole.customer) ...[
                const SizedBox(height: 28),
                Text(
                  'Así de sencillo',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 14),
                const _SimpleStep(
                  number: '1',
                  title: 'Indica el recorrido',
                  subtitle: 'Elige el punto de inicio y el destino.',
                ),
                const _SimpleStep(
                  number: '2',
                  title: 'Selecciona el vehículo',
                  subtitle: 'Te mostramos opciones fáciles de comparar.',
                ),
                const _SimpleStep(
                  number: '3',
                  title: 'Confirma la solicitud',
                  subtitle: 'Revisa todo antes de enviarla.',
                  showLine: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.navy,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.route, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 22),
              const Text(
                'Solicitar una mudanza',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Elige las direcciones y el vehículo que necesitas.',
                style: TextStyle(color: Color(0xFFDDE9F0), fontSize: 16),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Comenzar',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: AppColors.navy, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverActionCard extends StatelessWidget {
  const _DriverActionCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: const Padding(
          padding: EdgeInsets.all(22),
          child: Row(
            children: [
              Icon(Icons.assignment_outlined, color: Colors.white, size: 38),
              SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ver servicios asignados',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Consulta rutas e indicaciones importantes.',
                      style: TextStyle(color: Color(0xFFDDE9F0), fontSize: 16),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: AppColors.blue),
    );
  }
}

class _SimpleStep extends StatelessWidget {
  const _SimpleStep({
    required this.number,
    required this.title,
    required this.subtitle,
    this.showLine = true,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: const Color(0xFFE4F1F3),
              child: Text(
                number,
                style: const TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (showLine)
              Container(width: 2, height: 42, color: AppColors.border),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3, bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.email,
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    required this.onLogout,
  });

  final String email;
  final String? displayName;
  final String? avatarUrl;
  final AccountRole role;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _UserAvatar(url: avatarUrl),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName ?? 'Usuario',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              role.label,
                              style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Sesión', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('logoutButton'),
                onPressed: onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFFE4F1F3),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.teal, size: 34),
    );
    return ClipOval(
      child: SizedBox(
        width: 64,
        height: 64,
        child: url == null
            ? fallback
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
