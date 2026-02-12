<p align="center">
  <img src="assets/studio_logo_black.png" alt="PIXEL-FORGE" width="280"/>
</p>

# Lumen Cascade

<p align="center">
  <img src="assets/maxresdefault.jpg" alt="Lumen Cascade" width="320"/>
</p>

<p align="center">
  <strong>Vertical space shooter</strong> · Godot 4.5 · RU / EN · <strong>Яндекс Игры</strong>
</p>

<p align="center">
  <a href="https://godotengine.org"><img src="https://img.shields.io/badge/Godot-4.5-478cbf?logo=godot-engine" alt="Godot 4.5"/></a>
  <a href="https://yandex.ru/games"><img src="https://img.shields.io/badge/Яндекс_Игры-платформа-red" alt="Яндекс Игры"/></a>
  <a href="#лицензия"><img src="https://img.shields.io/badge/лицензия-образовательный_проект-lightgrey" alt="Лицензия"/></a>
</p>

---

## О игре

**Lumen Cascade** — вертикальный космический шутер: управляй кораблём, сбивай врагов, собирай буффы и держись как можно дольше.

- Корабль с разными двигателями и оружием  
- Враги и боссы  
- Буффы (щит, усиления)  
- Взрывы и постобработка  
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

1. Установи [Godot 4.5](https://godotengine.org/download) (режим GL Compatibility).
2. Клонируй репозиторий и открой папку проекта в Godot.
3. Запусти сцену `main_menu` или нажми F5.

Экспорт под Desktop / Web / Android — через **Project → Export**.

**Ссылка на игру (Яндекс Игры):** добавь сюда URL после публикации.

## Структура проекта

| Папка / файл | Назначение |
|--------------|------------|
| `scenes/` | Сцены: игрок, враги, пули, буффы, UI (меню, HUD, game over) |
| `scripts/` | Логика: `yandex_games.gd` (обёртка SDK), меню, HUD, враги, пули |
| `assets/` | Спрайты, фоны, логотипы, анимации |
| `shaders/` | Heat distort, post-fx |
| `translations/` | Локализация (RU/EN) |
| `custom_html_shell.html` | HTML-оболочка для веб-экспорта с Яндекс SDK |

## Платформа Яндекс Игры

Игра разработана и публикуется на [Яндекс Играх](https://yandex.ru/games/). В веб-сборке используется **Yandex Games SDK v2**:

- **Player** — авторизация (`openAuthDialog`), данные игрока (`getPlayer`), локаль (`get_sdk_locale`)
- **Leaderboards** — отправка счёта (`setScore`), топ и позиция игрока (`getEntries`, `getPlayerEntry`)
- **Rewarded** — реклама за продолжение после Game Over (`showRewardedVideo`)
- **GameplayAPI** — старт/стоп геймплея, события паузы (`game_api_pause` / `game_api_resume`)
- **Flags** — A/B-флаги (`getFlags`)

Обёртка над SDK: `scripts/yandex_games.gd`; инициализация в `web_bild/index.html` и `custom_html_shell.html`.

## Технологии

- **Godot** 4.5, GDScript  
- Шейдеры (heat distort, post-fx)  
- Переводы через CSV  

## Сборка веб-версии (Яндекс Игры)

1. **Project → Export** → пресет HTML5.
2. В качестве **Custom HTML** укажи `custom_html_shell.html` (в нём уже подключён Yandex Games SDK v2).
3. Собери билд и залей на сервер / загрузи в кабинет разработчика Яндекс Игр.

## Лицензия

Проект представлен в образовательных целях. Ресурсы (спрайты, музыка) могут иметь свои лицензии.

---

<p align="center">
  <img src="assets/studio_logo_black.png" alt="PIXEL-FORGE" width="160"/>
</p>
<p align="center">
  <sub>SPRITE-FORGE</sub>
</p>
