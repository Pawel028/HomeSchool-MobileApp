import 'package:homeschooling/core/api_client.dart';
import 'package:homeschooling/core/auth_tokens.dart';
import 'package:homeschooling/models/remote_config.dart';

class ConfigRepository {
  ConfigRepository(this._api);

  final ApiClient _api;

  Future<RemoteConfig> fetch() async {
    final Object? data = await _api.get('/v1/config', auth: AuthKind.none);
    return parseObject(data, RemoteConfig.fromJson);
  }
}
