# Especificação — Controle de Produção Simples

Versão 1.0 • 29/09/2026 • Novo projeto Supabase

## 1. Objetivo e limite do projeto

Substituir o preenchimento disperso das ordens por um aplicativo simples, com exatamente **três telas de operação**. O login é uma caixa/modal de acesso, não um quarto módulo. Preservar o fluxo de planejamento, preparo, embutimento e expedição. Esta especificação consolida as decisões da conversa; não é uma cópia literal do antigo `spec.md`.

As antigas telas de temperos e de embutimento passam a ser seções de uma única tela chamada **Produção**. As seções podem recolher/expandir. Não criar ERP, dashboard gerencial, estoque completo, cadastro de fornecedores, faturamento, financeiro, compras, permissões por setor, API própria ou cálculo automático de receitas nesta versão.

## 2. Tecnologias obrigatórias

- **HTML, CSS e JavaScript puro**, sem React, Vue, Angular ou TypeScript.
- **Supabase**: PostgreSQL, Supabase Auth (e-mail/senha) e cliente JavaScript v2. Fixar uma versão testada do cliente ao implementar.
- **GitHub**: arquivos, histórico e pull requests (PRs).
- **GitHub Pages**: publicação do frontend estático, sem servidor próprio ou build obrigatório.
- **Google Stitch**: pode fornecer o HTML/CSS inicial. Extrair o código do ZIP e revisar o resultado; o ZIP não é o site publicado.
- Sem Node/Express, Python/FastAPI, Docker, ORM ou Edge Functions obrigatórios. Ferramentas de teste podem rodar no ambiente do agente sem virar requisito para o usuário abrir o site.

### Arquivos do aplicativo a implementar

| Arquivo | Papel |
|---|---|
| `index.html` | Entrada do site, login, menu e três telas |
| `styles.css` | Visual e impressão |
| `app.js` | Supabase, validações, cálculos e navegação |
| `config.js` | Somente URL do projeto e chave pública/publishable |
| `.nojekyll` | Arquivo vazio para publicação estática |
| `spec.md`, `task.md`, `AGENTS.md`, `schema.sql`, `README.md` | Requisitos, execução, instruções, banco e instalação |

Preferir essa estrutura pequena. Os cinco documentos deste pacote **não contêm ainda a interface implementada**.

Em `config.js`, usar `window.APP_CONFIG = { supabaseUrl: '...', supabasePublishableKey: '...' };`. Carregar config, cliente Supabase e app nessa ordem. Nunca inserir senha, chave secret/service_role ou string de conexão. A chave publishable é pública; a autorização vem do login e das políticas RLS. Não mostrar instruções técnicas de configuração depois que os valores estiverem válidos.

## 3. Acesso e uso

- Primeiro piloto: uma empresa, com usuários criados pelo administrador no Supabase Auth e autorizados na tabela `usuarios_permitidos`. Todos os autorizados veem os mesmos dados operacionais. Novas contas não ganham acesso automaticamente.
- Sem cadastro público pelo site. Login com e-mail/senha, restauração da sessão e botão Sair.
- Usuário sem sessão não consulta dados operacionais. Usuário autenticado, mas não autorizado, recebe mensagem clara de falta de acesso.
- Em cada operação: estado de carregamento, botão bloqueado enquanto salva, sucesso somente após resposta do banco e erro legível em caso de falha. Preservar o formulário quando der erro.
- Os nomes dos colaboradores identificam responsáveis pelo preenchimento; não são assinatura digital nem prova de autenticação.

## 4. As três telas

### Tela 1 — Planejamento

Lista das OPs com número, data, responsável, situação e total planejado. Criar OP em formulário/modal com pelo menos um sabor.

| Campo | Regra |
|---|---|
| Número da OP | Obrigatório, único; informado pelo usuário |
| Data | Obrigatória, data local da operação |
| Responsável | Seleção de colaborador ativo; gravar o nome como registro histórico |
| Situação | `rascunho`, `em_producao`, `concluida` ou `cancelada` |
| Observações | Opcional |
| Sabores | Uma linha por sabor, nome obrigatório e quantidade planejada em kg maior que zero |
| Total planejado | Soma das linhas; calculado, não digitado |

