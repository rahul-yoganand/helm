import 'package:equatable/equatable.dart';

/// One `[board]` commit on the target repo's main checkout — the board's
/// git-native audit log.
class ActivityEvent extends Equatable {
  const ActivityEvent({required this.sha, required this.date, required this.message});

  final String sha;
  final String date;
  final String message;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        sha: (json['sha'] as String?) ?? '',
        date: (json['date'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
      );

  @override
  List<Object?> get props => [sha, date, message];
}
