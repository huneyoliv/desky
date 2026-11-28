# Issue #5 — engenharia reversa estática do APK YPT

**Escopo:** criação de grupos e, subsidiariamente, notificações/nudges.
**Base do Desky:** `ab2d56e9bc49a7d0c7c730bd5d529888ec21f132`.
**Aquisição e análise:** 2026-11-28.
**Resultado:** análise estática concluída com xrefs ARM64 e parser AOT parcialmente recuperados. **O contrato completo de `/group/make/v2` não foi comprovado.**

## 1. Resposta executiva

O XAPK analisado é o YPT `810.1.26`/`810126`, package `com.pallo.passiontimerscoped`. A página oficial do fornecedor aponta para esse package no Google Play. O artefato foi obtido de um mirror público e seu SHA-256 coincide com o publicado pelo mirror; isso comprova integridade em relação ao mirror, não autoria da Pallo Inc.

A primeira tentativa com o Blutter upstream falhou porque o snapshot unificado não expunha `_kDartVmSnapshotData` em `.dynsym`. Uma tentativa posterior com o fork compatível com Dart 3.13 gerou `pp.txt` e `objs.txt`. JADX também produziu código Java ao ser executado somente sobre `classes11.dex`, depois das falhas de memória com o APK completo.

Para criação de grupos, foram comprovados:

- a string `/group/make/v2`, seu objeto no pool e um xref ARM64 exato;
- uma closure consumidora associada à rota;
- objetos/chaves de modelo relacionados a grupos.

**Não foram comprovados:** método HTTP, host vinculado ao call site, corpo do request, encoding, headers, campos obrigatórios/opcionais ou formatos de sucesso/erro. O mapa de strings encontrado no pool não será apresentado como payload porque não foi ligado ao request.

Nenhuma conta, credencial, escrita em produção ou sondagem de API foi usada.

## 2. Proveniência e identidade

1. <https://yeolpumta.com> aponta para <https://play.google.com/store/apps/details?id=com.pallo.passiontimerscoped>.
2. A página do Play identificava **YPT - Study Timer & Tracker**, desenvolvedor **Pallo Inc**, atualização em 2026-11-26.
3. A página pública do mirror APKPure anunciava a mesma versão/data:
   <https://apkpure.com/ypt-yeolpumta/com.pallo.passiontimerscoped>.
4. Download público inicial:
   `https://d.apkpure.net/b/XAPK/com.pallo.passiontimerscoped?version=latest`.
5. O `manifest.json` interno declara `version_name=810.1.26`, `version_code=810126`, minSdk 24, targetSdk 36 e splits ARM64/en/mdpi.
6. Androguard identificou estruturas de assinatura APK v2/v3. **A verificação criptográfica completa e o fingerprint não foram concluídos**; o mirror não é chamado de origem oficial nem a assinatura de plenamente verificada.

### Hashes SHA-256

| Artefato | SHA-256 |
|---|---|
| XAPK | `f6338e9d99b3ae648af44ee6fdd47b5c8c31d7fa2f489d636ffaf58225e232ea` |
| APK base | `cb3c347ee13d75ae60fc05745e7cced0ef8b97101f93c842dd8b38fcfd36a14d` |
| Split ARM64 | `15fb6c76a348fb5e4d07604e70955e2b960b3718ed86857a94c596a967d1d888` |
| Split `config.en` | `4ad480d97fd316daf8898cd847347a3c5ba73c38adfc8c9bc89043c72190d524` |
| Split `config.mdpi` | `d6a7722f5fb81917c3b12c0a5dfac804011d9896c03ce7184a3a142fdf647572` |
| `libapp.so` | `b830e7ae060f97b9e52175f1aeb84b705a78186748f821b88c4615b01cfe1a9f` |
| `libflutter.so` | `34f4113ae93b2c7069030f0bcfede18e7c83ed548b71a75c9ebb749403d3a060` |

`libapp.so` tem 59.573.128 bytes e veio exclusivamente de `config.arm64_v8a.apk`. Os artefatos ficam fora do commit em `.agents/artifacts/issue5-ypt/`.

## 3. Ferramentas e artefatos de fluxo

