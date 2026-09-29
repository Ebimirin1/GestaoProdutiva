-- CONTROLE DE PRODUÇÃO SIMPLES — PostgreSQL / Supabase — Acesso Público (Sem Login)
-- Execute inteiro UMA VEZ no NOVO projeto Supabase, no SQL Editor.
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

-- Lista de acesso mantida para compatibilidade
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

-- Datas de atualização do servidor
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

-- Permissões de esquema e sequências
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;

-- RLS habilitado com acesso público para anon e authenticated (sem login)
DO $$
DECLARE nome text;
BEGIN
  FOREACH nome IN ARRAY ARRAY['colaborador','ordem_producao','ordem_sabor','batelada','pedido','pedido_item']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', nome);
    EXECUTE format('REVOKE ALL ON public.%I FROM PUBLIC, anon, authenticated', nome);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE ON public.%I TO anon, authenticated', nome);
    EXECUTE format('CREATE POLICY acesso_publico_leitura ON public.%I FOR SELECT TO anon, authenticated USING (true)', nome);
    EXECUTE format('CREATE POLICY acesso_publico_inclusao ON public.%I FOR INSERT TO anon, authenticated WITH CHECK (true)', nome);
    EXECUTE format('CREATE POLICY acesso_publico_alteracao ON public.%I FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true)', nome);
  END LOOP;
END $$;

-- Criação atômica de OP + sabores (sem verificação de login)
CREATE FUNCTION public.fn_criar_ordem_producao(
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

-- Criação atômica de Pedido + itens (sem verificação de login)
CREATE FUNCTION public.fn_criar_pedido(
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
