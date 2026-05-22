-- =========================================================================
-- SCRIPT DE SEGURIDAD: ACTIVAR RLS Y POLÍTICAS DE ACCESO
-- Ejecutar en: Supabase Dashboard -> SQL Editor -> New Query -> Run
-- =========================================================================

-- ─────────────────────────────────────────────────────────────────────────
-- 1. FUNCIONES AUXILIARES (Evitan recursión infinita y optimizan políticas)
-- ─────────────────────────────────────────────────────────────────────────

-- Determina si el usuario autenticado tiene rol de Administrador
CREATE OR REPLACE FUNCTION public.es_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER -- Ejecuta con privilegios del creador (bypass RLS)
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.roles r ON r.id_rol = u.id_rol
    WHERE u.email = auth.email()
      AND lower(r.nombre) IN ('admin', 'administrador')
  );
END;
$$;

-- Determina si el usuario autenticado tiene rol de Validador (Guardia) o Admin
CREATE OR REPLACE FUNCTION public.es_validador_o_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.usuarios u
    JOIN public.roles r ON r.id_rol = u.id_rol
    WHERE u.email = auth.email()
      AND lower(r.nombre) IN ('admin', 'administrador', 'validador')
  );
END;
$$;

-- Retorna el id_usuario correspondiente al email autenticado actual
CREATE OR REPLACE FUNCTION public.mi_id_usuario()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id integer;
BEGIN
  SELECT id_usuario INTO v_id FROM public.usuarios WHERE email = auth.email();
  RETURN v_id;
END;
$$;


-- ─────────────────────────────────────────────────────────────────────────
-- 2. HABILITAR RLS EN TODAS LAS TABLAS
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.listado_estudiantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.entradas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asistencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scan_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.soporte_mensajes ENABLE ROW LEVEL SECURITY;


-- ─────────────────────────────────────────────────────────────────────────
-- 3. POLÍTICAS PARA: roles
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de roles para todos" ON public.roles;
CREATE POLICY "Lectura de roles para todos" ON public.roles
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Modificación de roles solo admin" ON public.roles;
CREATE POLICY "Modificación de roles solo admin" ON public.roles
  FOR ALL TO authenticated USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 4. POLÍTICAS PARA: usuarios
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de usuarios" ON public.usuarios;
CREATE POLICY "Lectura de usuarios" ON public.usuarios
  FOR SELECT TO authenticated
  USING (email = auth.email() OR public.es_validador_o_admin());

DROP POLICY IF EXISTS "Inserción de usuarios" ON public.usuarios;
CREATE POLICY "Inserción de usuarios" ON public.usuarios
  FOR INSERT TO authenticated
  WITH CHECK (email = auth.email() OR public.es_admin());

DROP POLICY IF EXISTS "Actualización de usuarios" ON public.usuarios;
CREATE POLICY "Actualización de usuarios" ON public.usuarios
  FOR UPDATE TO authenticated
  USING (email = auth.email() OR public.es_admin());

DROP POLICY IF EXISTS "Eliminación de usuarios solo admin" ON public.usuarios;
CREATE POLICY "Eliminación de usuarios solo admin" ON public.usuarios
  FOR DELETE TO authenticated
  USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 5. POLÍTICAS PARA: eventos
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de eventos" ON public.eventos;
CREATE POLICY "Lectura de eventos" ON public.eventos
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Modificación de eventos solo admin" ON public.eventos;
CREATE POLICY "Modificación de eventos solo admin" ON public.eventos
  FOR ALL TO authenticated USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 6. POLÍTICAS PARA: listado_estudiantes
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de listado_estudiantes para todos" ON public.listado_estudiantes;
CREATE POLICY "Lectura de listado_estudiantes para todos" ON public.listado_estudiantes
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Modificación de listado_estudiantes solo admin" ON public.listado_estudiantes;
CREATE POLICY "Modificación de listado_estudiantes solo admin" ON public.listado_estudiantes
  FOR ALL TO authenticated USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 7. POLÍTICAS PARA: pagos
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de pagos" ON public.pagos;
CREATE POLICY "Lectura de pagos" ON public.pagos
  FOR SELECT TO authenticated
  USING (id_usuario = public.mi_id_usuario() OR public.es_admin());

