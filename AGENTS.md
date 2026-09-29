# AGENTS.md — Regras para o Jules

## Objetivo

Implementar o MVP descrito em `spec.md`, acompanhando `task.md`. São exatamente três telas: Planejamento, Produção e Expedição. O aplicativo é aberto e público, sem tela de login, senha ou verificação de sessão.

## Arquitetura obrigatória

HTML + CSS + JavaScript puro; Supabase PostgreSQL/cliente JS; GitHub Pages. Sem framework de frontend, servidor Express/FastAPI, ORM ou build obrigatório.

## Regras de Acesso e Banco

- O acesso é livre para visitantes (papel `anon` do Supabase).
- NUNCA utilize `service_role`, chaves secretas ou senhas no código frontend.
- Mantenha RLS habilitado com permissões de `SELECT, INSERT, UPDATE` para `anon`. Não conceda `DELETE`.
- Para o banco existente, forneça o arquivo incremental `liberar_acesso_publico.sql`. Não execute SQL no banco remoto por conta própria.
- O `schema.sql` atualizado é utilizado para instalações novas.

## Resumo das três telas

1. **Planejamento:** OPs, quantidades por sabor, modal de colaboradores.
2. **Produção:** Bateladas (máx. 150 kg), temperos, insumos e embutimento.
3. **Expedição:** Pedidos de atacado e matriz de saldo estimado para a loja.