- JADX 1.5.7: o APK completo falhou por memória; o recorte `classes11.dex` produziu `jadx-classes11/sources/`.
- Blutter inicial: `worawit/blutter`, falha em `extract_dart_info.py:20` ao não encontrar `_kDartVmSnapshotData` em `.dynsym`.
- Blutter compatível: `https://github.com/leandrobattochio/blutter.git`, commit `5623054` (“Support Dart 3.13.x unified AOT snapshots”), com modificações locais de CMake para o ambiente Windows.
- Saída AOT usada: `blutter-out-dart313/pp.txt` e `objs.txt`.
- Referências e disassembly: `native/libapp.pool-xrefs.txt`, `target-callsite-disasm.txt` e `group-make-flow-disasm.txt`.
- Scripts preservados: `aot_pool_xrefs.py` e `aot_direct_xrefs.py`.

Nos dumps citados, os file offsets são iguais aos VAs. Eles não devem ser confundidos com os offsets ASCII iniciais.

## 4. Criação de grupos — o que está comprovado

### 4.1 Rota e closure

| Evidência | Localização |
|---|---|
| ASCII `/group/make/v2` | file offset `0x11a1cc` |
| String no pool | `pp+0x115e78`, `pp.txt:170294` |
| Xref ARM64 ADD/LDR | `0x2d15a48/0x2d15a4c`, `target-callsite-disasm.txt:23-24` |
| Closure estática consumidora | `0x2d15a70`, `pp+0x1148e0`, `pp.txt:169320` |
| Xref da closure | `0x380ecdc/0x380ece0`, `native/libapp.pool-xrefs.txt:3-4` |

A closure `0x2d15a70` lê dois valores do objeto preparado e chama `0x276b310`. O dump comprova fluxo associado à string da rota, mas o nome obfuscado do chamado não foi resolvido para um método Dio/HTTP específico.

**Consequência:** a rota e sua closure não são mais apenas uma string isolada. Entretanto, o literal `POST` não foi ligado a esse fluxo. `POST /group/make/v2` permanece candidato histórico, não conclusão deste APK.

### 4.2 Objetos e chaves relacionados

| Item | Evidência estática | Limite |
|---|---|---|
| `goalTime` | `pp+0x115d60`; xrefs `0x3698bfc/c00` e `0x380e1f4/1f8` | Não ligado ao corpo do request |
| `maxMemberCount` | `pp+0x115d68`; xrefs `0x3698a84/a88` e `0x380e27c/280` | Não ligado ao corpo do request |
| `inviteLink` | `pp+0x115d70`; xrefs em `0x380e27c` e `0x380e2a8` | Não ligado ao corpo do request |
| `nicknameRule` | `pp+0x115d98`; xref `0x380e510/514` | Não ligado ao corpo do request |
| `useApproval` | `pp+0x115da0`; xref `0x380e600/604` | Não ligado ao corpo do request |

`pp.txt:325359-325365` contém um `Map<String,String>(5)`:

```text
title       -> title
notice      -> notice
password    -> password
max_members -> maxMemberCount
goal_hours  -> goalTime
```

Esse objeto pode representar serialização de um modelo. **Não foi encontrado fluxo que o ligue ao request de `/group/make/v2`.** Portanto:

- `title`, `notice`, `password`, `max_members` e `goal_hours` não são afirmados como nomes do payload;
- `goalTime` e `maxMemberCount` não são promovidos de nomes de propriedades a campos de request;
- categoria, introdução, Cam Study, obrigatoriedade e defaults permanecem desconhecidos;
- `inviteLink`, `nicknameRule` e `useApproval` podem pertencer ao modelo de resposta/edição e não são incluídos em um request hipotético.

Nenhum exemplo JSON/form/multipart foi produzido, pois daria aparência de contrato a dados não demonstrados.

## 5. Contrato solicitado — estado final

| Pergunta | Resultado sustentado |
|---|---|
| Rota | `/group/make/v2` com pool object, xref e closure comprovados |
| Método HTTP | **Desconhecido**; POST é somente candidato histórico |
| Host | **Desconhecido por vínculo ao call site** |
| Campos exatos do payload | **Desconhecidos**; há chaves de modelo, não um request recuperado |
| Encoding | **Desconhecido**; JSON/form/multipart não foi inferido |
| Headers obrigatórios | **Desconhecidos**; nenhum Authorization/Content-Type foi vinculado ao fluxo |
| Obrigatórios/opcionais | **Desconhecidos** |
| Sucesso | **Desconhecido**; desserializador/ramificação de sucesso não foi confirmado |
| Erro | **Desconhecido**; status/corpo/códigos não foram confirmados |

A função recuperada em `target-callsite-disasm.txt` não foi interpretada além das instruções preservadas. Não se preencheu o restante com relatórios antigos, convenções do Dio ou suposições.

## 6. Notificações e nudges — evidência AOT

