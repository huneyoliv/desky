# Issue #5 — auditoria de sincronização de estudo

Data: 2026-11-28
Base inspecionada: `ab2d56e9bc49a7d0c7c730bd5d529888ec21f132`
Escopo: somente os três relatos de sincronização. O PR #29 não foi usado como implementação ou como evidência.

## Resultado executivo

| Comportamento | Classificação na main |
|---|---|
| Timer local e contador de membro ativo | Implementação presente; usa relógio/delta, não apenas incrementos de um segundo |
| Totais agregados e estatísticas históricas em “tempo real” | Atualização por carregamento/polling, não streaming; não se pode prometer tempo real integral |
| Respostas de membros/ranking fora de ordem | **Bug local confirmado por inspeção**: resposta antiga pode sobrescrever uma mais nova |
| Reset diário do próprio usuário | Implementado com offset GMT do país e hora de reset |
| Reset diário no fuso de cada membro | **Não verificável sem contrato/backend**; o cliente não calcula o dia individual dos outros membros |
| Adoção, pausa e reconciliação normal | Há serialização e delta sincronizado; testes existentes cobrem os fluxos principais |
| Segundo stop ou saída após stop | **Reenvio local reproduzido em teste**: horário inicial antigo provoca nova submissão no segundo stop |
| Duplicação efetivamente persistida no servidor | **Não verificável sem backend/idempotência**; reenvio do cliente não prova contagem persistida em dobro |

Nenhum backend, conta, token ou dado de produção foi usado. Esta etapa foi de auditoria; não altera o timer nem o fluxo de grupos. As correções devem ser separadas e cobertas por regressões específicas, em vez de importar o escopo recusado do PR #29.

## 1. Tempo de estudo em tempo real

### Evidência de inspeção

- O timer local calcula delta de relógio em `timer_notifier.dart:614-676`, e `TimerScreen` observa o estado em `timer_screen.dart:49-60` e `111-116`.
- `GroupMemberModel` lê o total de `dl.sm`/`dl.tp` e o início de sessão de `dl.st` em `group_member_model.dart:44-95`.
- `member_live_timer.dart:45-46` e `64-90` limita o ticker local a membro estudando, não pausado e com timestamp válido. O ticker não faz requests e para em pausa/dispose.
- Os agregados de grupo continuam snapshots de `studyMs` atualizados por polls de 30 segundos em `group_detail_screen.dart:172-180`, `249-255` e `459-477`.
- `RanksScreen` carrega dados no init e em ações, sem assinatura do timer ou poll equivalente (`ranks_screen.dart:67-87` e `89-143`).

**Conclusão:** o contador local de atividade existe e não depende só de parar o timer. Não há evidência para chamar todos os agregados/históricos de “tempo real”; isso é uma limitação de atualização/contrato, não um erro de parsing demonstrado.

### Bug de ordenação confirmado por inspeção

`_loadMembersSilently` permite chamadas concorrentes e aplica qualquer resposta que chegar por último (`group_detail_screen.dart:249-255`). Uma resposta antiga, concluída depois de uma mais nova, pode substituir o estado recente. `_loadGroupRanksSilently` tem o mesmo padrão em `233-247`, e as trocas de período o reutilizam em `763-765` e `775-777`.

Não existe teste de ordem de respostas no conjunto inspecionado. A correção mínima recomendada é associar geração/request ID e período solicitado ao resultado, descartando respostas obsoletas. Isso requer teste com completers fora de ordem; não foi alterado nesta auditoria.

## 2. Reset diário e fuso de cada membro

### Próprio usuário — implementação presente

- `StudyDayHelper.studyDateYmd` converte o instante para UTC, aplica o offset GMT e a hora de reset (`study_day_helper.dart:54-65`).
- O timer verifica rollover a cada dez segundos (`timer_notifier.dart:195-207` e `442-458`) e passa a regra efetiva ao carregar `/logs/day` (`278-286`; `timer_repository.dart:118-137`).
- O offset vem do país selecionado (`timer_notifier.dart:1051-1075`).

O contrato local documenta **offset fixo do registro de países**, sem transições DST (`study_day_helper.dart:3-12`). Exigir timezone IANA/DST seria mudança de contrato, não bug provado por estes relatos.

### Outros membros — não verificável localmente

O modelo consome `sm`/`tp`, flags e início da sessão; não possui fuso nem study date individual de cada membro (`group_member_model.dart:4-33` e `44-101`). O cliente não executa o reset diário dos outros membros. A nota em `docs/api_matrix.md:92` registra ausência observada de fuso na resposta conhecida, mas não prova uma garantia universal sobre todos os payloads.

O ranking diário calcula uma data do observador em `group_repository.dart:56-80`. Isso não demonstra como o servidor fecha o dia de cada membro.

**Conclusão:** validar o relato exige ensaio de contrato/backend com membros em offsets distintos, antes e depois do reset de cada um. Não se deve inventar ou aplicar o fuso do observador a todos os membros.

## 3. Adoção, pausa, restauração e possível duplicidade

### Fluxos principais cobertos

