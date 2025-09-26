import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../onboarding/domain/models/company.dart';
import '../domain/models/request.dart';
import '../domain/requests_service.dart';

/// Create request page for submitting new service requests
class CreateRequestPage extends ConsumerStatefulWidget {
  const CreateRequestPage({super.key});

  @override
  ConsumerState<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends ConsumerState<CreateRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  
  String? _selectedFacilityId;
  RequestType _selectedType = RequestType.onDemand;
  RequestPriority _selectedPriority = RequestPriority.standard;
  TimeWindow? _preferredWindow;
  
  List<Facility> _facilities = [];
  List<XFile> _selectedFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    try {
      final facilities = await ref.read(requestsServiceProvider).getFacilities();
      if (mounted) {
        setState(() {
          _facilities = facilities;
          if (facilities.isNotEmpty) {
            _selectedFacilityId = facilities.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to load facilities: ${e.toString()}');
      }
    }
  }

  Future<void> _pickFiles() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> files = await picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80,
      );
      
      if (files.isNotEmpty && mounted) {
        setState(() {
          _selectedFiles = [..._selectedFiles, ...files];
        });
      }
    } catch (e) {
      _showErrorMessage('Failed to pick images: ${e.toString()}');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _selectTimeWindow() async {
    final now = DateTime.now();
    final initialStartTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 2)));
    final initialEndTime = TimeOfDay.fromDateTime(now.add(const Duration(hours: 6)));
    
    final dateResult = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    
    if (dateResult == null || !mounted) return;
    
    final startTimeResult = await showTimePicker(
      context: context,
      initialTime: initialStartTime,
      helpText: 'Select start time',
    );
    
    if (startTimeResult == null || !mounted) return;
    
    final endTimeResult = await showTimePicker(
      context: context,
      initialTime: initialEndTime,
      helpText: 'Select end time',
    );
    
    if (endTimeResult == null || !mounted) return;
    
    final startDateTime = DateTime(
      dateResult.year,
      dateResult.month,
      dateResult.day,
      startTimeResult.hour,
      startTimeResult.minute,
    );
    
    final endDateTime = DateTime(
      dateResult.year,
      dateResult.month,
      dateResult.day,
      endTimeResult.hour,
      endTimeResult.minute,
    );
    
    if (endDateTime.isBefore(startDateTime)) {
      _showErrorMessage('End time must be after start time');
      return;
    }
    
    setState(() {
      _preferredWindow = TimeWindow(
        startTime: startDateTime,
        endTime: endDateTime,
      );
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _selectedFacilityId == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final requestsService = ref.read(requestsServiceProvider);
      
      final request = await requestsService.createRequest(
        facilityId: _selectedFacilityId!,
        type: _selectedType,
        priority: _selectedPriority,
        description: _descriptionController.text.trim(),
        preferredWindow: _preferredWindow,
      );
      
      if (mounted) {
        _showSuccessMessage('Request submitted successfully');
        context.go('/requests/${request.id}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('Failed to submit request: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Request'),
        leading: IconButton(
          onPressed: () => context.go('/requests'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    _buildHeader(),
                    
                    const SizedBox(height: AppTheme.spacingL),
                    
                    // Facility selection
                    _buildFacilityDropdown(),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Type and priority
                    Row(
                      children: [
                        Expanded(child: _buildTypeSelection()),
                        const SizedBox(width: AppTheme.spacingM),
                        Expanded(child: _buildPrioritySelection()),
                      ],
                    ),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Description
                    _buildDescriptionField(),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // Preferred time window
                    _buildTimeWindowSection(),
                    
                    const SizedBox(height: AppTheme.spacingM),
                    
                    // File attachments
                    _buildFileAttachments(),
                    
                    const SizedBox(height: AppTheme.spacingL),
                    
                    // SLA info card
                    if (_selectedPriority == RequestPriority.critical)
                      _buildSlaInfoCard(),
                  ],
                ),
              ),
            ),
            
            // Submit button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Request Details',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacingS),
        Text(
          'Provide details about the HVAC/R service you need.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildFacilityDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedFacilityId,
      decoration: const InputDecoration(
        labelText: 'Facility *',
        prefixIcon: Icon(Icons.location_city),
      ),
      items: _facilities.map((facility) {
        return DropdownMenuItem(
          value: facility.id,
          child: Text(facility.name),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedFacilityId = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a facility';
        }
        return null;
      },
    );
  }

  Widget _buildTypeSelection() {
    return DropdownButtonFormField<RequestType>(
      value: _selectedType,
      decoration: const InputDecoration(
        labelText: 'Request Type',
        prefixIcon: Icon(Icons.category),
      ),
      items: RequestType.values.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(type.displayName),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedType = value);
        }
      },
    );
  }

  Widget _buildPrioritySelection() {
    return DropdownButtonFormField<RequestPriority>(
      value: _selectedPriority,
      decoration: const InputDecoration(
        labelText: 'Priority',
        prefixIcon: Icon(Icons.priority_high),
      ),
      items: RequestPriority.values.map((priority) {
        return DropdownMenuItem(
          value: priority,
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priority == RequestPriority.critical 
                      ? Colors.red 
                      : Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(priority.displayName),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedPriority = value);
        }
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      decoration: const InputDecoration(
        labelText: 'Description *',
        hintText: 'Describe the service issue or requirement in detail',
        prefixIcon: Icon(Icons.description),
        alignLabelWithHint: true,
      ),
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please provide a description';
        }
        if (value.trim().length < 10) {
          return 'Description must be at least 10 characters';
        }
        return null;
      },
    );
  }

  Widget _buildTimeWindowSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.schedule,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Preferred Time Window (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        
        if (_preferredWindow != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Time Window:',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: AppTheme.spacingXS),
                        Text(
                          '${_formatDateTime(_preferredWindow!.startTime)} - ${_formatTime(_preferredWindow!.endTime)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _preferredWindow = null),
                    icon: const Icon(Icons.clear),
                    tooltip: 'Remove time window',
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          OutlinedButton.icon(
            onPressed: _selectTimeWindow,
            icon: const Icon(Icons.access_time),
            label: const Text('Set Preferred Time'),
          ),
        ],
      ],
    );
  }

  Widget _buildFileAttachments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.attach_file,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              'Attachments (Optional)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        
        if (_selectedFiles.isNotEmpty) ...[
          ...List.generate(_selectedFiles.length, (index) {
            final file = _selectedFiles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
              child: ListTile(
                leading: const Icon(Icons.image),
                title: Text(file.name),
                trailing: IconButton(
                  onPressed: () => _removeFile(index),
                  icon: const Icon(Icons.delete),
                ),
              ),
            );
          }),
        ],
        
        OutlinedButton.icon(
          onPressed: _pickFiles,
          icon: const Icon(Icons.add_a_photo),
          label: const Text('Add Photos'),
        ),
      ],
    );
  }

  Widget _buildSlaInfoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Critical Priority SLA',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'This request will be assigned a 6-hour service level agreement (SLA) and must be addressed within this timeframe.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: FilledButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Submit Request'),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatDate(dateTime)} at ${_formatTime(dateTime)}';
  }

  String _formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Today';
    } else if (date == tomorrow) {
      return 'Tomorrow';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}