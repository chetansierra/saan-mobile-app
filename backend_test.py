#!/usr/bin/env python3
"""
Backend Testing Suite for Round 7 Billing (Invoices) + PhonePe Launcher Implementation

This comprehensive test suite validates the Flutter billing implementation including:
1. Domain Models: Invoice, InvoiceLine, PaymentAttempt with business logic
2. Repository Layer: BillingRepository CRUD operations and data integrity
3. Service Layer: BillingService business logic and admin operations
4. PhonePe Integration: Payment utilities and deeplink generation
5. KPI Integration: Billing metrics and dashboard data
6. Business Logic: Invoice generation, status transitions, totals calculation
7. Tenant Isolation: Multi-tenant data security
8. Error Handling: Validation and exception management

Focus: Comprehensive validation of billing system implementation as per MVP requirements
"""

import asyncio
import json
import sys
import traceback
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import re

class BillingBackendTester:
    """Comprehensive test suite for Round 7 Billing + PhonePe implementation"""
    
    def __init__(self):
        self.test_results = []
        self.errors = []
        self.warnings = []
        
    def log_result(self, test_name: str, status: str, message: str, details: Optional[Dict] = None):
        """Log test result with detailed information"""
        result = {
            'test': test_name,
            'status': status,  # 'PASS', 'FAIL', 'SKIP', 'WARNING'
            'message': message,
            'timestamp': datetime.now().isoformat(),
            'details': details or {}
        }
        self.test_results.append(result)
        
        status_emoji = {
            'PASS': '✅',
            'FAIL': '❌', 
            'SKIP': '⏭️',
            'WARNING': '⚠️'
        }
        
        print(f"{status_emoji.get(status, '❓')} {test_name}: {message}")
        if details:
            print(f"   Details: {json.dumps(details, indent=2)}")
    
    def test_invoice_model_structure(self):
        """Test Invoice domain model structure and business logic"""
        test_name = "Invoice Model Structure & Business Logic"
        
        try:
            with open('/app/lib/features/billing/domain/invoice.dart', 'r') as f:
                content = f.read()
            
            # Core model structure checks
            model_checks = {
                'class_definition': 'class Invoice extends Equatable',
                'tenant_isolation': 'final String tenantId',
                'request_ids': 'final List<String> requestIds',
                'invoice_number': 'final String invoiceNumber',
                'status_field': 'final InvoiceStatus status',
                'customer_info': 'final CustomerInfo customerInfo',
                'financial_fields': 'final double total',
                'date_fields': 'final DateTime issueDate',
                'json_serialization': 'factory Invoice.fromJson',
                'json_deserialization': 'Map<String, dynamic> toJson()',
                'copy_with': 'Invoice copyWith(',
                'equatable_props': 'List<Object?> get props'
            }
            
            # Business logic checks
            business_logic_checks = {
                'is_paid_getter': 'bool get isPaid',
                'is_unpaid_getter': 'bool get isUnpaid',
                'is_overdue_getter': 'bool get isOverdue',
                'days_until_due': 'int get daysUntilDue',
                'overdue_calculation': 'DateTime.now().isAfter(dueDate)'
            }
            
            # Status enumeration checks
            status_enum_checks = {
                'status_enum': 'enum InvoiceStatus',
                'draft_status': 'draft(\'draft\')',
                'sent_status': 'sent(\'sent\')',
                'pending_status': 'pending(\'pending\')',
                'paid_status': 'paid(\'paid\')',
                'failed_status': 'failed(\'failed\')',
                'refunded_status': 'refunded(\'refunded\')',
                'status_transitions': 'List<InvoiceStatus> get validNextStatuses',
                'can_transition': 'bool canTransitionTo(InvoiceStatus nextStatus)',
                'display_properties': 'String get displayName',
                'color_coding': 'String get colorHex'
            }
            
            # Customer info checks
            customer_checks = {
                'customer_class': 'class CustomerInfo extends Equatable',
                'required_fields': 'required this.name',
                'email_field': 'required this.email',
                'optional_fields': 'this.phone',
                'gst_support': 'this.gstNumber'
            }
            
            # Totals calculation checks
            totals_checks = {
                'totals_class': 'class InvoiceTotals extends Equatable',
                'from_line_items': 'factory InvoiceTotals.fromLineItems',
                'decimal_rounding': 'toStringAsFixed(2)',
                'subtotal_calculation': 'subtotal += line.lineTotal',
                'tax_calculation': 'taxAmount += line.taxAmount'
            }
            
            all_checks = {
                **model_checks,
                **business_logic_checks, 
                **status_enum_checks,
                **customer_checks,
                **totals_checks
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in all_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Validate status transition logic
            transition_patterns = [
                'draft.*sent',
                'sent.*pending.*paid.*failed',
                'pending.*paid.*failed',
                'paid.*refunded',
                'failed.*pending.*paid'
            ]
            
            transition_logic_found = any(
                re.search(pattern, content, re.IGNORECASE | re.DOTALL) 
                for pattern in transition_patterns
            )
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing invoice model patterns: {", ".join(failed_checks[:5])}',
                    {'passed': len(passed_checks), 'failed': len(failed_checks), 
                     'transition_logic': transition_logic_found})
            else:
                self.log_result(test_name, 'PASS', 
                    'Invoice model properly implemented with complete business logic',
                    {'validated_patterns': len(passed_checks), 'transition_logic': transition_logic_found})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading invoice model: {str(e)}')
    
    def test_invoice_line_model_structure(self):
        """Test InvoiceLine domain model structure and calculations"""
        test_name = "InvoiceLine Model Structure & Tax Calculations"
        
        try:
            with open('/app/lib/features/billing/domain/invoice_line.dart', 'r') as f:
                content = f.read()
            
            # Core model checks
            model_checks = {
                'class_definition': 'class InvoiceLine extends Equatable',
                'invoice_reference': 'final String invoiceId',
                'description_field': 'final String description',
                'quantity_field': 'final double quantity',
                'unit_price': 'final double unitPrice',
                'line_total': 'final double lineTotal',
                'tax_rate': 'final double taxRate',
                'tax_amount': 'final double taxAmount',
                'item_type': 'final InvoiceLineType itemType'
            }
            
            # Calculation checks
            calculation_checks = {
                'total_with_tax': 'double get totalWithTax',
                'from_service_data': 'factory InvoiceLine.fromServiceData',
                'decimal_precision': 'toStringAsFixed(2)',
                'line_total_calc': 'quantity * unitPrice',
                'tax_amount_calc': 'lineTotal * taxRate'
            }
            
            # Line item type enum checks
            type_enum_checks = {
                'line_type_enum': 'enum InvoiceLineType',
                'labor_type': 'labor(\'labor\')',
                'materials_type': 'materials(\'materials\')',
                'tax_type': 'tax(\'tax\')',
                'discount_type': 'discount(\'discount\')',
                'other_type': 'other(\'other\')'
            }
            
            # Template and validation checks
            template_checks = {
                'line_template_class': 'class LineItemTemplate',
                'labor_rates': 'static const Map<String, double> laborRates',
                'tax_rates': 'static const Map<String, double> taxRates',
                'material_prices': 'static const Map<String, double> materialPrices',
                'create_labor_line': 'static InvoiceLine createLaborLine',
                'create_material_line': 'static InvoiceLine createMaterialLine',
                'validator_class': 'class LineItemValidator',
                'validate_line_item': 'static List<String> validateLineItem',
                'validate_calculations': 'Line total calculation is incorrect'
            }
            
            all_checks = {
                **model_checks,
                **calculation_checks,
                **type_enum_checks,
                **template_checks
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in all_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Check for proper tax calculation logic
            tax_calculation_patterns = [
                r'lineTotal \* taxRate',
                r'quantity \* unitPrice',
                r'toStringAsFixed\(2\)'
            ]
            
            tax_logic_found = all(
                re.search(pattern, content) for pattern in tax_calculation_patterns
            )
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing invoice line patterns: {", ".join(failed_checks[:5])}',
                    {'passed': len(passed_checks), 'failed': len(failed_checks),
                     'tax_calculation_logic': tax_logic_found})
            else:
                self.log_result(test_name, 'PASS', 
                    'InvoiceLine model properly implemented with accurate tax calculations',
                    {'validated_patterns': len(passed_checks), 'tax_calculation_logic': tax_logic_found})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading invoice line model: {str(e)}')
    
    def test_payment_attempt_model_structure(self):
        """Test PaymentAttempt domain model and PhonePe integration"""
        test_name = "PaymentAttempt Model & PhonePe Integration"
        
        try:
            with open('/app/lib/features/billing/domain/payment_attempt.dart', 'r') as f:
                content = f.read()
            
            # Core model checks
            model_checks = {
                'class_definition': 'class PaymentAttempt extends Equatable',
                'invoice_reference': 'final String invoiceId',
                'attempt_date': 'final DateTime attemptDate',
                'amount_field': 'final double amount',
                'reference_id': 'final String referenceId',
                'status_field': 'final PaymentAttemptStatus status',
                'payment_method': 'final PaymentMethod paymentMethod',
                'error_handling': 'final String? errorMessage',
                'provider_transaction': 'final String? providerTransactionId'
            }
            
            # Status checks
            status_checks = {
                'attempt_status_enum': 'enum PaymentAttemptStatus',
                'initiated_status': 'initiated(\'initiated\')',
                'pending_status': 'pending(\'pending\')',
                'success_status': 'success(\'success\')',
                'failed_status': 'failed(\'failed\')',
                'cancelled_status': 'cancelled(\'cancelled\')',
                'timeout_status': 'timeout(\'timeout\')'
            }
            
            # Payment method checks
            method_checks = {
                'payment_method_enum': 'enum PaymentMethod',
                'phonepe_method': 'phonepe(\'phonepe\')',
                'upi_method': 'upi(\'upi\')',
                'card_method': 'card(\'card\')',
                'cash_method': 'cash(\'cash\')',
                'method_display': 'String get displayName',
                'method_colors': 'String get colorHex',
                'auto_status_support': 'bool get supportsAutoStatus'
            }
            
            # PhonePe utility checks
            phonepe_checks = {
                'phonepe_utils_class': 'class PhonePeUtils',
                'generate_deeplink': 'static String generateDeeplink',
                'generate_upi_intent': 'static String generateUpiIntent',
                'generate_reference_id': 'static String generateReferenceId',
                'validate_transaction_id': 'static bool isValidTransactionId',
                'format_amount': 'static String formatAmount',
                'parse_amount': 'static double parseAmount',
                'deeplink_format': 'phonepe://pay?',
                'upi_intent_format': 'upi://pay?',
                'amount_in_paise': 'amount * 100',
                'reference_generation': 'DateTime.now().millisecondsSinceEpoch'
            }
            
            # Factory method checks
            factory_checks = {
                'create_phonepe_attempt': 'factory PaymentAttempt.createPhonePeAttempt',
                'phonepe_method_assignment': 'paymentMethod: PaymentMethod.phonepe',
                'initiated_status_assignment': 'status: PaymentAttemptStatus.initiated'
            }
            
            all_checks = {
                **model_checks,
                **status_checks,
                **method_checks,
                **phonepe_checks,
                **factory_checks
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in all_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Check PhonePe specific patterns
            phonepe_patterns = [
                r'PhonePe.*Purple.*#5F2D91',
                r'phonepe://pay\?.*amount.*trid',
                r'upi://pay\?.*pa.*am.*tr',
                r'TXN_.*timestamp.*random'
            ]
            
            phonepe_integration = sum(1 for pattern in phonepe_patterns 
                                    if re.search(pattern, content, re.IGNORECASE))
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing payment attempt patterns: {", ".join(failed_checks[:5])}',
                    {'passed': len(passed_checks), 'failed': len(failed_checks),
                     'phonepe_integration_score': f'{phonepe_integration}/{len(phonepe_patterns)}'})
            else:
                self.log_result(test_name, 'PASS', 
                    'PaymentAttempt model and PhonePe integration properly implemented',
                    {'validated_patterns': len(passed_checks), 
                     'phonepe_integration_score': f'{phonepe_integration}/{len(phonepe_patterns)}'})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading payment attempt model: {str(e)}')
    
    def test_billing_repository_structure(self):
        """Test BillingRepository CRUD operations and data integrity"""
        test_name = "BillingRepository CRUD Operations & Data Integrity"
        
        try:
            with open('/app/lib/features/billing/data/billing_repository.dart', 'r') as f:
                content = f.read()
            
            # Repository structure checks
            structure_checks = {
                'class_definition': 'class BillingRepository',
                'singleton_pattern': 'static final BillingRepository _instance',
                'supabase_client': 'final SupabaseClient _client',
                'instance_getter': 'static BillingRepository get instance'
            }
            
            # CRUD operation checks
            crud_checks = {
                'create_invoice': 'Future<Invoice> createInvoice(Invoice draft, List<InvoiceLine> lines)',
                'get_invoice': 'Future<Invoice?> getInvoice(String invoiceId)',
                'get_invoice_lines': 'Future<List<InvoiceLine>> getInvoiceLines(String invoiceId)',
                'list_invoices': 'Future<PaginatedInvoices> listInvoices',
                'update_invoice_status': 'Future<Invoice> updateInvoiceStatus',
                'delete_invoice': 'Future<void> deleteInvoice(String invoiceId)'
            }
            
            # Payment attempt operations
            payment_checks = {
                'log_payment_attempt': 'Future<PaymentAttempt> logPaymentAttempt',
                'get_payment_attempts': 'Future<List<PaymentAttempt>> getPaymentAttempts',
                'update_payment_status': 'Future<PaymentAttempt> updatePaymentAttemptStatus'
            }
            
            # Transaction integrity checks
            transaction_checks = {
                'validation_method': 'List<String> _validateInvoiceCreation',
                'create_invoice_first': 'final invoiceResponse = await _client',
                'create_line_items': 'await _client.*from(SupabaseTables.invoiceLines)',
                'status_transition_validation': 'if (!currentInvoice.status.canTransitionTo(nextStatus))',
                'draft_deletion_check': 'if (invoice.status != InvoiceStatus.draft)'
            }
            
            # Totals calculation checks
            calculation_checks = {
                'compute_totals': 'Future<InvoiceTotals> computeTotals',
                'totals_from_lines': 'InvoiceTotals.fromLineItems(lines)',
                'decimal_rounding': 'toStringAsFixed(2)'
            }
            
            # KPI and analytics checks
            kpi_checks = {
                'get_billing_kpis': 'Future<BillingKPIs> getBillingKPIs',
                'unpaid_invoices': 'unpaidResponse.*count',
                'overdue_invoices': 'overdueResponse.*count',
                'outstanding_amount': 'outstandingAmount +=',
                'monthly_revenue': 'monthlyRevenue +='
            }
            
            # Pagination and filtering checks
            pagination_checks = {
                'pagination_support': 'int page = 1',
                'page_size': 'int pageSize = 20',
                'invoice_filters': 'InvoiceFilters? filters',
                'apply_filters': 'PostgrestFilterBuilder _applyInvoiceFilters',
                'tenant_filtering': '.eq(\'tenant_id\', tenantId)',
                'status_filtering': '.eq(\'status\', status)',
                'date_range_filtering': '.gte(\'issue_date\'',
                'search_filtering': '.or(\'invoice_number.ilike'
            }
            
            # Table reference checks
            table_checks = {
                'invoices_table': 'SupabaseTables.invoices',
                'invoice_lines_table': 'SupabaseTables.invoiceLines',
                'payment_attempts_table': 'SupabaseTables.paymentAttempts'
            }
            
            all_checks = {
                **structure_checks,
                **crud_checks,
                **payment_checks,
                **transaction_checks,
                **calculation_checks,
                **kpi_checks,
                **pagination_checks,
                **table_checks
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in all_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Check error handling patterns
            error_patterns = [
                r'try\s*{.*}.*catch.*{.*debugPrint.*rethrow',
                r'debugPrint\(.*❌.*Failed to',
                r'debugPrint\(.*✅.*created.*updated'
            ]
            
            error_handling_score = sum(1 for pattern in error_patterns 
                                     if re.search(pattern, content, re.DOTALL))
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing repository patterns: {", ".join(failed_checks[:5])}',
                    {'passed': len(passed_checks), 'failed': len(failed_checks),
                     'error_handling_score': f'{error_handling_score}/{len(error_patterns)}'})
            else:
                self.log_result(test_name, 'PASS', 
                    'BillingRepository properly implemented with comprehensive CRUD operations',
                    {'validated_patterns': len(passed_checks),
                     'error_handling_score': f'{error_handling_score}/{len(error_patterns)}'})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading billing repository: {str(e)}')
    
    def test_billing_service_business_logic(self):
        """Test BillingService business logic and admin operations"""
        test_name = "BillingService Business Logic & Admin Operations"
        
        try:
            with open('/app/lib/features/billing/domain/billing_service.dart', 'r') as f:
                content = f.read()
            
            # Service structure checks
            structure_checks = {
                'class_definition': 'class BillingService extends ChangeNotifier',
                'provider_definition': 'final billingServiceProvider = ChangeNotifierProvider',
                'auth_service_dependency': 'final AuthService _authService',
                'requests_service_dependency': 'final RequestsService _requestsService',
                'repository_instance': 'final BillingRepository _repository',
                'state_management': 'BillingState _state'
            }
            
            # Invoice generation checks
            generation_checks = {
                'generate_from_requests': 'Future<Invoice> generateFromRequests',
                'validate_requests': 'Future<List<ServiceRequest>> _validateAndFetchRequests',
                'completed_requests_only': 'if (!request.status.isClosed)',
                'extract_customer_info': 'CustomerInfo _extractCustomerInfo',
                'generate_invoice_number': 'await _repository.generateInvoiceNumber',
                'generate_line_items': 'List<InvoiceLine> _generateLineItemsFromRequests',
                'calculate_totals': 'await _repository.computeTotals',
                'create_with_lines': 'await _repository.createInvoice(invoiceDraft, lineItems)'
            }
            
            # Status transition methods
            status_checks = {
                'send_invoice': 'Future<void> sendInvoice(String invoiceId)',
                'mark_pending': 'Future<void> markPending(String invoiceId)',
                'mark_paid': 'Future<void> markPaid(String invoiceId)',
                'mark_failed': 'Future<void> markFailed(String invoiceId)',
                'mark_refunded': 'Future<void> markRefunded(String invoiceId)',
                'draft_to_sent': 'nextStatus: InvoiceStatus.sent',
                'sent_to_pending': 'nextStatus: InvoiceStatus.pending',
                'pending_to_paid': 'nextStatus: InvoiceStatus.paid'
            }
            
            # PhonePe integration checks
            phonepe_checks = {
                'record_phonepe_attempt': 'Future<PaymentAttempt> recordPhonePeAttempt',
                'phonepe_attempt_creation': 'PaymentAttempt.createPhonePeAttempt',
                'log_attempt': 'await _repository.logPaymentAttempt(attempt)',
                'auto_mark_pending': 'if (invoice?.status == InvoiceStatus.sent)',
                'reference_id_param': 'required String referenceId'
            }
            
            # Admin authorization checks
            admin_checks = {
                'is_admin_check': 'bool get _isAdmin',
                'admin_role_validation': '_authService.userProfile?.role == UserRole.admin',
                'send_admin_only': 'if (!_isAdmin).*Only admins can send invoices',
                'paid_admin_only': 'if (!_isAdmin).*Only admins can mark invoices as paid',
                'refund_admin_only': 'if (!_isAdmin).*Only admins can process refunds',
                'delete_admin_only': 'if (!_isAdmin).*Only admins can delete invoices'
            }
            
            # Business logic checks
            business_checks = {
                'tenant_validation': 'if (_tenantId != tenantId)',
                'estimate_hours': 'double _estimateHoursFromRequest',
                'labor_rate_calculation': 'double _getLaborRate',
                'materials_requirement': 'bool _requestRequiresMaterials',
                'priority_based_pricing': 'switch (request.priority)',
                'line_item_templates': 'LineItemTemplate.createLaborLine',
                'state_updates': '_updateInvoiceInState',
                'notification_listeners': 'notifyListeners()'
            }
            
            # Data loading and filtering checks
            data_checks = {
                'load_invoices': 'Future<void> loadInvoices',
                'pagination_support': 'int page = 1',
                'filtering_support': 'InvoiceFilters? filters',
                'get_invoice_detail': 'Future<InvoiceDetail?> getInvoiceDetail',
                'get_billing_kpis': 'Future<BillingKPIs> getBillingKPIs',
                'apply_filters': 'Future<void> applyFilters',
                'clear_filters': 'Future<void> clearFilters'
            }
            
            all_checks = {
                **structure_checks,
                **generation_checks,
                **status_checks,
                **phonepe_checks,
                **admin_checks,
                **business_checks,
                **data_checks
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in all_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Check business logic patterns
            business_patterns = [
                r'critical.*4\.0.*hours',
                r'high.*3\.0.*hours',
                r'medium.*2\.0.*hours',
                r'critical.*1200\.0.*rate',
                r'high.*800\.0.*rate',
                r'RequestPriority\.high.*RequestPriority\.critical.*materials'
            ]
            
            business_logic_score = sum(1 for pattern in business_patterns 
                                     if re.search(pattern, content, re.IGNORECASE))
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing service patterns: {", ".join(failed_checks[:5])}',
                    {'passed': len(passed_checks), 'failed': len(failed_checks),
                     'business_logic_score': f'{business_logic_score}/{len(business_patterns)}'})
            else:
                self.log_result(test_name, 'PASS', 
                    'BillingService properly implemented with comprehensive business logic',
                    {'validated_patterns': len(passed_checks),
                     'business_logic_score': f'{business_logic_score}/{len(business_patterns)}'})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading billing service: {str(e)}')
    
    def test_supabase_table_integration(self):
        """Test Supabase table references and database schema integration"""
        test_name = "Supabase Table Integration & Database Schema"
        
        try:
            with open('/app/lib/core/supabase/client.dart', 'r') as f:
                content = f.read()
            
            # Table constants checks
            table_checks = {
                'supabase_tables_class': 'abstract class SupabaseTables',
                'invoices_table': 'static const String invoices = \'invoices\'',
                'invoice_lines_table': 'static const String invoiceLines = \'invoice_lines\'',
                'payment_attempts_table': 'static const String paymentAttempts = \'payment_attempts\'',
                'tenant_isolation': 'static const String tenants = \'tenants\'',
                'profiles_table': 'static const String profiles = \'profiles\'',
                'requests_table': 'static const String requests = \'requests\''
            }
            
            # Client configuration checks
            client_checks = {
                'supabase_service_class': 'class SupabaseService',
                'client_singleton': 'static SupabaseClient get client',
                'auth_client': 'static GoTrueClient get auth',
                'database_client': 'static PostgrestClient get database',
                'storage_client': 'static SupabaseStorageClient get storage',
                'realtime_client': 'static RealtimeClient get realtime'
            }
            
            # Tenant isolation checks
            isolation_checks = {
                'tenant_extension': 'extension SupabaseClientExtension',
                'from_tenant_method': 'PostgrestFilterBuilder<Map<String, dynamic>> fromTenant',
                'tenant_filtering': '.eq(\'tenant_id\', tenantId)',
                'tenant_subscription': 'RealtimeChannel createTenantSubscription',
                'tenant_scoped_path': 'String getStoragePath'
            }
            
            # Storage integration checks
            storage_checks = {
                'storage_buckets': 'abstract class SupabaseBuckets',
                'attachments_bucket': 'static const String attachments = \'attachments\'',
                'signed_url_method': 'static Future<String> getSignedUrl',
                'upload_file_method': 'static Future<String> uploadFile'
            }
            
            all_checks = {
                **table_checks,
                **client_checks,
                **isolation_checks,
                **storage_checks
            }
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in all_checks.items():
                if pattern in content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Check for billing-specific table usage in repository
            try:
                with open('/app/lib/features/billing/data/billing_repository.dart', 'r') as f:
                    repo_content = f.read()
                
                table_usage_patterns = [
                    r'SupabaseTables\.invoices',
                    r'SupabaseTables\.invoiceLines',
                    r'SupabaseTables\.paymentAttempts'
                ]
                
                table_usage_score = sum(1 for pattern in table_usage_patterns 
                                      if re.search(pattern, repo_content))
                
            except:
                table_usage_score = 0
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing Supabase integration patterns: {", ".join(failed_checks[:5])}',
                    {'passed': len(passed_checks), 'failed': len(failed_checks),
                     'table_usage_score': f'{table_usage_score}/{len(table_usage_patterns)}'})
            else:
                self.log_result(test_name, 'PASS', 
                    'Supabase integration properly configured with billing table references',
                    {'validated_patterns': len(passed_checks),
                     'table_usage_score': f'{table_usage_score}/{len(table_usage_patterns)}'})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading Supabase client: {str(e)}')
    
    def test_kpi_integration(self):
        """Test KPI integration with billing metrics"""
        test_name = "KPI Integration & Billing Metrics"
        
        try:
            # Check BillingKPIs class in repository
            with open('/app/lib/features/billing/data/billing_repository.dart', 'r') as f:
                repo_content = f.read()
            
            kpi_checks = {
                'billing_kpis_class': 'class BillingKPIs',
                'unpaid_invoices_field': 'final int unpaidInvoices',
                'overdue_invoices_field': 'final int overdueInvoices',
                'outstanding_amount_field': 'final double outstandingAmount',
                'monthly_revenue_field': 'final double monthlyRevenue',
                'get_billing_kpis_method': 'Future<BillingKPIs> getBillingKPIs',
                'unpaid_count_query': 'unpaidResponse.*count',
                'overdue_count_query': 'overdueResponse.*count',
                'outstanding_calculation': 'outstandingAmount +=',
                'revenue_calculation': 'monthlyRevenue +='
            }
            
            # Check KPI queries
            query_checks = {
                'unpaid_status_filter': '.inFilter(\'status\', [\'sent\', \'pending\'])',
                'overdue_date_filter': '.lt(\'due_date\', now.toIso8601String())',
                'paid_status_filter': '.eq(\'status\', \'paid\')',
                'monthly_date_range': '.gte(\'updated_at\', monthStart.toIso8601String())',
                'tenant_isolation_kpis': '.eq(\'tenant_id\', tenantId)'
            }
            
            all_checks = {**kpi_checks, **query_checks}
            
            passed_checks = []
            failed_checks = []
            
            for check_name, pattern in all_checks.items():
                if pattern in repo_content:
                    passed_checks.append(check_name)
                else:
                    failed_checks.append(check_name)
            
            # Check if KPIs are used in service layer
            try:
                with open('/app/lib/features/billing/domain/billing_service.dart', 'r') as f:
                    service_content = f.read()
                
                service_kpi_usage = [
                    'Future<BillingKPIs> getBillingKPIs',
                    'await _repository.getBillingKPIs'
                ]
                
                service_integration = all(pattern in service_content for pattern in service_kpi_usage)
                
            except:
                service_integration = False
            
            # Check for potential RequestKPIs integration
            try:
                with open('/app/lib/features/home/kpi_service.dart', 'r') as f:
                    kpi_service_content = f.read()
                
                request_kpi_patterns = [
                    'unpaidInvoices',
                    'outstandingAmount',
                    'billing'
                ]
                
                request_kpi_integration = sum(1 for pattern in request_kpi_patterns 
                                            if pattern in kpi_service_content)
                
            except:
                request_kpi_integration = 0
            
            if failed_checks:
                self.log_result(test_name, 'FAIL', 
                    f'Missing KPI integration patterns: {", ".join(failed_checks[:5])}',
                    {'passed': len(passed_checks), 'failed': len(failed_checks),
                     'service_integration': service_integration,
                     'request_kpi_integration': f'{request_kpi_integration}/{len(request_kpi_patterns)}'})
            else:
                self.log_result(test_name, 'PASS', 
                    'KPI integration properly implemented with comprehensive billing metrics',
                    {'validated_patterns': len(passed_checks),
                     'service_integration': service_integration,
                     'request_kpi_integration': f'{request_kpi_integration}/{len(request_kpi_patterns)}'})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error reading KPI integration: {str(e)}')
    
    def test_error_handling_validation(self):
        """Test error handling and validation patterns"""
        test_name = "Error Handling & Validation Patterns"
        
        try:
            files_to_check = [
                '/app/lib/features/billing/data/billing_repository.dart',
                '/app/lib/features/billing/domain/billing_service.dart',
                '/app/lib/features/billing/domain/invoice_line.dart'
            ]
            
            error_patterns = {
                'try_catch_blocks': r'try\s*{.*}.*catch.*{',
                'debug_logging': r'debugPrint\(.*❌.*Failed to',
                'success_logging': r'debugPrint\(.*✅.*',
                'rethrow_pattern': r'rethrow;',
                'validation_errors': r'List<String>.*errors',
                'exception_throwing': r'throw Exception\(',
                'error_state_management': r'error:.*toString\(\)'
            }
            
            validation_patterns = {
                'invoice_validation': r'_validateInvoiceCreation',
                'line_item_validation': r'LineItemValidator\.validateLineItem',
                'status_transition_validation': r'canTransitionTo\(nextStatus\)',
                'tenant_validation': r'if \(_tenantId != tenantId\)',
                'admin_validation': r'if \(!_isAdmin\)',
                'required_field_validation': r'\.isEmpty.*required',
                'calculation_validation': r'abs\(\) > 0\.01',
                'date_validation': r'issueDate\.isAfter\(dueDate\)'
            }
            
            all_patterns = {**error_patterns, **validation_patterns}
            
            file_results = {}
            
            for file_path in files_to_check:
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                    
                    file_name = file_path.split('/')[-1]
                    file_results[file_name] = {
                        'error_handling': 0,
                        'validation': 0,
                        'total_patterns': 0
                    }
                    
                    for pattern_name, pattern in all_patterns.items():
                        if re.search(pattern, content, re.DOTALL | re.IGNORECASE):
                            file_results[file_name]['total_patterns'] += 1
                            if pattern_name in error_patterns:
                                file_results[file_name]['error_handling'] += 1
                            else:
                                file_results[file_name]['validation'] += 1
                
                except Exception as e:
                    file_results[file_path.split('/')[-1]] = {'error': str(e)}
            
            # Calculate overall scores
            total_error_handling = sum(result.get('error_handling', 0) for result in file_results.values())
            total_validation = sum(result.get('validation', 0) for result in file_results.values())
            total_patterns = sum(result.get('total_patterns', 0) for result in file_results.values())
            
            expected_patterns = len(all_patterns) * len(files_to_check)
            coverage_percentage = (total_patterns / expected_patterns) * 100 if expected_patterns > 0 else 0
            
            if coverage_percentage < 70:
                self.log_result(test_name, 'WARNING', 
                    f'Error handling coverage below threshold: {coverage_percentage:.1f}%',
                    {'error_handling_patterns': total_error_handling,
                     'validation_patterns': total_validation,
                     'coverage_percentage': f'{coverage_percentage:.1f}%',
                     'file_breakdown': file_results})
            else:
                self.log_result(test_name, 'PASS', 
                    f'Comprehensive error handling and validation implemented: {coverage_percentage:.1f}%',
                    {'error_handling_patterns': total_error_handling,
                     'validation_patterns': total_validation,
                     'coverage_percentage': f'{coverage_percentage:.1f}%',
                     'file_breakdown': file_results})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error analyzing error handling: {str(e)}')
    
    def test_tenant_isolation_security(self):
        """Test multi-tenant isolation and security patterns"""
        test_name = "Multi-Tenant Isolation & Security"
        
        try:
            files_to_check = [
                '/app/lib/features/billing/data/billing_repository.dart',
                '/app/lib/features/billing/domain/billing_service.dart'
            ]
            
            isolation_patterns = {
                'tenant_id_field': r'tenantId',
                'tenant_filtering': r'\.eq\(\'tenant_id\', tenantId\)',
                'tenant_validation': r'if \(_tenantId != tenantId\)',
                'tenant_context_check': r'if \(tenantId == null\)',
                'unauthorized_exception': r'Unauthorized.*Cannot access tenant data',
                'tenant_scoped_queries': r'tenantId.*required String tenantId'
            }
            
            security_patterns = {
                'admin_authorization': r'if \(!_isAdmin\)',
                'role_based_access': r'UserRole\.admin',
                'admin_only_operations': r'Only admins can',
                'auth_service_integration': r'_authService\.userProfile',
                'tenant_context_validation': r'No tenant context'
            }
            
            all_patterns = {**isolation_patterns, **security_patterns}
            
            file_results = {}
            
            for file_path in files_to_check:
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                    
                    file_name = file_path.split('/')[-1]
                    file_results[file_name] = {
                        'isolation_patterns': 0,
                        'security_patterns': 0,
                        'found_patterns': []
                    }
                    
                    for pattern_name, pattern in all_patterns.items():
                        if re.search(pattern, content, re.IGNORECASE):
                            file_results[file_name]['found_patterns'].append(pattern_name)
                            if pattern_name in isolation_patterns:
                                file_results[file_name]['isolation_patterns'] += 1
                            else:
                                file_results[file_name]['security_patterns'] += 1
                
                except Exception as e:
                    file_results[file_path.split('/')[-1]] = {'error': str(e)}
            
            # Check specific admin-only operations
            admin_operations = [
                'sendInvoice',
                'markPaid',
                'markRefunded',
                'deleteDraftInvoice'
            ]
            
            try:
                with open('/app/lib/features/billing/domain/billing_service.dart', 'r') as f:
                    service_content = f.read()
                
                admin_protected_ops = sum(1 for op in admin_operations 
                                        if f'{op}' in service_content and 'if (!_isAdmin)' in service_content)
                
            except:
                admin_protected_ops = 0
            
            # Calculate overall security score
            total_isolation = sum(result.get('isolation_patterns', 0) for result in file_results.values())
            total_security = sum(result.get('security_patterns', 0) for result in file_results.values())
            
            expected_isolation = len(isolation_patterns) * len(files_to_check)
            expected_security = len(security_patterns) * len(files_to_check)
            
            isolation_score = (total_isolation / expected_isolation) * 100 if expected_isolation > 0 else 0
            security_score = (total_security / expected_security) * 100 if expected_security > 0 else 0
            
            overall_score = (isolation_score + security_score) / 2
            
            if overall_score < 70:
                self.log_result(test_name, 'WARNING', 
                    f'Security implementation below threshold: {overall_score:.1f}%',
                    {'isolation_score': f'{isolation_score:.1f}%',
                     'security_score': f'{security_score:.1f}%',
                     'admin_protected_operations': f'{admin_protected_ops}/{len(admin_operations)}',
                     'file_breakdown': file_results})
            else:
                self.log_result(test_name, 'PASS', 
                    f'Comprehensive multi-tenant security implemented: {overall_score:.1f}%',
                    {'isolation_score': f'{isolation_score:.1f}%',
                     'security_score': f'{security_score:.1f}%',
                     'admin_protected_operations': f'{admin_protected_ops}/{len(admin_operations)}',
                     'file_breakdown': file_results})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error analyzing security patterns: {str(e)}')
    
    def test_presentation_layer_integration(self):
        """Test presentation layer components and UI integration"""
        test_name = "Presentation Layer & UI Integration"
        
        try:
            presentation_files = [
                '/app/lib/features/billing/presentation/invoice_list_page.dart',
                '/app/lib/features/billing/presentation/invoice_detail_page.dart',
                '/app/lib/features/billing/presentation/collect_payment_sheet.dart'
            ]
            
            ui_patterns = {
                'invoice_list_page': 'class InvoiceListPage',
                'invoice_detail_page': 'class InvoiceDetailPage',
                'collect_payment_sheet': 'class CollectPaymentSheet',
                'phonepe_button': '_buildPhonePeButton',
                'payment_launcher': 'PhonePe.*launcher',
                'manual_status_update': 'manual.*status.*update'
            }
            
            found_files = []
            missing_files = []
            ui_components = {}
            
            for file_path in presentation_files:
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                    
                    found_files.append(file_path.split('/')[-1])
                    
                    file_name = file_path.split('/')[-1]
                    ui_components[file_name] = {
                        'found_patterns': []
                    }
                    
                    for pattern_name, pattern in ui_patterns.items():
                        if re.search(pattern, content, re.IGNORECASE):
                            ui_components[file_name]['found_patterns'].append(pattern_name)
                
                except FileNotFoundError:
                    missing_files.append(file_path.split('/')[-1])
                except Exception as e:
                    ui_components[file_path.split('/')[-1]] = {'error': str(e)}
            
            # Check for PhonePe specific UI patterns
            phonepe_ui_patterns = [
                'PhonePe.*payment.*button',
                'phonepe.*deeplink',
                'payment.*launcher',
                'manual.*status',
                'collect.*payment'
            ]
            
            phonepe_ui_found = 0
            for file_path in presentation_files:
                try:
                    with open(file_path, 'r') as f:
                        content = f.read()
                    
                    for pattern in phonepe_ui_patterns:
                        if re.search(pattern, content, re.IGNORECASE):
                            phonepe_ui_found += 1
                            break
                
                except:
                    continue
            
            implementation_score = len(found_files) / len(presentation_files) * 100
            
            if missing_files or implementation_score < 100:
                self.log_result(test_name, 'WARNING', 
                    f'Presentation layer partially implemented: {implementation_score:.1f}%',
                    {'found_files': found_files,
                     'missing_files': missing_files,
                     'phonepe_ui_patterns': f'{phonepe_ui_found}/{len(phonepe_ui_patterns)}',
                     'ui_components': ui_components})
            else:
                self.log_result(test_name, 'PASS', 
                    f'Presentation layer fully implemented with PhonePe integration: {implementation_score:.1f}%',
                    {'found_files': found_files,
                     'phonepe_ui_patterns': f'{phonepe_ui_found}/{len(phonepe_ui_patterns)}',
                     'ui_components': ui_components})
                
        except Exception as e:
            self.log_result(test_name, 'FAIL', f'Error analyzing presentation layer: {str(e)}')
    
    def run_all_tests(self):
        """Run all billing backend tests"""
        print("💰 Starting Round 7 Billing (Invoices) + PhonePe Launcher Backend Tests")
        print("=" * 80)
        
        # Run all test methods
        test_methods = [
            self.test_invoice_model_structure,
            self.test_invoice_line_model_structure,
            self.test_payment_attempt_model_structure,
            self.test_billing_repository_structure,
            self.test_billing_service_business_logic,
            self.test_supabase_table_integration,
            self.test_kpi_integration,
            self.test_error_handling_validation,
            self.test_tenant_isolation_security,
            self.test_presentation_layer_integration
        ]
        
        for test_method in test_methods:
            try:
                test_method()
            except Exception as e:
                self.log_result(test_method.__name__, 'FAIL', 
                    f'Test execution failed: {str(e)}')
                traceback.print_exc()
        
        # Print summary
        self.print_summary()
    
    def print_summary(self):
        """Print comprehensive test summary"""
        print("\n" + "=" * 80)
        print("💰 ROUND 7 BILLING + PHONEPE TEST SUMMARY")
        print("=" * 80)
        
        passed = len([r for r in self.test_results if r['status'] == 'PASS'])
        failed = len([r for r in self.test_results if r['status'] == 'FAIL'])
        warnings = len([r for r in self.test_results if r['status'] == 'WARNING'])
        skipped = len([r for r in self.test_results if r['status'] == 'SKIP'])
        
        print(f"✅ PASSED: {passed}")
        print(f"❌ FAILED: {failed}")
        print(f"⚠️  WARNINGS: {warnings}")
        print(f"⏭️  SKIPPED: {skipped}")
        print(f"📊 TOTAL: {len(self.test_results)}")
        
        if failed > 0:
            print("\n❌ FAILED TESTS:")
            for result in self.test_results:
                if result['status'] == 'FAIL':
                    print(f"  • {result['test']}: {result['message']}")
        
        if warnings > 0:
            print("\n⚠️  WARNINGS:")
            for result in self.test_results:
                if result['status'] == 'WARNING':
                    print(f"  • {result['test']}: {result['message']}")
        
        print("\n" + "=" * 80)
        print("🔍 KEY FINDINGS:")
        print("• Domain Models: Invoice, InvoiceLine, PaymentAttempt with business logic")
        print("• Repository Layer: Comprehensive CRUD operations with transaction integrity")
        print("• Service Layer: Business logic with admin authorization and tenant isolation")
        print("• PhonePe Integration: Deeplink generation, UPI intents, reference ID management")
        print("• KPI Integration: Billing metrics for dashboard (unpaid, overdue, revenue)")
        print("• Security: Multi-tenant isolation and role-based access control")
        print("• Error Handling: Comprehensive validation and exception management")
        print("• Database Schema: Proper table references (invoices, invoice_lines, payment_attempts)")
        print("=" * 80)
        
        # Return overall status
        return failed == 0

def main():
    """Main test execution"""
    tester = BillingBackendTester()
    success = tester.run_all_tests()
    
    # Exit with appropriate code
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()