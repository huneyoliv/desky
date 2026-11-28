# Issue #5 — auditoria de recepção local de nudges

Data: 2026-11-28
Base: `ab2d56e9bc49a7d0c7c730bd5d529888ec21f132`
Escopo: recepção por polling de `GET /user/notifications`, somente dentro do app.

## Resultado

**A recepção de nudges por polling não foi implementada.** Até o momento da auditoria,
não há um payload recebido nem um mapeamento estático reproduzível que identifique um
nudge nesse endpoint. Implementar um discriminador por título, idioma, `SHAKE`, `WAKE`
ou `NUDGE` seria uma hipótese apresentada como contrato.

Foi feita somente uma melhoria genérica no polling já existente: uma instância de
`NotificationBell` não inicia outra leitura de não lidas enquanto a anterior estiver
pendente. O timer continua sendo um por instância, cancelado em `dispose`, e respostas
tardias continuam protegidas por `mounted`.

Não foram adicionados FCM, canal nativo, notificação do sistema operacional ou suporte
com o app fechado. Nenhuma conta ou API de produção foi usada nesta auditoria.

## O que o código faz hoje — evidência de inspeção

- `notification_repository.dart` consulta
  `/user/notifications?page=$page&is_new=$isNew`, lê `ns` (com fallbacks legados),
  converte cada item com `NotificationModel.fromJson` e remove IDs deletados
  localmente.
- `notification_model.dart` conserva `nt` em `type`, usa `id` como inteiro, `ir` como
  flag de leitura e `c` como data. `i1`, `i2` e `i3` alimentam título/mensagem conforme
  os campos preenchidos. Não existe classificação de nudge no modelo.
- `normalizedType` normaliza códigos de grupo conhecidos; os ramos visuais de
  `notifications_screen.dart` que procuram `SHAKE`/`WAKE`/`NUDGE` em `type` não provam
  que o servidor emita esses valores e não disparam alerta local.
- `NotificationBell` chama somente `fetchUnreadCount()` a cada 30 segundos. Esse método
  retorna um inteiro e descarta os modelos; portanto o polling atual não oferece itens
  para classificação, detecção de novos IDs ou alerta.
- `NotificationsNotifier` carrega a lista sob demanda, mas não possui timer nem
  mecanismo de deduplicação.
- `NotificationBell` aparece nos layouts sidebar e classic. Cada instância montada cria
  um timer e o cancela em `dispose`; a proteção adicionada cobre sobreposição de ticks
  dentro de uma mesma instância, não um coordenador global entre instâncias.

## Evidências de payload e fixtures

### Exemplos capturados já versionados (não são uma aquisição nova)

`docs/openapi.yaml`, no exemplo de `GET /user/notifications`, contém quatro itens de
`ns[]`: dois `GROUP_OUT`, um `GROUP_WARNING` e um `GROUP_JOIN_APPROVED`. Todos possuem
`id`, `i1`..`i4`, `c`, `ir` e `nt`. Nenhum é identificado como nudge.

`docs/api_endpoints.md` registra que, na amostra histórica de seis itens, `i1` era o
campo preenchido em todos e `i2`/`i3` estavam vazios; também registra que
`is_new=true` não filtrou a resposta. Assim, nem `is_new=true` nem `ir=false` bastam
para inferir que um item acabou de chegar.

### Fixtures e testes

- `_notice()` em `notification_api_contract_test.dart` reproduz o schema conhecido,
  mas não contém um nudge recebido. Os comentários e expects sobre a ausência de
  `shake` repetem a conclusão histórica; não são evidência independente do binário.
- `notification_repository_test.dart` contém um item legado com `type: 'shake'` e texto
  português. Esse mapa foi construído pelo próprio teste, não capturado da API, e não
  pode fundamentar classificação.
- `docs/api_endpoints.md` atribui uma lista de códigos `nt` ao binário oficial e afirma
  que nudge usa push. A verificação independente posterior de `apk-re` recuperou strings
  e offsets, mas não o parser nem call sites; portanto ela não transforma essa afirmação
  histórica em um fluxo comprovado de FCM ou de persistência REST.
