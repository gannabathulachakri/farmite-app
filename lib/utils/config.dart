class AppConfig {
  /// TODO: Replace this with your current active Vercel backend URL.
  /// If you get 404 DEPLOYMENT_NOT_FOUND, ensure the project is deployed on Vercel.
  static const String backendBaseUrl = 'https://farmitre-vegetables-backend.vercel.app';
  
  static const String verifyPaymentUrl = '$backendBaseUrl/verify-payment';
}
