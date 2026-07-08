import 'package:equatable/equatable.dart';

import 'task_detail_model.dart';

sealed class TaskDetailState extends Equatable {
  const TaskDetailState();

  @override
  List<Object?> get props => [];
}

class TaskDetailInitial extends TaskDetailState {
  const TaskDetailInitial();
}

class TaskDetailLoading extends TaskDetailState {
  const TaskDetailLoading();
}

/// Loaded task, plus action-in-flight flag and the last action's verbatim
/// script output (kept through reloads so the captain can read what happened).
class TaskDetailLoaded extends TaskDetailState {
  const TaskDetailLoaded(this.task, {this.actionRunning = false, this.lastResult});

  final TaskDetail task;
  final bool actionRunning;
  final ActionResult? lastResult;

  TaskDetailLoaded copyWith({
    TaskDetail? task,
    bool? actionRunning,
    ActionResult? lastResult,
  }) =>
      TaskDetailLoaded(
        task ?? this.task,
        actionRunning: actionRunning ?? this.actionRunning,
        lastResult: lastResult ?? this.lastResult,
      );

  @override
  List<Object?> get props => [task, actionRunning, lastResult];
}

class TaskDetailError extends TaskDetailState {
  const TaskDetailError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
