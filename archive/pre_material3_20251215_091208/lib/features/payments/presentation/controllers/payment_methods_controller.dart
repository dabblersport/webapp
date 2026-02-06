import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dabbler/data/models/payments/payment_method.dart';
import '../../domain/repositories/payment_methods_repository.dart';

/// Payment methods state
class PaymentMethodsState {
  final List<PaymentMethod> paymentMethods;
  final PaymentMethod? defaultPaymentMethod;
  final bool isLoading;
  final String? error;

  const PaymentMethodsState({
    this.paymentMethods = const [],
    this.defaultPaymentMethod,
    this.isLoading = false,
    this.error,
  });

  PaymentMethodsState copyWith({
    List<PaymentMethod>? paymentMethods,
    PaymentMethod? defaultPaymentMethod,
    bool? isLoading,
    String? error,
  }) {
    return PaymentMethodsState(
      paymentMethods: paymentMethods ?? this.paymentMethods,
      defaultPaymentMethod: defaultPaymentMethod ?? this.defaultPaymentMethod,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Payment methods controller
class PaymentMethodsController extends StateNotifier<PaymentMethodsState> {
  final PaymentMethodsRepository _repository;
  final String userId;

  PaymentMethodsController(this._repository, this.userId)
    : super(const PaymentMethodsState());

  /// Load payment methods for user
  Future<void> loadPaymentMethods() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getPaymentMethods(userId);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (methods) {
        final defaultMethod = methods.firstWhere(
          (m) => m.isDefault,
          orElse: () => methods.isNotEmpty
              ? methods.first
              : throw StateError('No methods'),
        );

        state = state.copyWith(
          paymentMethods: methods,
          defaultPaymentMethod: defaultMethod,
          isLoading: false,
        );
      },
    );
  }

  /// Add a new payment method
  Future<bool> addPaymentMethod(PaymentMethod paymentMethod) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.addPaymentMethod(paymentMethod);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (newMethod) {
        state = state.copyWith(
          paymentMethods: [...state.paymentMethods, newMethod],
          isLoading: false,
        );
        return true;
      },
    );
  }

  /// Delete a payment method
  Future<bool> deletePaymentMethod(String paymentMethodId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.deletePaymentMethod(paymentMethodId);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        final updatedMethods = state.paymentMethods
            .where((m) => m.id != paymentMethodId)
            .toList();

        state = state.copyWith(
          paymentMethods: updatedMethods,
          isLoading: false,
        );
        return true;
      },
    );
  }

  /// Set a payment method as default
  Future<bool> setDefaultPaymentMethod(String paymentMethodId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.setDefaultPaymentMethod(
      userId,
      paymentMethodId,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        // Update local state to reflect the new default
        final updatedMethods = state.paymentMethods.map((m) {
          return m.copyWith(isDefault: m.id == paymentMethodId);
        }).toList();

        final newDefault = updatedMethods.firstWhere(
          (m) => m.id == paymentMethodId,
        );

        state = state.copyWith(
          paymentMethods: updatedMethods,
          defaultPaymentMethod: newDefault,
          isLoading: false,
        );
        return true;
      },
    );
  }
}
