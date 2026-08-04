# ai.localhost

Ambiente local, privado e reproduzível de IA para desenvolvimento com código usando Docker Compose, Ollama e Open WebUI.

O objetivo é rodar modelos locais para apoio a desenvolvimento sem depender de APIs externas, mantendo os dados no host/WSL e expondo os serviços apenas em `localhost`.

O repositório e a interface usam o nome `ai.localhost`. Os diretórios internos, o manifesto e os volumes preservam o identificador histórico `local-coding-ai` para que instalações existentes continuem funcionando após a mudança de nome.

## Visão Geral

Este projeto entrega uma stack simples para Linux/WSL2:

- Ollama em container para executar LLMs localmente.
- Open WebUI em container para interface web local.
- Caddy como proxy reverso local para `ai.localhost`.
- Volumes nomeados para persistir modelos e dados.
- Bind padrão em `127.0.0.1`, sem exposição para a rede local.
- Scripts e Makefile para operação diária.
- Comando global `ai.localhost` para iniciar o ambiente e abrir o Aider no projeto atual.
- Aider documentado para rodar no host/WSL, apontando para o Ollama local.

## Componentes e Fluxo

| Componente | Papel no ambiente |
|---|---|
| Docker Compose | Sobe e conecta os serviços, além de criar os volumes persistentes. Os atalhos `make` executam comandos do Compose. |
| Ollama | Servidor local que baixa, armazena e executa os modelos de linguagem. Sua API fica disponível no host em `http://localhost:11434`. |
| Modelo LLM | A IA que gera respostas. O modelo padrão é definido por `OLLAMA_MODEL_DEFAULT` no arquivo `.env`. |
| Open WebUI | Interface web local para conversar com os modelos. Não publica uma porta diretamente no host e conecta-se ao Ollama pela rede Docker. |
| Caddy | Proxy reverso que publica o Open WebUI em `https://ai.localhost` e redireciona automaticamente requisições HTTP para HTTPS. |
| Aider | Assistente de programação de terminal instalado no host/WSL. Ao ser iniciado dentro de um repositório, usa o Ollama local e pode trabalhar nos arquivos desse repositório. |
| `ai.localhost` | Comando instalado em `~/.local/bin` que inicia a stack quando necessário, define `OLLAMA_API_BASE`, seleciona o modelo configurado e abre o Aider no projeto atual. |
| SearXNG | Metabuscador opcional, iniciado somente com `make up-web-search`, que fornece busca web ao Open WebUI. |
| Volumes nomeados | Preservam os modelos do Ollama, os dados do Open WebUI e o cache do SearXNG mesmo após `make down`. |
| `.env` | Configuração local de portas, modelo padrão, autenticação e opções de busca; deve ser criado a partir de `.env.example`. |

Fluxo padrão, totalmente local:

```text
Navegador
    ↓ https://ai.localhost
Caddy → Open WebUI → Ollama → modelo local

Aider / curl
    ↓ http://localhost:11434
Ollama → modelo local
```

Com a busca web opcional habilitada, o Open WebUI consulta o SearXNG, que por sua vez pode fazer requisições a mecanismos e fontes externos. Sem esse modo, o ambiente não acessa a internet para responder aos prompts.

## Objetivos do Projeto

- Privacidade do código e dos prompts.
- Execução local sem serviços cloud.
- Reprodutibilidade em outra máquina.
- Seleção automática entre CPU e GPU NVIDIA no instalador, com comandos explícitos para operação manual.
- Evitar permissões amplas, `privileged: true`, `network_mode: host` e montagens sensíveis.

## Arquitetura

```text
WSL2/Linux Host
├── Navegador → Caddy → Open WebUI ┐
├── Aider ─────────────────────────┼→ Ollama → modelo local
└── curl ──────────────────────────┘

Docker Compose: Caddy, Open WebUI, Ollama e SearXNG opcional
Host/WSL: Aider e o comando ai.localhost
```

## Pré-Requisitos

- Linux ou WSL2.
- Docker Engine.
- Docker Compose v2.
- RAM recomendada: 16 GB para começar, 32 GB para modelos maiores.

O instalador automatizado instala, quando necessário, `curl`, Git, `make`, Python, `pipx`, `mkcert`, OpenSSL e ferramentas NSS em distribuições com `apt`. O Docker e o Compose devem estar previamente instalados porque a escolha entre Docker Engine e Docker Desktop depende da máquina. Na instalação manual, todas essas ferramentas são pré-requisitos.

No WSL2, mantenha seus projetos dentro do filesystem Linux, por exemplo `~/workspace/projeto`, em vez de `/mnt/c/...`.

## Instalação Automatizada

O instalador pode ser executado diretamente do GitHub. Inicie o comando dentro do repositório em que deseja abrir o Aider:

