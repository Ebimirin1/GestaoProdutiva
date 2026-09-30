-- CONTROLE DE PRODUÇÃO SIMPLES — PostgreSQL / Supabase — v1 — 29/09/2026
-- Execute inteiro UMA VEZ no NOVO projeto Supabase, no SQL Editor.
-- Não é migração do projeto antigo. Não inclui usuários ou dados de exemplo.
-- Se tabelas do aplicativo já existirem, aborta a transação sem apagar dados.

BEGIN;

DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['usuarios_permitidos','colaborador','ordem_producao',
                              'ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    IF to_regclass('public.' || nome) IS NOT NULL THEN
      RAISE EXCEPTION 'A tabela public.% já existe. Este arquivo é apenas para instalação inicial no novo projeto. Não apague dados; confira o projeto selecionado.', nome;
    END IF;
  END LOOP;
END $$;

-- Lista de acesso: somente usuários no Supabase Auth e autorizados nesta tabela têm acesso.
CREATE TABLE public.usuarios_permitidos (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  ativo boolean NOT NULL DEFAULT true,
  criado_em timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.colaborador (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL CHECK (length(btrim(nome)) > 0),
  ativo boolean NOT NULL DEFAULT true,
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX colaborador_nome_unico ON public.colaborador (lower(btrim(nome)));

CREATE TABLE public.ordem_producao (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero text NOT NULL UNIQUE CHECK (length(btrim(numero)) > 0),
  data date NOT NULL,
  responsavel text NOT NULL CHECK (length(btrim(responsavel)) > 0),
  situacao text NOT NULL DEFAULT 'rascunho'
    CHECK (situacao IN ('rascunho','em_producao','concluida','cancelada')),
  observacoes text NOT NULL DEFAULT '',
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ordem_producao_data_idx ON public.ordem_producao(data);

CREATE TABLE public.ordem_sabor (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ordem_id uuid NOT NULL REFERENCES public.ordem_producao(id) ON DELETE RESTRICT,
  nome text NOT NULL CHECK (length(btrim(nome)) > 0),
  planejado_kg numeric(12,3) NOT NULL CHECK (planejado_kg BETWEEN 0.001 AND 999999999.999),
  embutido_kg numeric(12,3) CHECK (embutido_kg BETWEEN 0 AND 999999999.999),
  insumos_descricao text NOT NULL DEFAULT '',
  responsavel_insumos text NOT NULL DEFAULT '',
  insumos_separados boolean NOT NULL DEFAULT false,
  concluido boolean NOT NULL DEFAULT false,
  lote text NOT NULL DEFAULT '',
  validade date,
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, ordem_id),
  CHECK (NOT insumos_separados OR length(btrim(responsavel_insumos)) > 0)
);
CREATE UNIQUE INDEX ordem_sabor_nome_unico
  ON public.ordem_sabor (ordem_id, lower(btrim(nome)));

CREATE TABLE public.batelada (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ordem_id uuid NOT NULL REFERENCES public.ordem_producao(id) ON DELETE RESTRICT,
  numero integer NOT NULL CHECK (numero > 0),
  lote text NOT NULL CHECK (length(btrim(lote)) > 0),
  carne_kg numeric(12,3) NOT NULL CHECK (carne_kg BETWEEN 0.001 AND 150),
  temperos_kg numeric(12,3) NOT NULL DEFAULT 0 CHECK (temperos_kg BETWEEN 0 AND 150),
  temperos_descricao text NOT NULL DEFAULT '',
  responsavel_separacao text NOT NULL DEFAULT '',
  responsavel_recebimento text NOT NULL DEFAULT '',
  separado boolean NOT NULL DEFAULT false,
  recebido boolean NOT NULL DEFAULT false,
  inicio_cura timestamptz,
  observacoes text NOT NULL DEFAULT '',
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (ordem_id, numero),
  CHECK (carne_kg + temperos_kg <= 150),
  CHECK (NOT separado OR length(btrim(responsavel_separacao)) > 0),
  CHECK (NOT recebido OR (separado AND length(btrim(responsavel_recebimento)) > 0))
);

CREATE TABLE public.pedido (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  numero text NOT NULL UNIQUE CHECK (length(btrim(numero)) > 0),
  ordem_id uuid NOT NULL REFERENCES public.ordem_producao(id) ON DELETE RESTRICT,
  cliente text NOT NULL CHECK (length(btrim(cliente)) > 0),
  data date NOT NULL,
  destino text NOT NULL DEFAULT '',
  situacao text NOT NULL DEFAULT 'rascunho'
    CHECK (situacao IN ('rascunho','separado','expedido','cancelado')),
  observacoes text NOT NULL DEFAULT '',
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, ordem_id)
);
CREATE INDEX pedido_ordem_idx ON public.pedido(ordem_id);

CREATE TABLE public.pedido_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pedido_id uuid NOT NULL,
  ordem_id uuid NOT NULL,
  ordem_sabor_id uuid NOT NULL,
  conservacao text NOT NULL CHECK (conservacao IN ('resfriado','congelado')),
  solicitado_kg numeric(12,3) NOT NULL CHECK (solicitado_kg BETWEEN 0.001 AND 999999999.999),
  separado_kg numeric(12,3) NOT NULL DEFAULT 0,
  criado_em timestamptz NOT NULL DEFAULT now(),
  atualizado_em timestamptz NOT NULL DEFAULT now(),
  FOREIGN KEY (pedido_id, ordem_id) REFERENCES public.pedido(id, ordem_id) ON DELETE RESTRICT,
  FOREIGN KEY (ordem_sabor_id, ordem_id) REFERENCES public.ordem_sabor(id, ordem_id) ON DELETE RESTRICT,
  UNIQUE (pedido_id, ordem_sabor_id, conservacao),
  CHECK (separado_kg >= 0 AND separado_kg <= solicitado_kg)
);
CREATE INDEX pedido_item_sabor_idx ON public.pedido_item(ordem_sabor_id, ordem_id);

-- Datas de atualização do servidor.
CREATE FUNCTION public.atualizar_data_modificacao()
RETURNS trigger LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.atualizado_em := now();
  RETURN NEW;
END $$;

DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    EXECUTE format('CREATE TRIGGER atualizar_data BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.atualizar_data_modificacao()', nome);
  END LOOP;
END $$;

-- A lista usuarios_permitidos usa RLS
ALTER TABLE public.usuarios_permitidos ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.usuarios_permitidos FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.usuarios_permitidos TO authenticated;
CREATE POLICY consultar_proprio_acesso ON public.usuarios_permitidos
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE FUNCTION public.tem_acesso()
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios_permitidos
    WHERE user_id = (SELECT auth.uid()) AND ativo
  );
