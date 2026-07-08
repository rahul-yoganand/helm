import 'package:flutter_bloc/flutter_bloc.dart';

import 'board_event.dart';
import 'board_repository.dart';
import 'board_state.dart';

/// Pure event -> state. [BoardRequested] shows a spinner; the WS-driven
/// [BoardChangedExternally] refetches silently so live updates don't flash
/// the whole board.
class BoardBloc extends Bloc<BoardEvent, BoardState> {
  BoardBloc(this._repository, this.projectId) : super(const BoardInitial()) {
    on<BoardRequested>(_onRequested);
    on<BoardChangedExternally>(_onChanged);
  }

  final BoardRepository _repository;
  final String projectId;

  Future<void> _onRequested(BoardRequested event, Emitter<BoardState> emit) async {
    emit(const BoardLoading());
    await _fetch(emit);
  }

  Future<void> _onChanged(BoardChangedExternally event, Emitter<BoardState> emit) async {
    // Keep showing the current board while the refetch is in flight.
    await _fetch(emit, keepOnError: state is BoardLoaded);
  }

  Future<void> _fetch(Emitter<BoardState> emit, {bool keepOnError = false}) async {
    try {
      emit(BoardLoaded(await _repository.fetchBoard(projectId)));
    } catch (e) {
      if (!keepOnError) {
        emit(BoardError('Could not load the board.\n\n$e'));
      }
    }
  }
}
