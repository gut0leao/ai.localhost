# Visão do localhost.ai

[Voltar ao README](../README.md) · [Roadmap](ROADMAP.md)

## Contexto

Modelos de linguagem passaram a apoiar desenvolvimento, pesquisa, escrita e análise de documentos. Ao mesmo tempo, usar serviços externos para código, documentos internos ou dados potencialmente sensíveis nem sempre é adequado. Muitas estações de trabalho já possuem CPU, memória e GPU capazes de executar modelos menores localmente, mas transformar esse hardware em um ambiente funcional ainda exige conhecimento de várias ferramentas e camadas de infraestrutura.

O **localhost.ai** atua nesse espaço: a estação de trabalho individual, com atenção especial a Windows + WSL2 e a ambientes corporativos sujeitos a VPN, proxy, inspeção TLS e CAs internas.

## Problema

O problema central não é instalar Ollama, Open WebUI, OpenCode ou Aider isoladamente. Cada projeto upstream já oferece seu próprio procedimento e evolui mais rápido em seu domínio.

O problema é disponibilizar uma estação de IA local coerente sem exigir que o usuário decida e configure manualmente runtime, modelos, aceleração, portas, certificados, persistência, integração, atualização e comportamento de rede. Essa fragmentação aumenta o esforço de instalação, dificulta a reprodução em outra máquina e favorece configurações acidentalmente inseguras.

## Visão

Oferecer uma distribuição leve para criação de uma estação de trabalho de IA local, integrando modelos, chat, RAG e desenvolvimento assistido por meio de uma configuração reproduzível, opinativa, compreensível e orientada à privacidade.

O projeto deve ser uma camada fina de integração, configuração e governança sobre componentes existentes. Seu valor de longo prazo está nas convenções, diagnósticos, controles e procedimentos que tornam o conjunto previsível — não na quantidade de comandos upstream encapsulados.

## Objetivos

- produzir instalações equivalentes em máquinas com recursos equivalentes;
- reduzir decisões técnicas que não agregam valor ao usuário final;
- oferecer defaults locais e conservadores, com conexões externas explícitas;
- documentar onde dados, modelos, configurações e certificados são armazenados;
- integrar runtime, chat/RAG e pelo menos uma ferramenta de desenvolvimento;
- funcionar de forma diagnosticável em Linux e Windows + WSL2;
- considerar proxies, CAs corporativas e restrições comuns de rede;
- permitir substituição incremental dos componentes atuais;
- complementar, e não disputar, plataformas corporativas de IA.

## Não objetivos

- competir com Ollama, Open WebUI, OpenCode, Aider ou outras ferramentas do ecossistema;
- criar uma nova plataforma de IA completa do zero;
- reimplementar recursos que um componente upstream já ofereça adequadamente;
- prometer isolamento, conformidade ou segurança que não sejam tecnicamente aplicados e verificáveis;
- substituir governança, identidade, autorização e infraestrutura compartilhada de uma plataforma corporativa;
- transformar cada comando simples de uma ferramenta em um wrapper próprio.

## Público-alvo

- usuários individuais que querem experimentar IA local com menor barreira técnica;
- desenvolvedores que lidam com repositórios internos ou dados que merecem tratamento local;
- profissionais que usam chat, documentos e bases de conhecimento individuais;
- equipes de suporte que precisam reproduzir a mesma configuração em várias estações;
- organizações que desejam aproveitar GPUs já adquiridas e subutilizadas.

## Princípios arquiteturais

### 1. Integração, não reimplementação

O projeto deve preferir configurações e APIs oficiais. Quando uma funcionalidade mantida localmente passar a existir adequadamente no upstream, a direção preferida é remover código e adotar a implementação oficial. Menos código de integração reduz manutenção e divergência.

### 2. Ferramentas são substituíveis

A arquitetura é composta por papéis: runtime de modelos, interface de chat/RAG, ferramenta de desenvolvimento, proxy local e serviços opcionais. Ollama, Open WebUI, OpenCode, Aider, Caddy e SearXNG são as implementações atuais desses papéis, não a identidade do projeto.

O acoplamento deve ser explícito e pequeno. Uma troca futura deve exigir principalmente adaptação de configuração e testes, não uma redefinição da visão.

### 3. Reduzir complexidade antes de reduzir comandos

