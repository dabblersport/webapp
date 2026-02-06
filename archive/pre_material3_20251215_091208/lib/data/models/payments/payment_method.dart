import 'package:equatable/equatable.dart';

/// Payment method types
enum PaymentType { card, paypal, applePay, googlePay, bankTransfer }

/// Payment method entity
class PaymentMethod extends Equatable {
  final String id;
  final String userId;
  final PaymentType type;
  final String? lastFour;
  final String? brand;
  final String? expiryDate;
  final String? email;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PaymentMethod({
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

  PaymentMethod copyWith({
    String? id,
    String? userId,
    PaymentType? type,
    String? lastFour,
    String? brand,
    String? expiryDate,
    String? email,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentMethod(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      lastFour: lastFour ?? this.lastFour,
      brand: brand ?? this.brand,
      expiryDate: expiryDate ?? this.expiryDate,
      email: email ?? this.email,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    lastFour,
    brand,
    expiryDate,
    email,
    isDefault,
    createdAt,
    updatedAt,
  ];
}
