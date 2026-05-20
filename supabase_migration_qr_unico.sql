-- ============================================================
-- Migración: QR Único
-- Ejecutar en Supabase → SQL Editor
-- ============================================================

-- 1. Agregar columna de expiración del QR
ALTER TABLE entradas
  ADD COLUMN IF NOT EXISTS fecha_expiracion TIMESTAMPTZ;

-- 2. Agregar contador de versión (se incrementa cada vez que se regenera)
ALTER TABLE entradas
  ADD COLUMN IF NOT EXISTS version_qr INTEGER NOT NULL DEFAULT 1;

-- 3. Garantizar unicidad del código QR a nivel de base de datos
--    (los QR UUID v4 son únicos por naturaleza, pero esto lo refuerza)
ALTER TABLE entradas
  ADD CONSTRAINT IF NOT EXISTS entradas_codigo_qr_unique UNIQUE (codigo_qr);

-- 4. Actualizar registros existentes con versión 1 (retrocompatibilidad)
UPDATE entradas SET version_qr = 1 WHERE version_qr IS NULL;

-- ============================================================
-- Opcional: índice para búsquedas por código QR (ya existe si
-- hay una restricción UNIQUE, pero lo agregamos explícitamente
-- si se prefiere un índice parcial)
-- ============================================================
-- CREATE INDEX IF NOT EXISTS idx_entradas_codigo_qr ON entradas (codigo_qr);

-- ============================================================
-- Verificación: ver estructura final de la tabla
-- ============================================================
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'entradas'
-- ORDER BY ordinal_position;
