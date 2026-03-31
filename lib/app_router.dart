import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/screens/access/company_access_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/highlighter/document_highlighter_screen.dart';
import '../presentation/screens/highlighter/document_editor_screen.dart';
import '../presentation/screens/template/template_fill_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/access',
    routes: [
      GoRoute(path: '/access', builder: (_, __) => const CompanyAccessScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/highlight',
        builder: (_, __) => const DocumentHighlighterScreen(),
      ),
      GoRoute(
        path: '/editor',
        builder: (_, __) => const DocumentEditorScreen(),
      ),
      GoRoute(
        path: '/fill',
        builder: (_, __) => const TemplateFillScreen(),
      ),
    ],
  );
});
