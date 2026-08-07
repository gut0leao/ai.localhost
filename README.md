# localhost.ai

> ## Projeto interrompido
>
> O desenvolvimento do `localhost.ai` foi interrompido por falta de viabilidade prática para o hardware disponível.
>
> Após testes reais, o ambiente demonstrou exigir, no mínimo, **48 GB de RAM física** e **16 GB de VRAM** para oferecer uma experiência local minimamente estável e útil — especialmente em fluxos de agentes, análise de repositórios e uso de modelos voltados a programação.
>
> Como esses requisitos estão fora da capacidade de hardware atualmente disponível e não há previsão de atualização, o projeto não receberá novas funcionalidades ou suporte ativo.
>
> O repositório permanece público como registro do trabalho e pode ser útil como referência, mas deve ser considerado **arquivado / sem manutenção**.

**Distribuição leve para criar uma estação de trabalho de IA local, com configuração reproduzível, opinativa e orientada à privacidade.**

O **localhost.ai** integra execução de modelos, chat, RAG e desenvolvimento assistido por IA em Linux ou Windows com WSL2. Seu propósito não é ensinar a instalar produtos isolados: é reduzir as decisões, os riscos de configuração e o trabalho necessário para obter um ambiente coerente e compreensível.

O projeto está em evolução. A instalação atual já conecta os componentes descritos abaixo, mas ainda não oferece isolamento de rede, auditoria completa, backup integrado nem versionamento imutável de todas as dependências.

Leia a [visão e os princípios arquiteturais](docs/VISION.md) e o [roadmap](docs/ROADMAP.md).

> O projeto, o repositório e o comando usam o nome `localhost.ai`. A interface continua em `https://ai.localhost`: esse hostname é reservado para loopback e não depende de DNS externo. Instalações anteriores com os nomes `ai.localhost` e `local-coding-ai` permanecem compatíveis.

## O problema que resolve

Montar uma estação de IA local exige escolher modelos e ferramentas, conectar serviços, configurar GPU, portas, certificados, persistência e permissões, além de diagnosticar diferenças entre Windows, WSL2 e Docker. Em redes corporativas, proxies TLS e CAs internas acrescentam outra camada de falhas possíveis.

O **localhost.ai** fornece convenções e uma integração testável para que o usuário não precise compreender todo esse ecossistema antes de começar. O valor está na coerência do conjunto: procedimento de instalação repetível, configurações compatíveis, defaults conservadores, persistência conhecida e operação documentada.

## Para quem é útil

- pessoas que desejam experimentar modelos locais sem montar cada integração manualmente;
- desenvolvedores que trabalham com código que não deve ser enviado diretamente a serviços externos;
- profissionais que analisam documentos e usam chat/RAG individualmente;
- estações Windows + WSL2, inclusive sob VPN, proxy ou CA corporativa;
- organizações que desejam aproveitar GPUs já disponíveis e frequentemente subutilizadas nas estações de trabalho.

O projeto atua na camada individual da estação. Não substitui plataformas corporativas de IA, seus controles de acesso, governança centralizada, integrações institucionais ou capacidade compartilhada.

## O que a distribuição configura hoje

| Função | Implementação atual | Papel arquitetural |
|---|---|---|
| Runtime local de modelos | Ollama | Componente essencial atual; deve poder ser substituído futuramente por outro runtime compatível. |
| Chat e RAG | Open WebUI | Componente essencial atual para interface, conversas, uploads e indexação. |
| Desenvolvimento assistido | OpenCode | Experiência de agente mais abrangente e principal candidato para esse papel. |
| Desenvolvimento complementar | Aider | Alternativa mais direta de terminal; sobrepõe parte do OpenCode e é instalado hoje por compatibilidade e escolha do usuário. |
| HTTPS local | Caddy + mkcert | Publicação local da interface com certificado confiável no host. |
| Busca web | SearXNG | Componente opcional, ativado por perfil do Compose. |
| Integração e operação | Compose, `.env`, scripts e manifesto | Convenções, seleção de modelos, diagnóstico inicial, persistência e reversão cuidadosa das alterações do instalador. |

O instalador atual ainda instala **OpenCode e Aider**. Isso descreve o comportamento desta versão, não uma dependência conceitual dos dois. Tornar a ferramenta de desenvolvimento selecionável por perfil, mantendo Aider como opção, está no roadmap; nenhuma ferramenta foi removida nesta revisão.

## Diferencial em relação à instalação manual

- seleciona modelos compatíveis com os recursos detectados;
- conecta runtime, interface web e ferramentas de desenvolvimento;
- mantém portas publicadas em `127.0.0.1` por padrão;
- configura HTTPS local e confiança do certificado em Linux/WSL e, quando possível, no Windows;
- trata CA corporativa compartilhada com os containers;
- registra em manifesto as alterações feitas pelo instalador para permitir restauração cuidadosa;
- padroniza diretórios, volumes, variáveis e comandos de operação;
- valida GPU, serviços e conectividade antes e depois da instalação.

Atalhos que apenas economizam digitação existem por conveniência e compatibilidade, mas não são o núcleo estratégico do projeto. O critério para novas funcionalidades é reduzir complexidade, risco ou decisões — não apenas reduzir o número de comandos.

