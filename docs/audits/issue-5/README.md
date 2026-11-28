# Issue #5 — auditoria de grupos, nudges e sincronização

**Base:** `ab2d56e9bc49a7d0c7c730bd5d529888ec21f132` (`main` em 2026-11-28)
**Issue:** <https://github.com/huneyoliv/desky/issues/5>
**Método:** inspeção da main, engenharia reversa estritamente estática e testes locais com fakes/adapters. Nenhuma conta, credencial de YPT ou escrita em produção foi usada.

## Entregas e conclusões

| Frente | Resultado | Evidência |
|---|---|---|
| Criação de grupos | APK/XAPK identificado por versão/package/hash; rota com xref ARM64/closure e parser de notificações parcialmente recuperados. Nenhum payload foi incorporado ao cliente: método, campos, encoding, headers e respostas de criação permanecem sem contrato completo. | [Engenharia reversa do APK](group-creation-reverse-engineering.md) |
| Recepção de nudges | Não foi encontrado discriminador estrutural suficiente em `/user/notifications`. Alertas, classificação e dedupe de nudges **não foram implementados** com base em títulos, idioma ou fixtures sintéticas. | [Recepção de nudges](nudge-reception.md) |
| Polling do sino | Uma instância não sobrepõe leituras quando um tick anterior continua pendente. Timer, refresh explícito trailing e resposta tardia após dispose têm testes de ciclo de vida. | `notification_bell.dart` e `notification_bell_polling_test.dart` |
| Tempo real e fuso | Contadores locais existem; agregados continuam snapshots/polls. Reset por fuso de cada membro não é verificável no cliente sem contrato/backend. | [Sincronização](synchronization-audit.md) |
| Adoção/pausa/stop | A main tem um caminho local de reenvio após segundo stop/exit e um caminho de respostas fora de ordem. Duplicação persistida no servidor não foi afirmada nem testada. | [Sincronização](synchronization-audit.md) |

Não foram reabertos Stats i18n, calendário, temas, To-Do unificado, sidebar, contraste ou rotas de grupos já tratados. O PR #29 não foi importado nem usado como solução.

## Alterações de código

- `lib/features/notifications/widgets/notification_bell.dart`: impede overlap por instância, restringe o `catch` ao acesso/fetch do repositório, mantém `setState` protegido por `mounted` e coalesce somente o refresh explícito de fechamento do painel durante outro fetch.
- `test/features/notifications/notification_bell_polling_test.dart`: cobre ticks sem overlap, dispose sem exceção tardia e exatamente um trailing após fechar o painel real durante fetch pendente. Uma mutação temporária sem `mounted` também falhou como esperado, confirmando a sensibilidade do teste de dispose.

Não há nova dependência, FCM, notificação nativa do SO, entrega com o app fechado, detector de nudge ou implementação de criação de grupo.

## Validação integrada

Ambiente: Flutter **3.47.9**, Dart **3.13.7**, Windows. SDK, worktree e `PUB_CACHE` foram expostos por caminhos sem espaços porque o hook nativo `objective_c` falhou antes dos testes quando recebeu caminhos com espaços. A primeira falha foi de ambiente, não uma falha de teste.

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed `
  lib/features/notifications/widgets/notification_bell.dart `
  test/features/notifications/notification_bell_polling_test.dart
flutter analyze --no-pub
flutter test --no-pub <15 arquivos focados>
```

Arquivos de teste:

```text
test/features/notifications/notification_api_contract_test.dart
test/features/notifications/notification_repository_test.dart
test/features/notifications/notifications_notifier_test.dart
test/features/notifications/notifications_screen_test.dart
test/features/notifications/notification_bell_polling_test.dart
test/unit/notification_bell_test.dart
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

Resultados reais da execução integrada:

- `pub get`: exit 0;
- formatação: `Formatted 2 files (0 changed)`;
- analyzer: `No issues found!`, exit 0;
- testes: **91/91 aprovados**, `All tests passed!`, exit 0;
- os 91 testes compreendem 25 de notificações e 66 de grupos/sincronização.

Em uma execução separada da baseline, o teste temporário de segundo stop falhou com `Expected: <1>` e `Actual: <2>`, reproduzindo o reenvio local. Esse teste intencionalmente regressivo não integra os 91 testes aprovados nem o PR.

Os testes usam implementações controladas localmente. Eles **não** provam contrato de produção, classificação de nudge, idempotência do backend, reset por fuso de cada membro ou correção dos dois novos achados de sincronização.

## Evidência, teste e hipótese

- **Inspeção estática:** arquivo/linha da main, strings com SHA-256 e offsets de arquivo no binário.
- **Teste real:** somente os comandos e resultados acima e os testes adicionais referenciados nos relatórios.
- **Hipótese/limitação:** campos sem call site, regex sem consumidor, comportamento do servidor sem ensaio autorizado e ausência de payload real de nudge.

Strings vizinhas em `.rodata` não foram interpretadas como relação de fluxo. Reenvio local não foi apresentado como duplicação persistida. Ausência de uma string não foi apresentada como prova de ausência semântica.

## Limitações restantes

1. O contrato completo de criação de grupos exige recuperar o builder do request e o parser da resposta, ou uma captura controlada/autorizada; o relatório registra os xrefs recuperados e as lacunas restantes.
2. Nudges por polling exigem um item real sanitizado ou fluxo estático que ligue tipo/campos estáveis ao endpoint; sem isso não há classificação/dedupe legítimos.
3. O segundo stop/exit e respostas fora de ordem precisam de correções isoladas com testes de regressão próprios.
4. Idempotência de `/study/stop` e reset diário por membro exigem validação de backend autorizada; nenhuma foi realizada.
5. Binários, ferramentas, logs de crash e artefatos de reversing permanecem fora do commit.
