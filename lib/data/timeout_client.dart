import 'package:http/http.dart' as http;

/// An http client that gives up rather than hanging forever.
///
/// There was no timeout anywhere in the app: a request that never answered left
/// a spinner turning indefinitely, with no way back except a browser reload.
/// Applying it here rather than at ~110 call sites means every PostgREST,
/// GoTrue and Storage call inherits it — `Supabase.initialize(httpClient: …)`.
class TimeoutClient extends http.BaseClient {
  TimeoutClient({http.Client? inner, this.timeout = const Duration(seconds: 20)})
    : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(timeout);

  @override
  void close() => _inner.close();
}
