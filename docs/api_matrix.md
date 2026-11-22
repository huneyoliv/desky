# Matriz de Módulos, Funcionalidades e Status da API YPT

Especificação dos módulos do aplicativo oficial e o status de cada contrato do lado do Desky.
O status distingue **validado ao vivo** (resposta real observada na conta de teste) de
**não confirmado** (rota existe, contrato desconhecido) e **bloqueado** (rota responde erro
que impede o uso).

> Última revisão de contratos: **2026-11-20**, em alterações pendentes. A versão do Desky permanece **1.2.1**; linhas marcadas com ⚠️ mudaram na 1.2.0.

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
| Iniciar estudo | `POST /study/start` | `pi.tgclab.com` | **Validado ao vivo** — o Desky envia `{subject, subject_id, deviceModel, taskId}`; `taskId` foi aceito, mas nenhuma associação à tarefa foi observada na resposta ou no log |
| Encerrar estudo | `POST /study/stop` | `pi.tgclab.com` | **Validado ao vivo** — o Desky envia `{subject, subject_id, startedAt, study_ms, deviceModel}` |
| Registrar pausa (WearOS) | `POST /rest/record` | `pi.tgclab.com` | ⚠️ **Divergente** — espera **`{tag}`**; o Desky envia timestamps e recebe **HTTP 500** |
| Pausa pelo planner | `POST /study/study-plan/rest` | `pi.tgclab.com` | ⚠️ **Recusado** — existe, mas devolve `s: false` com o payload do Desky; corpo real não recuperável (só Dart) |
| Tempo de cam study | `POST /study/cam-ms` | `pi.tgclab.com` | ⚠️ **Não confiável** — devolve `{s: true}` até com corpo vazio, portanto não valida nada |

**Consequência conhecida:** a pausa (estudo vs. descanso) não é utilizável — nenhuma das duas
rotas entrega o contrato, e `rs`/`as` em `/logs/day` nunca vieram populados.

## 3. Planner, tarefas e agenda

| Funcionalidade | Endpoint | Host | Status |
|---|---|---|---|
| **Tarefas de um dia** | `GET /study/study-plan/get-by-date` com `start_at`, `end_at`, `is_unscheduled` | `pi.tgclab.com` | ⚠️ **Validado ao vivo** — é o contrato real das tarefas do Planner; a lista vem em `r` |
| Conteúdo do planner | `GET /planner/stuff` | `pi.tgclab.com` | Não reconfirmado na 1.2.0 |
| Criar tarefa | `POST /study/study-plan/rest` | `pi.tgclab.com` | **Revalidado ao vivo em 2026-11-20** — `{title, subject_id, start_at, all_day, order, score, duration}`; matéria e objeto confirmados por releitura |
| Atualizar / concluir tarefa | `PUT /study/study-plan/rest` | `pi.tgclab.com` | **Revalidado ao vivo em 2026-11-20** — título e `subject_id` persistiram; `score: 1` conclui e `null` reabre |
| Excluir tarefa | `DELETE /study/study-plan/rest` | `pi.tgclab.com` | **Revalidado ao vivo em 2026-11-20** — exige corpo JSON `{id}`; query-only falhou. Uma ocorrência foi removida individualmente e `target:"all"` removeu a série restante, com zero itens ao final |
| Reordenar plano | `/study/study-plan/update-order` | `pi.tgclab.com` | Não confirmado |
| D-days (listar) | `GET /user/d-day/get` | `pi.tgclab.com` | **Validado ao vivo** — responde `{"s": true}` e **não expõe chave de lista** em nenhuma variação testada (`?date=`, `?year=`, `?all=1`, `?include_past=true`, `?id=`). `GET /planner/ddays` responde **404** |
| D-days (criar) | `POST /user/d-day/create` | `pi.tgclab.com` | **Validado ao vivo** — exige `title` **e** `date` (não `targetDate`); `{}`, `{title}` e `{title,targetDate}` devolvem HTML 500. Resposta: `{"s": true, "d": {id, tt, dt, st}}` |
| D-days (excluir) | `POST /user/d-day/delete` com `{id}` | `pi.tgclab.com` | **Validado ao vivo** — `200 {"s": true}`; o `DELETE /planner/dday/:id` do código antigo não existe |
| D-days (editar) | `POST /user/d-day/edit` | `pi.tgclab.com` | **Não confirmado** — `{}` devolve HTML 500 e as chaves obrigatórias são desconhecidas |
| Temas do planner | `GET /planner/themes` | `pi.tgclab.com` | **Validado ao vivo** |
| Grade de horários (listar) | `GET /timetable/timetables` | `pi.tgclab.com` | **Validado ao vivo** — a lista vem em `rt` (não `timetables`), com as chaves compactas `id, t, sd, ed, st, et, lw, scid` |
| Grade de horários (detalhe) | `GET /timetable/detail/v70630?id=<ttid>` | `pi.tgclab.com` | **Validado ao vivo** — devolve `{"s": true, "sb": []}` |
| Grade de horários (excluir bloco) | `DELETE /timetable/detail/v70630` com `{id}` no corpo | `pi.tgclab.com` | **Validado ao vivo** — `{"s": true}`; id inexistente devolve `{"s": false, "m": "already removed"}`. Enviar o id na query string produz HTML 500 |
| Grade de horários (criar bloco) | `POST /timetable/detail/v70630` | `pi.tgclab.com` | **Validado ao vivo em 2026-11-21** — `{ttid,t,lw,st,et,scid,sd,ed,c}`; `c` é a cor ARGB e `sd/ed` vêm do container. Resposta `s:true` com `rs`; bloco confirmado em `sb` e limpo pelo DELETE |
| Scheduler (dia letivo/folga) | `/scheduler/v2/day-on` e `day-off` | `pi.tgclab.com` | **Validado ao vivo** |
| ⚠️ To-do do calendário | `GET /logs/calendar/todos?startDate&endDate` | `pi.tgclab.com` | **Validado, mas vazio** — aceita só camelCase; nunca devolveu um elemento |
| ⚠️ Resumo do calendário | `GET /logs/calendar/home?startDate&endDate` | `pi.tgclab.com` | **Validado ao vivo** — devolve `{ds, ss, ts}` |
| ⚠️ Criar tarefa (legado) | `POST /study/task/make` | `pi.tgclab.com` | **Quebrado** — página HTML de erro 500 para todo método e payload testado (13 combinações) |
| ⚠️ Estatísticas de tarefas | `/study/todo/statistics/main` | `pi.tgclab.com` | **404 em GET** |

