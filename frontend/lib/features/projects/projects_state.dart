import 'package:equatable/equatable.dart';

import 'projects_model.dart';

sealed class ProjectsState extends Equatable {
  const ProjectsState();

  @override
  List<Object?> get props => [];
}

class ProjectsInitial extends ProjectsState {
  const ProjectsInitial();
}

class ProjectsLoading extends ProjectsState {
  const ProjectsLoading();
}

class ProjectsLoaded extends ProjectsState {
  const ProjectsLoaded(this.info);

  final ProjectsInfo info;

  @override
  List<Object?> get props => [info];
}

class ProjectsError extends ProjectsState {
  const ProjectsError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
