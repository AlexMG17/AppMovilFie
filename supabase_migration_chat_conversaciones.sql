-- ============================================================
-- Migración: Chat conversacional estilo WhatsApp
-- Ejecutar en Supabase → SQL Editor
-- ============================================================

-- 1. Agregar columna que identifica a qué conversación pertenece el mensaje
--    (siempre es el UUID del estudiante, independientemente de quién escribió)
ALTER TABLE soporte_mensajes
  ADD COLUMN IF NOT EXISTS conversacion_usuario_id TEXT;

-- 2. Retrocompatibilidad: rellenar mensajes existentes de estudiantes
UPDATE soporte_mensajes
  SET conversacion_usuario_id = usuario_id
  WHERE conversacion_usuario_id IS NULL AND es_admin = false;

-- 3. Índice para búsquedas rápidas por conversación
CREATE INDEX IF NOT EXISTS idx_soporte_mensajes_conv
  ON soporte_mensajes (conversacion_usuario_id, created_at);

-- ============================================================
-- IMPORTANTE: Políticas RLS
-- Si RLS está activado en soporte_mensajes, ejecuta también:
-- ============================================================

-- Opción A (más simple para uso interno): deshabilitar RLS
-- ALTER TABLE soporte_mensajes DISABLE ROW LEVEL SECURITY;

-- Opción B: policies específicas
-- (Reemplaza 'administrador' con el nombre exacto del rol en tu tabla roles)

-- Elimina policies anteriores si existen
-- DROP POLICY IF EXISTS "Estudiantes ven su conversacion" ON soporte_mensajes;
-- DROP POLICY IF EXISTS "Estudiantes insertan mensajes" ON soporte_mensajes;
-- DROP POLICY IF EXISTS "Admin acceso total" ON soporte_mensajes;

-- Estudiante: solo lee/escribe en su propia conversación
-- CREATE POLICY "Estudiantes ven su conversacion" ON soporte_mensajes
--   FOR SELECT USING (conversacion_usuario_id = auth.uid()::text);
--
-- CREATE POLICY "Estudiantes insertan mensajes" ON soporte_mensajes
--   FOR INSERT WITH CHECK (
--     conversacion_usuario_id = auth.uid()::text AND es_admin = false
--   );

-- Admin: acceso total
-- CREATE POLICY "Admin acceso total" ON soporte_mensajes
--   FOR ALL USING (
--     EXISTS (
--       SELECT 1 FROM usuarios u
--       JOIN roles r ON r.id_rol = u.id_rol
--       WHERE u.email = auth.email()
--         AND lower(r.nombre) IN ('admin', 'administrador')
--     )
--   );

-- ============================================================
-- Verificación
-- ============================================================
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_name = 'soporte_mensajes' ORDER BY ordinal_position;