```bash
cd ~/workspace/meu-projeto
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/install.sh | bash
```

Esse comando remoto é necessário apenas uma vez para preparar a máquina. Ao final, ele instala o executável `ai.localhost` em `~/.local/bin`. A partir daí, o uso diário em qualquer repositório Git requer somente:

```bash
cd ~/workspace/meu-projeto
ai.localhost
```

O diretório em que o instalador é executado não limita a instalação. Você também pode instalá-lo a partir da sua pasta pessoal sem abrir o Aider imediatamente:

```bash
cd ~
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/install.sh \
  | bash -s -- --no-launch
```

Antes de baixar imagens ou modelos, o instalador verifica Linux/WSL2, RAM, VRAM, GPU NVIDIA, espaço em disco, Docker, Compose e dependências do host. Em seguida, ele:

- instala dependências básicas ausentes em sistemas com `apt` após confirmação;
- clona ou atualiza a stack em `~/.local/share/local-coding-ai`;
- valida ou configura o NVIDIA Container Toolkit quando há uma GPU compatível;
- instala o Aider com `pipx`;
- gera e instala o certificado local de `https://ai.localhost` com `mkcert`;
- sobe a stack em CPU ou GPU;
- escolhe e baixa um modelo Qwen geral e outro voltado a código;
- mostra URLs e comandos de gerenciamento antes de abrir o Aider com o Qwen geral mais recente compatível no repositório atual; o modelo especializado em código permanece disponível como alternativa;
- instala o comando global `ai.localhost`, que elimina a necessidade de exportar `OLLAMA_API_BASE` ou repetir o nome do modelo.

Durante a execução, o instalador mantém um manifesto em `~/.local/state/local-coding-ai`. Ele registra o que já existia e o que foi adicionado pelo projeto para permitir uma desinstalação completa sem remover ferramentas compartilhadas que já estavam na máquina.

