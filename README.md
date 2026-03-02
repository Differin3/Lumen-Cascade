<p align="center">
  <img src="assets/studio_logo_black.png" alt="PIXEL-FORGE" width="280"/>
</p>

<h1 align="center">Lumen Cascade</h1>

<p align="center">
  <img src="assets/maxresdefault.jpg" alt="Lumen Cascade" width="320"/>
</p>

<p align="center">
  <strong>Vertical space shooter</strong> · Godot 4.6 · RU / EN · <strong>Яндекс Игры</strong>
</p>

<p align="center">
  <a href="https://godotengine.org"><img src="https://img.shields.io/badge/Godot-4.6-478cbf?logo=godot-engine" alt="Godot 4.6"/></a>
  <a href="https://yandex.ru/games/app/lumen-cascade-308818"><img src="https://img.shields.io/badge/Яндекс_Игры-страница_игры-ffcc00?logo=yandex&logoColor=000" alt="Lumen Cascade на Яндекс Играх"/></a>
  <a href="#лицензия"><img src="https://img.shields.io/badge/лицензия-личный_коммерческий-green" alt="Лицензия"/></a>
</p>

<p align="center">
  <a href="https://yandex.ru/games/app/lumen-cascade-308818">
    <img src="https://img.shields.io/badge/Играть%20в%20Lumen%20Cascade-Яндекс%20Игры-ffcc00?logo=yandex&logoColor=000" alt="Играть в Lumen Cascade на Яндекс Играх"/>
  </a>
</p>

---

## Об игре

**Lumen Cascade** — вертикальный космический шутер: управляй кораблём, сбивай врагов, собирай баффы и держись как можно дольше.

- Корабль с разными двигателями и оружием  
- Враги и боссы  
- Баффы (щит, ракеты)  
- Взрывы и постобработка  
- Централизованное управление звуком (музыка, SFX, UI)  
- Локализация: русский и английский  

## Скриншоты

<table>
<tr>
<td align="center"><img src="screenshots/2d7CROtF8u.png" alt="Меню и геймплей" width="480"/></td>
<td align="center"><img src="screenshots/merged-image-1769800124855.png" alt="Геймплей" width="480"/></td>
</tr>
</table>

## Управление

| Действие | Клавиши / Геймпад |
|----------|-------------------|
| Движение | WASD / стрелки / левый стик |
| Стрельба | ЛКМ / кнопка огня |
| Буст     | Space |
| Пауза   | ESC |

## Запуск

1. Установи [Godot 4.6](https://godotengine.org/download) (режим GL Compatibility).
2. Клонируй репозиторий и открой папку проекта в Godot.
3. Запусти сцену `main_menu` или нажми F5.

Экспорт под Desktop / Web / Android — через **Project → Export**.

**Ссылка на игру (Яндекс Игры):** [Играть в Lumen Cascade](https://yandex.ru/games/app/lumen-cascade-308818)

## Структура проекта

| Папка / файл | Назначение |
|--------------|------------|
| `scenes/` | Сцены: игрок, враги, пули, баффы, UI (меню, HUD, game over, пауза) |
| `scripts/` | Логика: `main.gd` (уровень), `yandex_games.gd` (обёртка SDK), `AudioManager.gd` (звук), `remote_config.gd` (флаги), меню, HUD, game_over, враги, пули |
| `assets/` | Спрайты, фоны, шрифты (Project Space), тема (cosmic_theme) |
| `shaders/` | Heat distort, post-fx |
| `translations/` | Локализация (RU/EN) |
| `custom_html_shell.html` | HTML-оболочка для веб-экспорта с Яндекс SDK |

## Аудиосистема

Централизованное управление звуком через **AudioManager** (Autoload):

- **Регистрация** — все `AudioStreamPlayer` регистрируются в менеджере (типы: Music, SFX, UI)
- **Пауза / возобновление** — при ESC, потере фокуса вкладки, паузе SDK звук ставится на паузу и возобновляется с того же места
- **Полная остановка** — при смерти и показе rewarded-рекламы (требование Яндекс.Игр)
- **Настройки** — громкость и mute сохраняются в `user://audio_settings.cfg`

## Платформа Яндекс Игры

Игра разработана и публикуется на [Яндекс Играх](https://yandex.ru/games/). В веб-сборке используется **Yandex Games SDK v2**:

- **Player** — авторизация (`openAuthDialog`), данные игрока (`getPlayer`), локаль (`get_sdk_locale`)
- **Leaderboards** — отправка счёта (`setScore`), топ и позиция игрока (`getEntries`, `getPlayerEntry`)
- **Rewarded** — реклама за продолжение после Game Over (кнопка «Продолжить» + пометка «за просмотр рекламы»)
- **GameplayAPI** — старт/стоп геймплея, события паузы (`game_api_pause` / `game_api_resume`)
- **Flags** — A/B-флаги (`getFlags`) для Remote Config. Таблица флагов:

| Флаг | По умолчанию | Описание |
|------|--------------|----------|
| `difficult` | `easy` | Уровень сложности (зарезервировано) |
| `enemy_hp` | `5` | HP врагов |
| `enemy_spawn_rate` | `1.5` | Интервал спавна врагов, сек |
| `rocket_spawn_rate` | `70` | Интервал спавна баффа «ракеты», сек |
| `shield_spawn_rate` | `100` | Интервал спавна баффа «щит», сек |

Обёртка над SDK: `scripts/yandex_games.gd`; инициализация в `web_bild/index.html` и `custom_html_shell.html`.

## Шрифты

Проект использует шрифт **Project Space** (Alexander Sviridov) — космический стиль с поддержкой кириллицы.

| Файл | Назначение |
|------|------------|
| `assets/fonts/Project Space Font/` | Исходные шрифты (ttf, otf) |
| `assets/theme/cosmic_font_bold.tres` | FontVariation с `variation_embolden = 0.35` |
| `assets/theme/cosmic_theme.tres` | Глобальная тема (подключена в Project Settings → GUI) |

Шрифты распространяются по [SIL Open Font License 1.1](http://scripts.sil.org/OFL) — **можно свободно использовать** в проекте, README, модифицировать и распространять. Подробности в `assets/fonts/Project Space Font/OFL.txt`.

## Технологии

- **Godot** 4.6, GDScript  
- Шрифт **Project Space**, тема `cosmic_theme.tres`  
- Шейдеры (heat distort, post-fx)  
- Переводы через CSV (RU/EN)  

## CI / CD

GitHub Actions автоматически собирает веб-версию при каждом push в `main`/`master` и при создании тега `v*`.

| Триггер | Действие |
|---------|----------|
| Push в main/master | Экспорт HTML5, артефакт `web-build` |
| Pull Request | Экспорт HTML5 (проверка сборки) |
| Тег `v*` (напр. `v0.1.0`) | Экспорт + создание Release с артефактами |

Workflow: [.github/workflows/ci.yml](.github/workflows/ci.yml). Используется [firebelley/godot-export](https://github.com/firebelley/godot-export).

## Сборка веб-версии (Яндекс Игры)

1. **Project → Export** → пресет HTML5.
2. В качестве **Custom HTML** укажи `custom_html_shell.html` (в нём уже подключён Yandex Games SDK v2).
3. Собери билд и залей на сервер / загрузи в кабинет разработчика Яндекс Игр.

## Лицензия

Личный коммерческий проект. Ресурсы (спрайты, музыка) могут иметь свои лицензии.

---

<p align="center">
  <img src="assets/studio_logo_black.png" alt="PIXEL-FORGE" width="160"/>
</p>
<p align="center">
  <sub>SPRITE-FORGE</sub>
</p>
