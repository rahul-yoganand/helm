import '../../core/api_client.dart';
import 'board_model.dart';

/// Data access for the kanban board: board tasks + crew/worktree status in
/// one fetch so the screen renders atomically.
class BoardRepository {
  BoardRepository(this._api);

  final ApiClient _api;

  Future<BoardData> fetchBoard(String projectId) async {
    final board =
        await _api.dio.get<Map<String, dynamic>>('/api/v1/projects/$projectId/board');
    final agents =
        await _api.dio.get<Map<String, dynamic>>('/api/v1/projects/$projectId/agents');
    return BoardData(
      statuses: (board.data!['statuses'] as List<dynamic>).cast<String>(),
      tasks: (board.data!['tasks'] as List<dynamic>)
          .map((t) => TaskSummary.fromJson(t as Map<String, dynamic>))
          .toList(),
      worktrees: (agents.data!['worktrees'] as List<dynamic>)
          .map((w) => CrewWorktree.fromJson(w as Map<String, dynamic>))
          .toList(),
      ghAuthenticated: (agents.data!['gh_authenticated'] as bool?) ?? false,
    );
  }
}
