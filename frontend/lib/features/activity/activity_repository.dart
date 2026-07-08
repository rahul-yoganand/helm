import '../../core/api_client.dart';
import 'activity_model.dart';

class ActivityRepository {
  ActivityRepository(this._api);

  final ApiClient _api;

  Future<List<ActivityEvent>> fetchActivity(String projectId) async {
    final r = await _api.dio
        .get<Map<String, dynamic>>('/api/v1/projects/$projectId/activity');
    return (r.data!['events'] as List<dynamic>)
        .map((e) => ActivityEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
