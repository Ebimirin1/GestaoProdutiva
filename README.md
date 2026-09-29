# Controle de Produção — Versão Simples (Supabase Auth)

Este projeto é um aplicativo web para controle de produção artesanal com três telas: **Planejamento, Produção e Expedição**. Tecnologias: **HTML + CSS + JavaScript + Supabase + GitHub Pages**.

## Requisito de Acesso

O acesso ao aplicativo exige autenticação por **e-mail e senha** via Supabase Auth e autorização pela tabela `usuarios_permitidos`.

## Instruções para o Banco Existente no Supabase

Para autorizar o usuário administrador (`UID: fc952189-34d3-4963-b6c6-f408a249a47b`) e restaurar as políticas de segurança RLS no banco existente:

1. Abra o painel do seu projeto no Supabase (`https://supabase.com`).
2. Acesse **SQL Editor** → **New query**.
3. Copie todo o conteúdo do arquivo `restaurar_acesso_admin.sql`.
4. Clique em **Run**.
5. O script inserirá o UID do administrador em `usuarios_permitidos` com `ativo = true` e restaurará as políticas RLS.

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
