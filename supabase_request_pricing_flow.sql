-- =============================================================
-- Nexus Campus - Flujo de solicitudes con paradas y precio propuesto
-- Ejecutar en: Supabase Dashboard > SQL Editor
-- =============================================================

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS passenger_count INTEGER NOT NULL DEFAULT 1
CHECK (passenger_count > 0);

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS pickup_note TEXT;

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS dropoff_note TEXT;

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS pickup_latitude DOUBLE PRECISION;

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS pickup_longitude DOUBLE PRECISION;

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS dropoff_latitude DOUBLE PRECISION;

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS dropoff_longitude DOUBLE PRECISION;

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS request_stops JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS proposed_price NUMERIC(10,2);

ALTER TABLE public.trip_requests
ADD COLUMN IF NOT EXISTS price_note TEXT;

ALTER TABLE public.trip_requests
DROP CONSTRAINT IF EXISTS trip_requests_status_check;

ALTER TABLE public.trip_requests
ADD CONSTRAINT trip_requests_status_check
CHECK (status IN ('pending', 'price_proposed', 'accepted', 'rejected'));

DROP POLICY IF EXISTS "trip_requests_update" ON public.trip_requests;

CREATE POLICY "trip_requests_update" ON public.trip_requests
  FOR UPDATE USING (
    auth.uid() = passenger_id OR
    auth.uid() IN (
      SELECT driver_id FROM public.trips WHERE id = trip_id
    )
  )
  WITH CHECK (
    auth.uid() = passenger_id OR
    auth.uid() IN (
      SELECT driver_id FROM public.trips WHERE id = trip_id
    )
  );

DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.trip_requests;
EXCEPTION
  WHEN duplicate_object THEN NULL;
  WHEN undefined_object THEN NULL;
END $$;

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
