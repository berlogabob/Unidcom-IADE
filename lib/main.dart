import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/admin_page.dart';
import 'app/dashboard.dart';
import 'app/my_profile.dart';
import 'data/supabase.dart' as data;
import 'public/outputs.dart';
import 'public/output_page.dart';
import 'public/people_list.dart';
import 'public/person_page.dart';
import 'public/projects.dart';
import 'public/project_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nmghxkhstlnxypmfmfhk.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_uCvM2dlnxkS3gqCsyaANVQ_RswEP6Zm',
  );

  // ignore: deprecated_member_use
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(const UnidcomApp());
}

// ponytail: login gate OFF for today (campus wifi blocking auth). Flip to
// false to restore the login screen. Anon visitors get the public view.
const _loginDisabled = true;

final _router = GoRouter(
  initialLocation: '/people',
  refreshListenable: GoRouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  redirect: (context, state) {
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    final onLogin = state.matchedLocation == '/login';
    if (!_loginDisabled) {
      if (!hasSession) return onLogin ? null : '/login';
      if (onLogin) return '/people';
    }
    if (state.matchedLocation == '/') return '/people';
    if (state.matchedLocation == '/app/admin' && !data.isAdmin) {
      return '/people';
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    GoRoute(path: '/', redirect: (_, _) => '/people'),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/people', builder: (_, _) => const PeopleListScreen()),
        GoRoute(
          path: '/people/:id',
          builder: (_, state) =>
              PersonPageScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(path: '/projects', builder: (_, _) => const ProjectsScreen()),
        GoRoute(
          path: '/projects/:id',
          builder: (_, state) =>
              ProjectPageScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(path: '/outputs', builder: (_, _) => const OutputsScreen()),
        GoRoute(
          path: '/outputs/:id',
          builder: (_, state) =>
              OutputPageScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/app/dashboard',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(path: '/app/admin', builder: (_, _) => const AdminScreen()),
      ],
    ),
    GoRoute(path: '/app/profile', builder: (_, _) => const MyProfileScreen()),
  ],
);

class UnidcomApp extends StatelessWidget {
  const UnidcomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Unidcom IADE',
      theme: ThemeData(colorSchemeSeed: Colors.black, useMaterial3: true),
      routerConfig: _router,
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final admin = data.isAdmin;
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    final destinations = [
      _NavItem('/people', Icons.people, 'People'),
      _NavItem('/outputs', Icons.article, 'Outputs'),
      _NavItem('/projects', Icons.work, 'Projects'),
      _NavItem('/app/dashboard', Icons.dashboard, 'Dashboard'),
      if (admin)
        _NavItem('/app/admin', Icons.admin_panel_settings, 'Admin'),
    ];
    final index = destinations.indexWhere((item) => path.startsWith(item.path));
    final selectedIndex = index < 0 ? 0 : index;

    return Scaffold(
      appBar: AppBar(
        title: Text(switch (destinations[selectedIndex].path) {
          '/outputs' => 'Outputs',
          '/projects' => 'Projects',
          '/app/dashboard' => 'Dashboard',
          '/app/admin' => 'Admin',
          _ => 'People',
        }),
        actions: hasSession
            ? [
                IconButton(
                  tooltip: 'My profile',
                  icon: const Icon(Icons.account_circle),
                  onPressed: () => context.go('/app/profile'),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  icon: const Icon(Icons.logout),
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Sign in',
                  icon: const Icon(Icons.login),
                  onPressed: () => context.go('/login'),
                ),
              ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (value) => context.go(destinations[value].path),
        destinations: [
          for (final item in destinations)
            NavigationDestination(icon: Icon(item.icon), label: item.label),
        ],
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.icon, this.label);

  final String path;
  final IconData icon;
  final String label;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (mounted) context.go('/people');
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _signIn,
                  child: Text(_loading ? 'Signing in...' : 'Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
