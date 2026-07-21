import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/dashboard.dart';
import 'app/my_profile.dart';
import 'app/reports.dart';
import 'app/review_queue.dart';
import 'public/outputs.dart';
import 'public/people_list.dart';
import 'public/person_page.dart';
import 'public/projects.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // ignore: deprecated_member_use
  await Supabase.initialize(url: url, anonKey: anonKey);

  runApp(const UnidcomApp());
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const PeopleListScreen()),
    GoRoute(path: '/people/:id', builder: (_, _) => const PersonPageScreen()),
    GoRoute(path: '/projects', builder: (_, _) => const ProjectsScreen()),
    GoRoute(path: '/outputs', builder: (_, _) => const OutputsScreen()),
    GoRoute(path: '/app/profile', builder: (_, _) => const MyProfileScreen()),
    GoRoute(path: '/app/review', builder: (_, _) => const ReviewQueueScreen()),
    GoRoute(path: '/app/dashboard', builder: (_, _) => const DashboardScreen()),
    GoRoute(path: '/app/reports', builder: (_, _) => const ReportsScreen()),
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
