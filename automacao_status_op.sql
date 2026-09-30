-- CONTROLE DE PRODUÇÃO SIMPLES — Migração Incremental: Automação do Status da OP
-- Execute todo este código no SQL Editor do Supabase (https://supabase.com).

BEGIN;

-- 1. Adicionar o campo 'concluido' na tabela ordem_sabor se ainda não existir
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'ordem_sabor'
      AND column_name = 'concluido'
  ) THEN
    ALTER TABLE public.ordem_sabor ADD COLUMN concluido boolean NOT NULL DEFAULT false;
  END IF;
END $$;

-- 2. Função de trigger para atualizar o status geral da OP automaticamente
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

  -- Obter situação atual da OP
  SELECT situacao INTO v_situacao_atual
  FROM public.ordem_producao
  WHERE id = v_ordem_id;

  -- Regra 6: Preservar 'cancelada'
  IF v_situacao_atual = 'cancelada' THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Contar sabores e sabores concluídos
  SELECT
    count(*),
    count(*) FILTER (WHERE concluido = true),
    bool_or(concluido = true OR embutido_kg IS NOT NULL OR insumos_separados = true)
  INTO v_total_sabores, v_sabores_concluidos, v_tem_sabor_iniciado
  FROM public.ordem_sabor
  WHERE ordem_id = v_ordem_id;

  -- Regra 5: Uma OP sem sabores não pode ser concluída automaticamente
  IF v_total_sabores = 0 THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Verificar se qualquer batelada foi iniciada
  SELECT bool_or(separado = true OR recebido = true OR inicio_cura IS NOT NULL)
  INTO v_tem_batelada_iniciada
  FROM public.batelada
  WHERE ordem_id = v_ordem_id;

  -- Regra 4: Quando TODOS os sabores estiverem concluídos -> 'concluida'
  IF v_sabores_concluidos = v_total_sabores THEN
    UPDATE public.ordem_producao
    SET situacao = 'concluida'
    WHERE id = v_ordem_id AND situacao IS DISTINCT FROM 'concluida';

  -- Regra 2: Quando QUALQUER sabor ou batelada for iniciado -> 'em_producao'
  ELSIF coalesce(v_tem_sabor_iniciado, false) OR coalesce(v_tem_batelada_iniciada, false) THEN
    UPDATE public.ordem_producao
    SET situacao = 'em_producao'
    WHERE id = v_ordem_id AND situacao IS DISTINCT FROM 'em_producao';
  END IF;

  RETURN COALESCE(NEW, OLD);
END $$;

REVOKE ALL ON FUNCTION public.fn_atualizar_status_op_automatico() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fn_atualizar_status_op_automatico() TO authenticated;

-- 3. Criar triggers nas tabelas ordem_sabor e batelada
DROP TRIGGER IF EXISTS trg_atualizar_status_op_sabor ON public.ordem_sabor;
CREATE TRIGGER trg_atualizar_status_op_sabor
  AFTER INSERT OR UPDATE OR DELETE ON public.ordem_sabor
  FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_status_op_automatico();

DROP TRIGGER IF EXISTS trg_atualizar_status_op_batelada ON public.batelada;
CREATE TRIGGER trg_atualizar_status_op_batelada
  AFTER INSERT OR UPDATE OR DELETE ON public.batelada
  FOR EACH ROW EXECUTE FUNCTION public.fn_atualizar_status_op_automatico();

COMMIT;

-- Recarregar o cache de esquema do PostgREST
NOTIFY pgrst, 'reload schema';
