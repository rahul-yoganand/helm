import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/ws_client.dart';
import 'board_bloc.dart';
import 'board_event.dart';
import 'board_model.dart';
import 'board_repository.dart';
import 'board_state.dart';

/// The kanban board: one column per status, a crew strip on top, live
/// updates via the board WebSocket (UI dispatches events; it never calls
/// bloc methods).
class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  late final BoardBloc _bloc;
  late final BoardSocket _socket;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _bloc = BoardBloc(BoardRepository(api), widget.projectId)
      ..add(const BoardRequested());
    _socket = BoardSocket(wsBase: api.wsBase, projectId: widget.projectId)..connect();
    _sub = _socket.events.listen((_) => _bloc.add(const BoardChangedExternally()));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _socket.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Board — ${widget.projectId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          actions: [
            IconButton(
              tooltip: 'Activity feed',
              icon: const Icon(Icons.history),
              onPressed: () => context.go('/p/${widget.projectId}/activity'),
            ),
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
              onPressed: () => _bloc.add(const BoardRequested()),
            ),
          ],
        ),
        body: BlocBuilder<BoardBloc, BoardState>(
          builder: (context, state) {
            return switch (state) {
              BoardInitial() || BoardLoading() =>
                const Center(child: CircularProgressIndicator()),
              BoardError(:final message) => Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => _bloc.add(const BoardRequested()),
                      child: const Text('Retry'),
                    ),
                  ]),
                ),
              BoardLoaded(:final data) => _BoardView(
                  data: data, projectId: widget.projectId),
            };
          },
        ),
      ),
    );
  }
}

class _BoardView extends StatelessWidget {
  const _BoardView({required this.data, required this.projectId});

  final BoardData data;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!data.ghAuthenticated)
          MaterialBanner(
            content: const Text(
                'GitHub CLI not authenticated — PR automation is off; use --local approve/submit.'),
            leading: const Icon(Icons.cloud_off),
            actions: const [SizedBox.shrink()],
          ),
        if (data.worktrees.isNotEmpty) _CrewStrip(worktrees: data.worktrees),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final status in data.statuses)
                  Expanded(
                    child: _StatusColumn(
                      status: status,
                      tasks: data.tasks.where((t) => t.status == status).toList(),
                      projectId: projectId,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Who is working right now: one chip per live worktree.
class _CrewStrip extends StatelessWidget {
  const _CrewStrip({required this.worktrees});

  final List<CrewWorktree> worktrees;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final w in worktrees)
            Tooltip(
              message: w.lastCommit ?? '',
              child: Chip(
                avatar: const Icon(Icons.engineering, size: 18),
                label: Text('${w.owner ?? "?"} → ${w.taskId} (${w.status ?? "?"})'),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  const _StatusColumn({
    required this.status,
    required this.tasks,
    required this.projectId,
  });

  final String status;
  final List<TaskSummary> tasks;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.statusColor(status, scheme);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(status, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text('${tasks.length}',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final t in tasks) _TaskCard(task: t, projectId: projectId),
                if (tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('—',
                        style: TextStyle(color: scheme.outline),
                        textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.projectId});

  final TaskSummary task;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/p/$projectId/task/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(task.id, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(width: 6),
                  if (task.area.isNotEmpty)
                    _MiniChip(text: task.area, color: scheme.secondaryContainer),
                  const Spacer(),
                  if (task.status == 'backlog')
                    _MiniChip(
                      text: task.blocked ? 'BLOCKED' : 'READY',
                      color: task.blocked
                          ? scheme.errorContainer
                          : scheme.tertiaryContainer,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (task.owner != null) ...[
                const SizedBox(height: 4),
                Text('@${task.owner}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.primary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
