import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/ws_client.dart';
import 'activity_bloc.dart';
import 'activity_event.dart';
import 'activity_repository.dart';
import 'activity_state.dart';

/// The board's audit trail: [board] commits, newest first, refreshed live
/// when the WebSocket reports a change.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.projectId});

  final String projectId;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late final ActivityBloc _bloc;
  late final BoardSocket _socket;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiClient>();
    _bloc = ActivityBloc(ActivityRepository(api), widget.projectId)
      ..add(const ActivityRequested());
    _socket = BoardSocket(wsBase: api.wsBase, projectId: widget.projectId)..connect();
    _sub = _socket.events.listen((_) => _bloc.add(const ActivityRequested()));
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
          title: Text('Activity — ${widget.projectId}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/p/${widget.projectId}'),
          ),
        ),
        body: BlocBuilder<ActivityBloc, ActivityState>(
          builder: (context, state) {
            return switch (state) {
              ActivityInitial() ||
              ActivityLoading() =>
                const Center(child: CircularProgressIndicator()),
              ActivityError(:final message) =>
                Center(child: Text(message, textAlign: TextAlign.center)),
              ActivityLoaded(:final events) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.commit, size: 18),
                      title: Text(e.message),
                      subtitle: Text('${e.sha} · ${e.date}'),
                    );
                  },
                ),
            };
          },
        ),
      ),
    );
  }
}
