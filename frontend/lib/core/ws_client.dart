import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Auto-reconnecting subscription to one project's board WebSocket.
///
/// The backend pushes thin events ({"type": "board_changed" | "worktrees_changed"});
/// consumers refetch over REST when one arrives. On socket loss we retry with
/// exponential backoff (2s → 15s cap) until [dispose] — the dashboard should
/// survive backend restarts without user action.
class BoardSocket {
  BoardSocket({required String wsBase, required String projectId})
      : _url = '$wsBase/api/v1/projects/$projectId/ws';

  final String _url;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  WebSocketChannel? _channel;
  bool _disposed = false;
  int _retrySeconds = 2;

  Stream<Map<String, dynamic>> get events => _controller.stream;

  void connect() {
    if (_disposed) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_url));
      _channel!.stream.listen(
        (data) {
          _retrySeconds = 2; // healthy again — reset the backoff
          try {
            _controller.add(jsonDecode(data as String) as Map<String, dynamic>);
          } catch (_) {/* ignore malformed frames */}
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    Future.delayed(Duration(seconds: _retrySeconds), connect);
    _retrySeconds = (_retrySeconds * 2).clamp(2, 15);
  }

  void dispose() {
    _disposed = true;
    _channel?.sink.close();
    _controller.close();
  }
}
