import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dabbler/data/models/payments/payment_method_model.dart';

/// Exception for payment methods operations
class PaymentMethodsException implements Exception {
  final String message;
  PaymentMethodsException(this.message);

  @override
  String toString() => 'PaymentMethodsException: $message';
}

/// Payment methods remote data source
abstract class PaymentMethodsDataSource {
  Future<List<PaymentMethodModel>> getPaymentMethods(String userId);
  Future<PaymentMethodModel?> getDefaultPaymentMethod(String userId);
  Future<PaymentMethodModel> addPaymentMethod(PaymentMethodModel paymentMethod);
  Future<PaymentMethodModel> updatePaymentMethod(
    PaymentMethodModel paymentMethod,
  );
  Future<void> deletePaymentMethod(String paymentMethodId);
  Future<void> setDefaultPaymentMethod(String userId, String paymentMethodId);
}

/// Supabase implementation of payment methods data source
class SupabasePaymentMethodsDataSource implements PaymentMethodsDataSource {
  final SupabaseClient _supabaseClient;

  SupabasePaymentMethodsDataSource(this._supabaseClient);

  @override
  Future<List<PaymentMethodModel>> getPaymentMethods(String userId) async {
    try {
      final response = await _supabaseClient
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => PaymentMethodModel.fromJson(json))
          .toList();
    } on PostgrestException catch (e) {
      throw PaymentMethodsException('Database error: ${e.message}');
    } catch (e) {
      throw PaymentMethodsException(
        'Failed to get payment methods: ${e.toString()}',
      );
    }
  }

  @override
  Future<PaymentMethodModel?> getDefaultPaymentMethod(String userId) async {
    try {
      final response = await _supabaseClient
          .from('payment_methods')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      if (response == null) return null;
      return PaymentMethodModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw PaymentMethodsException('Database error: ${e.message}');
    } catch (e) {
      throw PaymentMethodsException(
        'Failed to get default payment method: ${e.toString()}',
      );
    }
  }

  @override
  Future<PaymentMethodModel> addPaymentMethod(
    PaymentMethodModel paymentMethod,
  ) async {
    try {
      final response = await _supabaseClient
          .from('payment_methods')
          .insert(paymentMethod.toJson())
          .select()
          .single();

      return PaymentMethodModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw PaymentMethodsException('Database error: ${e.message}');
    } catch (e) {
      throw PaymentMethodsException(
        'Failed to add payment method: ${e.toString()}',
      );
    }
  }

  @override
  Future<PaymentMethodModel> updatePaymentMethod(
    PaymentMethodModel paymentMethod,
  ) async {
    try {
      final response = await _supabaseClient
          .from('payment_methods')
          .update(paymentMethod.toJson())
          .eq('id', paymentMethod.id)
          .select()
          .single();

      return PaymentMethodModel.fromJson(response);
    } on PostgrestException catch (e) {
      throw PaymentMethodsException('Database error: ${e.message}');
    } catch (e) {
      throw PaymentMethodsException(
        'Failed to update payment method: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deletePaymentMethod(String paymentMethodId) async {
    try {
      await _supabaseClient
          .from('payment_methods')
          .delete()
          .eq('id', paymentMethodId);
    } on PostgrestException catch (e) {
      throw PaymentMethodsException('Database error: ${e.message}');
    } catch (e) {
      throw PaymentMethodsException(
        'Failed to delete payment method: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> setDefaultPaymentMethod(
    String userId,
    String paymentMethodId,
  ) async {
    try {
      // First, unset all other payment methods as default
      await _supabaseClient
          .from('payment_methods')
          .update({'is_default': false})
          .eq('user_id', userId);

      // Then set the selected one as default
      await _supabaseClient
          .from('payment_methods')
          .update({'is_default': true})
          .eq('id', paymentMethodId);
    } on PostgrestException catch (e) {
      throw PaymentMethodsException('Database error: ${e.message}');
    } catch (e) {
      throw PaymentMethodsException(
        'Failed to set default payment method: ${e.toString()}',
      );
    }
  }
}
