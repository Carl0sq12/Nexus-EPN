import 'package:equatable/equatable.dart';

/// Interfaz genérica para casos de uso (use cases) en la capa de dominio.
abstract class UseCase<T, Params> {
  Future<T> call(Params params);
}

/// Parámetros vacíos para casos de uso que no requieren argumentos.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => [];
}
