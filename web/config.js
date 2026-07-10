// Configuración pública de Supabase.
// La "anon key" está diseñada para ser pública (se usa en apps cliente),
// pero igual asegurate de tener las Row Level Security (RLS) activadas
// en tus tablas de Supabase.
window.SUPABASE_CONFIG = {
  url: 'https://yepevszmcvivawlmoayd.supabase.co',
  anonKey: 'sb_publishable_HRP6auYUVCpRPWD9qOZYGw_hZd_GMv_',
  // A dónde volver dentro de tu app móvil una vez que el usuario
  // termina el flujo acá en la web (deep link de tu app Flutter).
  appDeepLink: 'nexuscampus://auth-callback',
};