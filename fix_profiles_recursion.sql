-- ============================================================
-- FIX: Infinite recursion en policies de profiles
-- Ejecutar en SQL Editor de Supabase
-- ============================================================

-- Deshabilitar RLS temporalmente para poder modificar
ALTER TABLE profiles DISABLE ROW LEVEL SECURITY;

-- Eliminar TODAS las policies existentes de profiles
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Profiles viewable by authenticated" ON profiles;
DROP POLICY IF EXISTS "Profiles insertable by authenticated" ON profiles;
DROP POLICY IF EXISTS "Profiles updatable by owner" ON profiles;
DROP POLICY IF EXISTS "Superadmin full access profiles" ON profiles;
DROP POLICY IF EXISTS "Admin view own profile" ON profiles;
DROP POLICY IF EXISTS "Service role full access" ON profiles;
DROP POLICY IF EXISTS "Allow superadmin all profiles" ON profiles;
DROP POLICY IF EXISTS "Allow admin own profile" ON profiles;
DROP POLICY IF EXISTS "Users can view profiles" ON profiles;

-- ============================================================
-- RECREAR POLICIES SIN RECURSIÓN
-- La regla de oro: NUNCA hacer SELECT sobre 'profiles' dentro de una policy de 'profiles'
-- ============================================================

-- Volver a habilitar RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- 1. SELECT: Cualquiera puede ver cualquier perfil (pública)
--    Esto es seguro si no hay datos sensibles, o puedes restringir:
CREATE POLICY "Profiles are viewable by all"
  ON profiles FOR SELECT
  USING (true);

-- 2. INSERT: Solo el propio usuario o service role
CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (id = auth.uid());

-- 3. UPDATE: Solo el propio usuario puede actualizar su perfil
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (id = auth.uid());

-- 4. DELETE: Solo el propio usuario
CREATE POLICY "Users can delete own profile"
  ON profiles FOR DELETE
  USING (id = auth.uid());

-- ============================================================
-- OPCIÓN ALTERNATIVA: Si necesitas que solo superadmin vea todos
-- y usuarios normales solo vean su propio perfil, usa esto en vez de (1):
-- ============================================================

-- Descomenta y ejecuta esto si prefieres visibilidad restringida:

-- DROP POLICY IF EXISTS "Profiles are viewable by all" ON profiles;

-- -- Crear función para verificar rol sin recursión
-- CREATE OR REPLACE FUNCTION public.is_superadmin()
-- RETURNS boolean AS $$
-- BEGIN
--   RETURN EXISTS (
--     SELECT 1 FROM auth.users
--     WHERE id = auth.uid()
--     AND (raw_app_meta_data->>'rol' = 'superadmin' OR raw_user_meta_data->>'rol' = 'superadmin')
--   );
-- END;
-- $$ LANGUAGE plpgsql SECURITY DEFINER;

-- -- Superadmin ve todo
-- CREATE POLICY "Superadmin can view all profiles"
--   ON profiles FOR SELECT
--   USING (is_superadmin());

-- -- Usuarios ven solo su perfil
-- CREATE POLICY "Users can view own profile"
--   ON profiles FOR SELECT
--   USING (id = auth.uid());

-- ============================================================
-- NOTAS IMPORTANTES
-- ============================================================

-- El error "infinite recursion" ocurre cuando haces:
--   SELECT ... FROM profiles ...
-- dentro de una policy de la tabla profiles.

-- Solución: Usar auth.uid() directamente o funciones SECURITY DEFINER
-- que consulten auth.users en lugar de profiles.

-- Si necesitas políticas más complejas, considera:
-- 1. Guardar el rol en app_metadata del usuario de auth
-- 2. Usar auth.jwt()->>'role' para verificar permisos
-- 3. O crear funciones SECURITY DEFINER que hagan la lógica

