import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import 'projects_bloc.dart';
import 'projects_event.dart';
import 'projects_model.dart';
import 'projects_repository.dart';
import 'projects_state.dart';

/// Landing page: the registered target repos with board summary counts.
/// Tapping a project activates it and opens its board.
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProjectsBloc(ProjectsRepository(context.read<ApiClient>()))
        ..add(const ProjectsRequested()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Helm — Projects')),
        body: BlocBuilder<ProjectsBloc, ProjectsState>(
          builder: (context, state) {
            return switch (state) {
              ProjectsInitial() ||
              ProjectsLoading() =>
                const Center(child: CircularProgressIndicator()),
              ProjectsError(:final message) => _ErrorView(message: message),
              ProjectsLoaded(:final info) => _ProjectList(info: info),
            };
          },
        ),
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({required this.info});

  final ProjectsInfo info;

  @override
  Widget build(BuildContext context) {
    if (info.projects.isEmpty) {
      return const Center(
        child: Text('No projects registered.\nRun `helm init <repo>` first.',
            textAlign: TextAlign.center),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        for (final p in info.projects)
          Card(
            child: ListTile(
              leading: Icon(
                p.id == info.active ? Icons.sailing : Icons.folder_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(p.id),
              subtitle: Text(p.path),
              trailing: p.counts == null
                  ? const Text('no board')
                  : Text(
                      p.counts!.entries
                          .where((e) => e.value > 0)
                          .map((e) => '${e.value} ${e.key}')
                          .join(' · '),
                    ),
              onTap: () {
                context.read<ProjectsBloc>().add(ProjectActivated(p.id));
                context.go('/p/${p.id}');
              },
            ),
          ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.read<ProjectsBloc>().add(const ProjectsRequested()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
