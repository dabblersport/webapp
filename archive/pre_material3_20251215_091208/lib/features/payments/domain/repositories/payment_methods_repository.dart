import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/data/models/payments/payment_method.dart';

/// Payment methods repository interface
abstract class PaymentMethodsRepository {
  /// Get all payment methods for a user
  Future<Result<List<PaymentMethod>, Failure>> getPaymentMethods(String userId);

  /// Get the default payment method for a user
  Future<Result<PaymentMethod?, Failure>> getDefaultPaymentMethod(
    String userId,
  );

  /// Add a new payment method
  Future<Result<PaymentMethod, Failure>> addPaymentMethod(
    PaymentMethod paymentMethod,
  );

  /// Update an existing payment method
  Future<Result<PaymentMethod, Failure>> updatePaymentMethod(
    PaymentMethod paymentMethod,
  );

  /// Delete a payment method
  Future<Result<void, Failure>> deletePaymentMethod(String paymentMethodId);

  /// Set a payment method as default
  Future<Result<void, Failure>> setDefaultPaymentMethod(
    String userId,
    String paymentMethodId,
  );
}
