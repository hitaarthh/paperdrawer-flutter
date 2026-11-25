import '../result/result.dart';

/// One business action that spans more than one repository or service, such
/// as "add an item" (check the plan's capacity, copy the originals, write the
/// row, reschedule reminders).
///
/// Rules:
/// - A use case only orchestrates. Rules live in domain objects
///   (`PlanPolicy`, `ItemCapacity`), storage lives in repositories.
/// - It returns a [Result] and never throws.
/// - It is stateless: all inputs come in through [call], all collaborators
///   through the constructor.
/// - A view model action that touches one repository calls the repository
///   directly; don't wrap it in a use case just for ceremony.
abstract interface class UseCase<Input, Output> {
  Future<Result<Output>> call(Input input);
}

/// A [UseCase] that needs no input.
abstract interface class NoInputUseCase<Output> {
  Future<Result<Output>> call();
}
