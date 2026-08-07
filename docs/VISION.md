# Visão do ai.localhost

[Voltar ao README](../README.md)

O objetivo do **ai.localhost** é facilitar a instalação e configuração de ferramentas de IA em ambiente local. O projeto reúne Docker Compose, Ollama, Open WebUI, Aider, OpenCode, Caddy, mkcert e SearXNG opcional em uma experiência única, para que usuários não precisem selecionar, conectar e ajustar manualmente cada componente.

## O problema

Modelos de linguagem estão se tornando ferramentas comuns para escrever, analisar documentos, pesquisar informações e desenvolver software. Entretanto, organizações que trabalham com dados pessoais, códigos internos, contratos, processos administrativos e outras informações sensíveis ainda dependem, muitas vezes de forma pouco controlada, de serviços de IA executados na nuvem.

Ao enviar um prompt, documento ou trecho de código para esses serviços, a organização transfere informações para uma infraestrutura externa sobre a qual possui controle limitado. Para órgãos públicos e setores regulados, isso cria riscos de privacidade, segurança, conformidade e soberania dos dados.

Ao mesmo tempo, muitas estações de trabalho corporativas possuem GPUs capazes de executar modelos de inteligência artificial, mas esses recursos permanecem ociosos durante grande parte do tempo. Em empresas públicas, isso representa capacidade computacional adquirida com dinheiro público que não está sendo plenamente aproveitada.

## A proposta

O **ai.localhost** transforma uma estação de trabalho Windows em um ambiente privado de inteligência artificial. Os modelos, conversas, documentos e códigos permanecem na máquina do usuário, sem depender de APIs comerciais de IA na nuvem.

A solução utiliza a CPU e, quando disponível, a GPU da própria estação de trabalho para executar os modelos. Dessa forma, equipamentos já adquiridos passam a entregar valor adicional, sem a necessidade de provisionar imediatamente nova infraestrutura centralizada para cada uso individual.

O projeto reúne tecnologias existentes e as entrega como uma experiência única, integrada e reproduzível. Ele não desenvolve um novo modelo nem uma nova plataforma de IA: seu valor está em remover a complexidade de selecionar, instalar, configurar e conectar todos os componentes.

Com poucas instruções e um único comando, o usuário obtém um ambiente local pronto para trabalhar.

## Para quem

Para profissionais de áreas administrativas, o **Open WebUI** oferece uma interface semelhante às ferramentas de IA mais conhecidas. Por meio do navegador, o usuário pode conversar com o modelo, analisar arquivos, organizar documentos em bases de conhecimento e consultar informações internas sem enviá-las para um provedor externo.

Para desenvolvedores, o **Aider** leva o modelo local ao terminal. Ele pode compreender um repositório, explicar código, propor alterações, criar testes e editar arquivos, mantendo o código-fonte no próprio ambiente de trabalho. Como alternativa, o **OpenCode** oferece uma experiência de agente de terminal com sessões, subagentes, comandos, skills, MCPs e hooks, também conectada apenas ao Ollama local na configuração padrão.

## Complementar às soluções corporativas

O **ai.localhost** não pretende competir com plataformas corporativas de IA em nuvem. Ele atende a uma camada diferente da necessidade.

Na Dataprev, por exemplo, a **LIA** funciona como uma solução coletiva disponibilizada pela empresa. Embora opere em ambiente controlado e on-premises, sua infraestrutura utiliza a Oracle Cloud Infrastructure — OCI — e softwares fornecidos por empresas contratadas.

O **ai.localhost**, por outro lado, funciona diretamente na estação de trabalho e aproveita a GPU que já está disponível para aquele trabalhador. Ele pode ser usado como uma primeira camada individual de produtividade para tarefas locais, experimentações, análise de documentos e desenvolvimento, antes de recorrer à solução coletiva da organização.

As duas abordagens podem coexistir:

* a solução local atende ao uso individual, imediato e restrito à estação;
* a solução corporativa atende a serviços compartilhados, governança centralizada, integração institucional e maior capacidade computacional;
* o trabalhador pode resolver localmente tarefas compatíveis com sua estação e utilizar a plataforma corporativa quando precisar de modelos maiores, serviços compartilhados ou recursos institucionais.

## Como a solução funciona

| Tecnologia           | Papel na solução                                                                                |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| **Windows e WSL2**   | Permitem executar o ambiente Linux necessário sem substituir o sistema operacional do usuário.  |
| **Docker Compose**   | Instala e conecta os serviços de forma isolada e reproduzível.                                  |
| **Ollama**           | Baixa, armazena e executa os modelos de linguagem localmente.                                   |
| **CPU e GPU locais** | Fornecem a capacidade computacional da solução, aproveitando recursos já existentes na estação. |
| **Open WebUI**       | Oferece a interface web para conversas, arquivos e bases de conhecimento.                       |
| **Aider**            | Oferece assistência de programação diretamente nos repositórios locais.                         |
| **OpenCode**         | Alternativa de agente de terminal local para programação, conectada ao Ollama; não duplica modelos. |
| **Caddy e mkcert**   | Disponibilizam a interface por HTTPS, limitada à própria máquina.                               |
| **SearXNG**          | Acrescenta busca na internet de forma opcional e controlada.                                    |
| **ai.localhost**     | Unifica instalação, configuração, seleção de modelos e inicialização do ambiente.               |

## Valor da iniciativa

O **ai.localhost** busca tornar a IA local uma alternativa prática, e não apenas tecnicamente possível. Seus principais ganhos são:

* maior controle sobre documentos, prompts e códigos;
* aproveitamento das GPUs ociosas das estações de trabalho;
* melhor retorno sobre equipamentos adquiridos com recursos públicos;
* redução da dependência de serviços externos;
* ausência de custos recorrentes com APIs de IA;
* ambiente reproduzível e auditável;
* produtividade para usuários técnicos e administrativos;
* complementaridade com plataformas corporativas de IA;
* liberdade para substituir modelos e componentes da pilha.

O WSL ainda representa uma barreira inicial para usuários não técnicos, mas sua instalação no Windows é relativamente simples. O projeto reduz o restante da complexidade e transforma várias ferramentas isoladas em uma solução única.

## Visão

**Democratizar o acesso à inteligência artificial local, aproveitando a capacidade computacional já disponível nas estações de trabalho e oferecendo a pessoas e organizações uma forma simples, produtiva e soberana de utilizar LLMs, de maneira complementar às plataformas corporativas de IA.**
