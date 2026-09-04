/// Exception thrown when a social sign-in (Google/Apple/etc) succeeds at the OAuth provider
/// level, but the account is not yet registered in the backend (e.g. error code '111' from YPT API).
class SocialSignUpRequiredException implements Exception {
  final String provider;
  final String socialId;
  final String email;
  final String name;

  const SocialSignUpRequiredException({
    required this.provider,
    required this.socialId,
    required this.email,
    required this.name,
  });

  @override
  String toString() =>
      'SocialSignUpRequiredException(provider: $provider, socialId: $socialId, email: $email, name: $name)';
}
