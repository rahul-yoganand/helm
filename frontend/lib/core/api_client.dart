import 'package:dio/dio.dart';

/// Thin wrapper around [Dio] that centralises the backend base URL and
/// common client configuration.
///
/// Override at build time with:
///   flutter run --dart-define=HELM_API_BASE_URL=http://host:port
class ApiClient {
  ApiClient({String? baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? defaultBaseUrl,
                connectTimeout: const Duration(seconds: 5),
                // Action endpoints shell out to board scripts that may push
                // and open PRs — allow well beyond the backend's 60s cap.
                receiveTimeout: const Duration(seconds: 90),
                responseType: ResponseType.json,
              ),
            );

  static const String defaultBaseUrl = String.fromEnvironment(
    'HELM_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8642',
  );

  final Dio _dio;

  /// The underlying Dio instance, exposed for feature repositories.
  Dio get dio => _dio;

  /// ws:// equivalent of the configured base URL, for the live board socket.
  String get wsBase =>
      _dio.options.baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
}
