# Matriz de Módulos, Funcionalidades e Status da API YPT

Especificação dos módulos do aplicativo oficial e o status de cada contrato do lado do Desky.
O status distingue **validado ao vivo** (resposta real observada na conta de teste) de
**não confirmado** (rota existe, contrato desconhecido) e **bloqueado** (rota responde erro
que impede o uso).

> Última revisão: **1.2.0** (2026-11-19). As linhas marcadas com ⚠️ mudaram nesta versão.

---

## 1. Sessão e autenticação

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| Login por e-mail/senha (JWT) | `POST /user/sign-in-jwt` | `pi.tgclab.com` | **Validado ao vivo** |
| Login social (Google/Apple) | `POST /user/sign-in-jwt` com `loginProvider` | `pi.tgclab.com` | **Validado ao vivo** |
| Splash / inicialização | `POST /user/v2/splash-login` | `pi.tgclab.com` | **Validado ao vivo** |
| Recarga de estado | `POST /user/v2/reload/info` | `pi.tgclab.com` | **Validado ao vivo** |
| Matérias | `/user/subject/*` | `pi.tgclab.com` | **Validado ao vivo** |
| Sincronização de relógio | `GET /time/` | `pi.tgclab.com` | **Validado ao vivo** |

## 2. Cronômetro e sessão de estudo

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| Iniciar estudo | `POST /study/start` | `pi.tgclab.com` | **Validado ao vivo** — corpo real do app: `{subject, deviceModel}`; devolve `st` e **`sp`** |
| Encerrar estudo | `POST /study/stop` | `pi.tgclab.com` | **Validado ao vivo** — o **Desky envia campos extras** (`subject_id`, `startedAt`, `study_ms`, `taskId`); o servidor tolera |
| Registrar pausa (WearOS) | `POST /rest/record` | `pi.tgclab.com` | ⚠️ **Divergente** — espera **`{tag}`**; o Desky envia timestamps e recebe **HTTP 500** |
| Pausa pelo planner | `POST /study/study-plan/rest` | `pi.tgclab.com` | ⚠️ **Recusado** — existe, mas devolve `s: false` com o payload do Desky; corpo real não recuperável (só Dart) |
| Tempo de cam study | `POST /study/cam-ms` | `pi.tgclab.com` | ⚠️ **Não confiável** — devolve `{s: true}` até com corpo vazio, portanto não valida nada |

**Consequência conhecida:** a pausa (estudo vs. descanso) não é utilizável — nenhuma das duas
rotas entrega o contrato, e `rs`/`as` em `/logs/day` nunca vieram populados.

## 3. Planner, tarefas e agenda

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| **Tarefas de um dia** | `GET /study/study-plan/get-by-date` com `start_at`, `end_at`, `is_unscheduled` | `pi.tgclab.com` | ⚠️ **Validado ao vivo** — é o contrato real do To-Do; a lista vem em `r` |
| Conteúdo do planner | `GET /planner/stuff` | `pi.tgclab.com` | Não reconfirmado na 1.2.0 |
| Criar tarefa | `POST /study/study-plan/rest` | `pi.tgclab.com` | **Validado ao vivo** — `{title, subject_id, start_at, all_day, order, score, duration}` |
| Atualizar / concluir tarefa | `PUT /study/study-plan/rest` | `pi.tgclab.com` | **Validado ao vivo** — `score: 1` marca concluída, `null` desmarca |
| Excluir tarefa | `DELETE /study/study-plan/rest?id=` (ou `&target=all`) | `pi.tgclab.com` | **Validado ao vivo** |
| Reordenar plano | `/study/study-plan/update-order` | `pi.tgclab.com` | Não confirmado |
| D-days | `GET /planner/ddays` | `pi.tgclab.com` | **Validado ao vivo** |
| Temas do planner | `GET /planner/themes` | `pi.tgclab.com` | **Validado ao vivo** |
| Grade de horários | `GET /timetable/timetables` | `pi.tgclab.com` | **Validado ao vivo** |
| Scheduler (dia letivo/folga) | `/scheduler/v2/day-on` e `day-off` | `pi.tgclab.com` | **Validado ao vivo** |
| ⚠️ To-do do calendário | `GET /logs/calendar/todos?startDate&endDate` | `pi.tgclab.com` | **Validado, mas vazio** — aceita só camelCase; nunca devolveu um elemento |
| ⚠️ Resumo do calendário | `GET /logs/calendar/home?startDate&endDate` | `pi.tgclab.com` | **Validado ao vivo** — devolve `{ds, ss, ts}` |
| ⚠️ Criar tarefa (legado) | `POST /study/task/make` | `pi.tgclab.com` | **Quebrado** — página HTML de erro 500 para todo método e payload testado (13 combinações) |
| ⚠️ Estatísticas de tarefas | `/study/todo/statistics/main` | `pi.tgclab.com` | **404 em GET** |

