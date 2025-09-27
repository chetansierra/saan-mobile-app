import 'package:equatable/equatable.dart';

/// Invoice line item model for detailed billing breakdown
class InvoiceLine extends Equatable {
  const InvoiceLine({
    this.id,
    required this.invoiceId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.taxRate,
    required this.taxAmount,
    this.itemType = InvoiceLineType.labor,
  });

  /// Line item ID (auto-generated UUID)
  final String? id;

  /// Invoice ID this line belongs to
  final String invoiceId;

  /// Description of the line item
  final String description;

  /// Quantity of the item
  final double quantity;

  /// Unit price per item
  final double unitPrice;

  /// Line total (quantity * unitPrice, before tax)
  final double lineTotal;

  /// Tax rate as percentage (e.g., 0.18 for 18%)
  final double taxRate;

  /// Tax amount for this line item
  final double taxAmount;

  /// Type of line item
  final InvoiceLineType itemType;

  /// Total including tax
  double get totalWithTax => lineTotal + taxAmount;

  /// Create InvoiceLine from JSON (Supabase response)
  factory InvoiceLine.fromJson(Map<String, dynamic> json) {
    return InvoiceLine(
      id: json['id'] as String?,
      invoiceId: json['invoice_id'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
      taxRate: (json['tax_rate'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num).toDouble(),
      itemType: InvoiceLineType.fromString(json['item_type'] as String? ?? 'labor'),
    );
  }

  /// Convert InvoiceLine to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'line_total': lineTotal,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'item_type': itemType.value,
    };
  }

  /// Create a line item from service request data
  factory InvoiceLine.fromServiceData({
    required String invoiceId,
    required String description,
    required double quantity,
    required double unitPrice,
    required double taxRate,
    InvoiceLineType itemType = InvoiceLineType.labor,
  }) {
    final lineTotal = double.parse((quantity * unitPrice).toStringAsFixed(2));
    final taxAmount = double.parse((lineTotal * taxRate).toStringAsFixed(2));

    return InvoiceLine(
      invoiceId: invoiceId,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: lineTotal,
      taxRate: taxRate,
      taxAmount: taxAmount,
      itemType: itemType,
    );
  }

  /// Create a copy with updated fields
  InvoiceLine copyWith({
    String? id,
    String? invoiceId,
    String? description,
    double? quantity,
    double? unitPrice,
    double? lineTotal,
    double? taxRate,
    double? taxAmount,
    InvoiceLineType? itemType,
  }) {
    return InvoiceLine(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lineTotal: lineTotal ?? this.lineTotal,
      taxRate: taxRate ?? this.taxRate,
      taxAmount: taxAmount ?? this.taxAmount,
      itemType: itemType ?? this.itemType,
    );
  }

  @override
  List<Object?> get props => [
        id,
        invoiceId,
        description,
        quantity,
        unitPrice,
        lineTotal,
        taxRate,
        taxAmount,
        itemType,
      ];
}

/// Invoice line item type enumeration
enum InvoiceLineType {
  labor('labor'),
  materials('materials'),
  tax('tax'),
  discount('discount'),
  other('other');

  const InvoiceLineType(this.value);

  final String value;

  /// Create InvoiceLineType from string value
  static InvoiceLineType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'labor':
        return InvoiceLineType.labor;
      case 'materials':
        return InvoiceLineType.materials;
      case 'tax':
        return InvoiceLineType.tax;
      case 'discount':
        return InvoiceLineType.discount;
      case 'other':
        return InvoiceLineType.other;
      default:
        throw ArgumentError('Invalid invoice line type: $value');
    }
  }

  /// Display name for the line type
  String get displayName {
    switch (this) {
      case InvoiceLineType.labor:
        return 'Labor';
      case InvoiceLineType.materials:
        return 'Materials';
      case InvoiceLineType.tax:
        return 'Tax';
      case InvoiceLineType.discount:
        return 'Discount';
      case InvoiceLineType.other:
        return 'Other';
    }
  }

  /// Color hex code for line type display
  String get colorHex {
    switch (this) {
      case InvoiceLineType.labor:
        return '#2196F3'; // Blue
      case InvoiceLineType.materials:
        return '#FF9800'; // Orange
      case InvoiceLineType.tax:
        return '#9E9E9E'; // Grey
      case InvoiceLineType.discount:
        return '#4CAF50'; // Green
      case InvoiceLineType.other:
        return '#9C27B0'; // Purple
    }
  }

  /// Icon name for line type display
  String get iconName {
    switch (this) {
      case InvoiceLineType.labor:
        return 'person_outline';
      case InvoiceLineType.materials:
        return 'inventory_2';
      case InvoiceLineType.tax:
        return 'receipt';
      case InvoiceLineType.discount:
        return 'discount';
      case InvoiceLineType.other:
        return 'category';
    }
  }
}

