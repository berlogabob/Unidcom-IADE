import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app/add_output_page.dart';
import 'app/admin_page.dart';
import 'app/admin_requests.dart';
import 'app/dashboard.dart';
import 'app/mode_chooser.dart';
import 'app/my_profile.dart';
import 'app/portal_pages.dart';
import 'app/request_form.dart';
import 'app/researcher_home.dart';
import 'app/requests_page.dart';
import 'app/settings_page.dart';
import 'app/welcome_pack.dart';
import 'data/failure.dart';
import 'data/features.dart';
import 'data/supabase.dart' as data;
import 'data/timeout_client.dart';
import 'orcid_nonce.dart';
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
import 'theme/tokens.dart';
import 'widgets/app_shell.dart';
import 'widgets/nav_model.dart';
import 'widgets/portal_shell.dart';

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

// Set in main() when an ORCID return trip wants a landing other than the
// default; read once by _router. Null means "land on the Welcome pack".
String? _postAuthLanding;

// Set in main() when the ORCID broker redirected back with a failure; routes
// the app to /login and is consumed by LoginScreen so it shows exactly once.
String? _orcidError;

Future<void> main() async {
  // Nothing reported errors anywhere in this system: if the portal broke, the
  // detection mechanism was a researcher emailing someone. These two hooks plus
  // runZonedGuarded below are the whole net — see lib/data/failure.dart for the
  // single seam a hosted reporter would plug into.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    reportError(details.exception, details.stack, context: 'flutter');
  };
  runZonedGuarded(_boot, (error, stack) {
    reportError(error, stack, context: 'uncaught');
  });
}

Future<void> _boot() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ponytail: Flutter web draws to a canvas, so UI tests see nothing until the
  // semantics tree exists. Build with --dart-define=E2E=true for Maestro runs;
  // off in production, where an always-on semantics tree is wasted work.
  if (const bool.fromEnvironment('E2E')) {
    SemanticsBinding.instance.ensureSemantics();
  }

  // A bad key or a network failure at boot used to throw before runApp, so the
  // researcher got a permanently blank white page with no message at all.
  try {
    await Supabase.initialize(
      url: _supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: _supabaseAnonKey,
      httpClient: TimeoutClient(),
    );
  } catch (error, stack) {
    reportError(error, stack, context: 'Supabase.initialize');
    // Not the normal app: the router reads Supabase.instance on every redirect,
    // so without a client there is nothing to route.
    runApp(_StartupFailureApp(message: DataFailure.from(error).message));
    return;
  }

  // Hash URL strategy => the orcid-auth broker's ?token_hash sits before the
  // '#', invisible to go_router; Uri.base is the only place it exists. Never
  // name this param `code` — supabase_flutter's URL auto-detection would try
  // a PKCE exchange on it and throw.
  final tokenHash = Uri.base.queryParameters['token_hash'];
  if (tokenHash != null) {
    // Login-CSRF guard. `state` used to be a bare return URL, so an attacker
    // could finish their OWN ORCID authorization, capture the code, and hand a
    // victim a link that silently signed the victim's browser in *as the
    // attacker* — after which the victim's profile edits, publications and
    // support requests all went into the attacker's account.
    //
    // The broker now echoes back the nonce we put in `state`. Only the browser
    // that started the flow knows it, so a callback we did not initiate is
    // refused here. This check is the one that matters: the broker cannot make
    // it, having no session of its own.
    final expected = takeOrcidNonce();
    final returned = Uri.base.queryParameters['orcid_nonce'];
    if (expected != null && expected.isNotEmpty && expected != returned) {
      _orcidError =
          'That sign-in link did not come from this browser, so it was '
          'ignored. Start again from the Sign in page.';
    } else {
      try {
        await Supabase.instance.client.auth.verifyOTP(
          type: OtpType.magiclink,
          tokenHash: tokenHash,
        );
        await data.claimPersonByOrcid();
      } catch (_) {
        // F5 replays the consumed one-time token; the persisted session wins.
      }
    }
  }
  // Back from the Connect ORCID link flow: land on the (now-linked) profile.
  // The session predates the redirect, but its JWT lacks the fresh
  // app_metadata.orcid — refresh so hasLinkedOrcid reads true immediately.
  if (Uri.base.queryParameters['orcid_linked'] == '1') {
    try {
      await Supabase.instance.client.auth.refreshSession();
    } catch (_) {}
    // Only claim the profile landing if a session really survived: /app/profile
    // is auth-gated, so flagging it after a failed refresh would bounce the
    // user to /login with no explanation. Sign-in lands on the Welcome pack,
    // but this is the *link* flow — the user pressed Connect ORCID on their
    // own profile and has to come back to it.
    if (Supabase.instance.client.auth.currentSession != null) {
      _postAuthLanding = '/app/profile';
      // Pressing Connect ORCID on your own profile *is* the answer to the
      // chooser: you were acting as a researcher. Skip the question, or an
      // admin gets interrogated on the way back from ORCID and loses the
      // profile landing this whole branch exists to preserve.
      data.chooseMode(data.ViewMode.researcher);
    }
  }

  // Broker failures come back as ?orcid_error= before the '#', so go_router
  // never sees them. Read it here, not in LoginScreen.initState: the param
  // sits outside the fragment, so a return trip that lands anywhere but
  // /login would drop the message silently — the failure most of the pilot
  // cohort will hit, since a researcher whose iD isn't on file yet gets
  // exactly this redirect.
  // ??=, not =: the nonce mismatch above already set a reason, and it must not
  // be overwritten by the (absent) broker error.
  _orcidError ??= Uri.base.queryParameters['orcid_error'];

  runApp(const UnidcomApp());
}

