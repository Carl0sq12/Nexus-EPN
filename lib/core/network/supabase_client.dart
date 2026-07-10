import 'package:supabase_flutter/supabase_flutter.dart';

/// Single access point for the Supabase client used across the data layer.
///
/// Use `supabaseClient` everywhere in datasources and repositories to avoid
/// spreading `Supabase.instance.client` throughout the codebase.
SupabaseClient get supabaseClient => Supabase.instance.client;