/// Line item template for common services
class LineItemTemplate {
  const LineItemTemplate._();

  /// Standard labor rates (per hour)
  static const Map<String, double> laborRates = {
    'Technician': 500.0,
    'Engineer': 800.0,
    'Specialist': 1200.0,
    'Supervisor': 1000.0,
  };

  /// Standard tax rates
  static const Map<String, double> taxRates = {
    'GST 18%': 0.18,
    'GST 12%': 0.12,
    'GST 5%': 0.05,
    'No Tax': 0.0,
  };

  /// Common material items with default prices
  static const Map<String, double> materialPrices = {
    'Basic Parts': 200.0,
    'Premium Parts': 500.0,
    'Consumables': 100.0,
    'Tools': 300.0,
    'Safety Equipment': 150.0,
  };

  /// Create standard labor line item
  static InvoiceLine createLaborLine({
    required String invoiceId,
    required String technicianType,
    required double hours,
    double taxRate = 0.18,
  }) {
    final rate = laborRates[technicianType] ?? laborRates['Technician']!;
    return InvoiceLine.fromServiceData(
      invoiceId: invoiceId,
      description: '$technicianType - $hours hours',
      quantity: hours,
      unitPrice: rate,
      taxRate: taxRate,
      itemType: InvoiceLineType.labor,
    );
  }

  /// Create standard material line item
  static InvoiceLine createMaterialLine({
    required String invoiceId,
    required String materialType,
    required double quantity,
    double? customPrice,
    double taxRate = 0.18,
  }) {
    final price = customPrice ?? materialPrices[materialType] ?? 200.0;
    return InvoiceLine.fromServiceData(
      invoiceId: invoiceId,
      description: '$materialType - $quantity units',
      quantity: quantity,
      unitPrice: price,
      taxRate: taxRate,
      itemType: InvoiceLineType.materials,
    );
  }

  /// Create custom line item
  static InvoiceLine createCustomLine({
    required String invoiceId,
    required String description,
    required double quantity,
    required double unitPrice,
    double taxRate = 0.18,
    InvoiceLineType itemType = InvoiceLineType.other,
  }) {
    return InvoiceLine.fromServiceData(
      invoiceId: invoiceId,
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      taxRate: taxRate,
      itemType: itemType,
    );
  }
}

/// Line item validation utilities
class LineItemValidator {
  const LineItemValidator._();

  /// Validate line item data
  static List<String> validateLineItem(InvoiceLine line) {
    final errors = <String>[];

    if (line.description.trim().isEmpty) {
      errors.add('Description is required');
    }

    if (line.quantity <= 0) {
      errors.add('Quantity must be greater than 0');
    }

    if (line.unitPrice < 0) {
      errors.add('Unit price cannot be negative');
    }

    if (line.taxRate < 0 || line.taxRate > 1) {
      errors.add('Tax rate must be between 0% and 100%');
    }

    // Validate calculations
    final expectedLineTotal = double.parse((line.quantity * line.unitPrice).toStringAsFixed(2));
    if ((line.lineTotal - expectedLineTotal).abs() > 0.01) {
      errors.add('Line total calculation is incorrect');
    }

    final expectedTaxAmount = double.parse((line.lineTotal * line.taxRate).toStringAsFixed(2));
    if ((line.taxAmount - expectedTaxAmount).abs() > 0.01) {
      errors.add('Tax amount calculation is incorrect');
    }

    return errors;
  }

  /// Validate list of line items
  static List<String> validateLineItems(List<InvoiceLine> lines) {
    final errors = <String>[];

    if (lines.isEmpty) {
      errors.add('At least one line item is required');
      return errors;
    }

    for (int i = 0; i < lines.length; i++) {
      final lineErrors = validateLineItem(lines[i]);
      for (final error in lineErrors) {
        errors.add('Line ${i + 1}: $error');
      }
    }

    return errors;
  }
}