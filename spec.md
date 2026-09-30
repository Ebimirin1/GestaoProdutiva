# Especificação — Controle de Produção Simples

Versão 4.0 • Quatro Telas e Login Inicial Exclusivo

## 1. Objetivo e limite do projeto

Substituir o preenchimento disperso das ordens por um aplicativo simples com **quatro telas de operação**:
1. **Planejamento:** Ordens de Produção (OP) e quantidades por sabor.
2. **Produção:** Temperos, bateladas, insumos e embutimento.
3. **Expedição:** Pedidos de atacado e separação por cliente.
4. **Saldo da Loja:** Resumo Geral por Sabor com saldo estimado para a loja (`embutido_kg - separado_atacado_kg`).

Ao abrir a URL do aplicativo, é apresentada uma **tela inicial exclusiva de login** por e-mail e senha via Supabase Auth. Após autenticação e autorização via `usuarios_permitidos`, o aplicativo libera o acesso às quatro telas operacionais.

Não criar ERP, dashboard gerencial, estoque completo, cadastro de fornecedores, faturamento, financeiro, compras ou cálculo automático de receitas nesta versão.

## 2. Tecnologias obrigatórias

- **HTML, CSS e JavaScript puro**, sem React, Vue, Angular ou TypeScript.
- **Supabase**: PostgreSQL, Supabase Auth (e-mail/senha) e cliente JavaScript v2.
- **GitHub**: arquivos, histórico e pull requests (PRs).
- **GitHub Pages**: publicação do frontend estático, sem servidor próprio ou build obrigatório.

### Arquivos do aplicativo

| Arquivo | Papel |
|---|---|
| `index.html` | Entrada do site, tela inicial exclusiva de login e quatro telas operacionais |
| `styles.css` | Visual e impressão |
| `app.js` | Supabase Auth, navegação entre 4 telas, validações e cálculos |
| `config.js` | Somente URL do projeto e chave pública publishable |
| `.nojekyll` | Arquivo vazio para publicação estática |
| `restaurar_acesso_admin.sql` | Migração SQL incremental para autorizar admin UID no banco existente |
| `spec.md`, `AGENTS.md`, `task.md`, `schema.sql`, `README.md` | Requisitos, execução, instruções, banco e instalação |

Em `config.js`, usar `window.APP_CONFIG = { supabaseUrl: '...', supabasePublishableKey: '...' };`. Nunca inserir senha, chave secret/service_role ou string de conexão.

## 3. Acesso e uso

- Tela de login inicial exclusiva antes de acessar qualquer dado operacional.
- Autenticação por e-mail e senha no Supabase Auth.
- Autorização controlada pela tabela `usuarios_permitidos` via função `tem_acesso()`.
- Administrador cadastrado no banco (`UID: fc952189-34d3-4963-b6c6-f408a249a47b`).
- Usuário sem sessão ou não autorizado é mantido na tela de login.

## 4. As quatro telas

### Tela 1 — Planejamento
- Ordens de Produção (OP) com número, data, responsável, situação e total planejado.
- Criar OP via RPC `fn_criar_ordem_producao` com pelo menos um sabor.
- Modal de colaboradores (nome, ativo/inativo).

### Tela 2 — Produção
- Seção A: Bateladas e Temperos (limite de 150 kg por batelada, marcações Separado/Recebido, início da cura + 12h de previsão).
- Seção B: Insumos e Embutimento por Sabor (diferença em kg e %, distinção de NULL "Não informado" para 0 kg).

### Tela 3 — Expedição
- Pedidos de cliente de atacado vinculados a OPs via RPC `fn_criar_pedido`.
- Itens por sabor e conservação (resfriado/congelado), separado entre 0 e solicitado.

### Tela 4 — Resumo Geral por Sabor (Saldo da Loja)
- Filtro por OP ativa ou visão geral de todas as OPs ativas.
- Colunas: Sabor, Planejado (kg), Embutido Real (kg), Separado Atacado (kg) e Saldo Estimado Loja (kg).
- Saldo da Loja = Quantidade Embutida − Quantidade Separada para Pedidos de Atacado Ativos.
- Quando o peso embutido ainda não foi informado, exibe "Não informado".
- Destaque para saldo negativo e linha de totais no rodapé.

## 5. Banco de dados e RLS
- Tabelas com RLS habilitado exigindo `tem_acesso()` para o papel `authenticated`.
- RPCs `fn_criar_ordem_producao` e `fn_criar_pedido` executam atomicamente com `SECURITY INVOKER` exigindo `tem_acesso()`.
