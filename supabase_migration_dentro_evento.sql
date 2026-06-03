-- Migración: geofencing QR visibility
-- Agrega dentro_evento a entradas para controlar visibilidad del QR por ubicación.
-- El guardia escanea para marcar entrada (dentro_evento = true).
-- El geofencing detecta la salida y resetea (dentro_evento = false).

ALTER TABLE entradas
  ADD COLUMN IF NOT EXISTS dentro_evento BOOLEAN NOT NULL DEFAULT false;

-- Resetear entradas 'usado' a 'activo': el estado ya no se usa para bloquear
-- re-entradas, esa responsabilidad pasa a dentro_evento.
UPDATE entradas
  SET estado = 'activo'
  WHERE estado = 'usado';

-- Índice para acelerar consultas de validación
CREATE INDEX IF NOT EXISTS idx_entradas_dentro_evento
  ON entradas (dentro_evento);
