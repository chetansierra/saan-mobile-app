import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/models/request.dart';

/// Visual timeline showing request status progression
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.currentStatus,
    this.isCompact = false,
  });

  final RequestStatus currentStatus;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final steps = RequestStatus.values;
    final currentIndex = steps.indexOf(currentStatus);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isCompact) ...[
          Text(
            'Status Progress',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
        ],
        
        ...List.generate(steps.length, (index) {
          final status = steps[index];
          final isCompleted = index <= currentIndex;
          final isCurrent = index == currentIndex;
          final isLast = index == steps.length - 1;

          return _buildTimelineStep(
            context,
            status: status,
            isCompleted: isCompleted,
            isCurrent: isCurrent,
            isLast: isLast,
            isCompact: isCompact,
          );
        }),
      ],
    );
  }

  Widget _buildTimelineStep(
    BuildContext context, {
    required RequestStatus status,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
    required bool isCompact,
  }) {
    final statusColor = Color(int.parse('0xFF${status.colorHex.substring(1)}'));
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline indicator
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isCompleted ? statusColor : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? statusColor : Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isCompleted
                  ? Icon(
                      isCurrent ? Icons.radio_button_checked : Icons.check,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (!isLast) ...[
              Container(
                width: 2,
                height: isCompact ? 20 : 32,
                color: isCompleted 
                    ? statusColor.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
              ),
            ],
          ],
        ),
        
        const SizedBox(width: AppTheme.spacingM),
        
        // Status info
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : (isCompact ? 8 : 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                    color: isCompleted
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                if (!isCompact && _getStatusDescription(status).isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacingXS),
                  Text(
                    _getStatusDescription(status),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getStatusDescription(RequestStatus status) {
    switch (status) {
      case RequestStatus.newRequest:
        return 'Request submitted and awaiting review';
      case RequestStatus.triaged:
        return 'Request reviewed and prioritized';
      case RequestStatus.assigned:
        return 'Engineer assigned to handle request';
      case RequestStatus.enRoute:
        return 'Engineer traveling to location';
      case RequestStatus.onSite:
        return 'Engineer working on-site';
      case RequestStatus.completed:
        return 'Work completed, awaiting verification';
      case RequestStatus.verified:
        return 'Request closed and verified';
    }
  }
}

/// Compact horizontal timeline for smaller spaces
class CompactStatusTimeline extends StatelessWidget {
  const CompactStatusTimeline({
    super.key,
    required this.currentStatus,
  });

  final RequestStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    final steps = RequestStatus.values;
    final currentIndex = steps.indexOf(currentStatus);
    final progressPercent = (currentIndex + 1) / steps.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentStatus.displayName,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${currentIndex + 1}/${steps.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingS),
        LinearProgressIndicator(
          value: progressPercent,
          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          valueColor: AlwaysStoppedAnimation<Color>(
            Color(int.parse('0xFF${currentStatus.colorHex.substring(1)}')),
          ),
        ),
      ],
    );
  }
}