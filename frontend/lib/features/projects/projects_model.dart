import 'package:equatable/equatable.dart';

/// One registered target repo (from ~/.helm/projects.json via the backend),
/// with per-status task counts for the gallery card.
class Project extends Equatable {
  const Project({required this.id, required this.path, this.counts});

  final String id;
  final String path;
  final Map<String, int>? counts; // null = repo missing/uninitialized

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        path: json['path'] as String,
        counts: (json['counts'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v as int)),
      );

  @override
  List<Object?> get props => [id, path, counts];
}

class ProjectsInfo extends Equatable {
  const ProjectsInfo({required this.projects, this.active});

  final List<Project> projects;
  final String? active;

  factory ProjectsInfo.fromJson(Map<String, dynamic> json) => ProjectsInfo(
        projects: (json['projects'] as List<dynamic>)
            .map((p) => Project.fromJson(p as Map<String, dynamic>))
            .toList(),
        active: json['active'] as String?,
      );

  @override
  List<Object?> get props => [projects, active];
}
