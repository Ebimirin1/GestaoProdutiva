# AGENTS.md — Regras para o Jules

## Objetivo

Implementar o MVP descrito em `spec.md`, acompanhando `task.md`. O aplicativo é composto por **quatro telas operacionais** (Planejamento, Produção, Expedição e Saldo da Loja) e uma **tela inicial exclusiva de login**.

## Arquitetura obrigatória

HTML + CSS + JavaScript puro; Supabase PostgreSQL/Auth/cliente JS; GitHub Pages. Sem framework de frontend, servidor Express/FastAPI, ORM ou build obrigatório.

## Regras de Acesso e Banco

- Tela exclusiva de login por e-mail/senha via Supabase Auth ao abrir a URL.
- Autorização mantida pela tabela `usuarios_permitidos` e função `tem_acesso()`.
- O administrador possui o UID `fc952189-34d3-4963-b6c6-f408a249a47b`.
- NUNCA coloque senhas, `service_role` ou chaves secretas no código frontend ou histórico.
- Mantenha RLS habilitado.
- Para o banco existente no Supabase, forneça o arquivo incremental `restaurar_acesso_admin.sql`. Não execute SQL no banco remoto por conta própria.
- O `schema.sql` atualizado é utilizado para instalações novas.

## Resumo das quatro telas

1. **Planejamento:** OPs, quantidades por sabor, modal de colaboradores.
2. **Produção:** Bateladas (máx. 150 kg), temperos, insumos e embutimento.
3. **Expedição:** Pedidos de atacado e separação por cliente.
4. **Saldo da Loja:** Resumo geral por sabor (planejado, embutido real, separado atacado, saldo estimado para a loja = embutido - separado).