Não cadastrar o mesmo sabor duas vezes na mesma OP, ignorando maiúsculas/minúsculas e espaços externos. Salvar cabeçalho e sabores juntos pela RPC `fn_criar_ordem_producao`.

Permitir editar o cabeçalho e cada linha existente, e adicionar sabores à OP. No MVP, não oferecer exclusão de registros já salvos; usar cancelamento da OP. Manter canceladas identificadas no histórico e fora da seleção padrão de novas operações. Bloquear novas operações sobre OP cancelada no frontend; o MVP não implementa máquina de estados no banco.

O cadastro simples de colaboradores fica em um modal desta tela: nome e ativo/inativo, sem página adicional. Sem nomes fictícios pré-carregados. Exibir o nome histórico mesmo que o colaborador fique inativo.

### Tela 2 — Produção

Selecionar uma OP e mostrar duas seções, sem criar novas telas:

**A. Temperos e bateladas**

- Cadastrar bateladas manualmente: número dentro da OP, lote, carne em kg, peso total dos temperos em kg, detalhamento dos temperos, responsáveis pela separação e pelo recebimento.
- O campo de detalhamento é texto em linhas: nome do tempero, quantidade, unidade e lote. Não existe ficha técnica automática nesta versão.
- Total da batelada = carne + peso total dos temperos, com limite de **150 kg**, validado também pelo banco. Não dividir automaticamente apenas o peso da carne por 150, pois os temperos também ocupam essa capacidade.
- Registrar marcações Separado e Recebido. Recebido exige Separado; cada marcação exige responsável.
- Data/hora de início da cura opcional. Exibir previsão de término em início + **12 horas**, apenas como referência operacional; não liberar automaticamente o produto.
- Bateladas pertencem à OP; não distribuir automaticamente uma batelada entre sabores. Alterar uma batelada não recalcula os pesos por sabor.

**B. Insumos e embutimento por sabor**

- Exibir uma linha/cartão por sabor da OP: planejado, insumos necessários (texto livre com nome/quantidade/unidade), responsável pelos insumos, marcação Insumos separados, peso embutido real, lote e validade opcionais.
- `embutido_kg = NULL` significa ainda não informado; zero significa que o operador informou produção zero. Diferenciar esses estados na interface.
- Diferença em kg = embutido − planejado. Diferença em % = diferença / planejado × 100. Mostrar ambos sem bloquear a gravação. Não presumir margem de 5%, 10% ou outra tolerância.
- O total planejado representa a previsão final por sabor; a batelada registra a mistura-base. Não presumir igualdade automática entre esses totais, pois os complementos podem ser adicionados depois.
- Salvar cada batelada ou linha de sabor explicitamente; não simular salvamento com localStorage.

### Tela 3 — Expedição

- Listar pedidos e criar pedido de **Cliente de atacado**. Um pedido pertence a uma OP nesta versão; para outra OP, criar outro pedido.
- Campos: número único, OP, cliente de atacado, data, destino opcional, observações e situação (`rascunho`, `separado`, `expedido`, `cancelado`).
- Itens: sabor da OP selecionada, conservação (`resfriado` ou `congelado`), solicitado em kg e separado em kg. Permitir o mesmo sabor em duas linhas quando a conservação for diferente.
- Salvar cabeçalho e itens juntos pela RPC `fn_criar_pedido`. Depois, editar cabeçalho ou linha separadamente e adicionar itens. Sem exclusão de itens já salvos nesta versão; cancelar o pedido se precisar refazê-lo.
- Quantidade solicitada > 0; separado entre zero e solicitado, validado também pelo banco. Um item não pode apontar para sabor de outra OP.
- Resumo por sabor: planejado, embutido informado, solicitado ativo, separado ativo e saldo estimado para loja = embutido − separado de pedidos não cancelados. Se embutido não foi informado, mostrar “Pendente”, não um saldo fictício.
- Saldo negativo gera alerta visível. O MVP registra os apontamentos e **não é um controle de reserva de estoque**: não bloqueia a soma de pedidos concorrentes por saldo disponível.
- O termo é sempre “Cliente de atacado”; fornecedor não é cliente desse fluxo. Não implementar preços, notas fiscais ou faturamento.

