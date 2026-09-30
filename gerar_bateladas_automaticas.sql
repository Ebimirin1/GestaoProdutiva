-- CONTROLE DE PRODUÇÃO SIMPLES — Migração Incremental: Geração Automática de Bateladas
-- Permite a criação e atualização atômica de Ordens de Produção (OP) com bateladas divididas em 95% carne e 5% tempero (máx 150,000 kg).

BEGIN;

-- 1. Função interna para geração automática de bateladas
CREATE OR REPLACE FUNCTION public.fn_gerar_bateladas_op(p_ordem_id uuid, p_numero text)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  v_total_kg numeric(12,3) := 0;
  v_restante_kg numeric(12,3);
  v_bat_peso numeric(12,3);
  v_carne numeric(12,3);
  v_temperos numeric(12,3);
  v_num integer := 1;
  v_lote text;
BEGIN
  -- Calcular o total planejado da OP somando os sabores
  SELECT coalesce(sum(planejado_kg), 0) INTO v_total_kg
  FROM public.ordem_sabor
  WHERE ordem_id = p_ordem_id;

  IF v_total_kg <= 0 THEN
    RAISE EXCEPTION 'A soma dos sabores da OP deve ser maior que zero.' USING ERRCODE = '22023';
  END IF;

  v_restante_kg := v_total_kg;

  WHILE v_restante_kg > 0 LOOP
    v_bat_peso := LEAST(v_restante_kg, 150.000);

    IF v_bat_peso = 150.000 THEN
      v_carne := 142.500;
      v_temperos := 7.500;
    ELSE
      v_carne := round(v_bat_peso * 0.95, 3);
      v_temperos := round(v_bat_peso - v_carne, 3);
    END IF;

    v_lote := 'LOTE-' || btrim(p_numero) || '-' || lpad(v_num::text, 2, '0');

    INSERT INTO public.batelada (
      ordem_id, numero, lote, carne_kg, temperos_kg, temperos_descricao, separado, recebido
    ) VALUES (
      p_ordem_id, v_num, v_lote, v_carne, v_temperos, '', false, false
    );

    v_restante_kg := v_restante_kg - v_bat_peso;
    v_num := v_num + 1;
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.fn_gerar_bateladas_op(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_gerar_bateladas_op(uuid, text) TO authenticated;

-- 2. Atualizar fn_criar_ordem_producao com geração de bateladas
CREATE OR REPLACE FUNCTION public.fn_criar_ordem_producao(
  p_numero text, p_data date, p_responsavel text, p_observacoes text, p_sabores jsonb
)
RETURNS uuid LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  v_id uuid;
  v_sabor jsonb;
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

  -- Gerar bateladas automaticamente
  PERFORM public.fn_gerar_bateladas_op(v_id, p_numero);

  RETURN v_id;
END $$;

REVOKE ALL ON FUNCTION public.fn_criar_ordem_producao(text,date,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_criar_ordem_producao(text,date,text,text,jsonb) TO authenticated;

-- 3. Função RPC para atualizar OP e recalcular bateladas com verificação de produção em andamento
CREATE OR REPLACE FUNCTION public.fn_atualizar_ordem_producao(
  p_id uuid, p_numero text, p_data date, p_responsavel text, p_situacao text, p_observacoes text, p_sabores jsonb
)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  v_sabor jsonb;
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

  -- Verificar se já existem registros em andamento
  IF EXISTS (
    SELECT 1 FROM public.batelada
    WHERE ordem_id = p_id AND (separado OR recebido OR inicio_cura IS NOT NULL)
  ) OR EXISTS (
    SELECT 1 FROM public.ordem_sabor
    WHERE ordem_id = p_id AND (embutido_kg IS NOT NULL OR insumos_separados)
  ) OR EXISTS (
    SELECT 1 FROM public.pedido
    WHERE ordem_id = p_id AND situacao != 'cancelado'
  ) THEN
    RAISE EXCEPTION 'Não é possível recalcular as bateladas da OP porque já existem apontamentos de produção, separação, recebimento ou pedidos em andamento.' USING ERRCODE = '55000';
  END IF;

  -- Atualizar dados da OP
  UPDATE public.ordem_producao
    SET numero = btrim(p_numero),
        data = p_data,
        responsavel = btrim(p_responsavel),
        situacao = p_situacao,
        observacoes = coalesce(p_observacoes, '')
    WHERE id = p_id;

  -- Limpar bateladas e sabores antigos
  DELETE FROM public.batelada WHERE ordem_id = p_id;
  DELETE FROM public.ordem_sabor WHERE ordem_id = p_id;

  -- Recriar sabores
  FOR v_sabor IN SELECT value FROM jsonb_array_elements(p_sabores)
  LOOP
    IF jsonb_typeof(v_sabor) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'Cada sabor deve ser um objeto.' USING ERRCODE = '22023';
    END IF;
    INSERT INTO public.ordem_sabor(ordem_id, nome, planejado_kg)
      VALUES (p_id, btrim(v_sabor->>'nome'), (v_sabor->>'planejado_kg')::numeric);
  END LOOP;

  -- Gerar bateladas atualizadas
  PERFORM public.fn_gerar_bateladas_op(p_id, p_numero);
END $$;

REVOKE ALL ON FUNCTION public.fn_atualizar_ordem_producao(uuid,text,date,text,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_atualizar_ordem_producao(uuid,text,date,text,text,text,jsonb) TO authenticated;

COMMIT;
