# Roadmap do localhost.ai

[Voltar ao README](../README.md) · [Visão](VISION.md)

Este roadmap registra direção, não promessa de prazo. Funcionalidades só devem ser apresentadas como existentes depois de implementadas e testadas.

## Critério de prioridade

Priorizar mudanças que reduzam complexidade, risco, decisões ou dificuldade de reprodução. Wrappers que apenas encurtam comandos devem permanecer pequenos e não competir com funcionalidades upstream.

## Agora: consolidar a base

1. **Instalação reproduzível**
   - substituir gradualmente tags móveis por versões ou digests controlados;
   - registrar versões instaladas e compatibilidade conhecida;
   - definir estratégia de migração e rollback de volumes.

2. **Configuração integrada**
   - documentar contratos entre runtime, chat/RAG e ferramenta de desenvolvimento;
   - reduzir configuração duplicada e preferir mecanismos oficiais upstream;
   - validar e explicar divergências quando configurações preexistentes impedirem a aplicação dos defaults locais;
   - preservar o manifesto de alterações e melhorar testes idempotentes.

3. **Documentação e inventário de dados**
   - manter claros os diretórios, volumes, portas e fluxos de rede;
   - documentar migração entre máquinas e recuperação antes de operações destrutivas;
   - separar documentação de usuário, operação e arquitetura à medida que o projeto crescer.

## Próximo: reduzir risco operacional

4. **Diagnóstico (`localhost.ai doctor`, nome provisório)**
   - verificar Windows/WSL, RAM física e alocada, GPU, VRAM, driver, runtime NVIDIA, Docker e Compose;
   - verificar runtime de modelos, interface web, ferramenta de desenvolvimento e modelos instalados;
   - testar conectividade entre componentes e reconhecer problemas comuns de proxy/CA;
   - evoluir o atual `install.sh --check-only`, sem afirmar cobertura que ele ainda não possui.

5. **Backup e restore**
   - exportar dados do Open WebUI, configurações e metadados para um artefato transportável;
   - distinguir backup de modelos, que podem ser baixados novamente, de conversas e índices únicos;
   - validar restauração em uma instalação limpa e compatibilidade entre versões.

6. **Atualização segura**
   - apresentar plano e versões antes de atualizar;
   - testar saúde após atualização e oferecer rollback quando tecnicamente possível;
   - evitar atualização cega de imagens e configurações persistidas.

7. **Segurança e privacidade**
   - inventariar telemetria e comportamento de rede de cada versão suportada;
   - avaliar política de egress e um modo mais restritivo;
   - incorporar verificação de artefatos, SBOM e alertas de configuração insegura quando viável.

## Depois: perfis e casos de uso

8. **Perfis de instalação**
   - `developer`: runtime, chat e uma ferramenta principal de desenvolvimento;
   - `knowledge`: chat/RAG, embeddings e fluxo seguro de documentos;
   - `private`: conectividade mais restrita e auditoria reforçada;
   - nomes e escopo são propostas e podem mudar após validação com usuários.

9. **RAG local e documentos**
   - definir fluxo com originais preservados, cópias de ingestão e índices gerados separados;
   - selecionar e versionar modelos de embedding compatíveis com os recursos da estação;
   - documentar atualização, exclusão e reconstrução dos índices.

10. **Auditoria (`localhost.ai audit`, nome provisório)**
    - listar serviços, portas, volumes, diretórios e configurações relevantes;
    - informar componentes com capacidade de acesso à Internet e telemetria conhecida;
    - diferenciar evidência observada de comportamento apenas documentado pelo upstream.

11. **Operação em redes corporativas**
    - ampliar diagnóstico de proxy, DNS, VPN, inspeção TLS e CAs internas;
    - estudar instalação com cache ou espelho corporativo e bootstrap parcialmente offline;
    - documentar responsabilidades entre Windows, WSL2, Docker Desktop e Docker Engine.

## Componentes de desenvolvimento

OpenCode e Aider são instalados atualmente. OpenCode cobre um conjunto mais amplo de recursos de agente; Aider permanece útil como alternativa direta. Antes de alterar o padrão:

- medir qualidade e estabilidade com os modelos locais suportados;
- permitir seleção por perfil;
- preservar compatibilidade com usuários existentes;
- tornar Aider opcional antes de considerar qualquer remoção.

## Fora de escopo

- criar um runtime de modelos, interface de chat ou agente de código próprio;
- duplicar recursos mantidos adequadamente por projetos upstream;
- substituir controles de uma plataforma corporativa de IA.
