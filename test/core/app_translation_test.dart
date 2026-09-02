import 'package:flutter_test/flutter_test.dart';
import 'package:desky/core/localization/app_translation.dart';

void main() {
  group('AppTranslation Comprehensive Tests', () {
    test('Translates Focus Mode keys across languages', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');
      final es = const AppTranslation(languageCode: 'es');
      final ja = const AppTranslation(languageCode: 'ja');

      expect(pt.tr('exit_focus'), 'Sair do Foco');
      expect(en.tr('exit_focus'), 'Exit Focus');
      expect(ko.tr('exit_focus'), '포커스 종료');
      expect(es.tr('exit_focus'), 'Salir del Enfoque');
      expect(ja.tr('exit_focus'), 'フォーカス終了');

      expect(pt.tr('focus_mode'), 'Modo Foco & Bloqueador');
      expect(en.tr('focus_mode'), 'Focus Mode & Blocker');
      expect(ko.tr('focus_mode'), '포커스 모드 및 앱 차단');
    });

    test('Translates Manual Study Log keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('manual_study_record'), 'Registro Manual de Estudo');
      expect(en.tr('manual_study_record'), 'Manual Study Record');
      expect(ko.tr('manual_study_record'), '공부 시간 수동 입력');

      expect(pt.tr('invalid_time_range'), 'O horário de término deve ser posterior ao início.');
      expect(en.tr('invalid_time_range'), 'End time must be after start time.');
    });

    test('Translates Pomodoro keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('pomodoro_settings'), 'Configurações do Pomodoro');
      expect(en.tr('pomodoro_settings'), 'Pomodoro Settings');
      expect(ko.tr('pomodoro_settings'), '뽀모도로 설정');

      expect(pt.tr('cycles_to_long_break'), 'Ciclos até Pausa Longa');
      expect(en.tr('cycles_to_long_break'), 'Cycles until Long Break');
    });

    test('Translates Planner & Todo keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('repeat_multiple_days'), 'Repetir em vários dias');
      expect(en.tr('repeat_multiple_days'), 'Repeat on multiple days');
      expect(ko.tr('repeat_multiple_days'), '여러 날 반복');

      expect(pt.tr('day_mon_short'), 'Seg');
      expect(en.tr('day_mon_short'), 'Mon');
      expect(ko.tr('day_mon_short'), '월');
    });

    test('Translates Rankings, Heatmap & Calendar keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('heatmap_title'), 'Mapa de Calor de Estudos (24h x 30d)');
      expect(en.tr('heatmap_title'), 'Study Heatmap (24h x 30d)');
      expect(ko.tr('heatmap_title'), '공부 잔디 히트맵 (24h x 30d)');

      expect(pt.tr('presence_calendar'), 'Calendário de Presença');
      expect(en.tr('presence_calendar'), 'Attendance Calendar');
      expect(ko.tr('presence_calendar'), '출석 달력');

      expect(pt.tr('my_category'), 'Minha Categoria');
      expect(en.tr('my_category'), 'My Category');
      expect(ko.tr('my_category'), '내 카테고리');

      expect(pt.tr('region'), 'Região / País');
      expect(en.tr('region'), 'Region / Country');
      expect(ko.tr('region'), '지역 / 국가');
    });

    test('Translates Flashcards keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('new_flashcard'), 'Novo Flashcard');
      expect(en.tr('new_flashcard'), 'New Flashcard');
      expect(ko.tr('new_flashcard'), '새 플래시카드');

      expect(pt.tr('card_front'), 'Frente (Pergunta ou Termo)');
      expect(en.tr('card_front'), 'Front (Question or Term)');
      expect(ko.tr('card_front'), '앞면 (질문 또는 용어)');

      expect(pt.tr('card_back'), 'Verso (Resposta ou Definição)');
      expect(en.tr('card_back'), 'Back (Answer or Definition)');
      expect(ko.tr('card_back'), '뒷면 (정답 또는 정의)');
    });

    test('Translates Avatars and Live Study keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');
      final es = const AppTranslation(languageCode: 'es');

      expect(pt.tr('my_avatars'), 'Meus Avatares');
      expect(en.tr('my_avatars'), 'My Avatars');
      expect(ko.tr('my_avatars'), '내 아바타');
      expect(es.tr('my_avatars'), 'Mis Avatares');

      expect(pt.tr('no_avatars'), 'Nenhum avatar encontrado.');
      expect(en.tr('no_avatars'), 'No avatars found.');
      expect(ko.tr('no_avatars'), '아바타를 찾을 수 없습니다.');

      expect(pt.tr('no_studicons'), 'Nenhum avatar encontrado.');
      expect(en.tr('no_studicons'), 'No avatars found.');

      expect(pt.tr('default_avatar'), 'Avatar Padrão');
      expect(en.tr('default_avatar'), 'Default Avatar');
      expect(ko.tr('default_avatar'), '기본 아바타');

      expect(pt.tr('group_avatar'), 'Avatar do Grupo');
      expect(en.tr('group_avatar'), 'Group Avatar');
      expect(ko.tr('group_avatar'), '그룹 아바타');

      expect(pt.tr('equipped'), 'Equipado');
      expect(en.tr('equipped'), 'Equipped');
      expect(ko.tr('equipped'), '장착중');

      expect(pt.tr('equip'), 'Equipar');
      expect(en.tr('equip'), 'Equip');
      expect(ko.tr('equip'), '장착하기');

      expect(pt.tr('live_study'), 'Live Study');
      expect(en.tr('live_study'), 'Live Study');
      expect(ko.tr('live_study'), '라이브 스터디');

      expect(pt.tr('cam_study'), 'Live Study');
      expect(en.tr('cam_study'), 'Live Study');
      expect(ko.tr('cam_study'), '라이브 스터디');
    });

    test('Translates Login subtitle and Google keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('login_subtitle'), 'Insira suas credenciais para continuar');
      expect(en.tr('login_subtitle'), 'Enter your credentials to continue');
      expect(ko.tr('login_subtitle'), '계속하려면 로그인 정보를 입력하세요');

      expect(pt.tr('continue_with_google'), 'Continuar com o Google');
      expect(en.tr('continue_with_google'), 'Continue with Google');
      expect(ko.tr('continue_with_google'), 'Google로 계속하기');
    });

    test('Translates Timelapse keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('timelapse_gallery'), 'Galeria de Timelapse');
      expect(en.tr('timelapse_gallery'), 'Timelapse Gallery');
      expect(ko.tr('timelapse_gallery'), '타임랩스 갤러리');
    });

    test('Translates Profile keys', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final ko = const AppTranslation(languageCode: 'ko');

      expect(pt.tr('edit_nickname'), 'Alterar Apelido');
      expect(en.tr('edit_nickname'), 'Change Nickname');
      expect(ko.tr('edit_nickname'), '닉네임 변경');

      expect(pt.tr('edit_status_msg'), 'Alterar Mensagem de Status');
      expect(en.tr('edit_status_msg'), 'Change Status Message');
      expect(ko.tr('edit_status_msg'), '상태 메시지 변경');

      expect(pt.tr('delete_account'), 'Excluir Minha Conta');
      expect(en.tr('delete_account'), 'Delete My Account');
      expect(ko.tr('delete_account'), '계정 탈퇴');
    });

    test('Translates Leitor de PDF, Decks, Challenges, Terms, Privacy and FAQ modules', () {
      final pt = const AppTranslation(languageCode: 'pt');
      final en = const AppTranslation(languageCode: 'en');
      final es = const AppTranslation(languageCode: 'es');
      final ko = const AppTranslation(languageCode: 'ko');
      final ja = const AppTranslation(languageCode: 'ja');

      // 1. Flashcards subtexts
      expect(pt.tr('flashcard_desc'), 'Crie baralhos e adicione cartões para acelerar seus estudos.');
      expect(en.tr('flashcard_desc'), 'Create decks and add cards to accelerate your studies.');
      expect(es.tr('flashcard_desc'), 'Crea mazos y añade tarjetas para acelerar tus estudios.');
      expect(ko.tr('flashcard_desc'), '덱을 생성하고 카드를 추가하여 학습을 가속화하세요.');

      expect(pt.tr('cards'), 'cartões');
      expect(en.tr('cards'), 'cards');
      expect(ko.tr('cards'), '카드');

      // 2. Deck creation
      expect(pt.tr('new_deck'), 'Novo Baralho de Flashcards');
      expect(en.tr('new_deck'), 'New Flashcard Deck');
      expect(ko.tr('new_deck'), '새 플래시카드 덱');

      expect(pt.tr('deck_title'), 'Título do Baralho');
      expect(en.tr('deck_title'), 'Deck Title');
      expect(ko.tr('deck_title'), '덱 제목');

      expect(pt.tr('card_front'), 'Frente (Pergunta ou Termo)');
      expect(en.tr('card_front'), 'Front (Question or Term)');
      expect(ko.tr('card_front'), '앞면 (질문 또는 용어)');

      // 3. PDF Reader & Leitor de PDF
      expect(pt.tr('pdf_reader_title'), 'Leitor de PDF');
      expect(en.tr('pdf_reader_title'), 'PDF Reader');
      expect(ko.tr('pdf_reader_title'), 'PDF 뷰어');

      expect(pt.tr('pdf_reader_empty_title'), 'Leitor de PDF (Materiais e Apostilas)');
      expect(en.tr('pdf_reader_empty_title'), 'PDF Reader (Materials & Books)');
      expect(ko.tr('pdf_reader_empty_title'), 'PDF 뷰어 (학습 자료 및 교재)');

      // 4. Challenges
      expect(pt.tr('challenges'), 'Desafios');
      expect(en.tr('challenges'), 'Challenges');
      expect(ko.tr('challenges'), '챌린지');

      expect(pt.tr('no_my_challenges'), 'Você ainda não entrou em nenhum desafio.');
      expect(en.tr('no_my_challenges'), "You haven't joined any challenges yet.");
      expect(ko.tr('no_my_challenges'), '아직 참여한 챌린지가 없습니다.');

      expect(pt.tr('do_checkin'), 'Fazer Check-in');
      expect(en.tr('do_checkin'), 'Do Check-in');
      expect(ko.tr('do_checkin'), '출석체크 하기');

      // 5. Terms & Privacy
      expect(pt.tr('drawer_settings_pallo_terms_title'), 'Termos de Uso e Serviço');
      expect(en.tr('drawer_settings_pallo_terms_title'), 'Terms of Service');
      expect(ko.tr('drawer_settings_pallo_terms_title'), '이용약관 및 서비스 약관');

      expect(pt.tr('terms_sec1_title'), '1. Aceitação dos Termos');
      expect(en.tr('terms_sec1_title'), '1. Acceptance of Terms');
      expect(ko.tr('terms_sec1_title'), '1. 약관의 동의');

      expect(pt.tr('privacy_sec1_title'), '1. Informações que Coletamos');
      expect(en.tr('privacy_sec1_title'), '1. Information We Collect');
      expect(ko.tr('privacy_sec1_title'), '1. 수집하는 개인정보');

      // 6. FAQ
      expect(pt.tr('faq_title'), 'Ajuda & FAQ');
      expect(en.tr('faq_title'), 'Help & FAQ');
      expect(ko.tr('faq_title'), '도움말 및 자주 묻는 질문');
      expect(ja.tr('faq_title'), 'ヘルプ＆FAQ');

      expect(pt.tr('faq_q1_title'), 'Como funciona o Cronômetro e o modo Pomodoro?');
      expect(en.tr('faq_q1_title'), 'How does the Stopwatch and Pomodoro mode work?');
      expect(ko.tr('faq_q1_title'), '스톱워치와 뽀모도로 모드는 어떻게 동작하나요?');

      // 7. Legal Disclaimer
      expect(pt.tr('legal_disclaimer'), contains('Desky é um cliente desktop independente'));
      expect(en.tr('legal_disclaimer'), contains('Desky is an independent third-party client'));
      expect(ko.tr('legal_disclaimer'), contains('Desky는 독립적인 서드파티 클라이언트'));

      // 8. Rankings Position
      expect(pt.tr('my_position'), 'Minha Posição');
      expect(en.tr('my_position'), 'My Rank');
      expect(ko.tr('my_position'), '내 순위');
      expect(es.tr('my_position'), 'Mi Posición');
      expect(ja.tr('my_position'), 'マイランク');
    });
  });
}