## 5. Interface e dados

- Menu com apenas Planejamento, Produção e Expedição; uma seção visível por vez no mesmo `index.html`. Usar navegação por hash (`#planejamento`, `#producao`, `#expedicao`) para permitir F5 no Pages sem rota 404.
- Visual já escolhido: Ruwudu com fonte de reserva legível; cores `#D99311`, `#D90404`, `#8C0303`, `#590202`, `#260101`; fundo claro e contraste adequado. Usar `design.md` existente se disponível e compatível com este escopo.
- Interface em português, kg com até três casas decimais e datas brasileiras. Armazenar datas como `DATE`, instantes como `TIMESTAMPTZ` e exibir horário de São Paulo. Evitar que uma data sem hora mude um dia por conversão de fuso.
- Caminhos relativos (`./styles.css`), compatíveis com Pages dentro de `/nome-do-repositorio/`.
- Responsivo para computador e celular; formulários com rótulos e uso por teclado. Botão Imprimir pode usar `window.print()` e CSS, sem geração de PDF por biblioteca.
- Renderizar texto de usuários com `textContent` ou DOM seguro. Não inserir conteúdo não confiável diretamente em `innerHTML`.
- Sem dados fictícios em produção. Não incluir a OP de teste antiga no novo banco.

## 6. Modelo do banco e contrato com o frontend

Sete tabelas: `usuarios_permitidos` (acesso), `colaborador`, `ordem_producao`, `ordem_sabor`, `batelada`, `pedido`, `pedido_item`. Temperos e insumos ficam em textos descritivos para reduzir cadastros e relações. Não existe tabela de receitas, histórico complexo ou catálogo de produtos neste MVP.

`schema.sql` é a fonte exata dos nomes, tipos, constraints e parâmetros. É uma instalação inicial **uma única vez no novo projeto**, não uma migração das 14 tabelas antigas. Se encontrar tabelas com os mesmos nomes, deve parar sem apagar dados.

| Operação | API |
|---|---|
| Criar OP + sabores | `rpc('fn_criar_ordem_producao', {p_numero, p_data, p_responsavel, p_observacoes, p_sabores})` |
| Cada sabor da RPC | `{nome, planejado_kg}` |
| Criar pedido + itens | `rpc('fn_criar_pedido', {p_numero, p_ordem_id, p_cliente, p_data, p_destino, p_observacoes, p_itens})` |
| Cada item da RPC | `{ordem_sabor_id, conservacao, solicitado_kg}`; separado começa em zero |
| Demais registros | Cliente Supabase: `select`, `insert`, `update`, respeitando RLS |

As duas RPCs retornam UUID. Ambas usam SECURITY INVOKER e a transação do PostgreSQL. Uma linha inválida desfaz a criação inteira. Formulários de edição salvam um registro por vez; não prometer edição atômica de várias linhas.

## 7. GitHub, Jules e publicação

O código extraído fica no repositório; o `index.html` fica na raiz. Pages publica `main` / `(root)`. Cada entrega do Jules deve ter commit e PR para `main`, com resumo e teste. Após revisão e merge, Pages publica automaticamente. **Abrir a PR não atualiza o site; o merge na branch publicada é que permite a atualização.**

Usar a publicação de PR disponível no Jules. Se a sessão exigir ação humana, informar “Clique em Publish PR”; não afirmar que publicou. Uma integração via API pode usar `automationMode: AUTO_CREATE_PR`, mas não é requisito deste MVP. A instrução escrita em Markdown não ativa API, agendamento, auto-merge nem GitHub Pages por si só.

## 8. Aceite

Concluir quando as três telas funcionarem no link do GitHub Pages, um usuário autorizado puder criar/consultar/editar os registros previstos, os dados reaparecerem após recarregar e acessos anônimos ou não autorizados não alcançarem dados operacionais. Informar separadamente teste local, teste no Supabase, PR criada, merge efetuado e Pages publicado. Não chamar o projeto de completo apenas por responder HTTP 200.