- A reconciliação é serializada e um `delayed is:false` não derruba uma sessão ainda não confirmada (`timer_notifier.dart:278-320`).
- A adoção ocorre sem novo `/study/start` quando o servidor está ativo e o cliente parado (`294-345`).
- Pause/stop usa `sessionElapsedMs-lastSyncedSessionElapsedMs` e marca o delta após sucesso ou enqueue (`789-847` e `853-903`).
- A restauração recria elapsed a partir do snapshot e limita snapshots a 24 horas (`timer_session_store.dart:57-75`; `timer_notifier.dart:211-253`).

Os testes existentes indicados ao final cobrem adoção, restauração, pausa e delta. Eles não cobrem o segundo stop descrito abaixo.

### Bug local reproduzido: estado inicial não é limpo

`TimerState.copyWith` recebe `DateTime? sessionStartAt` e `restStartAt`, mas atribui `sessionStartAt ?? this.sessionStartAt` e `restStartAt ?? this.restStartAt` (`timer_notifier.dart:90-102` e `127-128`). Portanto, passar `null` em `stopStudy` (`891-901`) não limpa os valores anteriores.

Fluxo confirmado por inspeção:

1. O primeiro stop sincroniza e zera elapsed/lastSynced, mas conserva o antigo `sessionStartAt`.
2. Um segundo stop satisfaz `sessionStartAt != null && !isPaused` (`876-883`).
3. Como elapsed é zero e o início antigo continua presente, `_syncCompletedFocusSession` recalcula `now-startAt` (`789-807`).
4. Com disciplina presente, isso pode chamar novamente `/study/stop` com uma duração recalculada.
5. A saída também considera `sessionStartAt != null` como sessão ativa (`main.dart:290-307`), tornando o caminho alcançável após um stop manual.

**Reprodução dinâmica na baseline:** um teste temporário, mantido fora do PR no worktree detached, executou `startStudy → stopStudy → stopStudy` com repositórios fake. A asserção de comportamento correto esperava uma chamada total a `stopStudy`, mas obteve **2** (`Expected: <1>`, `Actual: <2>`, linha 91 do teste). O comando foi `flutter test --no-pub test/features/timer/timer_second_stop_regression_test.dart`; o resultado foi **exit 1**, reproduzindo a regressão. Esse teste não faz parte da suíte aprovada do PR nem usa backend.

**O que está provado:** o cliente reenvia indevidamente no segundo stop. **O que não está provado:** que o servidor some duas vezes; pode haver deduplicação por `startedAt` ou outra regra desconhecida. O caminho de exit após stop foi identificado por inspeção, mas não exercitado separadamente.

A correção recomendada deve permitir limpar explicitamente esses campos e impedir stop quando não houver sessão running/paused ou delta pendente. Regressões necessárias: segundo stop e exit após stop devem produzir zero novas chamadas. Nenhuma dessas regressões existia na main inspecionada.

### Timeout e retry — limitação de idempotência

Após timeout de stop, o cliente enfileira a mesma fatia (`timer_notifier.dart:801-845`). O retry reenvia `startedAt` e `study_ms` (`offline_sync_repository.dart:79-119`), mas o ID local não entra no payload de `/study/stop` (`timer_repository.dart:34-56`).

Se a primeira escrita foi aceita e somente a resposta se perdeu, apenas deduplicação do servidor evita dobro. Sem ensaio autorizado de backend/idempotência, não se pode afirmar duplicação persistida nem garantir sua ausência.

## 4. Testes reais da auditoria

A frente de sincronização executou os arquivos abaixo na mesma revisão, com `flutter test --no-pub` e mapeamento de unidade sem espaços. Resultado relatado pela execução: **exit 0**.

```text
test/features/groups/member_live_timer_test.dart
test/unit/group_models_test.dart
test/features/groups/lifecycle_poll_coordinator_test.dart
test/features/timer/timer_session_resync_test.dart
test/features/timer/timer_break_and_reset_test.dart
test/unit/timer_day_reset_test.dart
test/unit/timer_daily_log_study_day_test.dart
test/unit/study_day_helper_test.dart
test/unit/offline_sync_test.dart
```

Casos diretamente relevantes: adoção em `timer_session_resync_test.dart:140-172`, restauração em `99-138`, e pausa/delta em `timer_break_and_reset_test.dart:81-106` e `133-188`.

**Cobertura dos novos achados:** o segundo stop foi reproduzido dinamicamente pelo teste temporário descrito acima, que falhou com 2 chamadas na baseline. Não havia teste de respostas fora de ordem na main; esse comportamento permanece confirmado somente por inspeção. O exit após stop também não foi exercitado separadamente.

## 5. Limitações e próximos passos

1. Corrigir o estado de stop em mudança isolada, com regressões de segundo stop e exit.
2. Corrigir ordenação de respostas em mudança isolada, com completers fora de ordem e troca de período.
3. Validar em ambiente autorizado se `/study/stop` é idempotente para o mesmo `startedAt`/sessão; não criar dados reais nesta auditoria.
4. Obter contrato de study day por membro antes de alterar reset/fuso de grupo.
5. Não classificar polling de 30 segundos como entrega em tempo real nem como prova de atraso no servidor.
