/// Supabaseプロジェクトの接続情報。
/// anon keyはRLSポリシー(supabase/schema.sql参照)で保護される前提の
/// 公開キーであり、クライアントアプリに埋め込んで問題ない
/// (service_role keyとは異なり秘密鍵ではない)。
class SupabaseConfig {
  SupabaseConfig._();

  static const String url = 'https://jnmbswzlkoewqqwitxza.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpubWJzd3psa29ld3Fxd2l0eHphIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyNDQ2NTAsImV4cCI6MjA5OTgyMDY1MH0.I-FPkjhMusXLhSgXzsvrky7JI7gx8pPWBDY_7mUYsE8';
}
