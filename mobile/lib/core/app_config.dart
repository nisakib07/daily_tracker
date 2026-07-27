class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // The deployed web app shares the same Supabase project/users and already
  // has a browser-based reset-password page — password reset emails sent
  // from mobile link back here to complete the reset, since there's no
  // mobile deep-link handling for the recovery flow.
  static const webAppUrl = String.fromEnvironment(
    'WEB_APP_URL',
    defaultValue: 'https://moneymaster-one.vercel.app',
  );

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
