import 'package:dabbler/core/fp/failure.dart';
import 'package:dabbler/core/fp/result.dart';
import 'package:dabbler/core/fp/result_guard.dart';
import 'package:dabbler/data/models/payments/payment_method.dart';
import 'package:dabbler/data/models/payments/payment_method_model.dart';
import '../../domain/repositories/payment_methods_repository.dart';
import '../datasources/payment_methods_datasource.dart';

/// Implementation of payment methods repository
class PaymentMethodsRepositoryImpl implements PaymentMethodsRepository {
  final PaymentMethodsDataSource dataSource;

  PaymentMethodsRepositoryImpl(this.dataSource);

  @override
  Future<Result<List<PaymentMethod>, Failure>> getPaymentMethods(
    String userId,
  ) {
    return guardResult(() async {
      try {
        final models = await dataSource.getPaymentMethods(userId);
        return models.map((m) => m.toEntity()).toList();
      } on PaymentMethodsException catch (e) {
        throw ServerFailure(message: e.message);
      } catch (e) {
        throw ServerFailure(
          message: 'Failed to get payment methods: ${e.toString()}',
        );
      }
    });
  }

  @override
  Future<Result<PaymentMethod?, Failure>> getDefaultPaymentMethod(
    String userId,
  ) {
    return guardResult(() async {
      try {
        final model = await dataSource.getDefaultPaymentMethod(userId);
        return model?.toEntity();
      } on PaymentMethodsException catch (e) {
        throw ServerFailure(message: e.message);
      } catch (e) {
        throw ServerFailure(
          message: 'Failed to get default payment method: ${e.toString()}',
        );
      }
    });
  }

  @override
  Future<Result<PaymentMethod, Failure>> addPaymentMethod(
    PaymentMethod paymentMethod,
  ) {
    return guardResult(() async {
      try {
        final model = PaymentMethodModel.fromEntity(paymentMethod);
        final result = await dataSource.addPaymentMethod(model);
        return result.toEntity();
      } on PaymentMethodsException catch (e) {
        throw ServerFailure(message: e.message);
      } catch (e) {
        throw ServerFailure(
          message: 'Failed to add payment method: ${e.toString()}',
        );
      }
    });
  }

  @override
  Future<Result<PaymentMethod, Failure>> updatePaymentMethod(
    PaymentMethod paymentMethod,
  ) {
    return guardResult(() async {
      try {
        final model = PaymentMethodModel.fromEntity(paymentMethod);
        final result = await dataSource.updatePaymentMethod(model);
        return result.toEntity();
      } on PaymentMethodsException catch (e) {
        throw ServerFailure(message: e.message);
      } catch (e) {
        throw ServerFailure(
          message: 'Failed to update payment method: ${e.toString()}',
        );
      }
    });
  }

  @override
  Future<Result<void, Failure>> deletePaymentMethod(String paymentMethodId) {
    return guardResult(() async {
      try {
        await dataSource.deletePaymentMethod(paymentMethodId);
      } on PaymentMethodsException catch (e) {
        throw ServerFailure(message: e.message);
      } catch (e) {
        throw ServerFailure(
          message: 'Failed to delete payment method: ${e.toString()}',
        );
      }
    });
  }

  @override
  Future<Result<void, Failure>> setDefaultPaymentMethod(
    String userId,
    String paymentMethodId,
  ) {
    return guardResult(() async {
      try {
        await dataSource.setDefaultPaymentMethod(userId, paymentMethodId);
      } on PaymentMethodsException catch (e) {
        throw ServerFailure(message: e.message);
      } catch (e) {
        throw ServerFailure(
          message: 'Failed to set default payment method: ${e.toString()}',
        );
      }
    });
  }
}
