import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/validation_job_recovery.dart';

void main() {
  group('matchActiveValidationJob', () {
    test('prefers exact idea and category match', () {
      final jobs = [
        {
          'id': 'older',
          'idea': 'AI meal planner',
          'category': 'saas_web',
          'created_at': '2026-03-08T10:00:00Z',
        },
        {
          'id': 'best',
          'idea': 'AI meal planner',
          'category': 'mobile_app',
          'created_at': '2026-03-08T10:01:00Z',
        },
      ];

      final match = matchActiveValidationJob(
        jobs,
        idea: 'AI meal planner',
        category: 'mobile_app',
      );

      expect(match?['id'], 'best');
    });

    test('falls back to newest exact idea match when category differs', () {
      final jobs = [
        {
          'id': 'old',
          'idea': 'Dog walking app',
          'category': 'mobile_app',
          'created_at': '2026-03-08T10:00:00Z',
        },
        {
          'id': 'new',
          'idea': 'Dog walking app',
          'category': 'saas_web',
          'created_at': '2026-03-08T10:05:00Z',
        },
      ];

      final match = matchActiveValidationJob(
        jobs,
        idea: 'Dog walking app',
        category: 'hardware',
      );

      expect(match?['id'], 'new');
    });

    test('returns null when there is no exact idea match', () {
      final jobs = [
        {
          'id': 'different',
          'idea': 'Receipt scanner',
          'category': 'mobile_app',
          'created_at': '2026-03-08T10:00:00Z',
        },
      ];

      final match = matchActiveValidationJob(
        jobs,
        idea: 'Parking finder',
        category: 'mobile_app',
      );

      expect(match, isNull);
    });
  });

  group('shouldKeepHistoryRefreshing', () {
    test('returns true while jobs are still running', () {
      expect(
        shouldKeepHistoryRefreshing(
          hasRunningJobs: true,
          lastRunningSeenAt: null,
          now: DateTime(2026, 3, 8, 12),
        ),
        isTrue,
      );
    });

    test('returns true during the grace window after jobs disappear', () {
      final now = DateTime(2026, 3, 8, 12, 0, 30);
      expect(
        shouldKeepHistoryRefreshing(
          hasRunningJobs: false,
          lastRunningSeenAt: DateTime(2026, 3, 8, 12, 0, 20),
          now: now,
        ),
        isTrue,
      );
    });

    test('returns false after the grace window expires', () {
      final now = DateTime(2026, 3, 8, 12, 1, 0);
      expect(
        shouldKeepHistoryRefreshing(
          hasRunningJobs: false,
          lastRunningSeenAt: DateTime(2026, 3, 8, 12, 0, 20),
          now: now,
        ),
        isFalse,
      );
    });
  });
}
