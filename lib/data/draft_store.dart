import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class DraftStore {
  Future<void> saveDraft({
    required String key,
    required Map<String, dynamic> payload,
  });

  Future<Map<String, dynamic>?> restoreDraft({required String key});

  Future<void> clearDraft({required String key});
}

class SharedPreferencesDraftStore implements DraftStore {
  const SharedPreferencesDraftStore({this.namespace = 'caris_drafts'});

  final String namespace;

  @override
  Future<void> saveDraft({
    required String key,
    required Map<String, dynamic> payload,
  }) async {
    final encoded = jsonEncode(payload);
    if (encoded.length > 50000) {
      throw ArgumentError(
        'Draft exceeds shared_preferences safe payload size.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey(key), encoded);
  }

  @override
  Future<Map<String, dynamic>?> restoreDraft({required String key}) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_storageKey(key));
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(encoded);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return null;
  }

  @override
  Future<void> clearDraft({required String key}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey(key));
  }

  String _storageKey(String key) => '$namespace:$key';
}
