-- RESTAURAR ACESSO AUTENTICADO E AUTORIZAR USUÁRIOS — MIGRAÇÃO INCREMENTAL
-- Execute este arquivo UMA VEZ no SQL Editor do Supabase para autorizar seus usuários autenticados no banco.

BEGIN;

-- 1. Autorizar o usuário administrador principal
INSERT INTO public.usuarios_permitidos (user_id, ativo)
VALUES ('fc952189-34d3-4963-b6c6-f408a249a47b'::uuid, true)
ON CONFLICT (user_id) DO UPDATE SET ativo = true;

-- 2. Garantir autorização para todos os usuários cadastrados no Supabase Auth (auth.users)
INSERT INTO public.usuarios_permitidos (user_id, ativo)
SELECT id, true FROM auth.users
ON CONFLICT (user_id) DO UPDATE SET ativo = true;

-- 3. Revogar permissões públicas (anon) e conceder acesso a usuários autenticados
REVOKE ALL ON public.usuarios_permitidos FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE ON public.usuarios_permitidos TO authenticated;

DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon', nome);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON public.%I TO authenticated', nome);
  END LOOP;
END $$;

-- 4. Função de verificação de permissão tem_acesso()
CREATE OR REPLACE FUNCTION public.tem_acesso()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios_permitidos
    WHERE user_id = (SELECT auth.uid()) AND ativo
  );
$$;
REVOKE ALL ON FUNCTION public.tem_acesso() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tem_acesso() TO authenticated;

-- 5. Atualizar políticas RLS para exigir tem_acesso()
DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', nome);

    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_leitura ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_inclusao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_alteracao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_leitura ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_inclusao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_alteracao ON public.%I', nome);

    EXECUTE format('CREATE POLICY equipe_leitura ON public.%I FOR SELECT TO authenticated USING ((SELECT public.tem_acesso()))', nome);
    EXECUTE format('CREATE POLICY equipe_inclusao ON public.%I FOR INSERT TO authenticated WITH CHECK ((SELECT public.tem_acesso()))', nome);
    EXECUTE format('CREATE POLICY equipe_alteracao ON public.%I FOR UPDATE TO authenticated USING ((SELECT public.tem_acesso())) WITH CHECK ((SELECT public.tem_acesso()))', nome);
  END LOOP;
END $$;

-- Política RLS para a própria tabela usuarios_permitidos
DROP POLICY IF EXISTS consultar_proprio_acesso ON public.usuarios_permitidos;
CREATE POLICY consultar_proprio_acesso ON public.usuarios_permitidos
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

COMMIT;

-- Recarregar cache PostgREST
NOTIFY pgrst, 'reload schema';
