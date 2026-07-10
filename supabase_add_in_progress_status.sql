-- Ejecutar en Supabase Dashboard > SQL Editor si tu tabla trips ya existe.
-- Permite que la app marque un viaje como iniciado.

ALTER TABLE public.trips
DROP CONSTRAINT IF EXISTS trips_status_check;

ALTER TABLE public.trips
ADD CONSTRAINT trips_status_check
CHECK (status IN ('active', 'cancelled', 'full', 'in_progress', 'completed'));
