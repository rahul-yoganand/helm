import 'package:flutter_bloc/flutter_bloc.dart';

import 'task_detail_event.dart';
import 'task_detail_repository.dart';
import 'task_detail_state.dart';

/// Pure event -> state. Actions run against the backend (which shells out to
/// the repo's own tasks/*.sh) and always end with a task refetch, so the
/// screen reflects the board's real post-action state, success or refusal.
class TaskDetailBloc extends Bloc<TaskDetailEvent, TaskDetailState> {
  TaskDetailBloc(this._repository, this.projectId, this.taskId)
      : super(const TaskDetailInitial()) {
    on<TaskRequested>(_onRequested);
    on<TaskActionRequested>(_onAction);
  }

  final TaskDetailRepository _repository;
  final String projectId;
  final String taskId;

  Future<void> _onRequested(TaskRequested event, Emitter<TaskDetailState> emit) async {
    final prior = state;
    // Keep the last action result visible across the refetch.
    if (prior is! TaskDetailLoaded) emit(const TaskDetailLoading());
    try {
      final task = await _repository.fetchTask(projectId, taskId);
      emit(TaskDetailLoaded(
        task,
        lastResult: prior is TaskDetailLoaded ? prior.lastResult : null,
      ));
    } catch (e) {
      emit(TaskDetailError('Could not load $taskId.\n\n$e'));
    }
  }

  Future<void> _onAction(TaskActionRequested event, Emitter<TaskDetailState> emit) async {
    final prior = state;
    if (prior is! TaskDetailLoaded || prior.actionRunning) return;
    emit(prior.copyWith(actionRunning: true));
    final result =
        await _repository.runAction(projectId, taskId, event.action, event.params);
    try {
      final task = await _repository.fetchTask(projectId, taskId);
      emit(TaskDetailLoaded(task, lastResult: result));
    } catch (_) {
      emit(prior.copyWith(actionRunning: false, lastResult: result));
    }
  }
}
