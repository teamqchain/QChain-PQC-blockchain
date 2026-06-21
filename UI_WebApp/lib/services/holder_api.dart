import 'dart:convert';
import 'package:qportal_webapp/models/holder_model.dart';
import 'package:qportal_webapp/services/core_api.dart';
import 'package:qportal_webapp/utils/webApp_config.dart';
import 'package:qportal_webapp/utils/logger.dart';

class HolderApi {
  // GET /getHolders
  static Future<List<HolderRecord>> getHolders({String search = ''}) async {
    logDebug('[HolderApi] getHolders called with search term: "$search"');
    if (!await ApiCore.ensureConnection()) {
      logDebug('[HolderApi] getHolders blocked: backend disconnected');
      throw ConnectionException();
    }
    try {
      final res = await ApiCore.client.get(
        Uri.parse('$kApiBaseUrl/getHolders').replace(
          queryParameters: search.isNotEmpty ? {'search': search} : null,
        ),
      );
      if (res.statusCode != 200) {
        logDebug('[HolderApi] getHolders failed: HTTP ${res.statusCode}');
        return [];
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = body['holders'] as List? ?? [];
      logDebug(
        '[HolderApi] getHolders success: fetched ${list.length} holders',
      );

      return list
          .map((e) => HolderRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      logDebug('[HolderApi] getHolders exception: $e');
      throw ConnectionException();
    }
  }
}
