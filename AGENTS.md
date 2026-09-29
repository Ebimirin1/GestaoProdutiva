# AGENTS.md — Regras para o Jules

## Objetivo

Implementar o MVP descrito em `spec.md`, acompanhando `task.md`. São exatamente três telas: Planejamento, Produção e Expedição. O login usa um modal de acesso por e-mail e senha via Supabase Auth.

## Arquitetura obrigatória

HTML + CSS + JavaScript puro; Supabase PostgreSQL/Auth/cliente JS; GitHub Pages. Sem framework de frontend, servidor Express/FastAPI, ORM ou build obrigatório.

## Regras de Acesso e Banco

- Autenticação por e-mail/senha no Supabase Auth.
- Autorização mantida pela tabela `usuarios_permitidos` e função `tem_acesso()`.
- O administrador possui o UID `fc952189-34d3-4963-b6c6-f408a249a47b`.
- NUNCA coloque senhas, `service_role` ou chaves secretas no código frontend ou histórico.
- Mantenha RLS habilitado.
- Para o banco existente no Supabase, forneça o arquivo incremental `restaurar_acesso_admin.sql`. Não execute SQL no banco remoto por conta própria.
- O `schema.sql` atualizado é utilizado para instalações novas.

## Resumo das três telas

1. **Planejamento:** OPs, quantidades por sabor, modal de colaboradores.
2. **Produção:** Bateladas (máx. 150 kg), temperos, insumos e embutimento.
3. **Expedição:** Pedidos de atacado e matriz de saldo estimado para a loja.