- `ct: WAKEUP` encontrado no OpenAPI pertence a desafios de estudo/despertar, não a um
  item de `ns[]`, e não foi usado como sinônimo de nudge.

### Hipóteses explicitamente rejeitadas

- procurar “cutucada”, “nudge”, “shake” ou equivalentes em `i1`/título;
- inferir tipo por idioma ou pelo conteúdo de `i2`/`i3`;
- transformar o fixture sintético `type: 'shake'` em contrato;
- tratar `ct: WAKEUP` de desafios como `nt` de notificação;
- interpretar `is_new=true` como uma lista incremental;
- presumir que um push FCM também persista um item em `/user/notifications`.

## Bloqueio para uma implementação confiável

Para viabilizar polling são necessários, no mínimo:

1. um item real sanitizado de `ns[]` correspondente a um nudge, ou evidência estática
   reproduzível que ligue um valor estrutural exato de `nt` a esse endpoint;
2. o significado de `i1`, `i2`, `i3` e `c` para esse tipo, sem depender de texto localizado;
3. confirmação de que `id` é presente, não zero e estável entre polls;
4. uma regra de baseline para não alertar todo o histórico na primeira execução.

Sem os itens 1–3 não é possível escrever testes legítimos de tipo, item novo e
duplicata: os testes apenas validariam um JSON inventado. Por esse motivo não foram
criados detector, armazenamento de IDs vistos ou alertas de nudge.

A coordenação com o agente `apk-re` foi registrada por `send_message`; foram solicitados
valores exatos, call sites e offsets/recortes reproduzíveis, inclusive para distinguir
handler FCM de persistência REST.

### Resultado estático parcial de `apk-re`

O relatório `group-creation-reverse-engineering.md`, seções 4, 6 e 7, foi inspecionado e
registra o APK `810.1.26` e o `libapp.so` SHA-256
`b830e7ae060f97b9e52175f1aeb84b705a78186748f821b88c4615b01cfe1a9f`. Os offsets abaixo
são offsets de arquivo informados pelo agente, não endereços virtuais ou call sites:

| Literal | Offset |
|---|---:|
| `/user/notifications` | `0x62a2af` |
| `GROUP_OUT` | `0x14cb14` |
| `GROUP_WARNING` | `0x5f74da` |
| `GROUP_JOIN_APPROVED` | `0x2d9b89` |
| `/group/push/shake/all` | `0x1c731c` |
| `/group/push/shake` | `0x4edc29` |
| `^SHAKE-([0-9]+)$` | `0x35e049` |
| `^CSHAKE-([0-9]+)$` | `0x750c3f` |

Esses dados comprovam somente a presença das strings no binário analisado. Este agente
inspecionou o relatório, não repetiu a extração do binário. Na primeira tentativa, Blutter
falhou porque `_kDartVmSnapshotData` não estava em `dynsym`, e JADX falhou por memória. Naquele
ponto não havia parser de `ns[]`, enum de `nt` com consumidor, handler Dart de FCM ou fluxo
de persistência recuperado.

Em uma segunda tentativa, `apk-re` relatou ter isolado `classes11.dex` e conseguido usar
JADX 1.5.7 nesse recorte. Em `StudyNudgeCardReceiver.java:6-16`, o receiver testa a extra
`n_type` contra `studyNudgeCard`, lê `stale_at` e `state` e chama um método nativo
ofuscado; o manifesto, nas linhas 967-971 relatadas, declara esse receiver com permissão
C2DM RECEIVE. Em `FlutterFirebaseMessagingService.java:4-10`, o override que recebe
`RemoteMessage` está vazio e o handler Dart não foi recuperado. Os artefatos descompilados
dessa segunda tentativa não estão nesta worktree e não foram inspecionados diretamente por
este agente; essas localizações são evidência relatada por `apk-re`.

Esse fluxo nativo comprova no máximo tratamento de `studyNudgeCard`, não de group nudge.
Não há relação demonstrada com `GROUP shake`, com os regex `SHAKE`/`CSHAKE` ou com
`/user/notifications`.