Uma funcionalidade tem alto valor quando reduz risco, decisões, divergência, tempo de diagnóstico ou dificuldade de reprodução. Encapsular um comando trivial tem valor baixo e deve ser feito apenas quando sustenta uma convenção útil ou compatibilidade.

### 4. Ambiente opinativo e reproduzível

Diretórios, portas, modelos, volumes, dados, atualização e integração devem seguir convenções claras. Defaults devem ser documentados e revisáveis. Reprodutibilidade também exige evoluir de tags móveis para versões controladas e oferecer atualização com validação e possibilidade de retorno.

### 5. Privacidade e execução local como padrão

Inferência local é o padrão. Conexões externas e ferramentas de rede devem ser identificáveis e, progressivamente, controláveis. A documentação deve distinguir comportamento implementado, limitações atuais e segurança desejada.

### 6. Compatibilidade incremental

Mudanças devem preservar instalações existentes sempre que razoável. Componentes sobrepostos podem ser despriorizados ou tornados opcionais antes de serem removidos. Migrações de dados e configurações precisam ser explícitas.

## Segurança e privacidade

### Controles existentes

- portas publicadas em `127.0.0.1` por padrão;
- Open WebUI acessível por proxy HTTPS local, sem publicar diretamente sua porta interna;
- containers sem `privileged`, `network_mode: host`, socket Docker ou montagem do diretório pessoal;
- autenticação do Open WebUI habilitada por padrão;
- certificados gerados localmente e chave da CA mantida pelo mkcert fora do repositório;
- CA corporativa montada como somente leitura nos containers;
- configuração gerada do OpenCode apontada para Ollama e permissões sensíveis definidas de forma restritiva;
- manifesto que registra alterações feitas pelo instalador para uma desinstalação mais cuidadosa.

### Limitações atuais

- não existe bloqueio de tráfego de saída dos containers ou processos no host;
- imagens com tags `latest` e `main` reduzem a reprodutibilidade e ampliam risco de atualização;
- não há auditoria automatizada de portas, telemetria, egress ou diretórios de dados;
- não há backup e restore integrados no estado atual do repositório;
- não há verificação de assinatura, SBOM ou política formal de vulnerabilidades;
- localhost e HTTPS local não substituem hardening do host, controle de acesso ou classificação da informação;
- componentes upstream podem mudar seu comportamento de rede e telemetria.
- configurações preexistentes do OpenCode são preservadas e podem habilitar provedores ou permissões diferentes dos defaults do projeto.

### Direção desejada

O projeto deve oferecer diagnóstico e auditoria legíveis, versões controladas, atualização segura, inventário de dados, backup testável e um perfil com conectividade mais restrita. Essas capacidades só devem ser anunciadas como segurança existente depois de implementadas e verificadas.

## Relação com ferramentas upstream

Ollama e Open WebUI ocupam hoje os papéis essenciais de runtime e chat/RAG. OpenCode cobre uma experiência ampla de agente de desenvolvimento. Aider oferece uma interação mais direta e continua útil como alternativa, mas há sobreposição significativa.

Na versão atual, o instalador instala OpenCode e Aider. A direção é permitir que perfis selecionem uma ferramenta principal e tratem alternativas como opcionais, sem remoção abrupta. A decisão deve considerar compatibilidade, qualidade com modelos locais, manutenção e preferência do usuário.

## Relação com soluções corporativas

O **localhost.ai** atende à estação individual: experimentação, desenvolvimento, análise de documentos e tarefas locais. Plataformas corporativas atendem colaboração, identidade, governança centralizada, integrações institucionais, modelos maiores e capacidade compartilhada.

As duas camadas são complementares. Uma organização pode aproveitar GPUs já presentes nas estações para cargas adequadas e encaminhar outros casos à plataforma corporativa, de acordo com sua classificação de dados e suas políticas. O projeto não pressupõe superioridade de uma camada nem critica fornecedores específicos.

## Direção futura

As prioridades são tornar a distribuição mais reproduzível, diagnosticável e verificável: controle de versões, atualização segura, `doctor`, auditoria, backup/restore, inventário de dados, perfis de instalação, RAG local com separação de originais e índices, e melhor operação sob redes corporativas.

Detalhes e ordem de execução estão no [roadmap](ROADMAP.md).
