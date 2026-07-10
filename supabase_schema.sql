-- =============================================================
-- Nexus Campus - Esquema completo para Supabase
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- =============================================================

-- 1. Tabla de perfiles (se crea automáticamente via trigger,
--    pero se deja la definición como referencia)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  role TEXT DEFAULT 'passenger' CHECK (role IN ('passenger', 'driver')),
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger para crear perfil automáticamente al registrarse
-- (Si ya existe, saltear)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role)
  VALUES (
    NEW.id,
    NEW.email,
    NEW.raw_user_meta_data->>'full_name',
    COALESCE(NEW.raw_user_meta_data->>'role', 'passenger')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 2. Tabla de viajes
CREATE TABLE IF NOT EXISTS public.trips (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  origin TEXT NOT NULL,
  destination TEXT NOT NULL,
  departure_time TIMESTAMPTZ NOT NULL,
  total_seats INTEGER NOT NULL CHECK (total_seats > 0),
  available_seats INTEGER NOT NULL CHECK (available_seats >= 0),
  price_per_seat NUMERIC(10,2) NOT NULL CHECK (price_per_seat >= 0),
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'full', 'in_progress', 'completed')),
  origin_latitude DOUBLE PRECISION,
  origin_longitude DOUBLE PRECISION,
  destination_latitude DOUBLE PRECISION,
  destination_longitude DOUBLE PRECISION,
  route_distance_meters DOUBLE PRECISION,
  route_duration_seconds DOUBLE PRECISION,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Tabla de solicitudes de viaje
CREATE TABLE IF NOT EXISTS public.trip_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  passenger_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'price_proposed', 'accepted', 'rejected')),
  passenger_count INTEGER NOT NULL DEFAULT 1 CHECK (passenger_count > 0),
  pickup_note TEXT,
  dropoff_note TEXT,
  pickup_latitude DOUBLE PRECISION,
  pickup_longitude DOUBLE PRECISION,
  dropoff_latitude DOUBLE PRECISION,
  dropoff_longitude DOUBLE PRECISION,
  request_stops JSONB NOT NULL DEFAULT '[]'::jsonb,
  proposed_price NUMERIC(10,2),
  price_note TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Tabla de vehículos