### Consolidação AOT posterior

`apk-re` relatou ter usado Blutter PR230 com correções para gerar `pp.txt` e `objs.txt`.
Este agente **inspecionou diretamente os artefatos resultantes**, sem repetir a geração:

- `.agents/artifacts/issue5-ypt/blutter-out-dart313/pp.txt:140198-140231`;
- `.agents/artifacts/issue5-ypt/blutter-out-dart313/objs.txt:142435-142585`;
- `.agents/artifacts/issue5-ypt/notification-candidate-disasm.txt`;
- `.agents/artifacts/issue5-ypt/native/libapp.pool-xrefs.txt`.

O pool preserva `/user/notifications` em `pp+0xe9fc0`, com referência ARM64 ADD/LDR em
`0x2212c24/0x2212c28`; os file offsets são iguais aos VAs nesse artefato. O parser geral em
`0x2212710` é chamado por `0x2212674` na closure `0x221261c`. As leituras comprovadas são:

| Campo | Pool | Instruções ADD/LDR no parser/closure |
|---|---|---|
| `ns` | `pp+0xe9ea8` | `0x22124bc/c0` e `0x2212544/48` |
| `i1` | `pp+0xe9f18` | `0x22127f4/27f8` |
| `i2` | `pp+0xe9f30` | `0x2212880/84` |
| `i3` | `pp+0xe9f48` | `0x221290c/10` |
| `i4` | `pp+0xe9f60` | `0x2212998/9c` |
| `ir` | `pp+0xe9f78` | `0x2212a24/28` |
| `nt` | `pp+0xdd8a0` | `0x2212a94/98` |

`pp.txt:140228` e os objetos inspecionados preservam `List<ZTd>(22)` na seguinte ordem:

| Índice | Literal | Índice | Literal |
|---:|---|---:|---|
| 0 | `GROUP_OUT` | 11 | `pushNotice` |
| 1 | `GROUP_WARNING` | 12 | `pushComment` |
| 2 | `DISBANDED` | 13 | `pushStoryComment` |
| 3 | **`SAKE`** | 14 | `pushStoryTagged` |
| 4 | `GROUP_POST` | 15 | `pushMissionRemind` |
| 5 | `GROUP_POST_COMMENT` | 16 | `pushMember` |
| 6 | `REMIND` | 17 | `GROUP_JOIN_WAITING` |
| 7 | `GROUP_OWNER` | 18 | `GROUP_JOIN_APPROVED` |
| 8 | `CHALLENGE_OUT` | 19 | `GROUP_JOIN_REJECTED` |
| 9 | `P_CHALLENGE_OUT` | 20 | `GROUP_NEW_MEMBER` |
| 10 | `pushWakeUp` | 21 | `GROUP_NEW_REQUEST` |

A grafia é **`SAKE`**, não `SHAKE`. Não foi demonstrado que `SAKE` signifique nudge, nem
que qualquer candidato da lista seja produzido por `/group/push/shake` ou represente um
nudge em `/user/notifications`. A lista e o parser geral também não fornecem um item real
de nudge, o significado dos campos de texto para esse tipo ou a estabilidade de `id` entre
polls. Referências aos regex `SHAKE`/`CSHAKE`, isoladamente, igualmente não resolvem sua
semântica de consumo.

Assim, a consolidação AOT melhora a evidência do parser geral, mas **não muda o bloqueio**:
continua ausente um discriminador estrutural que sustente classificação, dedupe e testes de
nudge sem inventar o contrato.

## Melhoria genérica entregue

Arquivos:

- `lib/features/notifications/widgets/notification_bell.dart`
- `test/features/notifications/notification_bell_polling_test.dart`

O `catch` envolve somente a obtenção do repositório e o await de `fetchUnreadCount()`.
A aplicação da resposta (`setState` e animação) fica fora dele e mantém a guarda `mounted`.
Ticks periódicos durante uma consulta pendente são descartados. Somente o refresh explícito
do fechamento do painel pode marcar um trailing, executado depois que a consulta pendente
termina; novos ticks durante esse trailing também são descartados.

