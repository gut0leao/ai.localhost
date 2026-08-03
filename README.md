# local-coding-ai

Ambiente local, privado e reproduzível de IA para desenvolvimento com código usando Docker Compose, Ollama e Open WebUI.

O objetivo é rodar modelos locais para apoio a desenvolvimento sem depender de APIs externas, mantendo os dados no host/WSL e expondo os serviços apenas em `localhost`.

## Visão Geral

Este projeto entrega uma stack simples para Linux/WSL2:

- Ollama em container para executar LLMs localmente.
- Open WebUI em container para interface web local.
- Volumes nomeados para persistir modelos e dados.
- Bind padrão em `127.0.0.1`, sem exposição para a rede local.
- Scripts e Makefile para operação diária.
- Aider documentado para rodar no host/WSL, apontando para o Ollama local.

## Componentes e Fluxo

| Componente | Papel no ambiente |
|---|---|
| Docker Compose | Sobe e conecta os serviços, além de criar os volumes persistentes. Os atalhos `make` executam comandos do Compose. |
| Ollama | Servidor local que baixa, armazena e executa os modelos de linguagem. Sua API fica disponível no host em `http://127.0.0.1:11434`. |
| Modelo LLM | A IA que gera respostas. O modelo padrão é definido por `OLLAMA_MODEL_DEFAULT` no arquivo `.env`. |
| Open WebUI | Interface web local para conversar com os modelos. Dentro da rede Docker, conecta-se ao Ollama por `http://ollama:11434`; no navegador, é acessado em `http://127.0.0.1:3000`. |
| Aider | Assistente de programação de terminal instalado no host/WSL. Ao ser iniciado dentro de um repositório, usa o Ollama local e pode trabalhar nos arquivos desse repositório. |
| SearXNG | Metabuscador opcional, iniciado somente com `make up-web-search`, que fornece busca web ao Open WebUI. |
| Volumes nomeados | Preservam os modelos do Ollama, os dados do Open WebUI e o cache do SearXNG mesmo após `make down`. |
| `.env` | Configuração local de portas, modelo padrão, autenticação e opções de busca; deve ser criado a partir de `.env.example`. |

Fluxo padrão, totalmente local:

```text
Navegador / Aider / curl
          ↓ localhost
        Ollama
          ↓
    modelo local
```

Com a busca web opcional habilitada, o Open WebUI consulta o SearXNG, que por sua vez pode fazer requisições a mecanismos e fontes externos. Sem esse modo, o ambiente não acessa a internet para responder aos prompts.

## Objetivos do Projeto

- Privacidade do código e dos prompts.
- Execução local sem serviços cloud.
- Reprodutibilidade em outra máquina.
- Setup simples para CPU, com GPU NVIDIA como opção documentada.
- Evitar permissões amplas, `privileged: true`, `network_mode: host` e montagens sensíveis.

## Arquitetura

```text
WSL2/Linux Host
└── Docker Compose
    ├── Ollama
    │   └── modelos locais persistidos
    └── Open WebUI
        └── interface local tipo ChatGPT

Aider no host/WSL
    ↓ localhost
Ollama Container
```

## Pré-Requisitos

- Linux ou WSL2.
- Docker Engine.
- Docker Compose v2.
- `make`, `bash` e `curl`.
- RAM recomendada: 16 GB para começar, 32 GB para modelos maiores.

No WSL2, mantenha seus projetos dentro do filesystem Linux, por exemplo `~/workspace/projeto`, em vez de `/mnt/c/...`.

## Instalação

Clone o repositório e entre na pasta:

```bash
git clone https://github.com/gut0leao/local-coding-ai.git
cd local-coding-ai
```

Crie o arquivo de configuração local:

```bash
cp .env.example .env
```

Revise as variáveis, especialmente portas e modelo padrão:

```bash
sed -n '1,120p' .env
```

## Primeiro Uso

Suba os serviços:

```bash
make up
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
http://127.0.0.1:3000
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
make up
```

Se quiser revisar as mudanças das imagens, consulte a documentação oficial dos projetos antes de atualizar ambientes importantes.

## Como Baixar Modelos

O modelo padrão fica em `.env`:

```env
OLLAMA_MODEL_DEFAULT=qwen2.5-coder:7b
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
make run-model MODEL=qwen2.5-coder:14b
```

## Como Testar o Ollama

```bash
make test-ollama
```

Teste manual:

```bash
curl http://127.0.0.1:11434/api/tags
```

A resposta esperada é um JSON com os modelos disponíveis.

## Como Acessar Open WebUI

Abra no navegador:

```text
http://127.0.0.1:3000
```

O Open WebUI usa `OLLAMA_BASE_URL=http://ollama:11434` dentro da rede do Docker Compose. No host, use `http://127.0.0.1:11434`.


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

Com o Ollama rodando via Docker Compose, use:

```bash
export OLLAMA_API_BASE=http://127.0.0.1:11434
aider --model ollama_chat/qwen3:8b
```

Também é possível informar outro modelo instalado:

```bash
aider --model ollama_chat/qwen3:14b
```

## Exemplo de Uso do Aider em um Projeto Git

```bash
cd ~/workspace/meu-projeto
git status
aider --model ollama_chat/qwen3:8b
```

Dentro do Aider, peça mudanças pequenas e revise o diff antes de commitar.

## Privacidade e Segurança

Por padrão:

- As portas são vinculadas a `127.0.0.1`.
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
