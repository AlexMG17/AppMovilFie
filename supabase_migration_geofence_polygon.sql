-- Migración: agregar columna poligono a la tabla eventos
-- Ejecutar en el SQL Editor de Supabase

ALTER TABLE eventos
  ADD COLUMN IF NOT EXISTS poligono JSONB DEFAULT NULL;

-- Ejemplo de estructura esperada:
-- [{"lat": -1.656, "lng": -78.674}, {"lat": -1.657, "lng": -78.675}, ...]
