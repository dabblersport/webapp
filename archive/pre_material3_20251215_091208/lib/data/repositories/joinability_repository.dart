import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/failure.dart';
import '../models/joinability_rule.dart';

/// Pure client-side joinability matrix.
/// Server remains the source of truth (RLS / RPC can still deny).
abstract class JoinabilityRepository {
  /// Evaluate joinability for current viewer given declarative inputs.
  /// Must be deterministic and fail-closed where security is concerned,
  /// but should avoid unnecessary blocking when information is obviously safe.
  Result<JoinabilityDecision, Failure> evaluate(JoinabilityInputs inputs);
}
