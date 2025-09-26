import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme.dart';
import '../../domain/models/request.dart';

/// SLA countdown badge with color-coded status and breach alerts
class SLABadge extends StatefulWidget {
  const SLABadge({
    super.key,
    required this.slaDueAt,
    this.showBreachAlert = false,
    this.size = SLABadgeSize.normal,
  });

  final DateTime? slaDueAt;
  final bool showBreachAlert;
  final SLABadgeSize size;

  @override
  State<SLABadge> createState() => _SLABadgeState();
}

class _SLABadgeState extends State<SLABadge> {
  Timer? _timer;
  Duration? _timeRemaining;
  SlaStatus _slaStatus = SlaStatus.none;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    
    // Update every minute if SLA is active
    if (widget.slaDueAt != null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) _updateCountdown();
      });
    }
  }

  @override
  void didUpdateWidget(SLABadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.slaDueAt != oldWidget.slaDueAt) {
      _timer?.cancel();
      
      if (widget.slaDueAt != null) {
        _updateCountdown();
        _timer = Timer.periodic(const Duration(minutes: 1), (_) {
          if (mounted) _updateCountdown();
        });
      } else {
        _timer = null;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    if (widget.slaDueAt == null) {
      setState(() {
        _timeRemaining = null;
        _slaStatus = SlaStatus.none;
      });
      return;
    }

    setState(() {
      _timeRemaining = SlaUtils.timeUntilSlaBreach(widget.slaDueAt);
      _slaStatus = SlaUtils.getSlaStatus(widget.slaDueAt);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slaDueAt == null) {
      return const SizedBox.shrink();
    }

    final color = Color(int.parse('0xFF${_slaStatus.colorHex.substring(1)}'));
    final timeText = SlaUtils.formatTimeRemaining(_timeRemaining);
    final isOverdue = _slaStatus == SlaStatus.critical;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // SLA Badge
        _buildSLABadge(context, color, timeText, isOverdue),
        
        // Breach Alert Banner
        if (widget.showBreachAlert && isOverdue) ...[
          const SizedBox(height: AppTheme.spacingS),
          _buildBreachAlert(context),
        ],
      ],
    );
  }

  Widget _buildSLABadge(BuildContext context, Color color, String timeText, bool isOverdue) {
    final badgeSize = widget.size;
    final iconSize = badgeSize == SLABadgeSize.large ? 20.0 : 16.0;
    final fontSize = badgeSize == SLABadgeSize.large ? 14.0 : 12.0;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: badgeSize == SLABadgeSize.small ? AppTheme.spacingS : AppTheme.spacingM,
        vertical: badgeSize == SLABadgeSize.small ? AppTheme.spacingXS : AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          badgeSize == SLABadgeSize.large ? AppTheme.radiusM : AppTheme.radiusS,
        ),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: isOverdue ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.schedule,
            size: iconSize,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacingXS),
          Text(
            'SLA: $timeText',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
          if (badgeSize == SLABadgeSize.large && widget.slaDueAt != null) ...[
            const SizedBox(width: AppTheme.spacingS),
            Text(
              '• Due ${DateFormat('MMM dd, HH:mm').format(widget.slaDueAt!)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color.withOpacity(0.8),
                fontSize: fontSize - 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreachAlert(BuildContext context) {
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
            Icons.warning,
            color: Theme.of(context).colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SLA Breach Alert',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXS),
                Text(
                  'This critical request has exceeded its 6-hour service level agreement. Immediate attention required.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// SLA badge size variations
enum SLABadgeSize {
  small,
  normal,
  large;
}

/// Standalone SLA info widget for request cards
class SLAInfo extends StatelessWidget {
  const SLAInfo({
    super.key,
    required this.slaDueAt,
    this.priority,
  });

  final DateTime? slaDueAt;
  final RequestPriority? priority;

  @override
  Widget build(BuildContext context) {
    // Only show for critical requests with SLA
    if (slaDueAt == null || priority != RequestPriority.critical) {
      return const SizedBox.shrink();
    }

    return SLABadge(
      slaDueAt: slaDueAt,
      size: SLABadgeSize.small,
    );
  }
}