DROP POLICY IF EXISTS "Inserción de pagos" ON public.pagos;
CREATE POLICY "Inserción de pagos" ON public.pagos
  FOR INSERT TO authenticated
  WITH CHECK (id_usuario = public.mi_id_usuario() OR public.es_admin());

DROP POLICY IF EXISTS "Actualización de pagos" ON public.pagos;
CREATE POLICY "Actualización de pagos" ON public.pagos
  FOR UPDATE TO authenticated
  USING (id_usuario = public.mi_id_usuario() OR public.es_admin());

DROP POLICY IF EXISTS "Eliminación de pagos solo admin" ON public.pagos;
CREATE POLICY "Eliminación de pagos solo admin" ON public.pagos
  FOR DELETE TO authenticated
  USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 8. POLÍTICAS PARA: entradas
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de entradas" ON public.entradas;
CREATE POLICY "Lectura de entradas" ON public.entradas
  FOR SELECT TO authenticated
  USING (id_usuario = public.mi_id_usuario() OR public.es_validador_o_admin());

DROP POLICY IF EXISTS "Inserción de entradas solo admin" ON public.entradas;
CREATE POLICY "Inserción de entradas solo admin" ON public.entradas
  FOR INSERT TO authenticated
  WITH CHECK (public.es_admin());

DROP POLICY IF EXISTS "Actualización de entradas" ON public.entradas;
CREATE POLICY "Actualización de entradas" ON public.entradas
  FOR UPDATE TO authenticated
  USING (public.es_validador_o_admin());

DROP POLICY IF EXISTS "Eliminación de entradas solo admin" ON public.entradas;
CREATE POLICY "Eliminación de entradas solo admin" ON public.entradas
  FOR DELETE TO authenticated
  USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 9. POLÍTICAS PARA: asistencias
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de asistencias" ON public.asistencias;
CREATE POLICY "Lectura de asistencias" ON public.asistencias
  FOR SELECT TO authenticated
  USING (public.es_validador_o_admin());

DROP POLICY IF EXISTS "Inserción de asistencias" ON public.asistencias;
CREATE POLICY "Inserción de asistencias" ON public.asistencias
  FOR INSERT TO authenticated
  WITH CHECK (public.es_validador_o_admin());

DROP POLICY IF EXISTS "Modificación de asistencias solo admin" ON public.asistencias;
CREATE POLICY "Modificación de asistencias solo admin" ON public.asistencias
  FOR ALL TO authenticated
  USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 10. POLÍTICAS PARA: scan_logs
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de scan_logs" ON public.scan_logs;
CREATE POLICY "Lectura de scan_logs" ON public.scan_logs
  FOR SELECT TO authenticated
  USING (public.es_validador_o_admin());

DROP POLICY IF EXISTS "Inserción de scan_logs" ON public.scan_logs;
CREATE POLICY "Inserción de scan_logs" ON public.scan_logs
  FOR INSERT TO authenticated
  WITH CHECK (public.es_validador_o_admin());

DROP POLICY IF EXISTS "Modificación de scan_logs solo admin" ON public.scan_logs;
CREATE POLICY "Modificación de scan_logs solo admin" ON public.scan_logs
  FOR ALL TO authenticated
  USING (public.es_admin());


-- ─────────────────────────────────────────────────────────────────────────
-- 11. POLÍTICAS PARA: soporte_mensajes
-- ─────────────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Lectura de mensajes" ON public.soporte_mensajes;
CREATE POLICY "Lectura de mensajes" ON public.soporte_mensajes
  FOR SELECT TO authenticated
  USING (conversacion_usuario_id = auth.uid()::text OR public.es_admin());

DROP POLICY IF EXISTS "Inserción de mensajes" ON public.soporte_mensajes;
CREATE POLICY "Inserción de mensajes" ON public.soporte_mensajes
  FOR INSERT TO authenticated
  WITH CHECK (
    (conversacion_usuario_id = auth.uid()::text AND es_admin = false)
    OR public.es_admin()
  );

DROP POLICY IF EXISTS "Modificación de mensajes solo admin" ON public.soporte_mensajes;
CREATE POLICY "Modificación de mensajes solo admin" ON public.soporte_mensajes
  FOR ALL TO authenticated
  USING (public.es_admin());