## Processamento local, Internet e limites

| Situação | Comportamento atual |
|---|---|
| Inferência padrão | Prompts são enviados ao Ollama local; não é necessária uma API comercial de modelos. |
| Instalação e atualização | Acessam GitHub, registros de containers, repositórios de pacotes e catálogos de modelos. |
| Busca web opcional | SearXNG e Open WebUI acessam fontes externas quando o perfil de busca é habilitado. |
| OpenCode | A configuração gerada usa o Ollama local e começa com ferramentas web negadas; uma configuração preexistente é preservada e pode usar outros provedores. O processo continua tecnicamente capaz de rede conforme configuração e plugins. |
| Aider | O launcher desativa a verificação de atualização e aponta para o Ollama local; outras formas de execução podem ter comportamento diferente. |
| Containers | Não há política de bloqueio de egress: serviços na rede Docker podem tecnicamente alcançar a Internet. |

`localhost`, HTTPS e execução local reduzem exposição, mas não equivalem a isolamento ou auditoria de segurança. As imagens usam tags móveis (`latest` e `main`), não há SBOM/verificação de assinatura, backup automatizado ou comando de auditoria. Consulte [Privacidade e Segurança](#privacidade-e-segurança) e o [roadmap](docs/ROADMAP.md).

## Arquitetura atual

```text
Windows + WSL2 / Linux
├── navegador → Caddy → Open WebUI ─┐
├── OpenCode / Aider ───────────────┼→ Ollama → modelos em volume local
└── SearXNG opcional → Internet ────┘

Docker Compose: Ollama, Open WebUI, Caddy e SearXNG opcional
Host/WSL: ferramentas de desenvolvimento, configuração e comandos de integração
```

## Comece Aqui

Se você não costuma instalar ferramentas de desenvolvimento, siga esta ordem. O instalador do **localhost.ai** prepara a stack local de IA, mas ele pressupõe que WSL/Linux e Docker já estejam funcionando.

### 1. Prepare o sistema operacional

No Windows, use WSL2 com uma distribuição Linux, preferencialmente Ubuntu. Siga a documentação oficial da Microsoft:

- [Instalar o WSL](https://learn.microsoft.com/windows/wsl/install)
- [Comandos básicos do WSL](https://learn.microsoft.com/windows/wsl/basic-commands)
- [Boas práticas para desenvolvimento com WSL](https://learn.microsoft.com/windows/wsl/setup/environment)

Depois de instalar, abra o terminal da distribuição Linux, não o PowerShell, para executar os comandos deste projeto.

Verifique se você está no Linux/WSL:

```bash
uname -a
```

No WSL2, mantenha seus projetos dentro do filesystem Linux, por exemplo `~/workspace/projeto`, em vez de `/mnt/c/...`. Isso melhora desempenho e evita problemas de permissão.

### 2. Instale o Docker

Você pode usar uma das opções abaixo:

- **Docker Desktop com integração WSL2**, recomendado para quem está no Windows e quer a configuração mais simples: [Docker Desktop WSL 2 backend](https://docs.docker.com/desktop/features/wsl/).
- **Docker Engine instalado diretamente no Ubuntu/WSL**, recomendado para quem prefere operar tudo dentro do Linux: [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

Não misture as duas abordagens na mesma distribuição sem entender as consequências. Escolha uma, finalize a instalação e valide antes de continuar.

Verifique no terminal Linux/WSL:

```bash
docker --version
docker compose version
docker info
```

Se `docker info` falhar por permissão, conclua a configuração pós-instalação indicada pela documentação oficial do Docker antes de executar o instalador do projeto.

Referência: [Post-installation steps for Docker Engine](https://docs.docker.com/engine/install/linux-postinstall/).

### 3. Confira recursos mínimos

Recomendado para começar:

- 16 GB de RAM disponível para o WSL/Linux.
- Cerca de 12 GB livres para imagens Docker e modelos pequenos.
- Acesso à internet para baixar imagens, dependências e modelos.
- GPU NVIDIA é opcional; CPU funciona, mas será mais lenta.

Confira memória e disco:

```bash
free -h
df -h .
```

Em notebooks com 32 GB de RAM física, um limite de 16 GB para o WSL costuma ser um bom ponto de partida. Veja também a seção [Recomendações para WSL2](#recomendações-para-wsl2).

Se você pretende usar GPU NVIDIA no Windows/WSL2, confirme primeiro que o driver e a integração com WSL estão corretos. Use a documentação oficial como referência:

- [NVIDIA CUDA on WSL User Guide](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)
- [Docker Desktop GPU support](https://docs.docker.com/desktop/features/gpu/)

### 4. Valide os requisitos básicos

Execute:

```bash
command -v curl git make python3
docker compose version
```

O instalador tenta instalar automaticamente dependências comuns como `curl`, Git, `make`, Python, `pipx`, `mkcert`, OpenSSL e ferramentas NSS em distribuições com `apt`. Docker e Compose devem estar prontos antes.

### 5. Rode apenas o diagnóstico

Antes de instalar de fato, execute o diagnóstico. Ele não baixa modelos nem altera a stack:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh \
  | bash -s -- --check-only
```

Se o diagnóstico passar, siga para a instalação automatizada.

## Instalação Automatizada

Com os pré-requisitos prontos, execute o instalador diretamente do GitHub. Por compatibilidade, a versão atual instala os dois assistentes de desenvolvimento e não abre nenhum deles ao final:

```bash
cd ~
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh \
  | bash -s -- --no-launch
```

Esse comando remoto é necessário apenas uma vez para preparar a máquina. Ao final, a interface web deve ficar disponível em:

```text
https://ai.localhost
```

Se você é desenvolvedor, escolha o assistente ao entrar em um repositório Git:

```bash
cd ~/workspace/meu-projeto
aider
opencode
```

Também é possível iniciar a instalação já dentro de um repositório Git e escolher qual assistente será oferecido ao final:

```bash
cd ~/workspace/meu-projeto
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh \
  | bash -s -- --launch-aider

curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh \
  | bash -s -- --launch-opencode
```

Antes de baixar imagens ou modelos, o instalador verifica Linux/WSL2, RAM, VRAM, GPU NVIDIA, espaço em disco, Docker, Compose e dependências do host. Em seguida, ele:

- instala dependências básicas ausentes em sistemas com `apt` após confirmação;
- clona ou atualiza a stack em `~/.local/share/localhost-ai`;
- valida ou configura o NVIDIA Container Toolkit quando há uma GPU compatível;
- instala o Aider com `pipx` e o OpenCode no diretório do usuário;
- gera e instala o certificado local de `https://ai.localhost` com `mkcert`;
- sobe a stack em CPU ou GPU;
- escolhe e baixa um modelo Qwen geral e outro voltado a código;
- instala e valida os comandos OpenCode e Aider, preservando as duas experiências disponíveis nesta versão;
- instala o comando global `localhost.ai`, que elimina a necessidade de exportar `OLLAMA_API_BASE` ou repetir o nome do modelo.

Durante a execução, o instalador mantém um manifesto em `~/.local/state/localhost-ai`. Ele registra o que já existia e o que foi adicionado pelo projeto para permitir uma desinstalação completa sem remover ferramentas compartilhadas que já estavam na máquina.

A seleção automática prioriza a geração Qwen mais recente que caiba de maneira razoável na RAM/VRAM detectada. Atualmente, ela usa Qwen 3.6 em máquinas grandes, Qwen 3.5 nos demais perfis e Qwen3-Coder ou Qwen2.5-Coder para programação. As famílias e tamanhos podem ser conferidos no catálogo oficial do [Qwen 3.6](https://ollama.com/library/qwen3.6), [Qwen 3.5](https://ollama.com/library/qwen3.5) e [Qwen3-Coder](https://ollama.com/library/qwen3-coder).

Opções úteis:

```bash
# Diagnóstico sem alterações ou downloads.
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh \
  | bash -s -- --check-only

# Instalação sem abrir um assistente ao final (também é o padrão).
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh \
  | bash -s -- --no-launch
```

É possível substituir a seleção automática:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh \
  | bash -s -- \
      --general-model qwen3.5:9b \
      --code-model qwen2.5-coder:7b \
      --aider-model qwen2.5-coder:7b \
      --opencode-model qwen2.5-coder:7b
```

Para revisar o instalador antes de executá-lo:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/install.sh -o /tmp/localhost-ai-install.sh
less /tmp/localhost-ai-install.sh
bash /tmp/localhost-ai-install.sh
```

## Desinstalação Completa

> **Atenção:** a desinstalação apaga definitivamente os modelos baixados, as conversas do Open WebUI e os demais dados armazenados nos volumes Docker. O repositório ainda não possui backup/restore integrado; faça uma exportação adequada antes de remover uma instalação que contenha dados importantes.

Confira primeiro o que seria removido, sem alterar a máquina:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/uninstall.sh \
  | bash -s -- --dry-run
```

Em um checkout local, os comandos equivalentes são:

```bash
./uninstall.sh --dry-run
./uninstall.sh
```

Execute a desinstalação completa:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/uninstall.sh | bash
```

Para uso não interativo:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/localhost.ai/main/uninstall.sh \
  | bash -s -- --yes
```

O desinstalador usa o manifesto para:

- remover containers, rede, volumes, modelos, conversas e imagens baixadas pelo instalador;
- remover o certificado de `ai.localhost` e desfazer a confiança da CA do `mkcert` quando ela foi criada pelo projeto, inclusive no armazenamento do usuário Windows quando configurado pelo WSL;
- desinstalar o Aider e o OpenCode somente se foram instalados pelo projeto;
- remover `localhost.ai` e restaurar qualquer launcher ou configuração anterior;
- remover somente os pacotes APT que não estavam instalados antes;
- restaurar `/etc/docker/daemon.json` e os arquivos do repositório NVIDIA quando o instalador os alterou;
- restaurar o `.env`, certificados e revisão Git anteriores quando a stack já existia;
- apagar o checkout em `~/.local/share/localhost-ai` somente quando ele foi clonado pelo instalador.

O Docker, o Docker Compose, o driver NVIDIA e o próprio WSL não são removidos, pois são pré-requisitos e não são instalados pelo projeto. Em instalações antigas que não possuem manifesto, o script remove os recursos próprios da stack, mas preserva Aider, OpenCode, CA, pacotes APT e configuração NVIDIA por não conseguir determinar com segurança sua origem.

Depois da desinstalação, abra um novo terminal antes de testar novamente o instalador.

## Instalação Manual

Clone o repositório e entre na pasta:

```bash
git clone https://github.com/gut0leao/localhost.ai.git
cd localhost.ai
```

Crie o arquivo de configuração local:

```bash
cp .env.example .env
```

Revise as variáveis, especialmente portas e modelo padrão:

```bash
sed -n '1,120p' .env
```

## Primeiro Uso após Instalação Manual

Esta seção se aplica somente a quem clonou e configurou o projeto manualmente. Se você utilizou o instalador automatizado, o HTTPS, a stack e os modelos já foram preparados; `localhost.ai --help` mostra as opções de integração, enquanto `aider` e `opencode` abrem os assistentes dentro de um repositório Git.

Configure o certificado HTTPS local:

```bash
sudo apt-get update
sudo apt-get install -y mkcert libnss3-tools
make setup-https
```

Suba os serviços em CPU:

```bash
make up
```

Ou, após configurar o runtime NVIDIA conforme a seção de GPU, suba-os com aceleração:

```bash
make up-gpu
```

Baixe o modelo inicial:

```bash
make pull-model
```

Teste o Ollama:

```bash
make test-ollama
```

Acesse o Open WebUI:

```text
https://ai.localhost
```

## Como Subir o Ambiente

```bash
make up
```

Verifique os containers:

```bash
make ps
```

Acompanhe logs:

```bash
make logs
```

## Como Parar o Ambiente

```bash
make down
```

Esse comando remove os containers da stack, mas preserva os volumes nomeados com modelos e dados do Open WebUI.

## Como Atualizar Imagens

```bash
make update-images
make up       # CPU
make up-gpu   # GPU NVIDIA
```

Execute apenas um dos dois comandos de inicialização, conforme o modo desejado.

Se quiser revisar as mudanças das imagens, consulte a documentação oficial dos projetos antes de atualizar ambientes importantes.

As imagens atuais usam tags móveis. Portanto, esse procedimento pode incorporar mudanças upstream sem que o conteúdo do repositório tenha mudado e ainda não oferece rollback automatizado. Preserve dados importantes antes de atualizar.

## Como Baixar Modelos

Os modelos padrão do ambiente e dos dois assistentes ficam em `.env`:

```env
OLLAMA_MODEL_DEFAULT=qwen3.5:4b
OLLAMA_AIDER_MODEL_DEFAULT=qwen2.5-coder:3b
OLLAMA_OPENCODE_MODEL_DEFAULT=qwen2.5-coder:3b
```

Baixe o modelo padrão:

```bash
make pull-model
```

Baixe outro modelo sem editar `.env`:

```bash
make pull-model MODEL=deepseek-coder-v2:16b
```

Liste modelos instalados:

```bash
make models
```

Abra uma sessão interativa:

```bash
make run-model
```

Ou com outro modelo:

```bash
make run-model MODEL=qwen3.5:9b
```

## Como Testar o Ollama

```bash
make test-ollama
```

Teste manual:

```bash
curl http://localhost:11434/api/tags
```

A resposta esperada é um JSON com os modelos disponíveis.

## Como Acessar Open WebUI

Abra no navegador:

```text
https://ai.localhost
```

O Caddy recebe a requisição HTTPS na porta `443` e a encaminha ao Open WebUI pela rede interna do Compose. Requisições para `http://ai.localhost` na porta `80` são redirecionadas para HTTPS; a interface não é servida por HTTP. A porta `3000` não é publicada no host.

O Open WebUI usa `OLLAMA_BASE_URL=http://ollama:11434` dentro da rede do Docker Compose. Para acessar diretamente a API do Ollama no host, use `http://localhost:11434`.

### HTTPS local com mkcert

O HTTPS é obrigatório para acessar a interface. Instale o [mkcert](https://github.com/FiloSottile/mkcert) e as ferramentas NSS no Ubuntu/WSL:

```bash
sudo apt-get update
sudo apt-get install -y mkcert libnss3-tools
```

Depois gere o certificado e inicie ou recrie o proxy:

```bash
make setup-https
```

Esse comando:

- instala a CA local do `mkcert` no armazenamento de confiança do Linux/WSL;
- gera um certificado para `ai.localhost`, `localhost`, `127.0.0.1` e `::1`;
- no WSL, tenta instalar a CA no armazenamento do usuário Windows para que o navegador do host confie nela;
- recria somente o container do proxy com HTTPS habilitado.

Os certificados ficam em `certs/`, são ignorados pelo Git e devem ser gerados separadamente em cada notebook. A chave privada da CA do `mkcert` não é copiada para este projeto. Não compartilhe essa chave: quem a possui pode emitir certificados confiáveis pela máquina.

Após a configuração, use:

```text
https://ai.localhost
```

Abrir `http://ai.localhost` apenas redireciona o navegador para esse endereço HTTPS. O proxy não inicia sem os certificados locais.

O comando `make test-open-webui` valida tanto o redirecionamento quanto o endpoint HTTPS confiável.

Se o navegador ainda exibir um alerta no WSL, reinicie-o para que recarregue o armazenamento de certificados do Windows.


## Busca Web Opcional com SearXNG

Por padrão, o modelo local não acessa a internet. Para adicionar busca web ao Open WebUI, este projeto inclui um serviço opcional `searxng` via Docker Compose profile.

Suba a stack com busca web habilitada:

```bash
make up-web-search
```

Teste o SearXNG:

```bash
make test-searxng
```

Acesse o SearXNG diretamente, se quiser validar no navegador:

```text
http://127.0.0.1:8080
```

No Open WebUI, confirme a configuração em:

```text
Admin Panel > Settings > Web Search
```

Valores esperados:

```text
Enable Web Search: enabled
Web Search Engine: searxng
Searxng Query URL: http://searxng:8080/search?q=<query>
```

No modo `make up-web-search`, o projeto também define `DEFAULT_MODEL_METADATA` para marcar `web_search` como recurso padrão dos modelos no Open WebUI. Esse modo desativa `ENABLE_SEARCH_QUERY_GENERATION` para evitar que modelos locais recusem a etapa de gerar consultas de busca. Ainda assim, se a interface mostrar o botão de ferramentas/mais opções, confirme que `Web Search` está ativo no chat antes de enviar a pergunta.

Para voltar ao modo sem SearXNG, pare e suba a stack padrão:

```bash
make down
make up
```

Observação: usar SearXNG permite buscar na web sem API paga, mas ainda há tráfego de rede para motores/fontes externos consultados pelo metabuscador.

## Assistentes de Programação no Host/WSL

OpenCode e Aider não rodam em containers neste projeto. O instalador atual instala e valida ambos no host/WSL: OpenCode oferece a experiência de agente mais abrangente e é o principal candidato para o papel de ferramenta de desenvolvimento; Aider permanece uma alternativa direta e útil. Há sobreposição entre eles, e a escolha continua explícita. Perfis que instalem apenas a opção desejada são uma evolução planejada, não um comportamento existente.

Para uma instalação manual do Aider no Ubuntu executado pelo WSL:

```bash
sudo apt-get update
sudo apt-get install -y pipx
pipx ensurepath
exec zsh -l
pipx install aider-chat
```

O comando `exec zsh -l` recarrega o shell para que o diretório de binários do `pipx` entre no `PATH`. Se você usar outro shell, feche e abra um novo terminal WSL antes de executar `aider --version`.

## Como Usar Aider e OpenCode com Ollama Local

O instalador integra os comandos `aider` e `opencode` ao shell interativo. Dentro de qualquer repositório Git, eles iniciam a stack se necessário, definem a conexão com o Ollama local e abrem o assistente com o modelo selecionado para a máquina:

```bash
cd ~/workspace/meu-projeto
aider
opencode
```

Para escolher manualmente qualquer modelo já baixado ou encaminhar outras opções ao assistente escolhido:

```bash
aider --model ollama_chat/qwen3.5:9b
opencode --model ollama/qwen2.5-coder:7b
aider --message "explique a arquitetura deste projeto"
```

As integrações são funções de shell instaladas no arquivo de inicialização do Bash ou Zsh atual. Elas preservam `aider --help`, `aider --version`, `opencode --help` e `opencode --version` como comandos nativos. A configuração da stack fica em `~/.config/localhost-ai/stack-dir`, enquanto os modelos escolhidos ficam no `.env` da instalação. Para ignorar a integração, use `command aider` ou `command opencode`; as opções recebidas pelos comandos diretos são encaminhadas às ferramentas.

Ao iniciar, o comando sempre mostra um resumo curto com a URL da interface web, projeto e modelo ativos e os comandos para usar o modelo de código, baixar ou selecionar outro modelo e abrir outro projeto. A ajuda completa permanece disponível em `localhost.ai --help`.

Se a instalação foi feita manualmente, ainda é possível usar o Aider sem o comando auxiliar:

```bash
export OLLAMA_API_BASE=http://localhost:11434
aider --model ollama_chat/qwen3.5:9b
```

Dentro do Aider, peça mudanças pequenas e revise o diff antes de commitar.

Depois de abrir um novo terminal, os comandos diretos funcionam de forma integrada dentro de qualquer repositório Git:

```bash
aider
opencode
```

A configuração gerada para o OpenCode fica em `~/.config/opencode/opencode.json`. Ela conecta a API local `http://127.0.0.1:11434`, oferece os modelos Qwen usados pelo instalador e pede confirmação antes de editar arquivos, executar comandos, chamar subagentes ou acessar skills. Leitura de arquivos `.env` é bloqueada; busca e coleta web também começam bloqueadas. Se já existir uma configuração do OpenCode, o instalador a preserva e não a substitui; nesse caso, confirme manualmente o provedor e as permissões, pois os defaults locais do projeto não são aplicados.

Os modelos continuam pertencendo ao Ollama: nenhum dos dois assistentes mantém uma cópia, nem faz download paralelo. Após a instalação, as configurações usam os dois modelos escolhidos para a máquina:

| Ferramenta | Modo | Modelo |
| --- | --- | --- |
| Aider | `code` e editor do modo `architect` | `OLLAMA_AIDER_MODEL_DEFAULT` e `OLLAMA_CODE_MODEL_DEFAULT` (programação) |
| Aider | conversa, análise e sumarização | `OLLAMA_MODEL_DEFAULT` (geral), disponível como alias `local-chat` |
| OpenCode | `Build` | `OLLAMA_OPENCODE_MODEL_DEFAULT` (programação) |
| OpenCode | `Plan` | `OLLAMA_MODEL_DEFAULT` (geral, sem edição nem comandos) |

No Aider, `code` é o modo inicial; use `/ask` para conversar sem editar e `/architect` para o fluxo arquiteto/editor. Os aliases `/model local-chat` e `/model local-code` deixam os dois modelos disponíveis durante a sessão. No OpenCode, `Build` é o agente inicial e `Plan` usa o modelo geral; alterne entre eles com `Tab`. O comando direto `opencode` usa essa configuração global; ele não relê o `.env` automaticamente.

Para selecionar outro modelo local no OpenCode, use o seletor `/models` ou informe o identificador do Ollama:

```bash
opencode --model ollama/qwen2.5-coder:7b
```

Para atualizar o OpenCode no futuro, execute o instalador oficial dentro do WSL. Ele não requer `sudo`:

```bash
curl -fsSL https://opencode.ai/install | bash
```

## Dados, RAG e Persistência

O ambiente separa dados persistentes dos containers descartáveis. Os nomes físicos dos volumes recebem um prefixo do projeto Compose, mas os papéis são estes:

| Dado | Local atual | Observação |
| --- | --- | --- |
| Modelos Ollama | volume Docker `ollama-models` | Podem ser grandes e, em geral, podem ser baixados novamente. |
| Conversas, usuários, uploads e índices do Open WebUI | volume Docker `open-webui-data` | Contém dados únicos; remover o volume causa perda. |
| Configuração principal da stack | `.env` no diretório de instalação | Pode conter decisões locais e não deve ser versionada. |
| Configuração gerada do OpenCode | `~/.config/opencode/opencode.json` | Uma configuração preexistente é preservada pelo instalador. |
| Histórico local do Aider | arquivos `.aider*` no repositório em uso | Pode conter prompts e respostas; defina a política de versionamento do projeto de destino. |
| Referência à instalação usada pelos launchers | `~/.config/localhost-ai/stack-dir` | Permite que os comandos encontrem a stack. |
| Manifesto e cópias de segurança operacionais do instalador | `~/.local/state/localhost-ai` | Serve à reversão da instalação; não é backup dos chats ou modelos. |
| Certificado de `ai.localhost` | `certs/` no diretório de instalação | A CA e sua chave são administradas separadamente pelo `mkcert`. |

O Compose não monta automaticamente uma coleção de documentos pessoais no Open WebUI. Arquivos enviados pela interface passam a ser gerenciados nos dados persistentes do próprio Open WebUI e podem gerar índices de RAG no mesmo volume; detalhes internos podem variar entre versões upstream.

Para preservar a fonte primária de documentos, mantenha três áreas conceitualmente separadas:

1. **originais:** diretório sob controle do usuário, fora da área de trabalho das ferramentas e preferencialmente somente leitura para o fluxo de IA;
2. **ingestão:** cópias selecionadas e descartáveis, preparadas para upload ou indexação;
3. **dados gerados:** embeddings, índices, metadados e conversas mantidos no volume do Open WebUI.

Essa separação é uma recomendação operacional; o projeto ainda não a aplica por permissões nem oferece backup/restore integrado. Antes de atualizar de forma relevante, migrar ou desinstalar, exporte os dados importantes pelo mecanismo suportado pelo componente ou faça uma cópia consistente dos volumes. Um artefato transportável de backup e restauração testada está no [roadmap](docs/ROADMAP.md).

## Privacidade e Segurança

### Controles implementados

- As portas são vinculadas a `127.0.0.1`.
- O Open WebUI não publica sua porta interna diretamente; o acesso passa pelo proxy reverso local.
- Nenhum serviço usa `network_mode: host`.
- Nenhum container usa `privileged: true`.
- Não há montagem de `/home`, `~/.ssh`, `/var/run/docker.sock` ou repositórios pessoais.
- Modelos e dados ficam em volumes nomeados do Docker.
- O Aider roda no host/WSL e conversa com o Ollama local.
- A configuração gerada pelo projeto para o OpenCode usa o Ollama local, não habilita provedores externos e restringe ferramentas sensíveis.
- Os scripts auxiliares leem `.env` como arquivo de configuração e ignoram linhas inválidas, sem executar comandos definidos nele.

O serviço `ollama` usa o usuário padrão da imagem oficial. Isso é aceito aqui porque não há montagem de diretórios sensíveis, as portas ficam em localhost e o container não é privilegiado.

### Limitações e conectividade externa

Esses controles reduzem exposição acidental, mas não formam uma barreira de isolamento. Containers e processos no host continuam tecnicamente capazes de acessar a Internet; downloads de imagens, modelos, pacotes e atualizações dependem dessa conectividade. O SearXNG consulta fontes externas quando ativado, e plugins, ferramentas ou configurações adicionados pelo usuário podem mudar o comportamento de rede dos assistentes.

O projeto ainda não aplica política de egress, não inventaria toda telemetria upstream, não verifica assinaturas/SBOM e não fornece auditoria automatizada. O usuário continua responsável pelas políticas da organização, classificação dos dados, atualizações do host e avaliação dos componentes utilizados. Controles adicionais estão descritos como direção futura no [roadmap](docs/ROADMAP.md), não como garantias atuais.

Se houver problema de permissão em volumes, investigue o dono e o modo do volume antes de aplicar correções. Não use `chmod 777`.

## Recomendações de Performance

- Comece com modelos 7B em CPU.
- Feche aplicações pesadas antes de usar modelos maiores.
- Prefira quantizações menores quando a RAM for limitada.
- Mantenha projetos no filesystem Linux do WSL2.
- Use modelos maiores apenas se houver RAM suficiente.

Referência prática:

| Tamanho | RAM sugerida |
|---|---:|
| 7B | 8 a 12 GB |
| 14B | 16 a 24 GB |
| 32B | 32 GB ou mais |

## Recomendações para WSL2

- Use Docker Desktop com integração WSL2 ou Docker Engine instalado diretamente no WSL.
- Guarde repositórios em `~/workspace`, não em `/mnt/c`.
- Ajuste memória, CPU, swap e rede do WSL2 em `%UserProfile%\.wslconfig` quando for usar modelos locais por longos períodos.
- Reinicie o WSL após mudanças de configuração. Em PowerShell:

```powershell
wsl --shutdown
```

O arquivo `.wslconfig` fica no perfil do usuário Windows, por exemplo `C:\Users\seu-usuario\.wslconfig`, e vale para todas as distribuições WSL2. Um perfil conservador para esta stack é:

```ini
[wsl2]
# Em hosts com 32GB fisicos, 16GB e um bom ponto de partida.
# Use 20GB a 24GB apenas se for rodar modelos maiores e o Windows tiver folga.
memory=16GB

# Normalmente use de metade ate todos os processadores logicos.
# Em notebooks, limitar CPUs pode reduzir aquecimento e manter o host responsivo.
processors=8

# Swap ajuda quando o modelo estoura a RAM, mas fica bem mais lento.
# Use 4GB a 8GB para modelos pequenos/medios; aumente apenas se necessario.
swap=8GB

# Mantem servicos publicados pelo WSL acessiveis no Windows via localhost.
localhostForwarding=true

# Melhor compatibilidade de DNS/firewall em WSL recente, especialmente com VPN.
dnsTunneling=true
firewall=true

# Encerra a VM apos 60 segundos sem distribuicoes ativas.
vmIdleTimeout=60000
```

Em Windows 11 22H2 ou superior, redes corporativas, VPNs e proxies TLS como Zscaler costumam funcionar melhor com rede espelhada e proxy herdado do Windows:

```ini
[wsl2]
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
localhostForwarding=true

[experimental]
# Libera cache do WSL de volta ao Windows. Use gradual para evitar liberacoes bruscas.
autoMemoryReclaim=gradual
# Ajuda em alguns resolvedores corporativos quando dnsTunneling esta ativo.
bestEffortDnsParsing=true
```

Evite copiar opções sem necessidade. `nestedVirtualization=true` só é útil se você pretende rodar outra camada de virtualização dentro do WSL; para Docker, Ollama e Aider ela normalmente não muda nada. `swapFile` só precisa ser definido quando você quer mover o VHD de swap para outro disco.

Para aplicar e conferir:

```powershell
wsl --shutdown
wsl --status
```

Dentro do WSL:

```bash
free -h
nproc
```

Referência oficial: [configurações avançadas do WSL](https://learn.microsoft.com/windows/wsl/wsl-config) e [rede no WSL](https://learn.microsoft.com/windows/wsl/networking).

## Troubleshooting

### Open WebUI não conecta no Ollama

Verifique containers:

```bash
make ps
```

Confira logs:

```bash
make logs
```

Confirme que `OLLAMA_BASE_URL` está como `http://ollama:11434` no Compose.

### O comando `localhost.ai` não é encontrado

Confirme que `~/.local/bin` está no `PATH` e recarregue o shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
exec "$SHELL" -l
```

Se o arquivo ainda não existir, execute novamente o instalador. Em um checkout local atualizado:

```bash
./install.sh --no-launch
```

### A interface em `ai.localhost` não abre

Teste o proxy e consulte seus logs:

```bash
make test-open-webui
make logs-proxy
```

Confira também se as portas locais `80` ou `443` já estão sendo usadas por outro serviço:

```bash
ss -ltnp | grep -E ':(80|443) '
```

Se o HTTPS falhar, execute novamente `make setup-https` e reinicie o navegador. O endereço HTTP não é um fallback sem TLS: ele depende do mesmo proxy e apenas redireciona para HTTPS.

### Ollama não responde no host

```bash
make test-ollama
docker compose logs ollama
```

Veja se a porta `11434` já está em uso:

```bash
ss -ltnp | grep 11434
```

Se precisar, altere `OLLAMA_PORT` no `.env`.

### Modelo não encontrado

Liste os modelos:

```bash
make models
```

Baixe o modelo configurado:

```bash
make pull-model
```

### Performance lenta

Possíveis causas:

- Modelo grande demais para a RAM disponível.
- Execução CPU-only.
- Projeto em `/mnt/c` no WSL2.
- Muitas aplicações competindo por memória.

### Problemas de permissão

Evite permissões abertas. Primeiro identifique o volume:

```bash
docker volume ls
docker compose config --volumes
docker volume ls --filter name=ollama-models
```

Depois aplique apenas a correção mínima necessária conforme o erro encontrado.

## Suporte a GPU NVIDIA Opcional

Por padrão, a stack roda somente em CPU. Para usar uma GPU NVIDIA, este projeto oferece a sobreposição `docker-compose.gpu.yml`, que concede acesso a todas as GPUs NVIDIA ao serviço `ollama`. O Open WebUI continua sem acesso à GPU, pois apenas encaminha as conversas ao Ollama.

Esse recurso é destinado a Linux e Windows com WSL2. Não é compatível com Docker Desktop no macOS, que não fornece passagem de GPU para containers.

### Pré-requisitos

- GPU NVIDIA com driver instalado e reconhecido pelo sistema que hospeda o Docker (`nvidia-smi` deve responder sem erro).
- Docker Engine ou Docker Desktop com suporte a GPU; no WSL2, a integração WSL deve estar ativa.
- Docker Compose v2.

Antes de configurar o projeto, valide a GPU no host ou na distribuição WSL:

```bash
nvidia-smi
```

#### Docker Engine em Debian/Ubuntu

Instale o NVIDIA Container Toolkit e configure o runtime Docker:

```bash
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Para outras distribuições, siga o procedimento da [documentação oficial do NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

#### Docker Desktop com WSL2

Atualize o WSL e reinicie-o em um PowerShell com privilégios administrativos:

```powershell
wsl --update
wsl --shutdown
```

Depois, habilite a integração da sua distribuição em `Docker Desktop > Settings > Resources > WSL Integration`. O daemon é administrado pelo Docker Desktop; portanto, não execute `systemctl restart docker` dentro da distribuição. Consulte a [configuração de GPU do Docker Desktop](https://docs.docker.com/desktop/features/gpu/) para os requisitos de driver e versão do Windows.

Antes de subir a stack, valide que o Docker enxerga a GPU:

```bash
docker run --rm --gpus all nvidia/cuda:12.9.0-base-ubuntu22.04 nvidia-smi
```

O comando deve mostrar o nome da GPU e a versão do driver. Se falhar, corrija essa integração antes de continuar: o Compose não consegue contornar um driver ou runtime NVIDIA indisponível.

### Como iniciar com GPU

Pare a stack atual — os modelos e dados permanecem nos volumes nomeados — e suba a variante com GPU:

```bash
make down
make up-gpu
```

O alvo `up-gpu` combina `docker-compose.yml` com `docker-compose.gpu.yml`. A segunda configuração reserva todas as GPUs NVIDIA disponíveis para o Ollama usando `driver: nvidia`, `count: all` e `capabilities: [gpu]`.

Para reiniciar uma stack que já está em modo GPU:

```bash
make restart-gpu
```

Se também quiser habilitar a busca web opcional, use:

```bash
make up-gpu-web-search
```

Para voltar ao modo CPU:

```bash
make down
make up
```

### Como confirmar que o modelo usa GPU

Após abrir um modelo, verifique o processador em uso em outro terminal:

```bash
make run-model
```

Em outro terminal:

```bash
docker compose exec ollama ollama ps
```

O campo `PROCESSOR` deve indicar uso de GPU, total ou parcial. Modelos maiores do que a VRAM disponível podem usar GPU e RAM/CPU em conjunto; nesse caso, a aceleração é parcial, mas ainda pode reduzir o tempo de resposta. Para obter mais velocidade, escolha um modelo quantizado que caiba na VRAM disponível; para priorizar qualidade, modelos maiores podem usar a GPU parcialmente e complementar com RAM.

### Diagnóstico rápido

- Se `nvidia-smi` falhar no host/WSL, atualize ou corrija o driver NVIDIA e a integração WSL2 antes de testar o Docker.
- Se o teste com `docker run --gpus all ...` falhar, instale ou reconfigure o NVIDIA Container Toolkit e reinicie o daemon Docker.
- Se o Docker responder com erro de permissão no socket, use uma conta autorizada a operar o Docker antes de executar os comandos do projeto.
- Se o modelo continuar usando CPU, confira `make logs` e confirme que a stack foi iniciada com `make up-gpu`, não com `make up`.

Referências oficiais recomendadas:

- [Ollama: execução em Docker com GPU NVIDIA](https://docs.ollama.com/docker).
- [Docker Compose: acesso a GPU](https://docs.docker.com/compose/how-tos/gpu-support/).
- [NVIDIA Container Toolkit: instalação](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

## Roadmap Futuro

As próximas prioridades são reprodutibilidade de versões, inventário e migração de dados, diagnóstico (`doctor`), backup/restore, atualização segura, controles de privacidade, perfis de instalação, RAG com separação de documentos e auditoria. A ordem, o escopo e o que já existe estão detalhados no [roadmap do projeto](docs/ROADMAP.md).

## Licença

MIT. Consulte [LICENSE](LICENSE).
