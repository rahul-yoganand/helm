import 'package:equatable/equatable.dart';

sealed class ActivityFeedEvent extends Equatable {
  const ActivityFeedEvent();

  @override
  List<Object?> get props => [];
}

class ActivityRequested extends ActivityFeedEvent {
  const ActivityRequested();
}
