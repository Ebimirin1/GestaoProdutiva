# Controle de Produção — versão simples

Este pacote contém o planejamento e o banco de um aplicativo com três telas: **Planejamento, Produção e Expedição**. Tecnologias: **HTML + CSS + JavaScript + Supabase + GitHub Pages**.

## Comece aqui

| Arquivo | O que fazer com ele |
|---|---|
| `spec.md` | Requisitos do produto, tecnologias, três telas e regras |
| `AGENTS.md` | Instruções permanentes que o Jules deve seguir |
| `task.md` | Ordem de implementação e lista de aceite |
| `schema.sql` | Instalar uma vez no **novo projeto Supabase** |
| `README.md` | Este guia de instalação e publicação |

O nome reconhecido pelo Jules é **AGENTS.md**, em maiúsculas e no plural. Coloque os cinco arquivos na raiz do repositório. Não misture esta versão com as instruções antigas de quatro telas. O pacote não contém `index.html`: é a base para a implementação solicitada, e não um aplicativo já pronto.

## 1. Preparar o repositório

1. Baixe e extraia o ZIP deste pacote no computador.
2. Abra o repositório escolhido no GitHub. Pode usar um repositório novo para esta versão simples.
3. Na aba **Code**, clique em **Add file → Upload files**.
4. Arraste os **cinco arquivos descompactados** para a área de upload; não arraste a pasta externa nem o ZIP.
5. Clique em **Commit changes**. Como é a preparação inicial, pode salvar na branch `main` se ela for a branch escolhida.
6. Confira que os nomes `spec.md`, `AGENTS.md`, `task.md`, `schema.sql` e `README.md` aparecem juntos na lista principal.

Se o repositório já tiver `AGENTS.md`, esta versão é a substituição para o novo escopo simples; guarde a versão antiga no histórico do GitHub. O banco antigo não deve ser apagado.

## 2. Preparar o visual

Use `spec.md` e sua identidade visual no **Google Stitch**, caso queira gerar novamente o HTML/CSS. Peça exatamente três telas/abas, sem dashboard adicional. A tela Produção agrupa temperos, bateladas e embutimento.

Depois de baixar o código, extraia o ZIP. O arquivo de entrada deve se chamar `index.html` e ficar na raiz do repositório. Imagens/CSS/JS precisam acompanhar o HTML quando existirem. Não renomeie simplesmente um ZIP para HTML. O Jules pode fazer a organização T0 a partir do código do Stitch fornecido a ele.

## 3. Criar o novo banco Supabase

Você pode usar sua conta atual do Supabase e criar apenas **um novo projeto**. Não precisa abrir outra conta.

1. Crie o novo projeto e aguarde o banco ficar disponível.
2. Confirme no cabeçalho que está no **projeto novo**.
3. Abra **SQL Editor**, crie uma consulta vazia e cole todo o conteúdo de `schema.sql`.
4. Clique em **Run**. A execução instala sete tabelas, políticas de acesso e duas funções de criação atômica (além das funções auxiliares).
5. Se aparecer **Success. No rows returned**, a execução terminou. Consulte o **Table Editor** para ver as tabelas.
6. Não execute o schema novamente. Ele interrompe a instalação se já encontrar uma das tabelas do aplicativo. Isso evita confundir a instalação inicial com uma atualização do banco.

Não cole neste projeto o SQL SQLite ou as migrações antigas de 14 tabelas. O SQL deste pacote utiliza PostgreSQL nativo e não usa ENUMs.

## 4. Criar seu login e autorizar o acesso

1. No novo Supabase, acesse **Authentication → Users → Add user → Create user**.
2. Defina o e-mail e a senha do usuário do aplicativo. Confirme o e-mail pela opção disponível no painel ou pelo fluxo de confirmação.
3. Copie o **User UID** que o Supabase gerou.
4. Abra uma nova consulta no SQL Editor, cole o comando abaixo e substitua `COLE_O_UID_AQUI` pelo UUID copiado, mantendo as aspas:

```sql
INSERT INTO public.usuarios_permitidos (user_id)
VALUES ('COLE_O_UID_AQUI'::uuid)
ON CONFLICT (user_id) DO UPDATE SET ativo = true;
```

5. Execute. Somente usuários presentes nessa lista e com `ativo = true` têm acesso às tabelas operacionais. Para outro usuário, crie-o no Auth e repita a autorização com o UID dele. Os autorizados compartilham os dados da empresa.

O e-mail e a senha servem para a tela de login. Eles não vão em `config.js`, no GitHub nem nas mensagens ao Jules.

## 5. Configurar o frontend quando o Jules entregar a base

Obtenha no painel Supabase a **Project URL** e a **Publishable key** do novo projeto (opção Connect/Copy e configurações de API). Não use a secret key nem a `service_role`.

O arquivo `config.js` deve ter esta estrutura:

