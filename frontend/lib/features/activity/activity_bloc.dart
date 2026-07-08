import 'package:flutter_bloc/flutter_bloc.dart';

import 'activity_event.dart';
import 'activity_repository.dart';
import 'activity_state.dart';

class ActivityBloc extends Bloc<ActivityFeedEvent, ActivityState> {
  ActivityBloc(this._repository, this.projectId) : super(const ActivityInitial()) {
    on<ActivityRequested>(_onRequested);
  }

  final ActivityRepository _repository;
  final String projectId;

  Future<void> _onRequested(
      ActivityRequested event, Emitter<ActivityState> emit) async {
    emit(const ActivityLoading());
    try {
      emit(ActivityLoaded(await _repository.fetchActivity(projectId)));
    } catch (e) {
      emit(ActivityError('Could not load activity.\n\n$e'));
    }
  }
}
