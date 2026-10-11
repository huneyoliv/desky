<div align="center">

<img src="assets/icons/icon.png" alt="Desky Logo" width="128" height="128" />

# ⏱️ Desky — Yeolpumta Desktop Client

**Um cliente desktop moderno, poderoso e elegante para a plataforma de estudos Yeolpumta (YPT).**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20macOS%20%7C%20Linux-blue?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/huneyoliv/desky/releases)
[![Downloads](https://img.shields.io/github/downloads/huneyoliv/desky/total?style=for-the-badge&logo=github&logoColor=white&label=Downloads&color=blueviolet)](https://github.com/huneyoliv/desky/releases)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![CI/CD](https://img.shields.io/badge/Build-Passing-brightgreen?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/huneyoliv/desky/actions)
[![Tests](https://img.shields.io/badge/Tests-390%2B%20Passing-success?style=for-the-badge&logo=dart)](https://github.com/huneyoliv/desky)

**[English](README.md)** • **[Português (Brasil)](README.pt-BR.md)** • **[简体中文](README.zh-CN.md)**

[Recursos](#-recursos-principais) •
[Instalação](#-instalação-e-download) •
[Arquitetura](#-arquitetura-e-tecnologias) •
[Desenvolvimento](#-desenvolvimento-local) •
[Aviso Legal](#-aviso-legal) •
[Licença](#-licença)

</div>

---

## 📖 Sobre o Projeto

O **Desky** foi desenvolvido para oferecer a melhor experiência de produtividade e foco para estudantes que utilizam computadores desktop (Windows, macOS e Linux). Com uma interface dark AMOLED True Black inspirada no design do Yeolpumta e aprimorada para monitores de alta resolução, o aplicativo traz todas as funcionalidades essenciais da plataforma diretamente para o seu computador.

---

## ✨ Recursos Principais

### ⏱️ Cronômetro de Estudo & Pomodoro
- **Modo Padrão & Pomodoro**: Ciclos configuráveis de foco, pausa curta e pausa longa.
- **Gestão de Matérias**: Criação, edição, arquivamento e paleta de cores personalizada.
- **Registro Manual**: Inserção de sessões de estudo passadas com cálculo instantâneo.
- **Sincronização Offline**: Fila de requisições persistente em caso de instabilidade na conexão com resolução de conflitos.

### 🛡️ Modo Foco & Bloqueador de Distrações
- **Monitoramento de Processos**: Detecção automática e alertas para aplicativos não permitidos abertos durante o estudo.
- **Modo Estrito**: Bloqueio de navegação lateral para foco ininterrupto.
- **Mini Player Flutuante**: Janela compacta Always-on-Top para acompanhar o tempo enquanto consulta materiais de estudo.

### 👥 Grupos de Estudo & Live Study
- **Feed e Presença em Tempo Real**: Visualize membros estudando ao vivo com status detalhado e avatares animados.
- **Live Study**: Captura periódica e upload seguro de fotos de webcam para comprovação de presença.
- **Chat do Grupo**: Envio de mensagens, reações com emojis, anexos de mídia e stickers oficiais do YPT.
- **Interações Sociais**: Envio de "Toques" (Shake) para incentivar colegas de grupo.

### 🎮 Discord Rich Presence (RPC)
- **Sincronização em Tempo Real**: Exiba sua matéria atual de estudo, cronômetro decorrido e grupo de estudos diretamente no status do seu perfil do Discord.
- **Transição Automática**: Altera dinamicamente entre os estados "Estudando", "Em pausa" e "Inativo".

### 🔒 Autenticação Desktop Segura (OAuth PKCE)
- **E-mail & Senha**: Autenticação com suporte a redefinição de senha via código de verificação.
- **Google OAuth com PKCE**: Fluxo nativo no navegador com servidor loopback local, sem vulnerabilidades de webviews embutidas.

### 📅 Planner, Timetable & D-Days
- **D-Day Countdown**: Contagem regressiva visual para provas, exames e metas importantes.
- **To-Do List Inteligente**: Tarefas com prazos, prioridades e suporte a regras de recorrência.
- **Grade Semanal (Timetable)**: Planejador semanal interativo com blocos de horários por disciplina.

### 📊 Rankings Globais & Heatmap de Atividade
- **Classificação Multicategoria**: Rankings em tempo real globais, nacionais e por categoria de estudo (diário, semanal e mensal).
- **Matriz de Heatmap**: Gráfico de intensidade anual estilo GitHub para visualização da constância de estudo.
- **Calendário Mensal**: Histórico dia a dia com metas diárias e streaks.

### 🃏 Flashcards & Leitor de PDF (Smartbook)
- **Baralhos Personalizados**: Organização de cartas por matérias e tópicos com algoritmo SM-2 de repetição espaçada.
- **Leitor de PDF Integrado**: Visualização de livros, apostilas e criação rápida de flashcards a partir das páginas.

### 📹 Gravador de Timelapse
- Captura contínua de tela em intervalos configuráveis com galeria e reprodutor de vídeo interno.

### 🎨 Avatares & Loja
- Personalização de avatar com roupas, acessórios e poses dinâmicas sincronizadas com o estado de estudo.

### 🔔 Central de Notificações
- Central interna de notificações para avisos de grupos, toques de amigos e comunicados de novas versões.

### 🌐 Internacionalização Completa (i18n)
- Suporte a 28 idiomas com troca instantânea de idioma em tempo de execução.

### 🔄 Notificação de Atualizações In-App
- Verificação automática de novas versões com badge pulsante ao lado do sino de notificações.
- Modal interno com visualização do changelog oficial e botão de download direto do instalador da plataforma do usuário.

---

## 💻 Instalação e Download

Baixe a versão mais recente diretamente na página de [**Releases Oficiais**](https://github.com/huneyoliv/desky/releases/latest).

| Plataforma | Pacote / Instalador | Formato | Como Instalar |
| :--- | :--- | :--- | :--- |
| **Windows** | `Desky-Windows-Installer-x64.exe` | Instalador Executável | Execute o instalador `.exe` e siga as instruções do assistente. |
| **Windows** | `Desky-Windows-x64.msix` | Pacote MSIX | Instale diretamente pelo Windows App Installer / formato Microsoft Store. |
| **macOS** | `Desky-macOS-Installer.dmg` | Imagem de Disco | Abra o arquivo `.dmg` e arraste o `Desky.app` para `Applications`. |
| **Linux (Debian/Ubuntu)** | `Desky-Linux-x64.deb` | Pacote Debian | `sudo apt install ./Desky-Linux-x64.deb` ou `sudo dpkg -i Desky-Linux-x64.deb` |
| **Linux (Outras Distros)** | `Desky-Linux-x64.tar.gz` | Arquivo Portável | Extraia o `.tar.gz` e execute o binário `./desky`. |

---

## 🏗️ Arquitetura e Tecnologias

O projeto segue as diretrizes da **Clean Architecture**, com separação clara de responsabilidades:

```
lib/
├── core/                  # Serviços essenciais, rede, temas, constantes e i18n
│   ├── api/               # Cliente HTTP (Dio) e interceptors de autenticação
│   ├── cdn/               # Resolvedores de CDN dinâmicos para avatares e assets
│   ├── constants/         # Endpoints da API e configurações padrão
│   ├── localization/      # Motor de tradução e dicionários de fallback (28 idiomas)
│   ├── oauth/             # Google OAuth PKCE e servidor local de loopback
│   ├── services/          # Serviços do sistema (Foco, Câmera, Atualizações, Janela, Discord RPC)
│   └── theme/             # Paleta Dark AMOLED, tipografia e estilos visuais
├── data/                  # Camada de dados, DTOs e repositórios
│   ├── models/            # Modelos de dados com serialização JSON
│   └── repositories/      # Comunicação com a API e abstração de acesso a dados
├── features/              # Funcionalidades modulares
│   ├── auth/              # Autenticação por e-mail e Google OAuth PKCE
│   ├── challenges/        # Desafios de estudo e metas comunitárias
│   ├── flashcards/        # Gerenciamento de baralhos e algoritmo SM-2
│   ├── groups/            # Grupos de estudo, presença, chat e Live Study
│   ├── notifications/     # Central de notificações e alertas
│   ├── planner/           # Planejador de tarefas (To-Do), D-Days e grade de horários
│   ├── profile/           # Perfil de usuário e segurança da conta
│   ├── ranks/             # Rankings globais, matriz Heatmap e calendário mensal
│   ├── settings/          # Configurações de estudo, idioma e termos legais
│   ├── smartbook/         # Leitor integrado de PDF e visualizador de materiais
│   ├── store/             # Inventário e loja de itens do avatar
│   ├── timelapse/         # Gravação e galeria reprodutora de timelapses
│   ├── timer/             # Cronômetro principal, Pomodoro, Mini Player e matérias
│   └── updates/           # Verificador de releases, changelog e links de download
└── shared/                # Widgets compartilhados (AppShell, SidebarNav, TitleBar, Avatars)
```

### Principais Bibliotecas:
- **Framework**: [Flutter Desktop](https://flutter.dev) (Dart 3.x)
- **Gerenciamento de Estado**: [Flutter Riverpod](https://riverpod.dev)
- **Roteamento**: [GoRouter](https://pub.dev/packages/go_router)
- **Comunicação HTTP**: [Dio](https://pub.dev/packages/dio)
- **Armazenamento Seguro**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) e [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Gráficos e Animações**: [FL Chart](https://pub.dev/packages/fl_chart) e [Lottie](https://pub.dev/packages/lottie)
- **Controle de Janela Desktop**: [window_manager](https://pub.dev/packages/window_manager)

---

## 🛠️ Desenvolvimento Local

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.0.0`)
- **Windows**: Visual Studio 2022 com a carga de trabalho "Desenvolvimento para desktop com C++".
- **macOS**: Xcode 15+ com ferramentas de linha de comando.
- **Linux**: Dependências de compilação:
  ```bash
  sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev libjsoncpp-dev
  ```

### Clonando o Repositório
```bash
git clone https://github.com/huneyoliv/desky.git
cd desky
```

### Instalando Dependências
```bash
flutter pub get
```

### Executando o Aplicativo
```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

### Executando a Suíte de Testes
```bash
# Executar todos os testes automatizados
flutter test

# Análise estática de código
flutter analyze
```

---

## ⚖️ Aviso Legal

O **Desky** é um cliente independente de código aberto desenvolvido por terceiros e não possui afiliação, endosso, patrocínio ou vínculo com a **Pallo Inc.** ou com o **Yeolpumta (YPT)**. Todas as marcas registradas pertencem aos seus respectivos proprietários.

---

## 📄 Licença

Este projeto está licenciado sob os termos da licença [MIT](LICENSE).
