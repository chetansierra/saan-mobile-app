import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../auth/domain/auth_service.dart';
import '../../onboarding/domain/models/company.dart';
import '../domain/contracts_service.dart';
import '../domain/contract.dart';

/// Create contract page with multi-step form
class CreateContractPage extends ConsumerStatefulWidget {
  const CreateContractPage({super.key});

  @override
  ConsumerState<CreateContractPage> createState() => _CreateContractPageState();
}

class _CreateContractPageState extends ConsumerState<CreateContractPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Form controllers
  final _titleController = TextEditingController();
  final _serviceTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _precedenceController = TextEditingController(text: '0');
  final _criticalSlaController = TextEditingController();
  final _standardSlaController = TextEditingController();

  // Form state
  ContractType _contractType = ContractType.amc;
  PMFrequency _pmFrequency = PMFrequency.monthly;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 365));
  List<String> _selectedFacilityIds = [];
  List<Facility> _availableFacilities = [];
  List<DocumentUpload> _documents = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _serviceTypeController.dispose();
    _descriptionController.dispose();
    _precedenceController.dispose();
    _criticalSlaController.dispose();
    _standardSlaController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    try {
      final facilities = await ref.read(contractsServiceProvider).getFacilities();
      setState(() {
        _availableFacilities = facilities;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load facilities: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Contract'),
        leading: IconButton(
          onPressed: () => context.go('/contracts'),
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          TextButton(
            onPressed: _currentStep > 0 ? _previousStep : null,
            child: Text(
              'Back',
              style: TextStyle(
                color: _currentStep > 0 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),
          
          // Form content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildContractDetailsStep(),
                _buildFacilitySelectionStep(),
                _buildSLAConfigurationStep(),
                _buildDocumentUploadStep(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(
                right: index < _totalSteps - 1 ? AppTheme.spacingS : 0,
              ),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: isCompleted || isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    _getStepTitle(index),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isCompleted || isCurrent
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0: return 'Details';
      case 1: return 'Facilities';
      case 2: return 'SLA';
      case 3: return 'Documents';
      default: return '';
    }
  }

  Widget _buildContractDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contract Details',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Contract Title
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Contract Title *',
              hintText: 'Enter contract name',
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Contract Type
          Text(
            'Contract Type *',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Row(
            children: ContractType.values.map((type) {
              return Expanded(
                child: RadioListTile<ContractType>(
                  title: Text(type.shortName),
                  subtitle: Text(type.displayName),
                  value: type,
                  groupValue: _contractType,
                  onChanged: (value) {
                    setState(() {
                      _contractType = value!;
                    });
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Service Type
          TextFormField(
            controller: _serviceTypeController,
            decoration: const InputDecoration(
              labelText: 'Service Type *',
              hintText: 'e.g., HVAC, Electrical, Plumbing',
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Date Range
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectStartDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Start Date *',
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_startDate),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: InkWell(
                  onTap: _selectEndDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'End Date *',
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_endDate),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // PM Frequency
          DropdownButtonFormField<PMFrequency>(
            value: _pmFrequency,
            decoration: const InputDecoration(
              labelText: 'PM Frequency *',
            ),
            items: PMFrequency.values.map((frequency) {
              return DropdownMenuItem(
                value: frequency,
                child: Text(frequency.displayName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _pmFrequency = value!;
              });
            },
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Optional contract description',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Precedence
          TextFormField(
            controller: _precedenceController,
            decoration: const InputDecoration(
              labelText: 'Precedence',
              hintText: 'Priority order (0 = default)',
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitySelectionStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Facilities',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Choose which facilities this contract covers.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _availableFacilities.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
                  itemCount: _availableFacilities.length,
                  itemBuilder: (context, index) {
                    final facility = _availableFacilities[index];
                    final isSelected = _selectedFacilityIds.contains(facility.id);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
                      child: CheckboxListTile(
                        title: Text(facility.name),
                        subtitle: facility.address != null
                            ? Text(facility.address!)
                            : null,
                        value: isSelected,
                        onChanged: (selected) {
                          setState(() {
                            if (selected ?? false) {
                              _selectedFacilityIds.add(facility.id!);
                            } else {
                              _selectedFacilityIds.remove(facility.id!);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSLAConfigurationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SLA Configuration',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Define custom SLA hours that will override default values for requests under this contract.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Critical SLA
          TextFormField(
            controller: _criticalSlaController,
            decoration: const InputDecoration(
              labelText: 'Critical SLA (hours)',
              hintText: 'e.g., 4 (overrides default 6h)',
              helperText: 'Leave empty to use default 6 hours',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // Standard SLA
          TextFormField(
            controller: _standardSlaController,
            decoration: const InputDecoration(
              labelText: 'Standard SLA (hours)',
              hintText: 'e.g., 24',
              helperText: 'Leave empty for no SLA on standard requests',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppTheme.spacingL),
          
          // SLA Info
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      'SLA Override Rules',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  '• Contract SLA overrides default values when active\n'
                  '• Multiple contracts use precedence for tie-breaking\n'
                  '• Critical SLA should be shorter than Standard SLA',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadStep() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contract Documents',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppTheme.spacingS),
              Text(
                'Upload contract documents (PDF format recommended).',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _documents.isEmpty
              ? _buildDocumentUploadEmpty()
              : _buildDocumentList(),
        ),
      ],
    );
  }

  Widget _buildDocumentUploadEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.upload_file,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: AppTheme.spacingL),
          Text(
            'No Documents Added',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            'Add contract documents, terms, or service agreements.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacingL),
          FilledButton.icon(
            onPressed: _pickDocument,
            icon: const Icon(Icons.add),
            label: const Text('Add Document'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingL),
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final document = _documents[index];
              return _buildDocumentCard(document, index);
            },
          ),
        ),
        
        Padding(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          child: OutlinedButton.icon(
            onPressed: _pickDocument,
            icon: const Icon(Icons.add),
            label: const Text('Add Another Document'),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(DocumentUpload document, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(document.filename),
        subtitle: Text('${(document.bytes.length / 1024).ceil()} KB'),
        trailing: IconButton(
          onPressed: () => _removeDocument(index),
          icon: const Icon(Icons.delete),
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      padding: EdgeInsets.only(
        left: AppTheme.spacingL,
        right: AppTheme.spacingL,
        top: AppTheme.spacingM,
        bottom: MediaQuery.of(context).padding.bottom + AppTheme.spacingM,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentStep < _totalSteps - 1) ...[
            Expanded(
              child: FilledButton(
                onPressed: _canProceedToNextStep() ? _nextStep : null,
                child: Text('Continue'),
              ),
            ),
          ] else ...[
            Expanded(
              child: FilledButton(
                onPressed: _canCreateContract() && !_isLoading ? _createContract : null,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Contract'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _canProceedToNextStep() {
    switch (_currentStep) {
      case 0: // Details
        return _titleController.text.trim().isNotEmpty &&
               _serviceTypeController.text.trim().isNotEmpty;
      case 1: // Facilities
        return _selectedFacilityIds.isNotEmpty;
      case 2: // SLA
        return true; // Optional step
      case 3: // Documents
        return true; // Optional step
      default:
        return false;
    }
  }

  bool _canCreateContract() {
    return _titleController.text.trim().isNotEmpty &&
           _serviceTypeController.text.trim().isNotEmpty &&
           _selectedFacilityIds.isNotEmpty;
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Ensure end date is after start date
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 365));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _documents.add(DocumentUpload(
              filename: file.name,
              bytes: file.bytes!,
            ));
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick document: $e')),
      );
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  Future<void> _createContract() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Parse SLA values
      Duration? criticalSla;
      Duration? standardSla;
      
      if (_criticalSlaController.text.trim().isNotEmpty) {
        final hours = int.tryParse(_criticalSlaController.text.trim());
        if (hours != null && hours > 0) {
          criticalSla = Duration(hours: hours);
        }
      }
      
      if (_standardSlaController.text.trim().isNotEmpty) {
        final hours = int.tryParse(_standardSlaController.text.trim());
        if (hours != null && hours > 0) {
          standardSla = Duration(hours: hours);
        }
      }

      // Create contract input
      final contractInput = ContractInput(
        title: _titleController.text.trim(),
        contractType: _contractType,
        serviceType: _serviceTypeController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        pmFrequency: _pmFrequency,
        criticalSlaDuration: criticalSla,
        standardSlaDuration: standardSla,
        precedence: int.tryParse(_precedenceController.text.trim()) ?? 0,
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        facilityIds: _selectedFacilityIds,
      );

      // Validate input
      final contractsService = ref.read(contractsServiceProvider);
      final validationErrors = contractsService.validateContractInput(contractInput);
      
      if (validationErrors.isNotEmpty) {
        setState(() {
          _error = validationErrors.first;
          _isLoading = false;
        });
        return;
      }

      // Create contract
      final contract = await contractsService.createContract(contractInput);

      // Upload documents
      for (final document in _documents) {
        await contractsService.uploadContractDocument(
          contractId: contract.id!,
          filename: document.filename,
          bytes: document.bytes,
        );
      }

      // Navigate to contract detail
      if (mounted) {
        context.go('/contracts/${contract.id}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}

/// Document upload model
class DocumentUpload {
  const DocumentUpload({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final Uint8List bytes;
}