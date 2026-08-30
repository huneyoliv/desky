<div align="center">

# ⏱️ Desky — Yeolpumta Desktop Client

**Um cliente desktop moderno, poderoso e elegante para a plataforma de estudos Yeolpumta (YPT).**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20macOS%20%7C%20Linux-blue?style=for-the-badge&logo=windows&logoColor=white)](https://github.com/huneyoliv/desky/releases)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![CI/CD](https://img.shields.io/badge/Build-Passing-brightgreen?style=for-the-badge&logo=githubactions&logoColor=white)](https://github.com/huneyoliv/desky/actions)
[![Tests](https://img.shields.io/badge/Tests-339%2B%20Passing-success?style=for-the-badge&logo=dart)](https://github.com/huneyoliv/desky)

**[English](README.md)** • **[Português (Brasil)](README.pt-BR.md)**

[Recursos](#-recursos-principais) •
[Instalação](#-instalação-e-download) •
[Arquitetura](#-arquitetura-e-tecnologias) •
[Desenvolvimento](#-desenvolvimento-local) •
[Aviso Legal](#-aviso-legal) •
[Licença](#-licença)

</div>

---

## 📖 Sobre o Projeto

O **Desky** foi desenvolvido para oferecer a melhor experiência de produtividade e foco para estudantes que utilizam computadores desktop (Windows, macOS e Linux). Com uma interface dark moderna inspirada no design do Yeolpumta e aprimorada para monitores de alta resolução, o aplicativo traz todas as funcionalidades essenciais da plataforma diretamente para o seu computador.

---

## ✨ Recursos Principais

### ⏱️ Cronômetro de Estudo & Pomodoro
- **Modo Padrão & Pomodoro**: Ciclos configuráveis de foco, pausa curta e pausa longa.
- **Gestão de Matérias**: Criação, edição, arquivamento e paleta de cores personalizada.
- **Registro Manual**: Inserção de sessões de estudo passadas com cálculo instantâneo.
- **Sincronização Offline**: Fila de requisições persistente em caso de instabilidade na conexão.

### 🛡️ Modo Foco & Bloqueador de Distrações
- **Monitoramento de Processos**: Detecção automática e alertas para aplicativos não permitidos abertos durante o estudo.
- **Modo Estrito**: Bloqueio de navegação lateral para foco ininterrupto.
- **Mini Player Flutuante**: Janela compacta do cronômetro para acompanhar o tempo enquanto consulta materiais.

### 👥 Grupos de Estudo & Live Study
- **Feed e Presença em Tempo Real**: Visualize membros estudando ao vivo com status detalhado.
- **Live Study**: Captura periódica e upload seguro de fotos de webcam para comprovação de presença.
- **Chat do Grupo**: Envio de mensagens, reações com emojis, anexos de mídia e stickers oficiais do YPT.
- **Interações Sociais**: Envio de "Toques" (Shake) para incentivar colegas de grupo.

### 📅 Planner, Timetable & D-Days
- **D-Day Countdown**: Contagem regressiva visual para provas, exames e metas importantes.
- **To-Do List Inteligente**: Tarefas com prazos, prioridades e suporte a regras de recorrência.
- **Grade Semanal (Timetable)**: Planejador semanal interativo com blocos de horários por disciplina.

### 📊 Rankings Globais & Heatmap de Atividade
- **Classificação Multicategoria**: Rankings em tempo real globais, nacionais e por categoria de estudo.
- **Matriz de Heatmap**: Gráfico de intensidade anual estilo GitHub para visualização da constância de estudo.
- **Calendário Mensal**: Histórico dia a dia com metas diárias e streaks.

### 🃏 Flashcards & Leitor de PDF
- **Baralhos Personalizados**: Organização de cartas por matérias e tópicos com algoritmo SM-2.
- **Leitor de PDF Integrado**: Visualização de livros, apostilas e criação rápida de flashcards a partir das páginas.

### 📹 Gravador de Timelapse
- Captura contínua de tela em intervalos configuráveis com galeria e reprodutor interno.

### 🎨 Avatares & Loja
- Personalização de avatar com roupas, acessórios e poses dinâmicas sincronizadas com o estado de estudo.

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
| **macOS** | `Desky-macOS-Installer.dmg` | Imagem de Disco | Abra o arquivo `.dmg` e arraste o `Desky.app` para `Applications`. |
| **Linux (Debian/Ubuntu)** | `Desky-Linux-x64.deb` | Pacote Debian | `sudo apt install ./Desky-Linux-x64.deb` ou `sudo dpkg -i Desky-Linux-x64.deb` |
| **Linux (Outras Distros)** | `Desky-Linux-x64.tar.gz` | Arquivo Portável | Extraia o `.tar.gz` e execute o binário `./desky`. |

---

## 🏗️ Arquitetura e Tecnologias

O projeto segue as diretrizes da **Clean Architecture**, com separação clara de responsabilidades:

```
lib/
├── core/                  # Serviços globais, rede, temas, constantes e i18n
│   ├── api/               # Cliente HTTP (Dio) e interceptors de autenticação
│   ├── cdn/               # Resolução dinâmica de URLs de avatares e mídias
│   ├── constants/         # Endpoints e constantes da aplicação
│   ├── localization/      # Sistema de tradução e fallbacks
│   ├── services/          # Serviços do sistema (Foco, Webcam, Atualizações, Janelas)
│   └── theme/             # Paleta de cores escura, tipografia e estilos
├── data/                  # Modelos de dados e repositórios
│   ├── models/            # DTOs com serialização JSON e Freezed
│   └── repositories/      # Camada de abstração de dados e chamadas de API
├── features/              # Módulos verticais de funcionalidades
│   ├── auth/              # Login com e-mail e social (Google / Apple)
│   ├── challenges/        # Desafios de estudo e metas
│   ├── flashcards/        # Baralhos e algoritmo SM-2
│   ├── focus/             # Bloqueio de processos e Mini Player
│   ├── groups/            # Grupos, presenças ao vivo, chat e Live Study
│   ├── notifications/     # Central de notificações e avisos
│   ├── planner/           # Planner, To-Do list e grade horária
│   ├── profile/           # Perfil do estudante e configurações de conta
│   ├── ranks/             # Tabelas de classificação, Heatmap e Calendário
│   ├── settings/          # Preferências de estudo, idioma e legal
│   ├── smartbook/         # Leitor integrado de PDFs e materiais
│   ├── store/             # Loja de Avatares e inventário
│   ├── timelapse/         # Gravação e galeria de timelapses
│   ├── timer/             # Cronômetro principal, Pomodoro e matérias
│   └── updates/           # Verificador de releases, changelog e instaladores
└── shared/                # Widgets compartilhados (Shell, Sidebar, Título, Avatares)
```

### Principais Bibliotecas:
- **Framework**: [Flutter Desktop](https://flutter.dev) (Dart 3.x)
- **Gerenciamento de Estado**: [Flutter Riverpod](https://riverpod.dev)
- **Roteamento**: [GoRouter](https://pub.dev/packages/go_router)
- **Comunicação HTTP**: [Dio](https://pub.dev/packages/dio)
- **Armazenamento Seguro**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) & [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Gráficos & Animações**: [FL Chart](https://pub.dev/packages/fl_chart) & [Lottie](https://pub.dev/packages/lottie)
- **Manipulação de Janelas**: [window_manager](https://pub.dev/packages/window_manager)

---

## 🛠️ Desenvolvimento Local

### Pré-requisitos
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.0.0`)
- **Windows**: Visual Studio 2022 com a carga de trabalho "Desenvolvimento para Desktop com C++".
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

### Executando a Aplicação
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
# Executa todos os testes automatizados
flutter test

# Análise estática do código
flutter analyze
```

---

## ⚖️ Aviso Legal (Disclaimer)

O **Desky** é um cliente de terceiros independente e de código aberto, não sendo afiliado, endossado, patrocinado ou associado à **Pallo Inc.** ou ao **Yeolpumta (YPT)**. Todas as marcas registradas pertencem aos seus respectivos proprietários.

---

## 📄 Licença

Este projeto está sob a licença [MIT](LICENSE).
