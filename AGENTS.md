# AGENTS.md — Regras para o Jules

## Objetivo

Implementar o MVP descrito em `spec.md`, acompanhando `task.md`. São exatamente três telas: Planejamento, Produção e Expedição. Temperos/bateladas e embutimento são seções da tela Produção. Login e cadastro de colaboradores usam modais, sem novos módulos.

## Arquitetura obrigatória

HTML + CSS + JavaScript puro; Supabase PostgreSQL/Auth/cliente JS; GitHub Pages. Sem framework de frontend, servidor Express/FastAPI, ORM, build obrigatório ou dependência de Python na máquina do usuário. Ferramentas de teste no ambiente do agente são permitidas. Reaproveitar o código extraído do Google Stitch quando compatível, eliminando elementos fora do escopo.

## Fontes e prioridade

1. Instruções atuais do usuário e `spec.md` desta versão simples.
2. `schema.sql` como contrato do banco; `task.md` como sequência de implementação.
3. `design.md` e código existente como referências visuais, subordinados ao escopo simples.

Documentos antigos podem mencionar quatro telas ou 14 tabelas: não reintroduzir essa arquitetura. Não alterar regras de receita, tolerância, peso ou permissões por inferência.

## Execução

- Faça o próximo incremento pendente em `task.md`, começando por publicação da estrutura e autenticação. Entregue trabalho executável; não encerrar apenas dizendo “posso implementar”.
- Uma PR por incremento coerente, não uma PR por linha editada. Continue os itens autorizados conforme a capacidade da sessão e registre precisamente onde parou.
- Antes de mudar, leia os arquivos atuais e confira a branch. Preserve alterações do usuário. Não substitua o `index.html` configurado por um protótipo antigo.
- Priorize falhas de login/RLS, gravação e navegação antes de melhorias visuais. Não acrescente financeiro, estoque, gráficos, cálculo de receitas ou módulos fora da especificação.
- Mantenha `index.html` na raiz, links relativos e navegação por hash. O site deve abrir por HTTPS no GitHub Pages sem terminal na máquina do usuário.
- Use somente URL Supabase e chave pública/publishable em `config.js`. Preserve os valores existentes quando forem válidos. Nunca coloque senhas, `service_role`, chaves secretas ou tokens de GitHub/Jules no frontend ou histórico.
- Usuários autenticados precisam estar na lista de acesso. Não substituir essa verificação por acesso livre a todos os autenticados. Não desabilitar RLS para resolver erro de tela.
- A instalação `schema.sql` se destina ao novo projeto Supabase. Não executá-la no projeto antigo. Mudanças posteriores exigem arquivo incremental separado e instruções; não apagar ou recriar tabelas com dados.
- Não executar SQL remoto por conta própria. Preparar o arquivo e explicar a etapa ao administrador. Testes SQL podem ocorrer em banco local descartável.
- Campos de peso usam até três casas decimais. Não converter quantidade em ml/un para kg sem informação explícita. O peso total de temperos da batelada é informado em kg pelo operador.
- Não inventar dados reais nem fingir integração com localStorage. Mocks são exclusivos dos testes.

## Teste e evidência

Verificar o fluxo alterado, navegação e erros; teste de HTTP 200 sozinho não valida login nem gravação. Para banco: rollback de OP/pedido inválidos, lote com carne + temperos acima de 150 kg rejeitado, item de pedido com sabor de outra OP rejeitado e usuários não autorizados bloqueados. Com dados de teste em ambiente isolado, verificar que as três telas consultam e persistem corretamente. Não exigir testes extensos para alteração simples de texto.

## GitHub e GitHub Pages

- Criar commits e abrir/atualizar PR para `main` ao entregar alterações de código. Publicar a branch/PR pelo recurso disponível na sessão; se não houver capacidade, indicar explicitamente o botão Publish PR. Só afirmar publicação quando existir URL/identificador verificável.
- O usuário revisa e faz merge. Não habilitar auto-merge ou agendamentos sem configuração explícita. O site configurado em `main` / `(root)` atualiza depois do merge e da execução bem-sucedida do Pages.
- Se uma integração Jules API já existir, `automationMode: AUTO_CREATE_PR` pode criar PR automaticamente. Não implementar uma API ou GitHub Action adicional apenas para isso neste MVP.
- Atualizar `task.md` na mesma PR: marcar concluído apenas o implementado e testado; indicar separadamente passos que dependem de usuário, banco remoto ou publicação.
- Não versionar ZIPs de entrega, dados operacionais exportados ou credenciais secretas. Manter arquivos-fonte descompactados. Não apagar documentos antigos do usuário sem necessidade; identificar os cinco arquivos desta versão como referência atual.

## Resumo obrigatório de cada entrega

Em português: mudança implementada; testes executados e limitações; SQL pendente; link da PR ou ação necessária para publicá-la; próxima tarefa; como o usuário testa no Pages após merge. Use instruções curtas com o nome real dos botões.
