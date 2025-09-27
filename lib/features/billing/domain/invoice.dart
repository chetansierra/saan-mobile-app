import 'package:equatable/equatable.dart';

/// Invoice model for billing and payment management
class Invoice extends Equatable {
  const Invoice({
    this.id,
    required this.tenantId,
    required this.requestIds,
    required this.invoiceNumber,
    required this.status,
    required this.customerInfo,
    required this.issueDate,
    required this.dueDate,
    required this.subtotal,
    required this.taxAmount,
    required this.total,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Invoice ID (auto-generated UUID)
  final String? id;

  /// Tenant ID for multi-tenant isolation
  final String tenantId;

  /// List of request IDs this invoice is based on
  final List<String> requestIds;

  /// Human-readable invoice number (e.g., INV-2025-001)
  final String invoiceNumber;

  /// Current invoice status
  final InvoiceStatus status;

  /// Customer information (name, address, contact)
  final CustomerInfo customerInfo;

  /// Date when invoice was issued
  final DateTime issueDate;

  /// Payment due date
  final DateTime dueDate;

  /// Subtotal before tax
  final double subtotal;

  /// Total tax amount
  final double taxAmount;

  /// Final total amount (subtotal + tax, rounded to 2 decimals)
  final double total;

  /// Optional notes or terms
  final String? notes;

  /// Invoice creation timestamp
  final DateTime? createdAt;

  /// Invoice last updated timestamp
  final DateTime? updatedAt;

  /// Check if invoice is paid
  bool get isPaid => status == InvoiceStatus.paid;

  /// Check if invoice is unpaid (sent or pending)
  bool get isUnpaid => [InvoiceStatus.sent, InvoiceStatus.pending].contains(status);

  /// Check if invoice is overdue
  bool get isOverdue => isUnpaid && DateTime.now().isAfter(dueDate);

  /// Days until due (negative if overdue)
  int get daysUntilDue {
    final now = DateTime.now();
    final dueStart = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final todayStart = DateTime(now.year, now.month, now.day);
    return dueStart.difference(todayStart).inDays;
  }

  /// Create Invoice from JSON (Supabase response)
  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String?,
      tenantId: json['tenant_id'] as String,
      requestIds: (json['request_ids'] as List? ?? [])
          .map((id) => id.toString())
          .toList(),
      invoiceNumber: json['invoice_number'] as String,
      status: InvoiceStatus.fromString(json['status'] as String),
      customerInfo: CustomerInfo.fromJson(json['customer_info'] as Map<String, dynamic>),
      issueDate: DateTime.parse(json['issue_date'] as String),
      dueDate: DateTime.parse(json['due_date'] as String),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['tax_amount'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert Invoice to JSON (for Supabase operations)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'tenant_id': tenantId,
      'request_ids': requestIds,
      'invoice_number': invoiceNumber,
      'status': status.value,
      'customer_info': customerInfo.toJson(),
      'issue_date': issueDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'total': total,
      'notes': notes,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Invoice copyWith({
    String? id,
    String? tenantId,
    List<String>? requestIds,
    String? invoiceNumber,
    InvoiceStatus? status,
    CustomerInfo? customerInfo,
    DateTime? issueDate,
    DateTime? dueDate,
    double? subtotal,
    double? taxAmount,
    double? total,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Invoice(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      requestIds: requestIds ?? this.requestIds,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      status: status ?? this.status,
      customerInfo: customerInfo ?? this.customerInfo,
      issueDate: issueDate ?? this.issueDate,
      dueDate: dueDate ?? this.dueDate,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tenantId,
        requestIds,
        invoiceNumber,
        status,
        customerInfo,
        issueDate,
        dueDate,
        subtotal,
        taxAmount,
        total,
        notes,
        createdAt,
        updatedAt,
      ];
}

/// Invoice status enumeration
enum InvoiceStatus {
  draft('draft'),
  sent('sent'),
  pending('pending'),
  paid('paid'),
  failed('failed'),
  refunded('refunded');

  const InvoiceStatus(this.value);

  final String value;

  /// Create InvoiceStatus from string value
  static InvoiceStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'draft':
        return InvoiceStatus.draft;
      case 'sent':
        return InvoiceStatus.sent;
      case 'pending':
        return InvoiceStatus.pending;
      case 'paid':
        return InvoiceStatus.paid;
      case 'failed':
        return InvoiceStatus.failed;
      case 'refunded':
        return InvoiceStatus.refunded;
      default:
        throw ArgumentError('Invalid invoice status: $value');
    }
  }

  /// Display name for the status
  String get displayName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.failed:
        return 'Failed';
      case InvoiceStatus.refunded:
        return 'Refunded';
    }
  }

  /// Color hex code for status display
  String get colorHex {
    switch (this) {
      case InvoiceStatus.draft:
        return '#9E9E9E'; // Grey
      case InvoiceStatus.sent:
        return '#2196F3'; // Blue
      case InvoiceStatus.pending:
        return '#FF9800'; // Orange
      case InvoiceStatus.paid:
        return '#4CAF50'; // Green
      case InvoiceStatus.failed:
        return '#F44336'; // Red
      case InvoiceStatus.refunded:
        return '#9C27B0'; // Purple
    }
  }

  /// Icon name for status display
  String get iconName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'draft';
      case InvoiceStatus.sent:
        return 'send';
      case InvoiceStatus.pending:
        return 'pending';
      case InvoiceStatus.paid:
        return 'check_circle';
      case InvoiceStatus.failed:
        return 'error';
      case InvoiceStatus.refunded:
        return 'undo';
    }
  }

  /// Valid next statuses for transitions
  List<InvoiceStatus> get validNextStatuses {
    switch (this) {
      case InvoiceStatus.draft:
        return [InvoiceStatus.sent];
      case InvoiceStatus.sent:
        return [InvoiceStatus.pending, InvoiceStatus.paid, InvoiceStatus.failed];
      case InvoiceStatus.pending:
        return [InvoiceStatus.paid, InvoiceStatus.failed];
      case InvoiceStatus.paid:
        return [InvoiceStatus.refunded];
      case InvoiceStatus.failed:
        return [InvoiceStatus.pending, InvoiceStatus.paid];
      case InvoiceStatus.refunded:
        return []; // Terminal status
    }
  }

  /// Check if transition to another status is valid
  bool canTransitionTo(InvoiceStatus nextStatus) {
    return validNextStatuses.contains(nextStatus);
  }
}

