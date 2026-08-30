# Documentação Técnica, Algoritmo de CDN e Especificação Exaustiva da API YPT (Yeolpumta)

Este documento centraliza a especificação técnica oficial e exaustiva da API do **YPT (Yeolpumta)**, cobrindo a arquitetura de comunicação, **o algoritmo de carregamento de assets e resolução de mídias via CDN**, especificação de todos os endpoints REST, esquemas JSON (Request/Response), cabeçalhos HTTP exigidos e regras de negócio.

---

## 1. Algoritmo e Lógica de Carregamento de Assets via CDN

### 1.1 Motivação Arquitetural e Separação de Responsabilidades
O ecossistema YPT adota uma arquitetura desacoplada de alto desempenho:
- **API REST Principal (`https://pi.tgclab.com`)**: Processa lógica de negócios, mutações de banco de dados, autenticação JWT, estado do cronômetro em tempo real, envio de mensagens e controle de concorrência. **A API REST nunca retorna arquivos binários** (imagens ou áudios), devolvendo apenas os identificadores numéricos (`id`, `studiconID`, `pv`, `groupID`, `userID`).
- **CDN de Metadados Estáticos (`https://picf.tgclab.com`)**: Servidor alimentado por CloudFront/Cloudflare Edge Cache para entrega de catálogo de produtos da loja (Studicons, temas) e tabelas regionais com latência ultra-baixa.
- **CDN de Mídias Binárias (`https://alicdn.tgclab.com`)**: Armazenamento de objetos de alta disponibilidade para servir avatares (`.png`), fotos de perfil (`.jpg`), capturas de câmera (`cam`), figurinhas (`sticker`) e mídias de chat.
- **CDN de Mídia de Áudio (`https://alicdn.pallo.cn`)**: Distribuição de faixas em MP3 e artes de capa de ruídos brancos e playlists de foco.

---

### 1.2 Algoritmo de Descoberta e Geração de URLs para Novos Avatares (Studicons)

Quando novos avatares (Studicons) são lançados na loja virtual do YPT:

#### Passo 1: Descoberta via API/CDN de Metadados
O cliente (App Mobile, Desktop ou Web) consulta o catálogo da loja:
```http
GET https://picf.tgclab.com/studicon/list/new?p=1&lang=pt
```
O servidor retorna o catálogo em JSON contendo o array `scs`:
```json
{
  "s": true,
  "scs": [
    {
      "id": 377,
      "tk": "Estrategista do Deserto",
      "te": "Desert Strategist",
      "dk": "Descrição detalhada do personagem...",
      "price": 100
    }
  ]
}
```

#### Passo 2: Fórmula Determinística de Construção de URL no Cliente
Para qualquer Studicon retornado no catálogo (identificado por `id`), o cliente **não realiza chamadas adicionais à API** para descobrir as imagens. O cliente aplica a seguinte fórmula algorítmica:

$$	ext{URL\_CDN} = 	ext{"https://alicdn.tgclab.com/sc.v2/"} + 	ext{studiconID} + 	ext{"/"} + 	ext{pose} + 	ext{".png"}$$

#### Matriz de Resolução de Poses do Persona (`pose`)
| Interface / Estado do Aplicativo | Valor da Variável `pose` | URL Final Resultante |
| :--- | :--- | :--- |
| **Grid da Loja / Miniatura de Lista** | `mini.png` | `https://alicdn.tgclab.com/sc.v2/377/mini.png` |
| **Avatar Inativo / Modal de Preview** | `normal1.png` | `https://alicdn.tgclab.com/sc.v2/377/normal1.png` |
| **Cronômetro Ativo (Estudando Inicial)** | `sweat1.png` | `https://alicdn.tgclab.com/sc.v2/377/sweat1.png` |
| **Esforço Acumulado (Estudando Nível 2)** | `sweat2.png` | `https://alicdn.tgclab.com/sc.v2/377/sweat2.png` |
| **Foco Máximo / Sessão Prolongada** | `ignite1.png` | `https://alicdn.tgclab.com/sc.v2/377/ignite1.png` |
| **Modo Pausa / Descanso Agendado** | `smoke1.png` | `https://alicdn.tgclab.com/sc.v2/377/smoke1.png` |
| **Efeito de Conquista / Meta Atingida** | `fire1.png` | `https://alicdn.tgclab.com/sc.v2/377/fire1.png` |
| **Ícone Personalizado do Aplicativo** | `app.png` | `https://alicdn.tgclab.com/sc.v2/377/app.png` |

- **Lógica de Fallback**: Se o usuário não possui Studicon equipado (`studiconID == -1` ou nulo), o sistema utiliza a URL de fallback padrão: `https://alicdn.tgclab.com/sc.v2/-1/normal1.png`.

---

### 1.3 Algoritmo de Carregamento de Avatares de Outros Usuários (Grupos e Ranks)

Quando o aplicativo renderiza a lista de membros de um grupo de estudos ou tabela de ranking em tempo real:

1. O cliente chama o endpoint de estado dos membros:
   ```http
   GET https://pi.tgclab.com/logs/group/members/v2?groupID=6487271
   ```
