import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/payment_methods_datasource.dart';
import '../../data/repositories/payment_methods_repository_impl.dart';
import '../../domain/repositories/payment_methods_repository.dart';
import '../controllers/payment_methods_controller.dart';

/// Supabase client provider
final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Payment methods data source provider
final paymentMethodsDataSourceProvider = Provider<PaymentMethodsDataSource>((
  ref,
) {
  final supabaseClient = ref.watch(_supabaseClientProvider);
  return SupabasePaymentMethodsDataSource(supabaseClient);
});

/// Payment methods repository provider
final paymentMethodsRepositoryProvider = Provider<PaymentMethodsRepository>((
  ref,
) {
  final dataSource = ref.watch(paymentMethodsDataSourceProvider);
  return PaymentMethodsRepositoryImpl(dataSource);
});

/// Payment methods controller provider (requires userId)
final paymentMethodsControllerProvider =
    StateNotifierProvider.family<
      PaymentMethodsController,
      PaymentMethodsState,
      String
    >((ref, userId) {
      final repository = ref.watch(paymentMethodsRepositoryProvider);
      return PaymentMethodsController(repository, userId);
    });
