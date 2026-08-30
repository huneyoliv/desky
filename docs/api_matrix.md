# Matriz Completa de Módulos, Funcionalidades e Status da API YPT (Yeolpumta)

Esta matriz apresenta a especificação atualizada e exaustiva de **TODOS os 15 módulos e subsistemas** do aplicativo YPT identificados através da descompilação do APK, extração de dicionários e análise do arquivo de tráfego de rede (`YPT Completo.har`), indicando o status de validação com a API real em produção.

---

## 1. Módulos Core de Estudo e Sessão

| Módulo / Funcionalidade | Descrição Técnica | Endpoint Princpal | Backend / Host | Status de Validação |
| :--- | :--- | :--- | :--- | :--- |
| **Autenticação Direta (JWT)** | Autenticação por email/senha e emissão do JWT YPT | `POST /user/sign-in-jwt` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Autenticação Social (Google/Apple)** | Login federado via OAuth2 / OpenID Connect | `POST /user/sign-in-jwt` (com `loginProvider`) | `pi.tgclab.com` | **Validado (Especificado)** |
| **Inicialização de Sessão (Splash)** | Sincronização do app, push token, modelo e fuso | `POST /user/v2/splash-login` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Recarregamento de Estado (Reload)** | Recarga rápida do cronômetro e perfil | `POST /user/v2/reload/info` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Matérias (Subject Studies)** | Criação, edição, ordenação, arquivamento e exclusão | `POST /user/subject/*` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Cronômetro (Timer & Session)** | Iniciar, pausar, editar e adicionar sessões de estudo | `POST /study/*` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Sincronização de Relógio (Time Sync)** | Prevenção de fraude de horário via timestamp | `GET /time/` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |

---

## 2. Módulos de Organização, Planner e Agenda

| Módulo / Funcionalidade | Descrição Técnica | Endpoint Princpal | Backend / Host | Status de Validação |
| :--- | :--- | :--- | :--- | :--- |
| **Planner & Tarefas (Todo)** | Tarefas, hábitos, personalização de cores e blocos | `GET /planner/stuff` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Temas do Planner** | Temas visuais e molduras do planner | `GET /planner/themes` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Plano de Estudos por Data** | Tarefas agendadas por intervalo de datas | `GET /study/study-plan/get-by-date` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Registro de Descanso (Rest)** | Agendamento e pausa de descanso no planner | `POST /study/study-plan/rest` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Scheduler (Dias Letivos/Folga)** | Configuração de calendário, dia letivo e folga | `PUT /scheduler/v2/day-on` / `day-off` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Grade de Horários (Timetable)** | Horário semanal de aulas e sessões de estudo | `GET /timetable/timetables` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |

---

## 3. Módulos Diários, Estatísticas e Rankings

| Módulo / Funcionalidade | Descrição Técnica | Endpoint Princpal | Backend / Host | Status de Validação |
| :--- | :--- | :--- | :--- | :--- |
| **Log Diário de Estudo** | Histórico detalhado por matéria e fechamento | `GET /logs/day` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Histórico por Intervalo** | Histórico acumulado por período de dias | `POST /logs/range/days` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Ranking Global por Categoria** | Classificação de usuários por categoria e país | `GET /logs/category/member/ranks` | `picf.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Ranking Individual do Usuário** | Posição relativa do usuário na sua categoria | `GET /logs/my-category-rank` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Ranking do Grupo de Estudos** | Posição diária/semanal dos membros do grupo | `GET /logs/group/member/ranks` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Relatório de Frequência do Grupo** | Frequência e presença semanal dos membros | `GET /logs/v70701/group/attendances` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |

---

## 4. Módulos de Grupos, Comunidade e Mídia

| Módulo / Funcionalidade | Descrição Técnica | Endpoint Princpal | Backend / Host | Status de Validação |
| :--- | :--- | :--- | :--- | :--- |
| **Busca de Grupos de Estudo** | Listagem e filtros de grupos por categoria e país | `GET /group/list-new-2` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Detalhes e Entrada no Grupo** | Consulta de regras, membros e pedido de entrada | `GET /group/search-info/v2` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Membros Ativos no Grupo** | Status do cronômetro dos membros em tempo real | `GET /logs/group/members/v2` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Avisos e Alertas (Shake)** | Envio de chamadas e agitação de membros | `POST /group/push/shake` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Chat de Grupo & Histórico** | Mensagens de texto e filtro incremental | `GET /chat/group/messages` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Figurinhas / Stickers do Chat** | Conjuntos de figurinhas personalizadas do YPT | `GET /chat/sticker/sets` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Upload de Fotos do Chat** | Microserviço serverless para envio de imagens | `POST /file` | `alifn.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Desafios e Missões do Grupo** | Missões com metas diárias e taxa de inscrição | `GET /mission/challenges` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Publicações na Comunidade** | Posts e avisos na comunidade do grupo | `POST /group/legacy/post` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |

---

## 5. Personalização, Economia e Mídia de Foco

| Módulo / Funcionalidade | Descrição Técnica | Endpoint Princpal | Backend / Host | Status de Validação |
| :--- | :--- | :--- | :--- | :--- |
| **Catálogo de Studicons** | Avatares de personagens em pose normal/estudo/fogo | `GET /studicon/list/*` | `picf.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Meus Studicons Adquiridos** | Avatares pertencentes ao usuário | `GET /studicon/my/list` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **CDN de Imagens dos Studicons** | Servidor de imagens `.png` em 5 variações | `GET /sc.v2/{id}/*.png` | `alicdn.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Temas e Cores Visuais** | Temas escuro/claro e paletas de cor do app | `GET /theme/theme/my/` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Música & Ruído Branco** | Tocador de sons ambientais (chuva, café, fogueira) | `GET /music/ranks` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Playlists de Estudo** | Lista de faixas e registro de reprodução | `GET /playlist/musics` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Timelapses em Vídeo** | Vídeos gravados em acelerado dos estudos | `GET /timelapses` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |
| **Central de Notificações** | Mensagens de sistema, convites e lembretes | `GET /user/notifications` | `pi.tgclab.com` | **Validado ao Vivo (200 OK)** |

---

## Resumo dos Hosts e CDNs Utilizados

1. **`https://pi.tgclab.com`**: Processador de dados em tempo real e backend REST.
2. **`https://picf.tgclab.com`**: CDN para consultas públicas e leituras de alto tráfego.
3. **`https://alicdn.tgclab.com`**: CDN de assets gráficos e mídias estáticas.
4. **`https://alifn.tgclab.com`**: Endpoint de upload de arquivos serverless.