2. O servidor retorna o array de membros com os campos:
   - `ud`: User ID (`16300695`)
   - `st` ou `pv`: Studicon ID (`377`)
   - `is`: Boolean `dlIsStudying` (`true` se estiver estudando)
   - `sm`: Milissegundos estudados no dia
   - `hasCustomAvatar`: Boolean indicando se possui foto própria de perfil.

3. **Pseudocódigo da Lógica de Resolução no Cliente Desktop/Web**:
```python
def get_user_avatar_cdn_url(member_data):
    user_id = member_data.get('ud')
    has_custom_photo = member_data.get('hasCustomAvatar', False)
    
    # 1. Se o usuário usa foto personalizada
    if has_custom_photo:
        return f"https://alicdn.tgclab.com/user/profile/{user_id}.jpg"
    
    # 2. Se o usuário usa Studicon
    studicon_id = member_data.get('st') or member_data.get('pv') or -1
    is_studying = member_data.get('is', False)
    study_ms = member_data.get('sm', 0)
    
    if is_studying:
        if study_ms > 7200000:  # Mais de 2 horas contínuas de estudo
            pose = "ignite1.png"
        else:
            pose = "sweat1.png"
    else:
        pose = "normal1.png"
        
    return f"https://alicdn.tgclab.com/sc.v2/{studicon_id}/{pose}"
```

---

### 1.4 Algoritmo de Verificação por Câmera (Cam Study)
- Para grupos do tipo **Cam Study**, o app obtém a data atual e o ID do membro para requisitar a foto da câmera diretamente do CDN:
  $$	ext{URL\_Cam} = 	ext{"https://alicdn.tgclab.com/cam/"} + 	ext{YYYY-MM-DD} + 	ext{"/"} + 	ext{userID}$$
- Exemplo: `https://alicdn.tgclab.com/cam/2026-08-09/16300695`

---

### 1.5 Algoritmo de Mídia do Chat e Upload Serverless
1. **Envio de Mídia**: O cliente faz um upload `multipart/form-data` para o endpoint serverless: `POST https://alifn.tgclab.com/file`.
2. **Processamento Serverless**: A função serverless gera a miniatura (thumbnail) e retorna o caminho relativo: `/chat/groups/{groupID}/{timestamp}_{index}_thumb.jpg`.
3. **Renderização no Chat**: Todos os clientes concatenam o domínio do CDN:
   $$	ext{URL\_Chat} = 	ext{"https://alicdn.tgclab.com"} + 	ext{caminho\_relativo}$$

---

## 2. Cabeçalhos HTTP Exigidos e Regras de Autenticação

```http
Content-Type: application/json
User-Agent: Dart/3.11 (dart:io)
Authorization: JWT <TOKEN_JWT_SESSION>
```

> **REGRA CRÍTICA DE AUTENTICAÇÃO**:
> - O backend exige o prefixo `JWT ` no cabeçalho `Authorization`.
> - No endpoint de login (`/user/sign-in-jwt`), o cabeçalho é enviado como `Authorization: JWT`.

---

## 3. Especificação Completa dos Endpoints da API

### Módulo: Autenticação, Sessão e Dispositivo

#### `POST https://pi.tgclab.com/user/sign-in-jwt`
- **Função**: Login direto com Email/Senha ou Provedor Social.
- **Request Body**:
```json
{
  "email": "user@example.com",
  "password": "SecretPassword123",
  "loginProvider": "Email",
  "new": true,
  "getx": true,
  "language": "pt"
}
```
- **Response Body (200 OK)**:
```json
{
  "s": true,
  "jwt": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "today": "2026-08-09",
  "id": 16300695,
  "n": "Longkun1",
  "e": "user@example.com",
  "pv": 24,
  "ss": [
    {
      "id": 119611290,
      "tt": "Raciocínio Lógico",
      "sm": 0,
      "or": 100,
      "co": 4293227379,
      "dl": false,
      "ia": false
    }
  ]
}
```

#### `POST https://pi.tgclab.com/user/v2/splash-login`
- **Função**: Inicialização e registro de dispositivo.
- **Request Body**:
```json
{
  "version": 810041,
  "pushToken": "ch5sAmdJTju...",
  "timezone": "America/Fortaleza",
  "deviceType": "AOS",
  "osVersion": 29,
  "deviceModel": "Redmi Note 7",
  "pv": 19,
  "language": "pt"
}
```

---

### Módulo: Matérias (Subject Studies)

#### `POST https://pi.tgclab.com/user/subject/create`
- **Request Body**:
```json
{
  "title": "Português",
  "color": 4294948685,
  "order": 100
}
```

---

### Módulo: Cronômetro e Controle de Estudo

#### `POST https://pi.tgclab.com/study/start`
- **Request Body**:
```json
{
  "subject_id": 119611290,
  "start_at": "2026-08-10T00:15:00.000Z"
}
```

#### `POST https://pi.tgclab.com/study/stop`
- **Request Body**:
```json
{
  "subject_id": 119611290,
  "stop_at": "2026-08-10T00:45:00.000Z",
  "study_ms": 1800000
}
```

---

### Módulo: Grupos de Estudo e Membros em Tempo Real

#### `GET https://pi.tgclab.com/logs/group/members/v2?groupID=6487271`
- **Função**: Retorna o status de estudo e os identificadores para resolução de avatares CDN de todos os membros do grupo.
