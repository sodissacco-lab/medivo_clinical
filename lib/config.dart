/// Supabase settings for Medivo Clinical.
///
/// Paste your project's URL and its Publishable key (called "anon public"
/// on older projects) below. That key is designed to live inside the app:
/// the database is protected by Row Level Security.
///
/// NEVER put the secret / service_role key in this file or anywhere in the app.
class AppConfig {
    static const String supabaseUrl = 'https://skkyadirhvdaxigusfqk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNra3lhZGlyaHZkYXhpZ3VzZnFrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzNDE4NzgsImV4cCI6MjEwNTkxNzg3OH0.jUvk4BVIphewDEPYxh2Ubt2t_Tud-k2FK2iEse6F5NM';

  static const String appVersion = '0.1.0';
  static const String buildPhase = 'Phase 1 · Foundation';
}
