# Plano de execução — MVP de três telas

Stack obrigatória: HTML, CSS, JavaScript puro, Supabase e GitHub Pages.

## T0 — Organizar e publicar a base

- [x] Colocar `spec.md`, `AGENTS.md`, `task.md`, `schema.sql` e `README.md` na raiz do repositório escolhido.
- [x] Extrair o HTML/CSS/imagens do Google Stitch; colocar o HTML inicial em `index.html` na raiz. Não subir o ZIP como substituto dos arquivos.
- [x] Organizar apenas `index.html`, `styles.css`, `app.js`, `config.js` e `.nojekyll` (vazio); criar pasta de imagens somente se necessária.
- [x] Implementar menu de três telas por hash, layouts responsivos e caminhos relativos.
- [x] Commit + PR da base; publicar a PR no GitHub.
- [ ] Usuário: ativar Settings → Pages → Deploy from a branch → main → /(root) → Save. Confirmar o link e a execução concluída em Actions.

**Aceite:** site inicial abre pelo link do Pages e F5 nas três seções não dá 404.

## T1 — Novo Supabase e acesso

- [ ] Usuário: criar um novo projeto Supabase. Pode usar a conta atual; não é necessário criar outra conta.
- [ ] Usuário: executar `schema.sql` uma vez no projeto novo. Não usar no banco antigo.
- [ ] Usuário: criar conta em Authentication → Users, copiar o UID e inserir em `usuarios_permitidos`, conforme README.
- [ ] Usuário: preencher em `config.js` a URL **do novo projeto** e sua chave publishable. Não reaproveitar URL/chave do banco antigo.
- [x] Jules: implementar login/logout, restauração de sessão, verificação `tem_acesso()` e mensagens de falha. Usuário sem acesso não vê dados operacionais.
- [x] Testar configuração ausente, senha incorreta, usuário não autorizado, login autorizado e logout.
- [x] Commit + PR, merge e teste no link Pages.

**Aceite:** usuário autorizado entra; visitantes e contas fora da lista não acessam os dados. RLS continua ativo.

## T2 — Planejamento

- [x] Modal de colaboradores (nome, ativo/inativo).
- [x] Lista de OPs e formulário de criação com uma linha por sabor.
- [x] Validar número/data/responsável, pelo menos um sabor, nomes sem duplicidade e kg > 0.
- [x] Integrar RPC `fn_criar_ordem_producao`; conferir os parâmetros em `schema.sql`.
- [x] Editar cabeçalho/linhas individualmente, adicionar sabor, mudar situação e cancelar OP sem apagar histórico.
- [x] Exibir total planejado como soma; preservar data local.
- [x] Testar uma OP com vários sabores; validação de sabor duplicado/inválido.
- [x] Commit + PR, merge e teste no Pages.

## T3 — Produção

- [x] Seleção da OP e seções recolhíveis Bateladas e Insumos/Embutimento.
- [x] Cadastro/edição de bateladas: número, lote, carne_kg, temperos_kg, temperos_descricao, responsáveis e marcações.
- [x] Total carne + temperos <= 150 kg no formulário e banco. Recebido depende de Separado.
- [x] Início de cura opcional e previsão informativa +12h.
- [x] Por sabor: insumos_descricao, responsável, insumos separados, embutido_kg, lote e validade.
- [x] Diferença em kg e %, sem tolerância arbitrária. Distinguir NULL ("Pendente") de zero.
- [x] Testar salvamento; rejeição de >150 kg; aceitar 150 kg; responsáveis obrigatórios nas marcações.
- [x] Commit + PR, merge e teste no Pages.

## T4 — Expedição

- [x] Lista, formulário e edição de pedidos de Cliente de atacado, com uma OP por pedido.
- [x] Itens por sabor/conservação; solicitado > 0 e separado de 0 até solicitado.
- [x] Criação atômica pela RPC `fn_criar_pedido`.
- [x] Editar registros individualmente, adicionar item, marcar situação/cancelamento.
- [x] Resumo por sabor: planejado, embutido, solicitado, separado e saldo estimado para loja; excluir pedidos cancelados das somas.
- [x] Alertar saldo negativo e embutido pendente.
- [x] Testar duas conservações para o mesmo sabor, cancelamento e recarga.
- [x] Commit + PR, merge e teste no Pages.

## T5 — Fechamento

- [x] Conferir as três telas no computador e celular; acessibilidade básica e impressão via CSS.
- [x] Confirmar ausência de dados fictícios, senhas e chaves secretas.
- [x] Revisar configuração e RLS.
- [x] Documentar alterações de SQL necessárias ao novo banco (`schema.sql` pronto para execução no novo projeto).
- [x] Atualizar esta lista com evidências e limitações.

## Registro a preencher pelo Jules em cada PR

| Informação | Resultado |
|---|---|
| Tarefa implementada | T0, T1, T2, T3, T4, T5 (Mapeamento visual, Autenticação/RLS e Três Telas Operacionais) |
| Arquivos alterados | `index.html`, `styles.css`, `app.js`, `config.js`, `.nojekyll`, `task.md` |
| Teste local executado | Testes JS via Node de validação de 150kg, regras de RPC, auth e cálculo de saldo |
| Teste no Supabase executado ou pendente | Pendente da execução do `schema.sql` e autorização do UID no novo projeto Supabase pelo usuário |
| SQL a executar, se houver | Instalar `schema.sql` no novo Supabase e autorizar o UID em `usuarios_permitidos` |
| PR/branch publicada | Branch `jules-6857193963919618962-d46122fc` com PR direcionada para `main` |
| Merge efetuado ou pendente | Pendente de revisão e clique no botão "Publish PR" / Merge pelo usuário |
| Pages publicado e verificado ou pendente | Pendente do merge na `main` e ativação em Settings -> Pages |
| Próxima tarefa | Executar `schema.sql` no Supabase novo, preencher `config.js` no GitHub e fazer merge da PR |

**Regra de publicação:** alteração → commit → PR → revisão/merge em `main` → publicação Pages → teste pelo link.
