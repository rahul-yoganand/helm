import '../../core/api_client.dart';
import 'projects_model.dart';

/// Data access for the projects list. Throws on transport errors; the Bloc
/// maps that onto an error state.
class ProjectsRepository {
  ProjectsRepository(this._api);

  final ApiClient _api;

  Future<ProjectsInfo> fetchProjects() async {
    final r = await _api.dio.get<Map<String, dynamic>>('/api/v1/projects');
    return ProjectsInfo.fromJson(r.data!);
  }

  Future<void> activate(String projectId) async {
    await _api.dio.post<Map<String, dynamic>>('/api/v1/projects/$projectId/activate');
  }
}
