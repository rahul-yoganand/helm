import 'package:equatable/equatable.dart';

sealed class ProjectsEvent extends Equatable {
  const ProjectsEvent();

  @override
  List<Object?> get props => [];
}

class ProjectsRequested extends ProjectsEvent {
  const ProjectsRequested();
}

/// User tapped a project card — mark it active on the backend, then reload.
class ProjectActivated extends ProjectsEvent {
  const ProjectActivated(this.projectId);

  final String projectId;

  @override
  List<Object?> get props => [projectId];
}