**Consequência conhecida:** as tarefas do Planner usam o contrato
`/study/study-plan/*`, e **não** `/logs/calendar/todos` nem `/study/task/make`. A edição segue
limitada à ocorrência. A exclusão oferece ocorrência (padrão) ou série inteira após nova prova
live de `target:"all"` com releitura e limpeza; `applyToAll` permanece fora da UI.
O HAR `firestore.googleapis.com_2026_11_19_21_18_13.har` contém apenas `Listen` e
`RunAggregationQuery` sobre `userbooks`; ele não documenta as escritas REST de To-Do
nem a criação/edição de grupos. A ação de iniciar estudo pela tarefa envia `taskId`,
mas a associação persistente dessa sessão à tarefa **não foi comprovada**.

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
| Busca de grupos | `GET /group/list-new-2` | `pi.tgclab.com` | **Validado ao vivo** — honra `country_id`; a listagem e a pesquisa textual do Desky propagam o país selecionado |
| Detalhes / entrada | `GET /group/search-info/v2` | `pi.tgclab.com` | **Validado ao vivo** |
| Membros do grupo | `GET /logs/group/members/v2` | `pi.tgclab.com` | **Validado ao vivo** — `dl.is`, `dl.st`, `dl.sp` em UTC; **sem campo de fuso por membro** |
| Chat — ler | `GET /chat/group/messages?group_id=` | `pi.tgclab.com` | **Validado ao vivo** |
| Chat — enviar | `POST /chat/group/message` | `pi.tgclab.com` | **Validado ao vivo** — `{group_id, message}` |
| Figurinhas | `GET /chat/sticker/sets` | `pi.tgclab.com` | **Validado ao vivo** |
| Editar configurações do grupo | `POST /group/info/edit` | `pi.tgclab.com` | **Nome validado ao vivo** — `{id, title}` alterou e restaurou; `t`, `n` e `name` foram aceitos sem efeito. Demais campos não foram comprovados; `s:true` não basta |
| Validar nome do grupo | `POST /group/make/title/validate` | `pi.tgclab.com` | **Validado ao vivo** — `{title}` |
| **Criar grupo** | `POST /group/make/v2` | `pi.tgclab.com` | ⚠️ **Bloqueado** — `title` e `goalTime` confirmados; sondagens anteriores não criaram grupo. O HAR de 2026-11-19 **não contém esta rota** e o APK só comprova o literal, não o payload completo |
| ⚠️ Desafios de grupo | `/group/challenge/list`, `/detail`, `/make` | `pi.tgclab.com` | **Rotas existem no APK**; o 404 anterior era parâmetro errado, não rota ausente |
| Cutucar (nudge) — enviar | `POST /group/push/shake` | `pi.tgclab.com` | **Validado ao vivo** |
| Cutucar — receber | — | — | ⚠️ **Não implementado** — as notificações REST conhecidas não têm tipo de cutucada; o app oficial usa push FCM e o Desky não possui esse canal |
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