**Consequência conhecida:** a seção To-Do do Desky usa o contrato do planner
(`/study/study-plan/*`), e **não** `/logs/calendar/todos` nem `/study/task/make`.

## 4. Logs, estatísticas e rankings

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| Log do dia | `GET /logs/day?date=` | `pi.tgclab.com` | **Validado ao vivo** — `dl` com `is`, `st`, `sp`, `ls[]` |
| Histórico por intervalo | `POST /logs/range/days` | `pi.tgclab.com` | **Validado ao vivo** — `{id, isMember, startDate, endDate}` |
| Ranking por categoria | `GET /logs/category/member/ranks` | `picf.tgclab.com` | **Validado ao vivo** |
| Ranking do usuário | `GET /logs/my-category-rank` | `pi.tgclab.com` | **Validado ao vivo** |
| Ranking do grupo | `GET /logs/group/member/ranks` | `pi.tgclab.com` | **Validado ao vivo** |
| Frequência do grupo | `GET /logs/v70701/group/attendances` | `pi.tgclab.com` | **Validado ao vivo** |
| Fechamento do dia | `/logs/day/closing-log(s)` | `pi.tgclab.com` | Não confirmado |

⚠️ **Limites medidos:** a conta de teste tem **10 dias** de histórico (o mais antigo em
2026-04-19), então o limite de três anos do catálogo **não pôde ser verificado**. O horário
`st` chega **sempre em UTC** e o dia (`dt`) é o **dia local** do usuário (17/17 sessões).

## 5. Grupos e comunidade

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| Busca de grupos | `GET /group/list-new-2` | `pi.tgclab.com` | **Validado ao vivo** — honra `country_id` |
| Detalhes / entrada | `GET /group/search-info/v2` | `pi.tgclab.com` | **Validado ao vivo** |
| Membros do grupo | `GET /logs/group/members/v2` | `pi.tgclab.com` | **Validado ao vivo** — `dl.is`, `dl.st`, `dl.sp` em UTC; **sem campo de fuso por membro** |
| Chat — ler | `GET /chat/group/messages?group_id=` | `pi.tgclab.com` | **Validado ao vivo** |
| Chat — enviar | `POST /chat/group/message` | `pi.tgclab.com` | **Validado ao vivo** — `{group_id, message}` |
| Figurinhas | `GET /chat/sticker/sets` | `pi.tgclab.com` | **Validado ao vivo** |
| Editar configurações do grupo | `POST /group/info/edit` | `pi.tgclab.com` | **Validado ao vivo** — chave `id`, edição parcial |
| Validar nome do grupo | `POST /group/make/title/validate` | `pi.tgclab.com` | **Validado ao vivo** — `{title}` |
| **Criar grupo** | `POST /group/make/v2` | `pi.tgclab.com` | ⚠️ **Bloqueado** — `title` e `goalTime` confirmados; o servidor responde erro genérico e **não cria** (~380 sondagens) |
| ⚠️ Desafios de grupo | `/group/challenge/list`, `/detail`, `/make` | `pi.tgclab.com` | **Rotas existem no APK**; o 404 anterior era parâmetro errado, não rota ausente |
| Cutucar (nudge) — enviar | `POST /group/push/shake` | `pi.tgclab.com` | **Validado ao vivo** |
| Cutucar — receber | — | — | ⚠️ **Impossível no desktop** — não existe tipo de notificação para cutucada; o app oficial usa push FCM |
| Publicações | `POST /group/legacy/post` | `pi.tgclab.com` | **Validado ao vivo** |

