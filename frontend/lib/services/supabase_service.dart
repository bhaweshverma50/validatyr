import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    final response = await _client
        .from('validations')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<void> insert(String idea, Map<String, dynamic> result) async {
    await _client.from('validations').insert({
      'idea': idea,
      'opportunity_score': result['opportunity_score'] ?? 0,
      'score_breakdown': result['score_breakdown'] ?? {},
      'what_users_love': result['what_users_love'] ?? [],
      'what_users_hate': result['what_users_hate'] ?? [],
      'mvp_roadmap': result['mvp_roadmap'] ?? [],
      'pricing_suggestion': result['pricing_suggestion'] ?? '',
      'target_os_recommendation': result['target_os_recommendation'] ?? result['target_platform_recommendation'] ?? '',
      'market_breakdown': result['market_breakdown'] ?? '',
      'community_signals': result['community_signals'] ?? [],
      'competitors_analyzed': result['competitors_analyzed'] ?? [],
      // New founder intel fields:
      'category': result['category'] ?? 'mobile_app',
      'subcategory': result['subcategory'] ?? '',
      'tam': result['tam'] ?? '',
      'sam': result['sam'] ?? '',
      'som': result['som'] ?? '',
      'revenue_model_options': result['revenue_model_options'] ?? [],
      'top_funded_competitors': result['top_funded_competitors'] ?? [],
      'funding_landscape': result['funding_landscape'] ?? '',
      'go_to_market_strategy': result['go_to_market_strategy'] ?? '',
    });
  }

  static Future<void> delete(dynamic id) async {
    await _client.from('validations').delete().eq('id', id);
  }

  static Future<void> deleteAll() async {
    // bigserial IDs are always > 0 — use as filter to satisfy Supabase DELETE requirement
    await _client.from('validations').delete().gte('id', 0);
  }
}
