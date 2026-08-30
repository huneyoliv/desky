class OAuthException implements Exception {
  final String message;
  final bool isCancelled;

  const OAuthException(this.message, {this.isCancelled = false});

  @override
  String toString() => message;
}
