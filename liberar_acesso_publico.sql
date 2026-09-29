-- LIBERAR ACESSO PÚBLICO (SEM LOGIN) — MIGRAÇÃO INCREMENTAL
-- Execute este arquivo UMA VEZ no SQL Editor do Supabase para atualizar o banco existente.
-- Permite leitura, inclusão e alteração para visitantes (papel anon) sem necessitar de login ou senhas.
-- Não apaga tabelas nem dados existentes. Não concede DELETE.

BEGIN;

-- 1. Permissões de esquema e sequências
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- 2. Permissões de tabela para anon e authenticated
GRANT SELECT, INSERT, UPDATE ON public.colaborador TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.ordem_producao TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.ordem_sabor TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.batelada TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.pedido TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON public.pedido_item TO anon, authenticated;

-- 3. Atualizar e garantir Políticas RLS públicas para anon e authenticated
DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    -- Garantir RLS ativo
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', nome);

    -- Remover políticas restritivas antigas ou duplicadas se existirem
    EXECUTE format('DROP POLICY IF EXISTS equipe_leitura ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_inclusao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS equipe_alteracao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_leitura ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_inclusao ON public.%I', nome);
    EXECUTE format('DROP POLICY IF EXISTS acesso_publico_alteracao ON public.%I', nome);

    -- Criar novas políticas públicas abertas para anon e authenticated
    EXECUTE format('CREATE POLICY acesso_publico_leitura ON public.%I FOR SELECT TO anon, authenticated USING (true)', nome);
    EXECUTE format('CREATE POLICY acesso_publico_inclusao ON public.%I FOR INSERT TO anon, authenticated WITH CHECK (true)', nome);
    EXECUTE format('CREATE POLICY acesso_publico_alteracao ON public.%I FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true)', nome);
  END LOOP;
END $$;

-- 4. Funções RPC abertas (sem restrição de login)

-- RPC fn_criar_ordem_producao
CREATE OR REPLACE FUNCTION public.fn_criar_ordem_producao(
  p_numero text, p_data date, p_responsavel text, p_observacoes text, p_sabores jsonb
)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_id uuid; v_sabor jsonb;
BEGIN
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

GRANT EXECUTE ON FUNCTION public.fn_criar_ordem_producao(text,date,text,text,jsonb) TO anon, authenticated;

-- RPC fn_criar_pedido
CREATE OR REPLACE FUNCTION public.fn_criar_pedido(
  p_numero text, p_ordem_id uuid, p_cliente text, p_data date,
  p_destino text, p_observacoes text, p_itens jsonb
)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE v_id uuid; v_item jsonb;
BEGIN
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

GRANT EXECUTE ON FUNCTION public.fn_criar_pedido(text,uuid,text,date,text,text,jsonb) TO anon, authenticated;

COMMIT;