// The Hugo site (berlogabob.github.io/unidcom-site) is the public face now;
// this app is the portal. Login and the Welcome pack are its only anonymous
// surfaces — the pack is pre-login onboarding info, and a researcher reaches
// it from the public site before they have an account. Everything else,
// directory included, is the live internal view and needs a session.
bool needsAuth(String location) =>
    location != '/login' && !location.startsWith('/app/welcome');

String? anonymousRedirect(String location) {
  if (!v2 &&
      location.startsWith('/app/welcome/') &&
      welcomeSlugsM2.contains(location.substring('/app/welcome/'.length))) {
    return '/app/welcome/start';
  }
  return needsAuth(location) ? '/login' : null;
}

Widget parameterizedRouteWidget(String path, String value) => switch (path) {
  '/people/:id' => PersonPageScreen(key: ValueKey(value), id: value),
  '/outputs/:id' => OutputPageScreen(key: ValueKey(value), id: value),
  '/projects/:id' => ProjectPageScreen(key: ValueKey(value), id: value),
  '/labs/:id' => LabPageScreen(key: ValueKey(value), id: value),
  '/clusters/:id' => ClusterPageScreen(key: ValueKey(value), id: value),
  '/objectives/:id' => ObjectivePageScreen(key: ValueKey(value), id: value),
  '/conferences/:key' => ConferencePageScreen(
    key: ValueKey(value),
    confKey: value,
  ),
  '/app/requests/:id' => PortalShell(
    key: ValueKey(value),
    child: RequestFormPage(key: ValueKey(value), requestId: value),
  ),
  '/app/admin/:tool' => AdminScreen(key: ValueKey(value), tool: value),
  '/app/welcome/:section' => PortalShell(
    key: ValueKey(value),
    child: WelcomePackPage(key: ValueKey(value), section: value),
  ),
  _ => throw ArgumentError.value(path, 'path'),
};

/// Everything the centre-wide view owns: the directory, the admin screens and
/// the dashboards. Researcher mode has no way to reach any of it, because a
/// researcher was promised "only things connected to him, no extra".
///
/// A prefix list rather than a chain of ifs so that adding an admin screen
/// later is a one-line edit here, not a fourth branch in the redirect.
const _adminOnly = [
  '/people',
  '/projects',
  '/outputs',
  '/structure',
  '/conferences',
  '/labs',
  '/clusters',
  '/objectives',
  '/app/dashboard',
  '/app/admin',
  '/app/settings',
];

