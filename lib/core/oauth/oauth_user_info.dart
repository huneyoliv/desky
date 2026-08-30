class OAuthUserInfo {
  final String provider;
  final String socialId;
  final String email;
  final String name;

  const OAuthUserInfo({
    required this.provider,
    required this.socialId,
    required this.email,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'socialId': socialId,
        'email': email,
        'name': name,
      };
}
