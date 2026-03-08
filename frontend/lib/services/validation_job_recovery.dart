Map<String, dynamic>? matchActiveValidationJob(
  List<Map<String, dynamic>> jobs, {
  required String idea,
  String? category,
}) {
  final normalizedIdea = idea.trim().toLowerCase();
  if (normalizedIdea.isEmpty) return null;

  final exactIdeaMatches = jobs.where((job) {
    final jobIdea = (job['idea'] as String? ?? '').trim().toLowerCase();
    return jobIdea == normalizedIdea;
  }).toList();

  if (exactIdeaMatches.isEmpty) return null;

  final exactCategoryMatches = exactIdeaMatches.where((job) {
    return (job['category'] as String?) == category;
  }).toList();

  final candidates = exactCategoryMatches.isNotEmpty
      ? exactCategoryMatches
      : exactIdeaMatches;

  candidates.sort((a, b) {
    final aTime = DateTime.tryParse(a['created_at'] as String? ?? '');
    final bTime = DateTime.tryParse(b['created_at'] as String? ?? '');
    return (bTime ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
      aTime ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  });

  return candidates.first;
}

bool shouldKeepHistoryRefreshing({
  required bool hasRunningJobs,
  required DateTime? lastRunningSeenAt,
  required DateTime now,
  Duration graceWindow = const Duration(seconds: 20),
}) {
  if (hasRunningJobs) return true;
  if (lastRunningSeenAt == null) return false;
  return now.difference(lastRunningSeenAt) <= graceWindow;
}