/// Where a signed-in caller should be sent, or null to let them through.
///
/// Pure, so it can be tested without a session — the same reason [needsAuth]
/// is a bare function. It is *ergonomics only*: a researcher who types /people
/// is already stopped by RLS and by the anon grant revocation, and this must
/// never become the thing that protects a row. See ARCHITECTURE.md.
String? modeRedirect(
  String location, {
  required bool adminAccount,
  required bool adminMode,
  required bool chosen,
}) {
  // Ask the question before honouring any deep link, otherwise an admin's
  // bookmark silently decides the mode for them.
  if (adminAccount && !chosen) {
    return location == '/app/mode' ? null : '/app/mode';
  }
  // Answered, or never asked: the chooser has nothing left to say.
  if (location == '/app/mode') {
    return adminMode ? '/app/dashboard' : '/app/welcome/start';
  }
  if (!adminMode && _adminOnly.any(location.startsWith)) {
    return '/app/home';
  }
  // Support requests are v2. Hidden links are not enough — a bookmark from the
  // demo build would otherwise open a page v1 pretends does not exist.
  if (!v2 && location.startsWith('/app/requests')) {
    return '/app/home';
  }
  // M2 welcome sections: a bookmark must not open a page v1 pretends does not exist.
  final slug = location.startsWith('/app/welcome/')
      ? location.substring('/app/welcome/'.length)
      : null;
  if (!v2 && slug != null && welcomeSlugsM2.contains(slug)) {
    return '/app/welcome/start';
  }
  return null;
}

