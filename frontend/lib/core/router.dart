import 'package:go_router/go_router.dart';

import '../features/activity/activity_screen.dart';
import '../features/board/board_screen.dart';
import '../features/projects/projects_screen.dart';
import '../features/task_detail/task_detail_screen.dart';

/// Application routing table. go_router is the single source of navigation
/// truth; each feature owns its screen widget.
class AppRouter {
  const AppRouter._();

  static GoRouter create() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          name: 'projects',
          builder: (context, state) => const ProjectsScreen(),
        ),
        GoRoute(
          path: '/p/:proj',
          name: 'board',
          builder: (context, state) =>
              BoardScreen(projectId: state.pathParameters['proj']!),
        ),
        GoRoute(
          path: '/p/:proj/task/:id',
          name: 'task',
          builder: (context, state) => TaskDetailScreen(
            projectId: state.pathParameters['proj']!,
            taskId: state.pathParameters['id']!,
          ),
        ),
        GoRoute(
          path: '/p/:proj/activity',
          name: 'activity',
          builder: (context, state) =>
              ActivityScreen(projectId: state.pathParameters['proj']!),
        ),
      ],
    );
  }
}
