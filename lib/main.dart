import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app/admin_page.dart';
import 'app/dashboard.dart';
import 'app/my_profile.dart';
import 'data/supabase.dart' as data;
import 'public/cluster_page.dart';
import 'public/conferences.dart';
import 'public/lab_page.dart';
import 'public/objective_page.dart';
import 'public/outputs.dart';
import 'public/output_page.dart';
import 'public/people_list.dart';
import 'public/person_page.dart';
import 'public/projects.dart';
import 'public/project_page.dart';
import 'public/structure.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://nmghxkhstlnxypmfmfhk.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_uCvM2dlnxkS3gqCsyaANVQ_RswEP6Zm',
);
// ORCID client IDs are public, like the anon key above.
const _orcidClientId = String.fromEnvironment(
  'ORCID_CLIENT_ID',
  defaultValue: 'APP-L64W8QJWLPH4MUEM',
);

// Set in main() when an ORCID sign-in just completed; read once by _router.
bool _orcidSignedIn = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ponytail: Flutter web draws to a canvas, so UI tests see nothing until the
  // semantics tree exists. Build with --dart-define=E2E=true for Maestro runs;
  // off in production, where an always-on semantics tree is wasted work.
  if (const bool.fromEnvironment('E2E')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // ignore: deprecated_member_use
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);

  // Hash URL strategy => the orcid-auth broker's ?token_hash sits before the
  // '#', invisible to go_router; Uri.base is the only place it exists. Never
  // name this param `code` — supabase_flutter's URL auto-detection would try
  // a PKCE exchange on it and throw.
  final tokenHash = Uri.base.queryParameters['token_hash'];
  if (tokenHash != null) {
    try {
      await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.magiclink,
        tokenHash: tokenHash,
      );
      await data.claimPersonByOrcid();
      _orcidSignedIn = true;
    } catch (_) {
      // F5 replays the consumed one-time token; the persisted session wins.
    }
  }
  // Back from the Connect ORCID link flow: land on the (now-linked) profile.
  // The session predates the redirect, but its JWT lacks the fresh
  // app_metadata.orcid — refresh so hasLinkedOrcid reads true immediately.
  if (Uri.base.queryParameters['orcid_linked'] == '1') {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {}
    _orcidSignedIn = true;
  }

  runApp(const UnidcomApp());
}

// ponytail: login gate OFF for today (campus wifi blocking auth). Flip to
// false to restore the login screen. Anon visitors get the public view.
const _loginDisabled = true;

final _router = GoRouter(
  // Fresh ORCID sign-in lands on the (just-claimed) own profile.
  initialLocation: _orcidSignedIn ? '/app/profile' : '/people',
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
    if (state.matchedLocation == '/app/settings' && !data.isAdmin) {
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
          path: '/conferences',
          builder: (_, _) => const ConferencesScreen(),
        ),
        GoRoute(
          path: '/conferences/:key',
          builder: (_, state) =>
              ConferencePageScreen(confKey: state.pathParameters['key']!),
        ),
        GoRoute(path: '/structure', builder: (_, _) => const StructureScreen()),
        GoRoute(
          path: '/labs/:id',
          builder: (_, state) => LabPageScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/clusters/:id',
          builder: (_, state) =>
              ClusterPageScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/objectives/:id',
          builder: (_, state) =>
              ObjectivePageScreen(id: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/app/dashboard',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(path: '/app/admin', builder: (_, _) => const AdminScreen()),
        GoRoute(
          path: '/app/profile',
          builder: (_, _) => const MyProfileScreen(),
        ),
        GoRoute(
          path: '/app/home',
          builder: (_, _) => const Scaffold(
            body: Center(
              child: Text('/app/home — coming soon'),
            ),
          ),
        ),
        GoRoute(
          path: '/app/welcome/:section',
          builder: (_, state) {
            final section = state.pathParameters['section']!;
            return Scaffold(
              body: Center(
                child: Text('/app/welcome/$section — coming soon'),
              ),
            );
          },
        ),
        GoRoute(
          path: '/app/settings',
          builder: (_, _) => const Scaffold(
            body: Center(
              child: Text('/app/settings — coming soon'),
            ),
          ),
        ),
      ],
    ),
  ],
);

class UnidcomApp extends StatelessWidget {
  const UnidcomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Unidcom IADE',
      theme: unidcomTheme(),
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
  void initState() {
    super.initState();
    // Broker failures come back as ?orcid_error= before the '#' (hash routing),
    // so go_router never sees it — Uri.base does.
    final orcidError = Uri.base.queryParameters['orcid_error'];
    if (orcidError != null) _error = orcidError;
  }

  void _signInWithOrcid() {
    // state = where the broker redirects back to; must match the edge
    // function's allowlist exactly (origin + base path, trailing slash).
    final returnTo = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path}'
        : 'https://berlogabob.github.io/Unidcom-IADE/'; // mobile deep links: follow-up
    launchUrl(
      Uri.https('orcid.org', '/oauth/authorize', {
        'client_id': _orcidClientId,
        'response_type': 'code',
        'scope': 'openid',
        'redirect_uri': '$_supabaseUrl/functions/v1/orcid-auth',
        'state': returnTo,
      }),
      webOnlyWindowName: '_self', // not a popup — the session must land in this tab
    );
  }

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
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _signInWithOrcid,
                  child: const Text('Sign in with ORCID iD'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
