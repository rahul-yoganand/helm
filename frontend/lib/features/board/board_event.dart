import 'package:equatable/equatable.dart';

sealed class BoardEvent extends Equatable {
  const BoardEvent();

  @override
  List<Object?> get props => [];
}

/// Initial load or manual refresh (shows the loading spinner).
class BoardRequested extends BoardEvent {
  const BoardRequested();
}

/// A WebSocket change event arrived — silently refetch without dropping the
/// currently rendered board (no spinner flash on every agent commit).
class BoardChangedExternally extends BoardEvent {
  const BoardChangedExternally();
}