$$;
REVOKE ALL ON FUNCTION public.tem_acesso() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.tem_acesso() TO authenticated;

-- RLS habilitado para a equipe autorizada
DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', nome);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated', nome);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON public.%I TO authenticated', nome);
    EXECUTE format('CREATE POLICY equipe_leitura ON public.%I FOR SELECT TO authenticated USING ((SELECT public.tem_acesso()))', nome);
    EXECUTE format('CREATE POLICY equipe_inclusao ON public.%I FOR INSERT TO authenticated WITH CHECK ((SELECT public.tem_acesso()))', nome);
    EXECUTE format('CREATE POLICY equipe_alteracao ON public.%I FOR UPDATE TO authenticated USING ((SELECT public.tem_acesso())) WITH CHECK ((SELECT public.tem_acesso()))', nome);
  END LOOP;
END $$;

-- Função de trigger para atualizar o status geral da OP automaticamente
CREATE OR REPLACE FUNCTION public.fn_atualizar_status_op_automatico()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_ordem_id uuid;
  v_situacao_atual text;
  v_total_sabores integer := 0;
  v_sabores_concluidos integer := 0;
  v_tem_sabor_iniciado boolean := false;
  v_tem_batelada_iniciada boolean := false;
BEGIN
  IF TG_TABLE_NAME = 'ordem_sabor' THEN
    v_ordem_id := coalesce(NEW.ordem_id, OLD.ordem_id);
  ELSIF TG_TABLE_NAME = 'batelada' THEN
    v_ordem_id := coalesce(NEW.ordem_id, OLD.ordem_id);
  END IF;

  IF v_ordem_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT situacao INTO v_situacao_atual
  FROM public.ordem_producao
  WHERE id = v_ordem_id;

  IF v_situacao_atual = 'cancelada' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT
    count(*),
    count(*) FILTER (WHERE concluido = true),
    bool_or(concluido = true OR embutido_kg IS NOT NULL OR insumos_separados = true)
  INTO v_total_sabores, v_sabores_concluidos, v_tem_sabor_iniciado
  FROM public.ordem_sabor
  WHERE ordem_id = v_ordem_id;

  IF v_total_sabores = 0 THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  SELECT bool_or(separado = true OR recebido = true OR inicio_cura IS NOT NULL)
  INTO v_tem_batelada_iniciada
  FROM public.batelada
  WHERE ordem_id = v_ordem_id;

  IF v_sabores_concluidos = v_total_sabores THEN
    UPDATE public.ordem_producao
    SET situacao = 'concluida'
    WHERE id = v_ordem_id AND situacao IS DISTINCT FROM 'concluida';
  ELSIF coalesce(v_tem_sabor_iniciado, false) OR coalesce(v_tem_batelada_iniciada, false) THEN
    UPDATE public.ordem_producao
    SET situacao = 'em_producao'
    WHERE id = v_ordem_id AND situacao IS DISTINCT FROM 'em_producao';
  END IF;

  RETURN COALESCE(NEW, OLD);
