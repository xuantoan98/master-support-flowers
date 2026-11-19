import 'dart:async';
import 'dart:convert';
import 'dart:io';

class AddressSuggestion {
  const AddressSuggestion({
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  /// Full address as named by the map service; used verbatim when picked.
  final String description;
  final String mainText;
  final String secondaryText;
}

abstract interface class AddressSuggester {
  /// Suggestions for what the user typed. Throws on network failure so the UI
  /// can tell "no match" apart from "could not reach the service".
  Future<List<AddressSuggestion>> suggest(String input);
}

/// Goong Place AutoComplete (https://docs.goong.io/rest/place/).
///
/// Only the typed address text is sent; customer name/phone never leave the
/// device. The key comes from `--dart-define=GOONG_API_KEY=...` at build time.
class GoongAddressSuggester implements AddressSuggester {
  GoongAddressSuggester(this.apiKey, {HttpClient? client})
    : _client = client ?? HttpClient();

  static const _key = String.fromEnvironment('GOONG_API_KEY');

  /// Null when the app was built without a Goong key; the address field then
  /// works as plain manual input.
  static AddressSuggester? fromEnvironment() =>
      _key.isEmpty ? null : GoongAddressSuggester(_key);

  final String apiKey;
  final HttpClient _client;

  @override
  Future<List<AddressSuggestion>> suggest(String input) async {
    final query = input.trim();
    if (query.length < 3) {
      return const [];
    }
    final uri = Uri.https('rsapi.goong.io', '/Place/AutoComplete', {
      'api_key': apiKey,
      'input': query,
      'limit': '5',
    });
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 6));
    final response = await request.close().timeout(const Duration(seconds: 6));
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 6));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Goong ${response.statusCode}', uri: uri);
    }
    return parseGoongPredictions(jsonDecode(body));
  }
}

/// Reads a Goong AutoComplete response; unknown shapes yield no suggestions.
List<AddressSuggestion> parseGoongPredictions(Object? json) {
  if (json is! Map<String, dynamic>) {
    return const [];
  }
  final predictions = json['predictions'];
  if (predictions is! List) {
    return const [];
  }
  final result = <AddressSuggestion>[];
  for (final item in predictions) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final description = (item['description'] as String? ?? '').trim();
    if (description.isEmpty) {
      continue;
    }
    final formatting = item['structured_formatting'];
    final main = formatting is Map<String, dynamic>
        ? (formatting['main_text'] as String? ?? '').trim()
        : '';
    final secondary = formatting is Map<String, dynamic>
        ? (formatting['secondary_text'] as String? ?? '').trim()
        : '';
    result.add(
      AddressSuggestion(
        description: description,
        mainText: main.isEmpty ? description : main,
        secondaryText: secondary,
      ),
    );
  }
  return result;
}