CREATE TABLE IF NOT EXISTS public.vehicles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  brand TEXT NOT NULL,
  model TEXT NOT NULL,
  color TEXT NOT NULL,
  plate TEXT NOT NULL,
  photo_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. Tabla de mensajes
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Tabla de calificaciones
CREATE TABLE IF NOT EXISTS public.ratings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
  rater_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rated_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  score INTEGER NOT NULL CHECK (score >= 1 AND score <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. Tabla de alertas SOS
-- Se reutiliza una sola tabla para emergencias personales y problemas mecánicos:
-- ambos flujos comparten usuario, ubicación, mensaje, timestamps y políticas RLS.
CREATE TABLE IF NOT EXISTS public.sos_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  type TEXT NOT NULL DEFAULT 'personal_emergency'
    CHECK (type IN ('personal_emergency', 'mechanical_problem')),
  message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. Tabla de contactos de emergencia (NUEVA)
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  relationship TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para búsqueda rápida de contactos por usuario
CREATE INDEX IF NOT EXISTS idx_emergency_contacts_user_id ON public.emergency_contacts(user_id);

-- =============================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================

-- Habilitar RLS en todas las tablas
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;

-- Políticas básicas (lectura pública, escritura solo propia)

-- profiles: todos pueden leer, cada uno edita su propio perfil
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- trips: todos pueden leer, conductores crean/editan sus viajes
CREATE POLICY "trips_select" ON public.trips FOR SELECT USING (true);
CREATE POLICY "trips_insert" ON public.trips FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "trips_update" ON public.trips FOR UPDATE USING (auth.uid() = driver_id);

-- trip_requests: pasajeros ven sus solicitudes, conductores ven las de sus viajes
CREATE POLICY "trip_requests_select" ON public.trip_requests
  FOR SELECT USING (
    auth.uid() = passenger_id OR
    auth.uid() IN (SELECT driver_id FROM public.trips WHERE id = trip_id)
  );
CREATE POLICY "trip_requests_insert" ON public.trip_requests
  FOR INSERT WITH CHECK (auth.uid() = passenger_id);
CREATE POLICY "trip_requests_update" ON public.trip_requests
  FOR UPDATE USING (
    auth.uid() = passenger_id OR
    auth.uid() IN (SELECT driver_id FROM public.trips WHERE id = trip_id)
  )
  WITH CHECK (
    auth.uid() = passenger_id OR
    auth.uid() IN (SELECT driver_id FROM public.trips WHERE id = trip_id)
  );

CREATE OR REPLACE FUNCTION public.accept_proposed_trip_price(
  p_request_id UUID,
  p_trip_id UUID
)
RETURNS public.trip_requests
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request public.trip_requests%ROWTYPE;
  v_available_seats INTEGER;
  v_next_seats INTEGER;
BEGIN
  SELECT *
  INTO v_request
  FROM public.trip_requests
  WHERE id = p_request_id
    AND trip_id = p_trip_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Solicitud no encontrada';
  END IF;

  IF v_request.passenger_id <> auth.uid() THEN
    RAISE EXCEPTION 'No puedes aceptar esta solicitud';
  END IF;

  IF v_request.status <> 'price_proposed' THEN
    RAISE EXCEPTION 'Primero el conductor debe proponer precio';
  END IF;

  IF v_request.proposed_price IS NULL THEN
    RAISE EXCEPTION 'La solicitud no tiene precio propuesto';
  END IF;

  SELECT available_seats
  INTO v_available_seats
  FROM public.trips
  WHERE id = p_trip_id
    AND status IN ('active', 'full')
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El viaje ya no está disponible';
  END IF;

  IF v_available_seats < v_request.passenger_count THEN
    RAISE EXCEPTION 'No hay suficientes asientos disponibles';
  END IF;

  v_next_seats := v_available_seats - v_request.passenger_count;

  UPDATE public.trips
  SET
    available_seats = v_next_seats,
    status = CASE WHEN v_next_seats = 0 THEN 'full' ELSE status END
  WHERE id = p_trip_id;

  UPDATE public.trip_requests
  SET status = 'accepted'
  WHERE id = p_request_id
  RETURNING * INTO v_request;

  RETURN v_request;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_proposed_trip_price(UUID, UUID)
TO authenticated;

-- vehicles: todos ven, conductores gestionan
CREATE POLICY "vehicles_select" ON public.vehicles FOR SELECT USING (true);
CREATE POLICY "vehicles_insert" ON public.vehicles FOR INSERT WITH CHECK (auth.uid() = driver_id);
CREATE POLICY "vehicles_update" ON public.vehicles FOR UPDATE USING (auth.uid() = driver_id);
CREATE POLICY "vehicles_delete" ON public.vehicles FOR DELETE USING (auth.uid() = driver_id);

-- messages: participantes del viaje pueden leer y escribir
CREATE POLICY "messages_select" ON public.messages
  FOR SELECT USING (
    auth.uid() IN (
      SELECT driver_id FROM public.trips WHERE id = trip_id
      UNION
      SELECT passenger_id FROM public.trip_requests WHERE trip_id = trip_id AND status = 'accepted'
    )
  );
CREATE POLICY "messages_insert" ON public.messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id AND
    auth.uid() IN (
      SELECT driver_id FROM public.trips WHERE id = trip_id
      UNION
      SELECT passenger_id FROM public.trip_requests WHERE trip_id = trip_id AND status = 'accepted'
    )
  );

-- ratings: todos pueden ver, solo quien calificó puede insertar
CREATE POLICY "ratings_select" ON public.ratings FOR SELECT USING (true);
CREATE POLICY "ratings_insert" ON public.ratings FOR INSERT WITH CHECK (auth.uid() = rater_id);

-- sos_alerts: todos pueden insertar, solo el usuario puede ver sus alertas
CREATE POLICY "sos_alerts_select" ON public.sos_alerts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "sos_alerts_insert" ON public.sos_alerts FOR INSERT WITH CHECK (auth.uid() = user_id);

-- emergency_contacts: cada usuario ve y gestiona sus propios contactos
CREATE POLICY "emergency_contacts_select" ON public.emergency_contacts
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "emergency_contacts_insert" ON public.emergency_contacts
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "emergency_contacts_delete" ON public.emergency_contacts
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================================
-- DATOS DE EJEMPLO (opcional)
-- =============================================================

-- Crear usuarios de ejemplo directamente en auth.users NO es posible
-- desde SQL. En su lugar, usa el dashboard de Supabase > Authentication
-- o la API de Supabase para registrar usuarios con rol 'driver'.
--
-- Para registrar un conductor de prueba desde la app:
-- 1. Abrí la app
-- 2. Registrate con un correo
-- 3. Seleccioná "Conductor" como rol
-- 4. Confirmá el correo (si está habilitada la confirmación)
