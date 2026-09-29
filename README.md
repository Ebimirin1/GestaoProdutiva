# Controle de Produção — Versão Simples (Acesso Aberto)

Este projeto é um aplicativo web para controle de produção artesanal com três telas: **Planejamento, Produção e Expedição**. Tecnologias: **HTML + CSS + JavaScript + Supabase + GitHub Pages**.

## Requisito de Acesso

O aplicativo é **aberto e público**, sem necessidade de e-mail, senha ou login. Qualquer visitante pode acessar e operar o sistema diretamente.

## Instruções para o Banco Existente no Supabase

Se você já possui o banco instalado no Supabase e deseja liberar o acesso direto sem login:

1. Abra o painel do seu projeto no Supabase (`https://supabase.com`).
2. Acesse **SQL Editor** → **New query**.
3. Copie todo o conteúdo do arquivo `liberar_acesso_publico.sql`.
4. Clique em **Run**.
5. O script concederá permissões de `SELECT`, `INSERT` e `UPDATE` para o papel público (`anon`) e atualizará as funções RPC `fn_criar_ordem_producao` e `fn_criar_pedido`.

## Instruções para um Novo Banco no Supabase

Para instalações do zero em um novo projeto Supabase:
1. Abra o **SQL Editor** no projeto novo.
2. Copie e execute todo o arquivo `schema.sql`.

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
