import 'package:flutter_bloc/flutter_bloc.dart';

import 'projects_event.dart';
import 'projects_repository.dart';
import 'projects_state.dart';

/// Pure event -> state (no Cubit). The Bloc holds no business logic: it
/// orchestrates the async calls and maps success/failure onto immutable
/// state classes.
class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  ProjectsBloc(this._repository) : super(const ProjectsInitial()) {
    on<ProjectsRequested>(_onRequested);
    on<ProjectActivated>(_onActivated);
  }

  final ProjectsRepository _repository;

  Future<void> _onRequested(ProjectsRequested event, Emitter<ProjectsState> emit) async {
    emit(const ProjectsLoading());
    try {
      emit(ProjectsLoaded(await _repository.fetchProjects()));
    } catch (e) {
      emit(ProjectsError('Could not reach the Helm backend. Is it running?\n\n$e'));
    }
  }

  Future<void> _onActivated(ProjectActivated event, Emitter<ProjectsState> emit) async {
    try {
      await _repository.activate(event.projectId);
      emit(ProjectsLoaded(await _repository.fetchProjects()));
    } catch (e) {
      emit(ProjectsError('Could not activate ${event.projectId}.\n\n$e'));
    }
  }
}