Cobertura adicionada:

- dois ticks de 30 segundos durante uma resposta pendente não aumentam o número de
  chamadas; após sua conclusão, o próximo tick volta a consultar;
- abrir e fechar o painel real durante a primeira consulta não a sobrepõe: após sua
  conclusão, começa exatamente um refresh trailing, e um tick durante esse refresh não
  cria outra chamada;
- desmontar o widget cancela ticks futuros e uma resposta concluída depois do `dispose`
  não gera exceção.

Como verificação de eficácia do último teste, a condição `mounted` foi removida
temporariamente somente na aplicação da resposta. O teste falhou como esperado, com
`setState() called after dispose` em `_fetchUnread` e exit 1. O código foi restaurado ao
estado protegido antes da suíte final. Essa mutação não permanece no diff.

Esses testes usam repositório controlado localmente e não validam classificação de nudge,
múltiplos fechamentos do painel ou coordenação global entre instâncias do sino.

## Comandos e resultados

Os testes foram executados sem credenciais e com adapters/fakes locais. No Windows, a
primeira invocação pelo caminho longo falhou antes de rodar testes: o hook `objective_c`
não preservou o quoting de `C:\Users\Huney Oliveira`. A repetição usou os aliases
8.3 (`C:\Users\HUNEYO~1`) do SDK e da worktree, sem alterar dependências.

Baseline focado (cinco arquivos de teste existentes):

```powershell
& 'C:\Users\HUNEYO~1\develop\flutter\bin\flutter.bat' test `
  test/features/notifications/notification_api_contract_test.dart `
  test/features/notifications/notification_repository_test.dart `
  test/features/notifications/notifications_notifier_test.dart `
  test/features/notifications/notifications_screen_test.dart `
  test/unit/notification_bell_test.dart
```

Resultado real: **22 testes passaram** (`All tests passed!`).

Formatação e verificação da alteração própria:

```powershell
& 'C:\Users\HUNEYO~1\develop\flutter\bin\cache\dart-sdk\bin\dart.exe' format `
  lib/features/notifications/widgets/notification_bell.dart `
  test/features/notifications/notification_bell_polling_test.dart
& 'C:\Users\HUNEYO~1\develop\flutter\bin\cache\dart-sdk\bin\dart.exe' analyze `
  lib/features/notifications/widgets/notification_bell.dart `
  test/features/notifications/notification_bell_polling_test.dart
```

Resultados reais: `Formatted 2 files (1 changed)` e `No issues found!`.

Testes do novo arquivo, também executados individualmente com `--plain-name`:

```powershell
& 'C:\Users\HUNEYO~1\develop\flutter\bin\flutter.bat' test --no-pub `
  test/features/notifications/notification_bell_polling_test.dart
```

Resultado real: os **3 casos passaram individualmente** (`All tests passed!` em cada
execução) e novamente na suíte combinada abaixo. Uma tentativa anterior de executar o
arquivo completo foi abortada pelo runtime ao criar `DartWorker` (`os_thread.cc:345`),
sem chegar às asserções; o `flutter_tester` órfão foi identificado e encerrado antes das
novas execuções.

Verificação final combinada, sem resolver dependências novamente:

```powershell
& 'C:\Users\HUNEYO~1\develop\flutter\bin\flutter.bat' test --no-pub `
  test/features/notifications/notification_api_contract_test.dart `
  test/features/notifications/notification_repository_test.dart `
  test/features/notifications/notifications_notifier_test.dart `
  test/features/notifications/notifications_screen_test.dart `
  test/features/notifications/notification_bell_polling_test.dart `
  test/unit/notification_bell_test.dart
```

Resultado real da revisão final: **25 testes passaram** (`All tests passed!`). A
formatação final dos dois arquivos Dart próprios retornou `Formatted 2 files (0 changed)`,
e `dart analyze` retornou `No issues found!`.

Os registrantes de plugins gerados automaticamente durante a resolução de dependências
foram restaurados; não fazem parte da alteração.