```js
window.APP_CONFIG = {
  supabaseUrl: 'https://SEU-PROJETO.supabase.co',
  supabasePublishableKey: 'SUA-CHAVE-PUBLISHABLE'
};
```

Substitua os dois valores e salve no repositório. Esses valores públicos são utilizados pelo navegador; as políticas do banco controlam quem pode ler/gravar. Não copiar a URL/chave do projeto antigo. A configuração editada apenas no seu computador só chegará ao site quando entrar no GitHub.

Para login por e-mail e senha, não é necessário criar um backend próprio. Caso seja acrescentada recuperação de senha por e-mail no futuro, configurar também URLs de redirecionamento no Supabase; isso está fora do MVP atual.

## 6. Ativar o GitHub Pages

Faça esta etapa **depois de `index.html` existir na raiz da branch `main`**, com os arquivos CSS/JS/config necessários.

1. Abra o repositório no GitHub e clique em **Settings**.
2. No menu lateral, clique em **Pages**.
3. Em **Build and deployment → Source**, escolha **Deploy from a branch**.
4. Em **Branch**, escolha **main** e a pasta **/(root)**.
5. Clique em **Save**.
6. Na aba **Actions**, confira a execução do Pages até concluir. Volte a **Settings → Pages** e abra o link exibido pelo GitHub.
7. Use esse endereço para testar. Não use o endereço `github.com/.../blob/.../index.html`, que mostra o código, nem uma cópia `file:///` local.

Em GitHub Free, Pages está disponível para repositórios públicos; repositórios privados dependem do plano. O HTML/JS publicado é acessível pelo navegador, mas os dados operacionais permanecem protegidos pelo login e RLS. Não versionar exportações de produção, senhas ou tokens.

O site abre no formato `https://SEU-USUARIO.github.io/SEU-REPOSITORIO/`. Copie o link mostrado em Pages para evitar erros no nome. Não é necessário instalar Python para usar o site.

## 7. Como pedir ao Jules para implementar

Selecione no Jules o repositório que recebeu estes arquivos e a branch `main`. Inicie com:

> Leia AGENTS.md, spec.md, task.md e schema.sql desta versão simples. Use HTML, CSS e JavaScript puro com Supabase e GitHub Pages. Comece pela tarefa T0 e preserve o código visual compatível que já existe. Implemente em incrementos, atualize task.md e abra uma PR para main em cada entrega coerente. Não acrescente módulos fora das três telas. Informe o link da PR ou a ação Publish PR que eu preciso executar. Não execute o SQL no meu banco remoto. Depois da base publicada, siga T1 até T5.

Forneça ao Jules o código visual já extraído, se ele não estiver no repositório. Se o trabalho antigo ainda estiver apenas em uma sessão Jules/ZIP, ele não está automaticamente disponível em `main`.

## 8. Como as alterações chegam ao site

1. O Jules altera os arquivos e prepara commits numa branch.
2. A entrega é publicada como **PR** para `main`. Se necessário, clique em **Publish PR** no Jules.
3. Abra a PR no GitHub, revise os arquivos e clique em **Merge pull request → Confirm merge** quando estiver pronta.
4. O Pages publica a nova versão de `main`. Aguarde a execução em **Actions** terminar e abra o link do site; use Ctrl+F5 se estiver vendo uma versão em cache.

**Uma PR aberta não altera o site que publica `main`.** Escrever “criar PR” em `AGENTS.md` orienta o agente, mas não ativa uma automação no serviço. A API do Jules oferece `automationMode: AUTO_CREATE_PR` para quem já usa integração por API; não é preciso construir essa integração para este projeto. Auto-merge é outra configuração do GitHub e não está habilitado por estes arquivos.

## 9. O que foi validado nesta entrega

O `schema.sql` foi executado em PostgreSQL 18.3 local via PGlite, com `auth.users`, `auth.uid()` e papéis de acesso simulados para reproduzir os controles relevantes. Passou em 21 verificações: instalação/RLS, OP com quatro sabores, rollback, duplicidade de sabores, entradas inválidas, limites de batelada, recebimento, atualização, pedido com duas conservações, vínculo correto com OP, permissões de leitura/escrita, impedimento de autoautorização e reexecução sem perda de dados.

Isso valida o SQL nesse ambiente. Não foi executado no seu Supabase, não implementa/testa a interface e não publica nada no GitHub. Após a implementação, ainda é necessário testar o fluxo real no novo projeto e no Pages.

## Referências oficiais

- [Publicação do GitHub Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site)
- [Sobre o GitHub Pages e disponibilidade por plano](https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages)
- [AGENTS.md no Jules](https://jules.google/docs/)
- [Publicar mudanças do Jules](https://jules.google/docs/code/)
- [Jules API: criação automática de PR](https://jules.google/docs/api/reference/)
- [Supabase: RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase: chaves de API](https://supabase.com/docs/guides/api/api-keys)