A seleção automática prioriza a geração Qwen mais recente que caiba de maneira razoável na RAM/VRAM detectada. Atualmente, ela usa Qwen 3.6 em máquinas grandes, Qwen 3.5 nos demais perfis e Qwen3-Coder ou Qwen2.5-Coder para programação. As famílias e tamanhos podem ser conferidos no catálogo oficial do [Qwen 3.6](https://ollama.com/library/qwen3.6), [Qwen 3.5](https://ollama.com/library/qwen3.5) e [Qwen3-Coder](https://ollama.com/library/qwen3-coder).

Faça somente o diagnóstico, sem alterações ou downloads:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/install.sh \
  | bash -s -- --check-only
```

Instale sem abrir o Aider ao final:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/install.sh \
  | bash -s -- --no-launch
```

É possível substituir a seleção automática:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/install.sh \
  | bash -s -- \
      --general-model qwen3.5:9b \
      --code-model qwen2.5-coder:7b \
      --aider-model qwen3.5:9b
```

Para revisar o instalador antes de executá-lo:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/install.sh -o /tmp/ai-localhost-install.sh
less /tmp/ai-localhost-install.sh
bash /tmp/ai-localhost-install.sh
```

## Desinstalação Completa

> **Atenção:** a desinstalação apaga definitivamente os modelos baixados, as conversas do Open WebUI e os demais dados armazenados nos volumes Docker.

Confira primeiro o que seria removido, sem alterar a máquina:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/uninstall.sh \
  | bash -s -- --dry-run
```

Em um checkout local, os comandos equivalentes são:

```bash
./uninstall.sh --dry-run
./uninstall.sh
```

Execute a desinstalação completa:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/uninstall.sh | bash
```

Para uso não interativo:

```bash
curl -fsSL https://raw.githubusercontent.com/gut0leao/ai.localhost/main/uninstall.sh \
  | bash -s -- --yes
```

O desinstalador usa o manifesto para:

- remover containers, rede, volumes, modelos, conversas e imagens baixadas pelo instalador;
- remover o certificado de `ai.localhost` e desfazer a confiança da CA do `mkcert` quando ela foi criada pelo projeto, inclusive no armazenamento do usuário Windows quando configurado pelo WSL;
- desinstalar o Aider com `pipx` somente se ele não existia antes;
- remover `ai.localhost` e restaurar qualquer launcher ou configuração anterior;
- remover somente os pacotes APT que não estavam instalados antes;
- restaurar `/etc/docker/daemon.json` e os arquivos do repositório NVIDIA quando o instalador os alterou;
- restaurar o `.env`, certificados e revisão Git anteriores quando a stack já existia;
- apagar o checkout em `~/.local/share/local-coding-ai` somente quando ele foi clonado pelo instalador.

O Docker, o Docker Compose, o driver NVIDIA e o próprio WSL não são removidos, pois são pré-requisitos e não são instalados pelo projeto. Em instalações antigas que não possuem manifesto, o script remove os recursos próprios da stack, mas preserva Aider, CA, pacotes APT e configuração NVIDIA por não conseguir determinar com segurança sua origem.

Depois da desinstalação, abra um novo terminal antes de testar novamente o instalador.

## Instalação Manual

Clone o repositório e entre na pasta:

```bash
git clone https://github.com/gut0leao/ai.localhost.git
cd ai.localhost
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

Esta seção se aplica somente a quem clonou e configurou o projeto manualmente. Se você utilizou o instalador automatizado, o HTTPS, a stack e os modelos já foram preparados; entre em um repositório Git e execute `ai.localhost`.

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

## Como Baixar Modelos

O modelo padrão fica em `.env`:

```env
OLLAMA_MODEL_DEFAULT=qwen3.5:4b
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

## Como Instalar Aider no Host/WSL

O Aider não roda em container neste projeto. No Ubuntu executado pelo WSL, instale-o no host/WSL com `pipx`:

```bash
sudo apt-get update
sudo apt-get install -y pipx
pipx ensurepath
exec zsh -l
pipx install aider-chat
```

O comando `exec zsh -l` recarrega o shell para que o diretório de binários do `pipx` entre no `PATH`. Se você usar outro shell, feche e abra um novo terminal WSL antes de executar `aider --version`.

## Como Configurar Aider para Usar Ollama Local

O instalador cria o comando `ai.localhost`. Execute-o dentro de qualquer repositório Git; ele inicia a stack se necessário, define `OLLAMA_API_BASE` e abre o Aider com o modelo selecionado para a máquina:

```bash
cd ~/workspace/meu-projeto
ai.localhost
```

Use o modelo especializado em código baixado pelo instalador:

```bash
ai.localhost --code
```

Abra outro repositório sem trocar antes de diretório:

```bash
ai.localhost --project ~/workspace/outro-projeto
```

Para escolher manualmente qualquer modelo já baixado ou encaminhar outras opções ao Aider:

```bash
ai.localhost --model ollama_chat/qwen3.5:9b
ai.localhost --message "explique a arquitetura deste projeto"
```

O comando é um executável real, não um alias de shell. Por isso funciona da mesma forma no Bash e no Zsh. A configuração da stack fica em `~/.config/local-coding-ai/stack-dir`, enquanto os modelos escolhidos ficam no `.env` da instalação. Execute `ai.localhost --help` para ver as opções próprias; as demais opções são encaminhadas ao Aider.

Ao iniciar, o comando sempre mostra um resumo curto com a URL da interface web, projeto e modelo ativos e os comandos para usar o modelo de código, baixar ou selecionar outro modelo e abrir outro projeto. A ajuda completa permanece disponível em `ai.localhost --help`.

Se a instalação foi feita manualmente, ainda é possível usar o Aider sem o comando auxiliar:

```bash
export OLLAMA_API_BASE=http://localhost:11434
aider --model ollama_chat/qwen3.5:9b
```

Dentro do Aider, peça mudanças pequenas e revise o diff antes de commitar.

## Privacidade e Segurança

Por padrão:

- As portas são vinculadas a `127.0.0.1`.
- O Open WebUI não publica sua porta interna diretamente; o acesso passa pelo proxy reverso local.
- Nenhum serviço usa `network_mode: host`.
- Nenhum container usa `privileged: true`.
- Não há montagem de `/home`, `~/.ssh`, `/var/run/docker.sock` ou repositórios pessoais.
- Modelos e dados ficam em volumes nomeados do Docker.
- O Aider roda no host/WSL e conversa com o Ollama local.

O serviço `ollama` usa o usuário padrão da imagem oficial. Isso é aceito aqui porque não há montagem de diretórios sensíveis, as portas ficam em localhost e o container não é privilegiado.

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
- Ajuste memória do WSL2 em `%UserProfile%\.wslconfig` se necessário.
- Reinicie o WSL após mudanças de configuração:

```powershell
wsl --shutdown
```

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

### O comando `ai.localhost` não é encontrado

Confirme que `~/.local/bin` está no `PATH` e recarregue o shell:

```bash
export PATH="$HOME/.local/bin:$PATH"
exec "$SHELL" -l
```

Se o arquivo ainda não existir, execute novamente o instalador. Em um checkout local atualizado:

```bash
./install.sh --no-launch
```

### A interface `ai.localhost` não abre

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
docker volume inspect local-coding-ai_ollama-models
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

- Presets de modelos por memória disponível.
- Healthchecks.
- Scripts de bootstrap offline.
- Documentação de embeddings locais.

## Licença

MIT. Consulte [LICENSE](LICENSE).
