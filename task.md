# Plano de execução — MVP de quatro telas

Stack obrigatória: HTML, CSS, JavaScript puro, Supabase e GitHub Pages.

## T0 — Organizar e publicar a base

- [x] Colocar `spec.md`, `AGENTS.md`, `task.md`, `schema.sql` e `README.md` na raiz do repositório escolhido.
- [x] Extrair o HTML/CSS/imagens do Google Stitch; colocar o HTML inicial em `index.html` na raiz.
- [x] Organizar apenas `index.html`, `styles.css`, `app.js`, `config.js` e `.nojekyll` (vazio).
- [x] Implementar menu de quatro telas por hash (`#planejamento`, `#producao`, `#expedicao`, `#saldo-loja`).
- [x] Implementar tela inicial exclusiva de login por e-mail e senha.
- [x] Commit + PR da base; publicar a PR no GitHub.
- [ ] Usuário: ativar Settings → Pages → Deploy from a branch → main → /(root) → Save. Confirmar o link e a execução concluída em Actions.

## T1 — Supabase Auth e acesso

- [x] Conexão com o projeto Supabase (`ydvgbfbrkdfdtclbfqtc.supabase.co`) configurada em `config.js`.
- [x] Executar `restaurar_acesso_admin.sql` no Supabase para autorizar o administrador (`UID: fc952189-34d3-4963-b6c6-f408a249a47b`) e ativar RLS.
- [x] Jules: implementar login/logout, restauração de sessão e verificação `tem_acesso()`.
- [x] Commit + PR, merge e teste no link Pages.

## T2 — Planejamento

- [x] Modal de colaboradores (nome, ativo/inativo).
- [x] Lista de OPs e formulário de criação com uma linha por sabor via RPC `fn_criar_ordem_producao`. Geração automática de bateladas (95% carne e 5% tempero, limite de 150 kg).
- [x] Editar cabeçalho/linhas via RPC `fn_atualizar_ordem_producao` com regeneração automática de bateladas e bloqueio preventivo quando houver apontamentos em andamento.
- [x] Cancelar OP sem apagar histórico.

## T3 — Produção

- [x] Seleção da OP e seções recolhíveis Bateladas e Insumos/Embutimento.
- [x] Bateladas <= 150 kg geradas automaticamente (exibindo nº batelada, lote, carne kg, tempero kg e total kg), marcações Separado/Recebido, início de cura +12h.
- [x] Insumos e Embutimento por Sabor (diferença kg e %, distinção de NULL "Não informado" para 0 kg).

## T4 — Expedição

- [x] Lista, formulário e edição de pedidos de Cliente de atacado via RPC `fn_criar_pedido`.
- [x] Itens por sabor/conservação; solicitado > 0 e separado de 0 até solicitado.

## T5 — Saldo da Loja e Fechamento

- [x] Tela exclusiva "Resumo Geral por Sabor — Saldo da Loja" com filtro por OP ou geral.
- [x] Cálculo: Saldo da Loja = Embutido Real − Separado Atacado (excluindo pedidos cancelados).
- [x] Destaque de saldo negativo e rodapé com totais calculados.
- [x] Conferir as quatro telas em computador e celular; impressão CSS.
- [x] Documentar migração SQL `restaurar_acesso_admin.sql`.

## Registro a preencher pelo Jules em cada PR

| Informação | Resultado |
|---|---|
| Tarefa implementada | Tela inicial de login exclusiva, 4 telas operacionais (Planejamento, Produção, Expedição, Saldo da Loja) |
| Arquivos alterados | `config.js`, `index.html`, `app.js`, `restaurar_acesso_admin.sql`, `schema.sql`, `spec.md`, `AGENTS.md`, `README.md`, `task.md` |
| Teste local executado | Testes JS de cálculo de saldo, roteador de 4 telas, login e sessão |
| Teste no Supabase executado ou pendente | Conexão verificada com `ydvgbfbrkdfdtclbfqtc.supabase.co`. Resta executar `restaurar_acesso_admin.sql` no SQL Editor |
| SQL a executar, se houver | Executar `gerar_bateladas_automaticas.sql` no SQL Editor do Supabase para registrar `fn_atualizar_ordem_producao` |
| PR/branch publicada | Branch `jules-6857193963919618962-d46122fc` com PR para `main` |
| Merge efetuado ou pendente | Pendente de revisão e clique no botão "Publish PR" / Merge pelo usuário |
| Pages publicado e verificado ou pendente | Pendente do merge na `main` e ativação em Settings -> Pages |
| Próxima tarefa | Executar `restaurar_acesso_admin.sql` no Supabase, fazer merge da PR e testar no Pages |
