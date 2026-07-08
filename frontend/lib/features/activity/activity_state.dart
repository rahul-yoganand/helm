import 'package:equatable/equatable.dart';

import 'activity_model.dart';

sealed class ActivityState extends Equatable {
  const ActivityState();

  @override
  List<Object?> get props => [];
}

class ActivityInitial extends ActivityState {
  const ActivityInitial();
}

class ActivityLoading extends ActivityState {
  const ActivityLoading();
}

class ActivityLoaded extends ActivityState {
  const ActivityLoaded(this.events);

  final List<ActivityEvent> events;

  @override
  List<Object?> get props => [events];
}

class ActivityError extends ActivityState {
  const ActivityError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
