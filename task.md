# Plano de execução — MVP de três telas

Todas as tarefas abaixo estão pendentes no **novo projeto**. Os documentos não são evidência de implementação. Leia `spec.md` e `AGENTS.md` antes de iniciar. Stack obrigatória: HTML, CSS, JavaScript puro, Supabase e GitHub Pages.

## T0 — Organizar e publicar a base

- [ ] Colocar `spec.md`, `AGENTS.md`, `task.md`, `schema.sql` e `README.md` na raiz do repositório escolhido.
- [ ] Extrair o HTML/CSS/imagens do Google Stitch; colocar o HTML inicial em `index.html` na raiz. Não subir o ZIP como substituto dos arquivos.
- [ ] Organizar apenas `index.html`, `styles.css`, `app.js`, `config.js` e `.nojekyll` (vazio); criar pasta de imagens somente se necessária.
- [ ] Implementar menu de três telas por hash, layouts responsivos e caminhos relativos. Identificar funções ainda não implementadas; não simular integração.
- [ ] Commit + PR da base; publicar a PR no GitHub. Usuário faz merge.
- [ ] Usuário: ativar Settings → Pages → Deploy from a branch → main → /(root) → Save. Confirmar o link e a execução concluída em Actions.

**Aceite:** site inicial abre pelo link do Pages e F5 nas três seções não dá 404. A base visual ainda não significa que o banco está integrado.

## T1 — Novo Supabase e acesso

- [ ] Usuário: criar um novo projeto Supabase. Pode usar a conta atual; não é necessário criar outra conta.
- [ ] Usuário: executar `schema.sql` uma vez no projeto novo. Não usar no banco antigo.
- [ ] Usuário: criar conta em Authentication → Users, copiar o UID e inserir em `usuarios_permitidos`, conforme README.
- [ ] Usuário: preencher em `config.js` a URL **do novo projeto** e sua chave publishable. Não reaproveitar URL/chave do banco antigo.
- [ ] Jules: implementar login/logout, restauração de sessão, verificação `tem_acesso()` e mensagens de falha. Usuário sem acesso não vê dados operacionais.
- [ ] Testar configuração ausente, senha incorreta, usuário não autorizado, login autorizado e logout. Usar contas de teste em ambiente apropriado; não registrar senhas em arquivos.
- [ ] Commit + PR, merge e teste no link Pages.

**Aceite:** usuário autorizado entra; visitantes e contas fora da lista não acessam os dados. RLS continua ativo.

## T2 — Planejamento

- [ ] Modal de colaboradores (nome, ativo/inativo), lista inicialmente vazia.
- [ ] Lista de OPs e formulário de criação com uma linha por sabor.
- [ ] Validar número/data/responsável, pelo menos um sabor, nomes sem duplicidade e kg > 0.
- [ ] Integrar RPC `fn_criar_ordem_producao`; conferir os parâmetros em `schema.sql`.
- [ ] Editar cabeçalho/linhas individualmente, adicionar sabor, mudar situação e cancelar OP sem apagar histórico.
- [ ] Exibir total planejado como soma; preservar data local.
- [ ] Testar uma OP com vários sabores; uma linha inválida deve desfazer toda a criação. Recarregar página e confirmar dados.
- [ ] Commit + PR, merge e teste no Pages.

## T3 — Produção

- [ ] Seleção da OP e seções recolhíveis Bateladas e Insumos/Embutimento.
- [ ] Cadastro/edição de bateladas: número, lote, carne_kg, temperos_kg, temperos_descricao, responsáveis e marcações.
- [ ] Total carne + temperos <= 150 kg no formulário e banco. Recebido depende de Separado.
- [ ] Início de cura opcional e previsão informativa +12h; sem liberação automática.
- [ ] Por sabor: insumos_descricao, responsável, insumos separados, embutido_kg, lote e validade.
- [ ] Diferença em kg e %, sem tolerância arbitrária e sem bloqueio por diferença. Distinguir NULL de zero.
- [ ] Testar salvamento e recarga; rejeição de 151 kg; aceitar 150 kg; responsáveis obrigatórios nas marcações; diferença negativa e positiva.
- [ ] Commit + PR, merge e teste no Pages.

## T4 — Expedição

- [ ] Lista, formulário e edição de pedidos de Cliente de atacado, com uma OP por pedido.
- [ ] Itens por sabor/conservação; solicitado > 0 e separado de 0 até solicitado.
- [ ] Criação atômica pela RPC `fn_criar_pedido`; rejeitar sabor pertencente a outra OP.
- [ ] Editar registros individualmente, adicionar item, marcar situação/cancelamento. Sem exclusão de itens salvos.
- [ ] Resumo por sabor: planejado, embutido, solicitado, separado e saldo estimado para loja; excluir pedidos cancelados das somas.
- [ ] Alertar saldo negativo e embutido pendente; não implementar reserva/estoque ou faturamento.
- [ ] Testar duas conservações para o mesmo sabor, rollback de item inválido, cancelamento e recarga.
- [ ] Commit + PR, merge e teste no Pages.

## T5 — Fechamento

- [ ] Conferir as três telas no computador e celular; acessibilidade básica e impressão via CSS se incluída.
- [ ] Confirmar ausência de dados fictícios, senhas, chaves secretas e mensagens técnicas desnecessárias.
- [ ] Revisar configuração e RLS; testar que outro usuário não autorizado não obtém nem grava dados.
- [ ] Documentar alterações de SQL necessárias ao novo banco; nenhuma migração pendente pode ser escondida do usuário.
- [ ] Atualizar esta lista com evidências e limitações. Entregar link da PR e, após merge/publicação verificados, link do Pages.

## Registro a preencher pelo Jules em cada PR

| Informação | Resultado |
|---|---|
| Tarefa implementada | |
| Arquivos alterados | |
| Teste local executado | |
| Teste no Supabase executado ou pendente | |
| SQL a executar, se houver | |
| PR/branch publicada | |
| Merge efetuado ou pendente | |
| Pages publicado e verificado ou pendente | |
| Próxima tarefa | |

**Regra de publicação:** alteração → commit → PR → revisão/merge em `main` → publicação Pages → teste pelo link. Abrir PR não publica o site. A criação automática de PR depende da capacidade/configuração real do Jules, não apenas deste arquivo.
