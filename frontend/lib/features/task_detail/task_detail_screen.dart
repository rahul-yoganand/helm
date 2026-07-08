import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import 'task_detail_bloc.dart';
import 'task_detail_event.dart';
import 'task_detail_model.dart';
import 'task_detail_repository.dart';
import 'task_detail_state.dart';

/// One task: rendered markdown body, agent log, worktree/PR context, and the
/// captain's status-gated action buttons with a verbatim script-output panel.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.projectId, required this.taskId});

  final String projectId;
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskDetailBloc(
        TaskDetailRepository(context.read<ApiClient>()),
        projectId,
        taskId,
      )..add(const TaskRequested()),
      child: Scaffold(
        appBar: AppBar(
          title: Text('$taskId — $projectId'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/p/$projectId'),
          ),
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () =>
                    context.read<TaskDetailBloc>().add(const TaskRequested()),
              ),
            ),
          ],
        ),
        body: BlocBuilder<TaskDetailBloc, TaskDetailState>(
          builder: (context, state) {
            return switch (state) {
              TaskDetailInitial() ||
              TaskDetailLoading() =>
                const Center(child: CircularProgressIndicator()),
              TaskDetailError(:final message) =>
                Center(child: Text(message, textAlign: TextAlign.center)),
              TaskDetailLoaded() => _TaskView(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _TaskView extends StatelessWidget {
  const _TaskView({required this.state});

  final TaskDetailLoaded state;

  @override
  Widget build(BuildContext context) {
    final t = state.task;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: the task document.
        Expanded(
          flex: 3,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(t.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(t.status),
                    backgroundColor:
                        AppTheme.statusColor(t.status, scheme).withValues(alpha: 0.15),
                  ),
                  if (t.area.isNotEmpty) Chip(label: Text(t.area)),
                  if (t.kind.isNotEmpty) Chip(label: Text(t.kind)),
                  if (t.owner != null) Chip(label: Text('@${t.owner}')),
                  if (t.status == 'backlog')
                    Chip(
                      label: Text(t.blocked
                          ? 'BLOCKED by ${t.dependsOn.join(", ")}'
                          : 'READY'),
                      backgroundColor: t.blocked
                          ? scheme.errorContainer
                          : scheme.tertiaryContainer,
                    ),
                ],
              ),
              const Divider(height: 32),
              MarkdownBody(data: t.body, selectable: true),
              if (t.agentLog.trim().isNotEmpty) ...[
                const Divider(height: 32),
                Text('Agent log', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(t.agentLog,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        // Right: live context + actions.
        SizedBox(
          width: 320,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ContextCard(task: t),
              const SizedBox(height: 16),
              _ActionsCard(state: state),
              if (state.lastResult != null) ...[
                const SizedBox(height: 16),
                _ResultPanel(result: state.lastResult!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.task});

  final TaskDetail task;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Context', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('file: ${task.path}', style: const TextStyle(fontSize: 12)),
            if (task.worktree != null) ...[
              const SizedBox(height: 4),
              Text('branch: ${task.worktree!.branch}',
                  style: const TextStyle(fontSize: 12)),
              if (task.worktree!.lastCommit != null)
                Text('last: ${task.worktree!.lastCommit}',
                    style: const TextStyle(fontSize: 12)),
            ],
            if (task.pr != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('PR (${task.pr!.state})'),
                onPressed: () => launchUrlString(task.pr!.url),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The captain's controls, enabled strictly by board status — mirroring what
/// the underlying scripts would accept.
class _ActionsCard extends StatelessWidget {
  const _ActionsCard({required this.state});

  final TaskDetailLoaded state;

  @override
  Widget build(BuildContext context) {
    final t = state.task;
    final bloc = context.read<TaskDetailBloc>();
    final busy = state.actionRunning;
    final buttons = <Widget>[
      if (t.status == 'backlog' && !t.blocked)
        FilledButton.icon(
          icon: const Icon(Icons.assignment_ind),
          label: const Text('Claim…'),
          onPressed: busy ? null : () => _claimDialog(context, bloc),
        ),
      if (t.status == 'in-review') ...[
        FilledButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Approve…'),
          onPressed: busy ? null : () => _approveDialog(context, bloc),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.undo),
          label: const Text('Request changes…'),
          onPressed: busy ? null : () => _rejectDialog(context, bloc),
        ),
      ],
      if (const ['in-progress', 'in-review', 'changes-requested']
          .contains(t.status))
        TextButton.icon(
          icon: const Icon(Icons.person_off),
          label: const Text('Unclaim…'),
          onPressed: busy ? null : () => _unclaimDialog(context, bloc),
        ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Actions', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (busy)
                  const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            if (buttons.isEmpty)
              Text('No actions for status "${t.status}".',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              ...[for (final b in buttons) Padding(
                padding: const EdgeInsets.only(bottom: 8), child: b)],
          ],
        ),
      ),
    );
  }

  Future<void> _claimDialog(BuildContext context, TaskDetailBloc bloc) async {
    final controller = TextEditingController(text: 'captain');
    final agent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim task'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'Agent id (who is claiming?)',
              helperText: 'e.g. python-dev, voice-dev, db-dev, captain'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Claim')),
        ],
      ),
    );
    if (agent != null && agent.isNotEmpty) {
      bloc.add(TaskActionRequested('claim', {'agent': agent}));
    }
  }

  Future<void> _approveDialog(BuildContext context, TaskDetailBloc bloc) async {
    var local = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Approve task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('GitHub mode requires the PR to already be approved & '
                  'merged on GitHub. Local mode merges the task branch here.'),
              CheckboxListTile(
                value: local,
                onChanged: (v) => setState(() => local = v ?? false),
                title: const Text('Local merge (--local)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Approve')),
          ],
        ),
      ),
    );
    if (ok == true) {
      bloc.add(TaskActionRequested('approve', {'local': local}));
    }
  }

  Future<void> _rejectDialog(BuildContext context, TaskDetailBloc bloc) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request changes'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'What should be fixed?'),
          autofocus: true,
          maxLines: 3,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Request changes')),
        ],
      ),
    );
    if (reason != null && reason.isNotEmpty) {
      bloc.add(TaskActionRequested('reject', {'reason': reason}));
    }
  }

  Future<void> _unclaimDialog(BuildContext context, TaskDetailBloc bloc) async {
    var force = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Unclaim task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Returns the task to backlog and removes its worktree '
                  'and branch. Refused if the branch has commits, unless forced '
                  '(commits are LOST).'),
              CheckboxListTile(
                value: force,
                onChanged: (v) => setState(() => force = v ?? false),
                title: const Text('Force (discard commits)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Unclaim')),
          ],
        ),
      ),
    );
    if (ok == true) {
      bloc.add(TaskActionRequested('unclaim', {'force': force}));
    }
  }
}

/// Verbatim stdout/stderr of the last script run — failures read exactly like
/// a terminal, because they ARE the script's own words.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result});

  final ActionResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = [
      if (result.stdout.trim().isNotEmpty) result.stdout.trim(),
      if (result.stderr.trim().isNotEmpty) result.stderr.trim(),
    ].join('\n');
    return Card(
      color: result.ok ? null : scheme.errorContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(result.ok ? Icons.check_circle : Icons.error,
                    size: 18,
                    color: result.ok ? Colors.green : scheme.error),
                const SizedBox(width: 6),
                Text('${result.action} — exit ${result.exitCode}',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(text.isEmpty ? '(no output)' : text,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
