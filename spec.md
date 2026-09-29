# Especificação — Controle de Produção Simples

Versão 3.0 • Acesso Autenticado com Supabase Auth

## 1. Objetivo e limite do projeto

Substituir o preenchimento disperso das ordens por um aplicativo simples, com exatamente **três telas de operação**: **Planejamento, Produção e Expedição**. O login é uma caixa/modal de acesso (e-mail/senha via Supabase Auth), não um quarto módulo. Preservar o fluxo de planejamento, preparo, embutimento e expedição.

As telas de temperos e de embutimento são seções da tela **Produção**. Não criar ERP, dashboard gerencial, estoque completo, cadastro de fornecedores, faturamento, financeiro, compras ou cálculo automático de receitas nesta versão.

## 2. Tecnologias obrigatórias

- **HTML, CSS e JavaScript puro**, sem React, Vue, Angular ou TypeScript.
- **Supabase**: PostgreSQL, Supabase Auth (e-mail/senha) e cliente JavaScript v2.
- **GitHub**: arquivos, histórico e pull requests (PRs).
- **GitHub Pages**: publicação do frontend estático, sem servidor próprio ou build obrigatório.

### Arquivos do aplicativo

| Arquivo | Papel |
|---|---|
| `index.html` | Entrada do site, login modal, menu e três telas |
| `styles.css` | Visual e impressão |
| `app.js` | Supabase, autenticação, validações, cálculos e navegação |
| `config.js` | Somente URL do projeto e chave pública publishable |
| `.nojekyll` | Arquivo vazio para publicação estática |
| `restaurar_acesso_admin.sql` | Migração SQL incremental para autorizar admin UID no banco existente |
| `spec.md`, `AGENTS.md`, `task.md`, `schema.sql`, `README.md` | Requisitos, execução, instruções, banco e instalação |

Em `config.js`, usar `window.APP_CONFIG = { supabaseUrl: '...', supabasePublishableKey: '...' };`. Nunca inserir senha, chave secret/service_role ou string de conexão.

## 3. Acesso e uso

- Login por e-mail e senha via Supabase Auth.
- Autorização controlada pela tabela `usuarios_permitidos` via função `tem_acesso()`.
- Administrador cadastrado no banco (`UID: fc952189-34d3-4963-b6c6-f408a249a47b`).
- Usuário sem sessão ou não autorizado não visualiza nem grava dados operacionais.
- Os colaboradores da fábrica pertencem a um cadastro simples de nomes, sem contas de acesso individuais.

## 4. As três telas

### Tela 1 — Planejamento
- Ordens de Produção (OP) com número, data, responsável, situação e total planejado.
- Criar OP via RPC `fn_criar_ordem_producao` com pelo menos um sabor.
- Modal de colaboradores (nome, ativo/inativo).

### Tela 2 — Produção
- Seção A: Bateladas e Temperos (limite de 150 kg por batelada, marcações Separado/Recebido, início da cura + 12h de previsão).
- Seção B: Insumos e Embutimento por Sabor (diferença em kg e %, distinção de NULL "Pendente" para 0 kg).

### Tela 3 — Expedição
- Pedidos de cliente de atacado vinculados a OPs via RPC `fn_criar_pedido`.
- Itens por sabor e conservação (resfriado/congelado), separado entre 0 e solicitado.
- Matriz de Resumo por Sabor com saldo estimado para loja (excluindo pedidos cancelados das somas).

## 5. Banco de dados e RLS
- Tabelas com RLS habilitado exigindo `tem_acesso()` para o papel `authenticated`.
- RPCs `fn_criar_ordem_producao` e `fn_criar_pedido` executam atomicamente com `SECURITY INVOKER` exigindo `tem_acesso()` e permissão `EXECUTE` para `authenticated`.