final _router = GoRouter(
  // Every login lands on the Welcome pack; a broker failure lands on /login,
  // the only screen that can show the reason. _postAuthLanding overrides the
  // default for the Connect-ORCID return trip. Admins are bounced on to the
  // mode chooser by the redirect below rather than being named here — one
  // place decides that, and it has to be the one that also sees deep links.
  initialLocation: _orcidError != null
      ? '/login'
      : _postAuthLanding ?? '/app/welcome/start',
  // Two things now change what a route resolves to: signing in or out, and
  // switching mode. Merge them, or a mode switch leaves the old shell on screen
  // until the next navigation.
  refreshListenable: Listenable.merge([
    GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),
    data.viewMode,
  ]),
  errorBuilder: (context, state) {
    if (state.error != null) {
      reportError(state.error!, null, context: 'go_router');
    }
    // Not inside AppShell: errorBuilder runs outside the ShellRoute, so there
    // is no GoRouterState for the shell to read — it threw and left a blank
    // page (seen in the 2026-09-09 re-audit, r_unknown_route).
    return const Scaffold(body: NotFoundPage());
  },
  redirect: (context, state) {
    final hasSession = Supabase.instance.client.auth.currentSession != null;
    final onLogin = state.matchedLocation == '/login';
    // Anonymous callers are on the Welcome pack and have no mode to pick.
    if (!hasSession) return anonymousRedirect(state.matchedLocation);
    if (onLogin) {
      return data.isAdminAccount && !data.modeChosen
          ? '/app/mode'
          : '/app/welcome/start';
    }
    return modeRedirect(
      state.matchedLocation,
      adminAccount: data.isAdminAccount,
      adminMode: data.isAdmin,
      chosen: data.modeChosen,
    );
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
          builder: (_, state) => parameterizedRouteWidget(
            '/people/:id',
            state.pathParameters['id']!,
          ),
        ),
        GoRoute(path: '/projects', builder: (_, _) => const ProjectsScreen()),
        GoRoute(
          path: '/projects/:id',
          builder: (_, state) => parameterizedRouteWidget(
            '/projects/:id',
            state.pathParameters['id']!,
          ),
        ),
        GoRoute(path: '/outputs', builder: (_, _) => const OutputsScreen()),
        GoRoute(
          path: '/outputs/:id',
          builder: (_, state) => parameterizedRouteWidget(
            '/outputs/:id',
            state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/conferences',
          builder: (_, _) => const ConferencesScreen(),
        ),
        GoRoute(
          path: '/conferences/:key',
          builder: (_, state) => parameterizedRouteWidget(
            '/conferences/:key',
            state.pathParameters['key']!,
          ),
        ),
        GoRoute(path: '/structure', builder: (_, _) => const StructureScreen()),
        GoRoute(
          path: '/labs/:id',
          builder: (_, state) => parameterizedRouteWidget(
            '/labs/:id',
            state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/clusters/:id',
          builder: (_, state) => parameterizedRouteWidget(
            '/clusters/:id',
            state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/objectives/:id',
          builder: (_, state) => parameterizedRouteWidget(
            '/objectives/:id',
            state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/app/mode',
          builder: (_, _) => const ModeChooserScreen(),
        ),
        GoRoute(
          path: '/app/dashboard',
          builder: (_, _) => const DashboardScreen(),
        ),
        GoRoute(path: '/app/admin', redirect: (_, _) => '/app/admin/review'),
        GoRoute(
          path: '/app/admin/requests',
          builder: (_, _) => const AdminRequestsPage(),
        ),
        // The four admin tools are sidebar items, not tabs: each one is a URL.
        GoRoute(
          path: '/app/admin/:tool',
          redirect: (_, state) =>
              adminTools.contains(state.pathParameters['tool'])
              ? null
              : '/app/admin/review',
          builder: (_, state) => parameterizedRouteWidget(
            '/app/admin/:tool',
            state.pathParameters['tool']!,
          ),
        ),
        GoRoute(
          path: '/app/profile',
          builder: (_, _) => const PortalShell(child: MyProfileScreen()),
        ),
        GoRoute(
          path: '/app/profile/identifiers',
          builder: (_, _) => const PortalShell(
            child: MyProfileScreen(section: MySection.identifiers),
          ),
        ),
        GoRoute(
          path: '/app/profile/bio',
          builder: (_, _) => const PortalShell(
            child: MyProfileScreen(section: MySection.biography),
          ),
        ),
        GoRoute(
          path: '/app/profile/areas',
          builder: (_, _) =>
              const PortalShell(child: WipPage(title: 'Research Areas')),
        ),
        GoRoute(
          path: '/app/profile/interests',
          builder: (_, _) =>
              const PortalShell(child: WipPage(title: 'Research Interests')),
        ),
        GoRoute(
          path: '/app/profile/status',
          builder: (_, _) => const PortalShell(child: ProfileStatusPage()),
        ),
        GoRoute(
          path: '/app/outputs',
          builder: (_, _) => const PortalShell(
            child: MyProfileScreen(section: MySection.outputs),
          ),
        ),
        GoRoute(
          path: '/app/outputs/add',
          builder: (_, _) => const PortalShell(child: AddOutputPage()),
        ),
        GoRoute(
          path: '/app/outputs/edit',
          builder: (_, _) => const PortalShell(
            child: WipPage(
              title: 'Edit Scientific Outputs',
              note: 'Open an output from My Outputs to edit it',
            ),
          ),
        ),
        GoRoute(
          path: '/app/outputs/import',
          builder: (_, _) => const PortalShell(
            child: MyProfileScreen(section: MySection.importSync),
          ),
        ),
        GoRoute(
          path: '/app/outputs/validation',
          builder: (_, _) => const PortalShell(
            child: WipPage(title: 'Validation & Duplicates'),
          ),
        ),
        GoRoute(
          path: '/app/requests',
          builder: (_, _) => const PortalShell(child: RequestsPage()),
        ),
        GoRoute(
          path: '/app/requests/new',
          builder: (_, _) => const PortalShell(child: RequestFormPage()),
        ),
        GoRoute(
          path: '/app/requests/:id',
          builder: (_, state) => parameterizedRouteWidget(
            '/app/requests/:id',
            state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/app/home',
          builder: (_, _) => const PortalShell(child: ResearcherHomePage()),
        ),
        // One route per Overview/Help leaf in the researcher-portal IA — each
        // re-fetches on its own rather than being handed a slice of the
        // dashboard's already-loaded data.
        GoRoute(
          path: '/app/home/summary',
          builder: (_, _) => const PortalShell(child: OverviewSummaryPage()),
        ),
        GoRoute(
          path: '/app/home/recent',
          builder: (_, _) => const PortalShell(child: OverviewRecentPage()),
        ),
        GoRoute(
          path: '/app/home/alerts',
          builder: (_, _) => const PortalShell(child: OverviewAlertsPage()),
        ),
        GoRoute(
          path: '/app/home/status',
          builder: (_, _) => const PortalShell(child: ProfileStatusPage()),
        ),
        GoRoute(
          path: '/app/help/links',
          builder: (_, _) => const PortalShell(child: QuickLinksPage()),
        ),
        GoRoute(
          path: '/app/help/docs',
          builder: (_, _) =>
              const PortalShell(child: WipPage(title: 'Documentation')),
        ),
        GoRoute(
          path: '/app/help/faq',
          builder: (_, _) => const PortalShell(child: WipPage(title: 'FAQs')),
        ),
        // needsAuth treats bare /app/welcome as public, and the Hugo footer
        // could plausibly link it — without this it is the one "public" path
        // that 404s instead of resolving.
        GoRoute(path: '/app/welcome', redirect: (_, _) => '/app/welcome/start'),
        GoRoute(
          path: '/app/welcome/:section',
          builder: (_, state) => parameterizedRouteWidget(
            '/app/welcome/:section',
            state.pathParameters['section'] ?? 'start',
          ),
        ),
        GoRoute(path: '/app/settings', builder: (_, _) => const SettingsPage()),
      ],
    ),
  ],
);

/// Shown when the app cannot start at all. Deliberately depends on nothing —
/// no router, no Supabase, no theme lookup that could itself fail.
class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UNIDCOM',
      home: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'UNIDCOM could not start',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    container: true,
                    liveRegion: true,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reload the page. If it keeps happening, contact '
                    'unidcom@iade.pt.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    // Read once and consume: the query param outlives the navigation (go_router
    // only rewrites the fragment), so re-reading it would show a stale broker
    // error every time the user came back to this screen.
    if (_orcidError != null) {
      _error = _orcidError;
      _orcidError = null;
    }
  }

  void _signInWithOrcid() {
    // state = where the broker redirects back to; must match the edge
    // function's allowlist exactly (origin + base path, trailing slash).
    final returnTo = kIsWeb
        ? '${Uri.base.origin}${Uri.base.path}'
        : 'https://berlogabob.github.io/Unidcom-IADE/'; // mobile deep links: follow-up
    // signin|<nonce>|<returnTo> — the broker echoes the nonce back so main()
    // can prove the callback belongs to this browser. See the guard there.
    final nonce = issueOrcidNonce();
    final state = nonce.isEmpty ? returnTo : 'signin|$nonce|$returnTo';
    launchUrl(
      Uri.https('orcid.org', '/oauth/authorize', {
        'client_id': _orcidClientId,
        'response_type': 'code',
        'scope': 'openid',
        'redirect_uri': '$_supabaseUrl/functions/v1/orcid-auth',
        'state': state,
      }),
      webOnlyWindowName:
          '_self', // not a popup — the session must land in this tab
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
      // No navigation here on purpose: the session change wakes the router's
      // refreshListenable and its redirect sends us on. Navigating here too
      // would make the landing screen a thing decided in two places, and the
      // ORCID path already relies on the redirect alone.
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
            child: Card(
              color: AppColors.cardBg,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: AppColors.cardBorder),
                borderRadius: BorderRadius.circular(AppDims.radius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'UNIDCOM',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Research Information Management',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                      // liveRegion so assistive tech announces the failure when
                      // it appears; container:true because a bare Text here
                      // never reached Flutter web's semantics tree at all —
                      // screen readers and E2E alike were blind to it.
                      Semantics(
                        container: true,
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
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
        ),
      ),
    );
  }
}
