-- Migración: tabla para persistir lecturas del admin en soporte técnico
-- Ejecutar en el SQL Editor de Supabase

CREATE TABLE IF NOT EXISTS soporte_leidos_admin (
  admin_id     UUID NOT NULL,
  conversacion_usuario_id TEXT NOT NULL,
  leido_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (admin_id, conversacion_usuario_id)
);

-- RLS: cada admin solo puede leer/escribir sus propios registros
ALTER TABLE soporte_leidos_admin ENABLE ROW LEVEL SECURITY;

CREATE POLICY "admin_own_reads" ON soporte_leidos_admin
  USING (admin_id = auth.uid())
  WITH CHECK (admin_id = auth.uid());
