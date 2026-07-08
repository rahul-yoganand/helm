import 'package:equatable/equatable.dart';

sealed class TaskDetailEvent extends Equatable {
  const TaskDetailEvent();

  @override
  List<Object?> get props => [];
}

class TaskRequested extends TaskDetailEvent {
  const TaskRequested();
}

/// One of the four board actions. `params` matches the backend body
/// (claim: {agent}, approve: {local}, reject: {reason}, unclaim: {force}).
class TaskActionRequested extends TaskDetailEvent {
  const TaskActionRequested(this.action, this.params);

  final String action;
  final Map<String, dynamic> params;

  @override
  List<Object?> get props => [action, params];
}
