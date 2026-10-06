const _joinCodeLength = 6;

String? gameJoinCodeFromUri(Uri uri) {
  final code = uri.queryParameters['joinCode']?.trim().toUpperCase();
  if (code == null || !RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
    return null;
  }
  return code;
}

Uri gameJoinUri(Uri baseUri, String joinCode) {
  if ((baseUri.scheme != 'http' && baseUri.scheme != 'https') ||
      baseUri.host.isEmpty) {
    throw const FormatException(
      'A web address is required to create a game join link.',
    );
  }

  final code = joinCode.trim().toUpperCase();
  if (code.length != _joinCodeLength ||
      !RegExp(r'^[A-Z0-9]{6}$').hasMatch(code)) {
    throw const FormatException('The game join code must be six characters.');
  }

  return Uri(
    scheme: baseUri.scheme,
    userInfo: baseUri.userInfo,
    host: baseUri.host,
    port: baseUri.hasPort ? baseUri.port : null,
    path: '/',
    queryParameters: {'joinCode': code},
  );
}