A rota `/user/notifications` está em `pp+0xe9fc0`, com ADD/LDR em `0x2212c24/0x2212c28`. O parser geral em `0x2212710` é chamado por `0x2212674` na closure `0x221261c`.

| Campo | Pool | Instruções no parser/closure |
|---|---|---|
| `ns` | `pp+0xe9ea8` | `0x22124bc/c0`, `0x2212544/48` |
| `i1` | `pp+0xe9f18` | `0x22127f4/27f8` |
| `i2` | `pp+0xe9f30` | `0x2212880/84` |
| `i3` | `pp+0xe9f48` | `0x221290c/10` |
| `i4` | `pp+0xe9f60` | `0x2212998/9c` |
| `ir` | `pp+0xe9f78` | `0x2212a24/28` |
| `nt` | `pp+0xdd8a0` | `0x2212a94/98` |

Os acessos oficiais a `id` e `c` não foram resolvidos com o mesmo nível de evidência e não são inferidos. A lista `List<ZTd>(22)` contém `GROUP_OUT`, `GROUP_WARNING`, `DISBANDED`, `SAKE`, `GROUP_POST`, `GROUP_POST_COMMENT`, `REMIND`, `GROUP_OWNER`, desafios, eventos `push*` e códigos de entrada/membros. A grafia do índice 3 é literalmente **`SAKE`**, não `SHAKE`.

Não foi demonstrado que `SAKE` signifique nudge, nem que qualquer item da lista seja gerado por `/group/push/shake`. Também não foi recuperado um payload real de nudge, o significado dos textos para esse tipo ou a estabilidade de `id` para dedupe. A lista completa e as instruções estão em `nudge-reception.md`.

### Evidência Java/FCM

`StudyNudgeCardReceiver.java:6-16` testa `n_type == "studyNudgeCard"`, lê `stale_at`/`state` e chama um método nativo ofuscado. `FlutterFirebaseMessagingService.java:4-10` tem o override de `RemoteMessage` vazio. Esses fatos não ligam `studyNudgeCard` ao group nudge, aos regex `^SHAKE-([0-9]+)$`/`^CSHAKE-([0-9]+)$` ou a `/user/notifications`.

**Conclusão para polling:** continua ausente um discriminador estrutural confiável. Não se deve classificar por título, idioma, `SAKE`, `SHAKE`, `WAKE` ou `NUDGE` como heurística.

## 7. Comandos preservados

Os comandos abaixo foram preservados no histórico/artefatos. Não são reconstruídas invocações cuja linha completa não foi registrada.

```powershell
# Download público, sem credenciais
curl.exe -L --fail --retry 2 --connect-timeout 30   -A 'Mozilla/5.0'   -e 'https://apkpure.net/ypt-yeolpumta/com.pallo.passiontimerscoped/download'   -o 'YPT-810.1.26-810126-APKPure.xapk'   'https://d.apkpure.net/b/XAPK/com.pallo.passiontimerscoped?version=latest'

Get-FileHash -Algorithm SHA256 'YPT-810.1.26-810126-APKPure.xapk'
Get-ChildItem xapk\*.apk | ForEach-Object {
  Get-FileHash -Algorithm SHA256 $_.FullName
}

# Ferramentas iniciais
python -m pip install --target python-tools androguard pyelftools requests
git clone --depth 1 https://github.com/worawit/blutter.git blutter

# Execução compatível preservada em blutter-dart313/run-audit.cmd
python blutter.py ..\native ..\blutter-out-dart313 --no-analysis
```

A execução foi feita pelo wrapper `run-audit.cmd`, que configura Visual Studio/CMake/Ninja e `PYTHONPATH`. `pp.txt` e `objs.txt` foram gerados com essa configuração. As invocações completas de JADX e dos scripts Python de xref não foram preservadas em um log comandos+saidas; os caminhos dos artefatos são informados em vez de inventar flags.

## 8. Restrições e próxima evidência necessária

- Nenhuma conta, token ou segredo foi usado.
- Nenhuma criação/edição/sondagem em produção foi realizada.
- Nenhum tráfego com conta real foi capturado.
- Binários, ferramentas e dumps não fazem parte do commit.
- A assinatura do APK não foi plenamente verificada; a procedência do mirror é uma limitação explícita.

Para destravar a implementação da criação de grupos é necessário recuperar o restante do call site AOT até o builder do request e o parser da resposta, ou obter uma captura controlada/autorizada e sanitizada de uma criação bem-sucedida. Sem uma dessas evidências, o fluxo deve permanecer desabilitado no Desky.