## 6. Missões e desafios de estudo

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| Listar desafios | `GET /mission/challenges` | `pi.tgclab.com` | **Validado** — a lista vem em **`rs`** (nunca em `challenges`/`c`) |
| Meus desafios | `GET /mission/challenge/users` | `pi.tgclab.com` | **Validado ao vivo** |
| Participar / cancelar | — | — | ⚠️ **Não existem** — nem no APK (20 rotas de missão, nenhuma com `join`/`cancel`), nem na API (`/join`, `/cancel`, `/my` = 404) |
| Ranking de desafio | `/mission/challenge/ranking/{daily,weekly,monthly}-logs` | `pi.tgclab.com` | Existe, exige `challengeID` |
| Logs de desafio | `/mission/challenge/user/logs`, `/user/rest` | `pi.tgclab.com` | **Validado ao vivo** |

**Consequência conhecida:** a aba de Desafios do Desky é **somente leitura**. O schema de
elemento de `rs` nunca foi observado (nenhum desafio disponível na conta).

## 7. Mídia, loja e personalização

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| Catálogo de studicons | `GET /studicon/list/*` | `picf.tgclab.com` | **Validado ao vivo** |
| Studicons do usuário | `GET /studicon/my/list` | `pi.tgclab.com` | **Validado ao vivo** |
| CDN de imagens | `GET /sc.v2/{id}/*.png` | `alicdn.tgclab.com` | **Validado ao vivo** |
| Temas | `GET /theme/theme/my/` | `pi.tgclab.com` | **Validado ao vivo** |
| Música / ruído branco | `GET /music/ranks` | `pi.tgclab.com` | **Validado ao vivo** |
| Playlists | `GET /playlist/musics` | `pi.tgclab.com` | **Validado ao vivo** |
| Timelapses | `GET /timelapses` | `pi.tgclab.com` | **Validado ao vivo** — recurso **removido do Desky** na 1.2.0 |
| ⚠️ **Upload de arquivos** | `POST /file` | `alifn.tgclab.com` e `file.tgclab.com` | ⚠️ Os dois hosts existem; em `file.tgclab.com` um GET devolve **405**, portanto é POST-only. É o serviço de upload; a rota que liga o upload ao cam study **não foi identificada** |
| ⚠️ Foto de cam study | `GET /cam/{data}/{userId}` | `alicdn.tgclab.com` | Leitura validada (o Desky removiu o recurso na 1.2.0) |

## 8. Notificações

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| Listar notificações | `GET /user/notifications?page=` | `pi.tgclab.com` | **Validado ao vivo** — lista em `ns[]` (`id`, `i1`..`i4`, `c`, `ir`, `nt`) |
| Marcar como lida | `POST /user/read-notice` | `pi.tgclab.com` | **Validado ao vivo** — `{noticeID}`; **sem rota em lote** e sem rota de exclusão |
| Não lidas (comunidade) | `GET /community/notifications/unread-count` | `pi.tgclab.com` | **Validado ao vivo** — campo `unreadNotificationCount` |
| Registrar push (FCM) | `POST /user/push-token` | `pi.tgclab.com` | **Fora de escopo** — push é do app móvel |

**Códigos de `nt` conhecidos:** `GROUP_WARNING`, `GROUP_JOIN_APPROVED`, entre outros, sempre em
maiúsculas. **Não existe tipo de cutucada.**

---

## Hosts

| Host | Papel |
|---|---|
| `https://pi.tgclab.com` | API REST principal (a mesma usada pelo app oficial) |
| `https://picf.tgclab.com` | CDN de metadados e consultas de alto tráfego |
| `https://alicdn.tgclab.com` | CDN de imagens, áudio e capturas de câmera |
| `https://file.tgclab.com/file` | Upload de arquivos (POST-only) |
| `https://pi.pallo.cn` | Variante do app para a China (`/ai/any`, `/health`) |

---

## Ver também

- `apk_route_matrix.md` (fora do repositório, em `.desky_apk_work/`) — as 694 rotas extraídas do
  `libapp.so`, com a camada de cada uma (DEX/Retrofit ou só Dart).
- `CHANGELOG.md` — seção *Known Limitations* da versão vigente, que registra o que a API não
  entrega e por isso não foi implementado.