/// Customer information for invoicing
class CustomerInfo extends Equatable {
  const CustomerInfo({
    required this.name,
    required this.email,
    this.phone,
    this.address,
    this.gstNumber,
  });

  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String? gstNumber;

  /// Create CustomerInfo from JSON
  factory CustomerInfo.fromJson(Map<String, dynamic> json) {
    return CustomerInfo(
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      gstNumber: json['gst_number'] as String?,
    );
  }

  /// Convert CustomerInfo to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'gst_number': gstNumber,
    };
  }

  /// Create a copy with updated fields
  CustomerInfo copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? gstNumber,
  }) {
    return CustomerInfo(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      gstNumber: gstNumber ?? this.gstNumber,
    );
  }

  @override
  List<Object?> get props => [name, email, phone, address, gstNumber];
}

/// Invoice totals calculation helper
class InvoiceTotals extends Equatable {
  const InvoiceTotals({
    required this.subtotal,
    required this.taxAmount,
    required this.total,
  });

  final double subtotal;
  final double taxAmount;
  final double total;

  /// Create from line items with tax calculation
  factory InvoiceTotals.fromLineItems(List<InvoiceLine> lines) {
    double subtotal = 0.0;
    double taxAmount = 0.0;

    for (final line in lines) {
      subtotal += line.lineTotal;
      taxAmount += line.taxAmount;
    }

    // Round to 2 decimal places
    subtotal = double.parse(subtotal.toStringAsFixed(2));
    taxAmount = double.parse(taxAmount.toStringAsFixed(2));
    final total = double.parse((subtotal + taxAmount).toStringAsFixed(2));

    return InvoiceTotals(
      subtotal: subtotal,
      taxAmount: taxAmount,
      total: total,
    );
  }

  @override
  List<Object?> get props => [subtotal, taxAmount, total];
}

/// Invoice filters for list queries
class InvoiceFilters extends Equatable {
  const InvoiceFilters({
    this.statuses = const [],
    this.isOverdue,
    this.dateRange,
    this.searchQuery,
  });

  final List<InvoiceStatus> statuses;
  final bool? isOverdue;
  final DateRange? dateRange;
  final String? searchQuery;

  /// Whether any filters are active
  bool get hasActiveFilters {
    return statuses.isNotEmpty ||
           isOverdue != null ||
           dateRange != null ||
           (searchQuery != null && searchQuery!.trim().isNotEmpty);
  }

  /// Clear all filters
  InvoiceFilters clear() {
    return const InvoiceFilters();
  }

  /// Create copy with updated filters
  InvoiceFilters copyWith({
    List<InvoiceStatus>? statuses,
    bool? isOverdue,
    DateRange? dateRange,
    String? searchQuery,
  }) {
    return InvoiceFilters(
      statuses: statuses ?? this.statuses,
      isOverdue: isOverdue ?? this.isOverdue,
      dateRange: dateRange ?? this.dateRange,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [statuses, isOverdue, dateRange, searchQuery];
}

/// Date range for filtering
class DateRange extends Equatable {
  const DateRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  @override
  List<Object?> get props => [start, end];
}

/// Paginated invoice list response
/// Cursor for efficient pagination
class InvoiceCursor extends Equatable {
  const InvoiceCursor({
    required this.issueDate,
    required this.id,
  });

  final DateTime issueDate;
  final String id;

  /// Check if cursor is valid for pagination
  bool get isValid => id.isNotEmpty;

  /// Create cursor from invoice
  factory InvoiceCursor.fromInvoice(Invoice invoice) {
    return InvoiceCursor(
      issueDate: invoice.issueDate,
      id: invoice.id!,
    );
  }

  @override
  List<Object?> get props => [issueDate, id];

  @override
  String toString() => 'InvoiceCursor(issueDate: $issueDate, id: $id)';
}

class PaginatedInvoices extends Equatable {
  const PaginatedInvoices({
    required this.invoices,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    this.cursor,
  });

  final List<Invoice> invoices;
  final int total;
  final int page;
  final int pageSize;
  final bool hasMore;
  final InvoiceCursor? cursor;

  @override
  List<Object?> get props => [invoices, total, page, pageSize, hasMore, cursor];
}

// Forward declaration - defined in invoice_line.dart
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
  });

  final String? id;
  final String invoiceId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double taxRate;
  final double taxAmount;

  @override
  List<Object?> get props => [id, invoiceId, description, quantity, unitPrice, lineTotal, taxRate, taxAmount];
}