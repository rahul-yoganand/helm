import 'package:equatable/equatable.dart';

import 'board_model.dart';

sealed class BoardState extends Equatable {
  const BoardState();

  @override
  List<Object?> get props => [];
}

class BoardInitial extends BoardState {
  const BoardInitial();
}

class BoardLoading extends BoardState {
  const BoardLoading();
}

class BoardLoaded extends BoardState {
  const BoardLoaded(this.data);

  final BoardData data;

  @override
  List<Object?> get props => [data];
}

class BoardError extends BoardState {
  const BoardError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
