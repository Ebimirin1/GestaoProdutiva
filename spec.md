# Especificação — Controle de Produção Simples

Versão 2.0 • Acesso Público Aberto (Sem Login)

## 1. Objetivo e limite do projeto

Substituir o preenchimento disperso das ordens por um aplicativo simples, com exatamente **três telas de operação**: **Planejamento, Produção e Expedição**. O acesso é aberto e público para os visitantes, sem tela de login, senha ou sessão de usuário. Preservar o fluxo de planejamento, preparo, embutimento e expedição.

As telas de temperos e de embutimento são seções da tela **Produção**. Não criar ERP, dashboard gerencial, estoque completo, cadastro de fornecedores, faturamento, financeiro, compras ou cálculo automático de receitas nesta versão.

## 2. Tecnologias obrigatórias

- **HTML, CSS e JavaScript puro**, sem React, Vue, Angular ou TypeScript.
- **Supabase**: PostgreSQL, Supabase JS v2 client com acesso público (papel `anon`) controlado via RLS.
- **GitHub**: arquivos, histórico e pull requests (PRs).
- **GitHub Pages**: publicação do frontend estático, sem servidor próprio ou build obrigatório.

### Arquivos do aplicativo

| Arquivo | Papel |
|---|---|
| `index.html` | Entrada do site, menu e três telas |
| `styles.css` | Visual e impressão |
| `app.js` | Supabase, validações, cálculos e navegação |
| `config.js` | Somente URL do projeto e chave pública publishable |
| `.nojekyll` | Arquivo vazio para publicação estática |
| `liberar_acesso_publico.sql` | Migração SQL incremental para abrir acesso sem login no banco existente |
| `spec.md`, `AGENTS.md`, `task.md`, `schema.sql`, `README.md` | Requisitos, execução, instruções, banco e instalação |

Em `config.js`, usar `window.APP_CONFIG = { supabaseUrl: '...', supabasePublishableKey: '...' };`. Nunca inserir senha, chave secret/service_role ou string de conexão.

## 3. Acesso e uso

- Acesso totalmente aberto: qualquer visitante pode consultar, cadastrar e alterar dados operacionais nas três telas.
- Sem formulário de login ou e-mail/senha.
- Os nomes dos colaboradores identificam responsáveis no cadastro simples; não são contas de acesso nem assinatura digital.

## 4. As três telas

### Tela 1 — Planejamento
- Ordens de Produção (OP) com número, data, responsável, situação e total planejado.
- Criar OP via RPC `fn_criar_ordem_producao` com pelo menos um sabor.
- Gerenciar cadastro simples de colaboradores em modal.

### Tela 2 — Produção
- Seção A: Bateladas e Temperos (limite de 150 kg por batelada, marcações Separado/Recebido, início da cura + 12h de previsão).
- Seção B: Insumos e Embutimento por Sabor (diferença em kg e %, distinção de NULL "Pendente" para 0 kg).

### Tela 3 — Expedição
- Pedidos de cliente de atacado vinculados a OPs via RPC `fn_criar_pedido`.
- Itens por sabor e conservação (resfriado/congelado), separado entre 0 e solicitado.
- Matriz de Resumo por Sabor com saldo estimado para loja (excluindo pedidos cancelados das somas).

## 5. Banco de dados e RLS
- Tabelas com RLS habilitado concedendo `SELECT, INSERT, UPDATE` para `anon` e `authenticated`. Operação `DELETE` permanece bloqueada via RLS no frontend.
- RPCs `fn_criar_ordem_producao` e `fn_criar_pedido` executam atomicamente com `SECURITY INVOKER` e concessão `EXECUTE` para `anon`.
