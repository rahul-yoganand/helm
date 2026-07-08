import 'package:equatable/equatable.dart';

class TaskWorktree extends Equatable {
  const TaskWorktree({required this.path, required this.branch, this.lastCommit});

  final String path;
  final String branch;
  final String? lastCommit;

  factory TaskWorktree.fromJson(Map<String, dynamic> json) => TaskWorktree(
        path: (json['path'] as String?) ?? '',
        branch: (json['branch'] as String?) ?? '',
        lastCommit: json['last_commit'] as String?,
      );

  @override
  List<Object?> get props => [path, branch, lastCommit];
}

class PrInfo extends Equatable {
  const PrInfo({required this.state, required this.url, this.title});

  final String state;
  final String url;
  final String? title;

  factory PrInfo.fromJson(Map<String, dynamic> json) => PrInfo(
        state: (json['state'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        title: json['title'] as String?,
      );

  @override
  List<Object?> get props => [state, url, title];
}

/// Full task: frontmatter + markdown body + agent log + live git/PR context.
class TaskDetail extends Equatable {
  const TaskDetail({
    required this.id,
    required this.title,
    required this.status,
    required this.area,
    required this.kind,
    required this.blocked,
    required this.body,
    required this.agentLog,
    required this.path,
    this.owner,
    this.dependsOn = const [],
    this.worktree,
    this.pr,
  });

  final String id;
  final String title;
  final String status;
  final String area;
  final String kind;
  final bool blocked;
  final String body;
  final String agentLog;
  final String path;
  final String? owner;
  final List<String> dependsOn;
  final TaskWorktree? worktree;
  final PrInfo? pr;

  factory TaskDetail.fromJson(Map<String, dynamic> json) => TaskDetail(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'backlog',
        area: (json['area'] as String?) ?? '',
        kind: (json['kind'] as String?) ?? '',
        blocked: (json['blocked'] as bool?) ?? false,
        body: (json['body'] as String?) ?? '',
        agentLog: (json['agent_log'] as String?) ?? '',
        path: (json['path'] as String?) ?? '',
        owner: ((json['owner'] as String?) ?? '').isEmpty ? null : json['owner'] as String,
        dependsOn: ((json['depends_on'] as List<dynamic>?) ?? [])
            .map((d) => d.toString())
            .toList(),
        worktree: json['worktree'] == null
            ? null
            : TaskWorktree.fromJson(json['worktree'] as Map<String, dynamic>),
        pr: json['pr'] == null
            ? null
            : PrInfo.fromJson(json['pr'] as Map<String, dynamic>),
      );

  @override
  List<Object?> get props => [id, status, owner, blocked, body, agentLog, worktree, pr];
}

/// Verbatim result of a board script run — the GUI is a skin over the
/// scripts, so failures must read exactly like they would in a terminal.
class ActionResult extends Equatable {
  const ActionResult({
    required this.ok,
    required this.exitCode,
    required this.stdout,
    required this.stderr,
    required this.action,
  });

  final bool ok;
  final int exitCode;
  final String stdout;
  final String stderr;
  final String action;

  factory ActionResult.fromJson(String action, Map<String, dynamic> json) => ActionResult(
        ok: (json['ok'] as bool?) ?? false,
        exitCode: (json['exit_code'] as int?) ?? -1,
        stdout: (json['stdout'] as String?) ?? '',
        stderr: (json['stderr'] as String?) ?? '',
        action: action,
      );

  @override
  List<Object?> get props => [ok, exitCode, stdout, stderr, action];
}
