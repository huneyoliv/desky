class ApiConstants {
  ApiConstants._();

  // API Hosts
  static const String baseUrl = 'https://pi.tgclab.com';
  static const String metadataCdnUrl = 'https://picf.tgclab.com';
  static const String mediaCdnUrl = 'https://alicdn.tgclab.com';
  static const String uploadUrl = 'https://alifn.tgclab.com/file';
  static const String audioCdnUrl = 'https://alicdn.pallo.cn';

  // Endpoints
  static const String signInJwt = '/user/sign-in-jwt';
  static const String socialSignUpJwt = '/user/social/sign-up-jwt';
  static const String splashLogin = '/user/v2/splash-login';
  static const String reloadInfo = '/user/v2/reload/info';
  static const String sendSignupCode = '/user/v2/send-signup-code';
  static const String verifyCode = '/user/v2/verify-code';
  static const String createEmailAccount = '/user/v2/create-email-account';
  static const String unregister = '/user/unregister';
  static const String nicknameChange = '/user/nickname/change';
  static const String categoryByCountry = '/category/category-by-country';
  static const String existUsername = '/user/exist-username';

  // Subjects
  static const String subjectCreate = '/user/subject/create';
  static const String subjectList = '/user/subject/list';

  // Timer & Study
  static const String studyStart = '/study/start';
  static const String studyStop = '/study/stop';
  static const String studyBreak = '/study/study-plan/rest';
  static const String timeSync = '/time/';

  // Groups
  static const String groupMembers = '/logs/group/members/v2';
  static const String groupShake = '/group/push/shake';
  static const String groupChatMessages = '/chat/group/messages';

  // Default Headers & App Configuration Defaults
  static const String userAgent = 'Dart/3.11 (dart:io)';
  static const String jwtPrefix = 'JWT ';
  static const int defaultCountryId = 23;
  static const int defaultVersion = 810041;
  static const String defaultLanguage = 'pt';
  static const String defaultTimezone = 'America/Sao_Paulo';
  static const String defaultDeviceModel = 'Desktop';
  static const String defaultDeviceType = 'WIN';
}