END $$;

REVOKE ALL ON FUNCTION public.fn_atualizar_status_op_automatico() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_atualizar_status_op_automatico() TO authenticated;

DROP TRIGGER IF EXISTS trg_atualizar_status_op_sabor ON public.ordem_sabor;
CREATE TRIGGER trg_atualizar_status_op_sabor
  AFTER INSERT OR UPDATE OR DELETE ON public.ordem_sabor
  FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_status_op_automatico();

DROP TRIGGER IF EXISTS trg_atualizar_status_op_batelada ON public.batelada;
CREATE TRIGGER trg_atualizar_status_op_batelada
  AFTER INSERT OR UPDATE OR DELETE ON public.batelada
  FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_status_op_automatico();

-- Função interna para geração automática de bateladas
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

-- Criação de OP, sabores e bateladas na mesma transação
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

  PERFORM public.fn_gerar_bateladas_op(v_id, p_numero);

  RETURN v_id;
END $$;
REVOKE ALL ON FUNCTION public.fn_criar_ordem_producao(text,date,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_criar_ordem_producao(text,date,text,text,jsonb) TO authenticated;

-- Atualização de OP preservando bateladas e apontamentos
CREATE OR REPLACE FUNCTION public.fn_atualizar_ordem_producao(
  p_id uuid, p_numero text, p_data date, p_responsavel text, p_situacao text, p_observacoes text, p_sabores jsonb
)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  v_sabor jsonb;
  v_sabor_id uuid;
  v_nome text;
  v_planejado numeric(12,3);
  v_sabores_enviados_ids uuid[] := '{}';
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

  UPDATE public.ordem_producao
    SET numero = btrim(p_numero),
        data = p_data,
        responsavel = btrim(p_responsavel),
        situacao = p_situacao,
        observacoes = coalesce(p_observacoes, '')
    WHERE id = p_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ordem de produção não encontrada.' USING ERRCODE = 'P0002';
  END IF;

  FOR v_sabor IN SELECT value FROM jsonb_array_elements(p_sabores)
  LOOP
    IF jsonb_typeof(v_sabor) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'Cada sabor deve ser um objeto.' USING ERRCODE = '22023';
    END IF;

    v_nome := btrim(v_sabor->>'nome');
    v_planejado := (v_sabor->>'planejado_kg')::numeric;
    v_sabor_id := NULL;

    IF v_sabor->>'id' IS NOT NULL AND (v_sabor->>'id') != '' THEN
      v_sabor_id := (v_sabor->>'id')::uuid;
    END IF;

    IF v_sabor_id IS NOT NULL THEN
      UPDATE public.ordem_sabor
        SET nome = v_nome,
            planejado_kg = v_planejado
        WHERE id = v_sabor_id AND ordem_id = p_id;
    ELSE
      SELECT id INTO v_sabor_id
      FROM public.ordem_sabor
      WHERE ordem_id = p_id AND lower(btrim(nome)) = lower(v_nome);

      IF v_sabor_id IS NOT NULL THEN
        UPDATE public.ordem_sabor
          SET planejado_kg = v_planejado
          WHERE id = v_sabor_id;
      ELSE
        INSERT INTO public.ordem_sabor(ordem_id, nome, planejado_kg)
          VALUES (p_id, v_nome, v_planejado)
          RETURNING id INTO v_sabor_id;
      END IF;
    END IF;

    v_sabores_enviados_ids := array_append(v_sabores_enviados_ids, v_sabor_id);
  END LOOP;

  DELETE FROM public.ordem_sabor
  WHERE ordem_id = p_id
    AND NOT (id = ANY(v_sabores_enviados_ids))
    AND embutido_kg IS NULL
    AND NOT insumos_separados
    AND NOT EXISTS (
      SELECT 1 FROM public.pedido_item WHERE ordem_sabor_id = public.ordem_sabor.id
    );

  IF NOT EXISTS (SELECT 1 FROM public.batelada WHERE ordem_id = p_id) THEN
    PERFORM public.fn_gerar_bateladas_op(p_id, p_numero);
  END IF;
END $$;
REVOKE ALL ON FUNCTION public.fn_atualizar_ordem_producao(uuid,text,date,text,text,text,jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_atualizar_ordem_producao(uuid,text,date,text,text,text,jsonb) TO authenticated;

-- Criação de Pedido + itens
CREATE FUNCTION public.fn_criar_pedido(
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

NOTIFY pgrst, 'reload schema';
