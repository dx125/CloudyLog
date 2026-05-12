import 'package:flutter/material.dart';

import '../../domain/goal_status.dart';

Color colorForStatus(GoalStatus status) {
  switch (status) {
    case GoalStatus.reached:
      return Colors.green.shade600;
    case GoalStatus.close:
      return Colors.orange.shade700;
    case GoalStatus.low:
      return Colors.red.shade600;
    case GoalStatus.none:
      return Colors.transparent;
  }
}
