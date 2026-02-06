import 'package:dabbler/data/models/payments/payment_method.dart';

/// Payment method model for data layer
class PaymentMethodModel {
  final String id;
  final String userId;
  final String
  type; // 'card', 'paypal', 'applePay', 'googlePay', 'bankTransfer'
  final String? lastFour;
  final String? brand;
  final String? expiryDate;
  final String? email;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PaymentMethodModel({
    required this.id,
    required this.userId,
    required this.type,
    this.lastFour,
    this.brand,
    this.expiryDate,
    this.email,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Convert model to entity
  PaymentMethod toEntity() {
    return PaymentMethod(
      id: id,
      userId: userId,
      type: _parsePaymentType(type),
      lastFour: lastFour,
      brand: brand,
      expiryDate: expiryDate,
      email: email,
      isDefault: isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Create model from entity
  factory PaymentMethodModel.fromEntity(PaymentMethod entity) {
    return PaymentMethodModel(
      id: entity.id,
      userId: entity.userId,
      type: _paymentTypeToString(entity.type),
      lastFour: entity.lastFour,
      brand: entity.brand,
      expiryDate: entity.expiryDate,
      email: entity.email,
      isDefault: entity.isDefault,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Create model from JSON (Supabase)
  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      lastFour: json['last_four'] as String?,
      brand: json['brand'] as String?,
      expiryDate: json['expiry_date'] as String?,
      email: json['email'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert model to JSON (Supabase)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'last_four': lastFour,
      'brand': brand,
      'expiry_date': expiryDate,
      'email': email,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static PaymentType _parsePaymentType(String type) {
    switch (type.toLowerCase()) {
      case 'card':
        return PaymentType.card;
      case 'paypal':
        return PaymentType.paypal;
      case 'applepay':
      case 'apple_pay':
        return PaymentType.applePay;
      case 'googlepay':
      case 'google_pay':
        return PaymentType.googlePay;
      case 'banktransfer':
      case 'bank_transfer':
        return PaymentType.bankTransfer;
      default:
        return PaymentType.card;
    }
  }

  static String _paymentTypeToString(PaymentType type) {
    switch (type) {
      case PaymentType.card:
        return 'card';
      case PaymentType.paypal:
        return 'paypal';
      case PaymentType.applePay:
        return 'apple_pay';
      case PaymentType.googlePay:
        return 'google_pay';
      case PaymentType.bankTransfer:
        return 'bank_transfer';
    }
  }
}
