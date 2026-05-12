import 'package:cloudy_log/domain/goal_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goalStatusFor', () {
    test('reaches goal at exactly the goal count', () {
      expect(goalStatusFor(35, 35), GoalStatus.reached);
    });

    test('reaches goal when exceeded', () {
      expect(goalStatusFor(50, 35), GoalStatus.reached);
    });

    test('close when at least half but under goal', () {
      expect(goalStatusFor(18, 35), GoalStatus.close);
      expect(goalStatusFor(34, 35), GoalStatus.close);
    });

    test('low when under half', () {
      expect(goalStatusFor(0, 35), GoalStatus.low);
      expect(goalStatusFor(17, 35), GoalStatus.low);
    });

    test('none when goal is not positive', () {
      expect(goalStatusFor(10, 0), GoalStatus.none);
      expect(goalStatusFor(10, -5), GoalStatus.none);
    });

    test('none when count is negative', () {
      expect(goalStatusFor(-1, 35), GoalStatus.none);
    });
  });
}
