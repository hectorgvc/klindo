-- ============================================================
-- FIX DEFINITIVO: Infinite recursion en profiles
-- Ejecutar en SQL Editor de Supabase
-- ============================================================

-- PASO 1: Eliminar la policy problemática
DROP POLICY IF EXISTS "Superadmin ve todos los perfiles" ON profiles;

-- PASO 2: Crear función auxiliar que consulta auth.users (no profiles)
-- Esto evita la recursión porque no toca la tabla profiles
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM auth.users
    WHERE id = auth.uid()
    AND (
      raw_user_meta_data->>'rol' = 'superadmin'
      OR raw_app_meta_data->>'rol' = 'superadmin'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- PASO 3: Recrear la policy usando la función (no consulta profiles)
CREATE POLICY "Superadmin ve todos los perfiles"
  ON profiles FOR ALL
  USING (is_superadmin());

-- ============================================================
-- VERIFICACIÓN: Ver policies actuales
-- ============================================================
-- SELECT policyname, cmd, qual
-- FROM pg_policies
-- WHERE tablename = 'profiles';

-- ============================================================
-- NOTAS:
-- - La función is_superadmin() consulta auth.users, no profiles
-- - SECURITY DEFINER permite que la función vea auth.users sin restricciones
-- - Esto rompe el ciclo de recursión
-- ============================================================
