# Controle de Produção — Versão Simples (Quatro Telas)

Este projeto é um aplicativo web para controle de produção artesanal com quatro telas operacionais: **Planejamento, Produção, Expedição e Saldo da Loja**. As bateladas são geradas automaticamente na OP dividindo o total em 95% carne e 5% tempero (máx 150 kg por batelada). Tecnologias: **HTML + CSS + JavaScript + Supabase + GitHub Pages**.

## Tela Inicial de Login

Ao acessar o site, a primeira tela apresentada é a página exclusiva de **login por e-mail e senha**. Somente usuários autenticados via Supabase Auth e ativos na tabela `usuarios_permitidos` têm acesso ao sistema e às quatro telas.

## Instruções para o Banco Existente no Supabase

Para autorizar o usuário administrador e ativar/atualizar as funções RPC no banco existente:

1. Abra o painel do seu projeto no Supabase (`https://supabase.com`).
2. Acesse **SQL Editor** → **New query**.
3. **1º Passo:** Copie todo o conteúdo do arquivo `restaurar_acesso_admin.sql` e clique em **Run** (caso precise autorizar o admin UID).
4. **2º Passo:** Copie todo o conteúdo do arquivo `gerar_bateladas_automaticas.sql` e clique em **Run** (para criar/atualizar as funções atômicas de bateladas `fn_criar_ordem_producao` e `fn_atualizar_ordem_producao`).

## Instruções para um Novo Banco no Supabase

Para instalações do zero em um novo projeto Supabase:
1. Abra o **SQL Editor** no projeto novo.
2. Copie e execute todo o arquivo `schema.sql`.
3. Crie o usuário em **Authentication → Users** e insira o UID gerado na tabela `usuarios_permitidos`.

## Configuração em `config.js`

Em `config.js`, preencha apenas a URL e a chave publishable pública:

```js
window.APP_CONFIG = {
  supabaseUrl: 'https://SEU-PROJETO.supabase.co',
  supabasePublishableKey: 'SUA-CHAVE-PUBLISHABLE'
};
```

Nunca insira a chave `service_role` ou senhas de acesso.

## Publicação no GitHub Pages

1. Faça o merge da PR para a branch `main`.
2. Em **Settings → Pages**, escolha a branch `main` e a pasta `/(root)`.
3. Acesse o site pelo link fornecido pelo Pages.
