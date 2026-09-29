-- RESTAURAR ACESSO AUTENTICADO E AUTORIZAR ADMIN — MIGRAÇÃO INCREMENTAL
-- Execute este arquivo UMA VEZ no SQL Editor do Supabase para atualizar o banco existente.
-- Restaura RLS restrito a usuários autenticados e autorizados via usuarios_permitidos.

BEGIN;

-- 1. Autorizar o usuário administrador no usuarios_permitidos
INSERT INTO public.usuarios_permitidos (user_id, ativo)
VALUES ('fc952189-34d3-4963-b6c6-f408a249a47b'::uuid, true)
ON CONFLICT (user_id) DO UPDATE SET ativo = true;

-- 2. Revogar permissões públicas (anon) e conceder acesso a usuários autenticados
REVOKE ALL ON public.usuarios_permitidos FROM PUBLIC, anon;
GRANT SELECT ON public.usuarios_permitidos TO authenticated;

DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon', nome);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON public.%I TO authenticated', nome);
  END LOOP;
END $$;

-- 3. Função de verificação de permissão tem_acesso()
CREATE OR REPLACE FUNCTION public.tem_acesso()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios_permitidos
    WHERE user_id = (SELECT auth.uid()) AND ativo
  );
$$;
REVOKE ALL ON FUNCTION public.tem_acesso() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tem_acesso() TO authenticated;

-- 4. Atualizar políticas RLS para exigir tem_acesso()
DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    -- Garantir RLS habilitado
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', nome);

    -- Remover políticas públicas anteriores
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_leitura ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_inclusao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_alteracao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_leitura ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_inclusao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_alteracao ON public.%I', nome);

    -- Criar políticas RLS para a equipe autorizada
    EXECUTE format('CREATE POLICY equipe_leitura ON public.%I FOR SELECT TO authenticated USING ((SELECT public.tem_acesso()))', nome);
    EXECUTE format('CREATE POLICY equipe_inclusao ON public.%I FOR INSERT TO authenticated WITH CHECK ((SELECT public.tem_acesso()))', nome);
    EXECUTE format('CREATE POLICY equipe_alteracao ON public.%I FOR UPDATE TO authenticated USING ((SELECT public.tem_acesso())) WITH CHECK ((SELECT public.tem_acesso()))', nome);
  END LOOP;
END $$;

-- Política RLS para a própria tabela usuarios_permitidos
DROP POLICY IF EXISTS consultar_proprio_acesso ON public.usuarios_permitidos;
CREATE POLICY consultar_proprio_acesso ON public.usuarios_permitidos
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

-- 5. Função RPC fn_criar_ordem_producao com checagem de autorização
CREATE OR REPLACE FUNCTION public.fn_criar_ordem_producao(
  p_numero text, p_data date, p_responsavel text, p_observacoes text, p_sabores jsonb
)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_id uuid; v_sabor jsonb;
BEGIN
  IF NOT public.tem_acesso() THEN
    RAISE EXCEPTION 'Usuário sem autorização.' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_sabores) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Sabores deve ser uma lista.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_sabores) = 0 THEN
    RAISE EXCEPTION 'Informe pelo menos um sabor.' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.ordem_producao(numero, data, responsavel, observacoes)
    VALUES (btrim(p_numero), p_data, btrim(p_responsavel), coalesce(p_observacoes, ''))
    RETURNING id INTO v_id;
  FOR v_sabor IN SELECT value FROM jsonb_array_elements(p_sabores)
  LOOP
    IF jsonb_typeof(v_sabor) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'Cada sabor deve ser um objeto.' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.ordem_sabor(ordem_id, nome, planejado_kg)
      VALUES (v_id, btrim(v_sabor->>'nome'), (v_sabor->>'planejado_kg')::numeric);
  END LOOP;
  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_criar_ordem_producao(text,date,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_criar_ordem_producao(text,date,text,text,jsonb) TO authenticated;

-- 6. Função RPC fn_criar_pedido com checagem de autorização
CREATE OR REPLACE FUNCTION public.fn_criar_pedido(
  p_numero text, p_ordem_id uuid, p_cliente text, p_data date,
  p_destino text, p_observacoes text, p_itens jsonb
)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_id uuid; v_item jsonb;
BEGIN
  IF NOT public.tem_acesso() THEN
    RAISE EXCEPTION 'Usuário sem autorização.' USING ERRCODE = '42501';
  END IF;
  IF jsonb_typeof(p_itens) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'Itens deve ser uma lista.' USING ERRCODE = '22023';
  END IF;
  IF jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'Informe pelo menos um item.' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.pedido(numero, ordem_id, cliente, data, destino, observacoes)
    VALUES (btrim(p_numero), p_ordem_id, btrim(p_cliente), p_data,
            coalesce(p_destino, ''), coalesce(p_observacoes, ''))
    RETURNING id INTO v_id;
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_itens)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'Cada item deve ser um objeto.' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.pedido_item(pedido_id, ordem_id, ordem_sabor_id, conservacao, solicitado_kg)
      VALUES (v_id, p_ordem_id, (v_item->>'ordem_sabor_id')::uuid,
              v_item->>'conservacao', (v_item->>'solicitado_kg')::numeric);
  END LOOP;
  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_criar_pedido(text,uuid,text,date,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_criar_pedido(text,uuid,text,date,text,text,jsonb) TO authenticated;

COMMIT;
