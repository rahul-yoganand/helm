import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import 'task_detail_model.dart';

/// Data access for one task + the four captain/crew actions. Action failures
/// (HTTP 409 carrying the script's own words) are surfaced as [ActionResult]
/// rather than thrown, so the screen can show stdout/stderr verbatim.
class TaskDetailRepository {
  TaskDetailRepository(this._api);

  final ApiClient _api;

  Future<TaskDetail> fetchTask(String projectId, String taskId) async {
    final r = await _api.dio
        .get<Map<String, dynamic>>('/api/v1/projects/$projectId/tasks/$taskId');
    return TaskDetail.fromJson(r.data!);
  }

  Future<ActionResult> runAction(
    String projectId,
    String taskId,
    String action,
    Map<String, dynamic> body,
  ) async {
    try {
      final r = await _api.dio.post<Map<String, dynamic>>(
        '/api/v1/projects/$projectId/tasks/$taskId/$action',
        data: body,
      );
      return ActionResult.fromJson(action, r.data!);
    } on DioException catch (e) {
      // 409 = the script refused (CANNOT CLAIM, wrong status, unmerged PR…).
      // Its stdout/stderr live in the error detail — relay them verbatim.
      final detail = (e.response?.data as Map<String, dynamic>?)?['detail'];
      if (detail is Map<String, dynamic>) {
        return ActionResult.fromJson(action, detail);
      }
      if (detail is String) {
        return ActionResult(
            ok: false, exitCode: -1, stdout: '', stderr: detail, action: action);
      }
      rethrow;
    }
  }
}
