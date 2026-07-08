import 'package:equatable/equatable.dart';

/// One task card on the kanban board (frontmatter summary; body stays on the
/// detail endpoint).
class TaskSummary extends Equatable {
  const TaskSummary({
    required this.id,
    required this.title,
    required this.area,
    required this.kind,
    required this.status,
    required this.blocked,
    this.owner,
    this.phaseDir,
    this.dependsOn = const [],
  });

  final String id;
  final String title;
  final String area;
  final String kind;
  final String status;
  final bool blocked;
  final String? owner;
  final String? phaseDir;
  final List<String> dependsOn;

  factory TaskSummary.fromJson(Map<String, dynamic> json) => TaskSummary(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        area: (json['area'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'backlog',
        blocked: (json['blocked'] as bool?) ?? false,
        owner: _blankToNull(json['owner'] as String?),
        phaseDir: json['phase_dir'] as String?,
        dependsOn: ((json['depends_on'] as List<dynamic>?) ?? [])
            .map((d) => d.toString())
            .toList(),
      );

  static String? _blankToNull(String? s) => (s == null || s.isEmpty) ? null : s;

  @override
  List<Object?> get props => [id, title, area, kind, status, blocked, owner];
}

/// A live task worktree = a crew member's active claim.
class CrewWorktree extends Equatable {
  const CrewWorktree({
    required this.taskId,
    required this.branch,
    this.owner,
    this.status,
    this.title,
    this.lastCommit,
  });

  final String taskId;
  final String branch;
  final String? owner;
  final String? status;
  final String? title;
  final String? lastCommit;

  factory CrewWorktree.fromJson(Map<String, dynamic> json) => CrewWorktree(
        taskId: json['task_id'] as String,
        branch: (json['branch'] as String?) ?? '',
        owner: json['owner'] as String?,
        status: json['status'] as String?,
        title: json['title'] as String?,
        lastCommit: json['last_commit'] as String?,
      );

  @override
  List<Object?> get props => [taskId, branch, owner, status, lastCommit];
}

class BoardData extends Equatable {
  const BoardData({
    required this.statuses,
    required this.tasks,
    required this.worktrees,
    required this.ghAuthenticated,
  });

  final List<String> statuses;
  final List<TaskSummary> tasks;
  final List<CrewWorktree> worktrees;
  final bool ghAuthenticated;

  @override
  List<Object?> get props => [statuses, tasks, worktrees, ghAuthenticated];
}
