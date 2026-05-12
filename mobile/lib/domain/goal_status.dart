/// Pure domain rule: classifies a daily count against the configured goal.
/// Presentation-agnostic so the same thresholds apply to any renderer (and
/// later, the backend).
enum GoalStatus { reached, close, low, none }

GoalStatus goalStatusFor(int count, int goal) {
  if (goal <= 0 || count < 0) return GoalStatus.none;
  if (count >= goal) return GoalStatus.reached;
  return count / goal >= 0.5 ? GoalStatus.close : GoalStatus.low;
}
