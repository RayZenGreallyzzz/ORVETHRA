# ORVETHRA

Оригинальная 3D fantasy RPG (будущая MMORPG) на Godot 4.

**Тестируем на Android-планшете IT-801C:** Allwinner A523, 4 ГБ RAM, Android 15. Godot Compatibility и целевые 30 FPS.

## Полная сборка v0.5
- Архив `ORVETHRA_v05_Source.zip` содержит полную улицу с текстурами, основное меню с утверждённой обложкой и выбор персонажа.
- Workflow распаковывает этот архив перед Android-экспортом. В отдельных файлах репозитория также есть облегчённое тестовое меню.
- Готовый APK появляется во вкладке Actions после успешной сборки.

## v0.6 — тренировочные бои (офлайн)
- Три простых существа на поляне справа от городского входа
- Выбор монстра касанием или кнопкой, удар на расстоянии до 5,5 м
- HP героя и врага, ответный урон, возвращение в город при потере здоровья
- Опыт, уровень, тестовое серебро, автоматическое возрождение монстров
- Локальное сохранение прогресса, кнопка возврата в меню

Важно: это **тестовая локальная механика**, а не сетевой сервер или настоящая денежная валюта. Монстры пока без сложной анимации и ИИ. Вход Google всё ещё не подключён. Для теста: Гость → Локальный мир → герой → город, затем двигайся вправо от площади к тренировочной поляне.

## Новое в v0.5
- Рабочая навигация: Главное меню → Google (пока заглушка) или гость → локальный мир → создание персонажа → город.
- Локальное сохранение персонажа на устройстве, выбор расы и класса.
- Вариант оформления для утверждённой обложки `assets/title_cover.jpg` (сам файл изображения отдельно доступен в ZIP полного исходного проекта ORVETHRA v0.5, его нужно загрузить в репозиторий для художественного фона APK).
- Google авторизация и онлайн-сервер пока **не подключены**; нет реальной регистрации.

## Что сейчас в репозитории
- Лёгкая игровая 3D-сцена с персонажем от третьего лица
- Стартовая ремесленная улица, таверна, кузница и магическая лавка
- Дверные проходы, мебель внутри, крыши скрываются при входе
- Сенсорное управление на планшете, поворот камеры свайпом справа
- Отдельная настройка графики и измеритель FPS

Это **ранняя техническая проверка**, не полная версия v0.4 и не готовая MMORPG. Текстуры и сложные модели прежнего ZIP пока не перенесены.

## APK без компьютера
Вкладка [Actions](../../actions/workflows/android-debug.yml) → последний успешный запуск → внизу **Artifacts** → `ORVETHRA-IT801C-debug` (ZIP с APK).

GitHub Actions запускается после коммита в `main`. Не обещаем работоспособность до первого успешного экспорта и установки на планшет.

## Импорт предыдущей версии
Если добавить в корень репозитория **Aetherfall_Android_Build_Kit_v04.zip** из нашего чата, workflow автоматически распакует его вместо маленькой тестовой сцены и соберёт старую полноценную улицу v0.4 (меняя имя Android-приложения на ORVETHRA). Исходный ZIP сохранён в разговоре.

## План
Сначала APK, входы в здания, стабильный FPS и тач-управление. После теста: оптимизированный город, внешняя карта, монстры, питомцы с картами и подземелья.

© Авторы проекта ORVETHRA. Пока приватных ключей подписи нет; только тестовый debug APK.


## ORVETHRA Modular Manor Builder (Android v0.33)

From the city choose **☰ → 🧱 Конструктор особняка · детали**. The editor uses **17 built-in original modular pieces** (foundation, stone/wood floors, ceiling, balcony, stone/timber walls, door and window walls, arch, railing, pitched/flat roofs, ridge, stair, pillar, chimney). Touch the map to snap pieces to a 3 m grid; use 90° rotation, floor up/down (six levels), green/red ghost placement, copy, delete, undo/redo, roof hide, and floor isolation. Tap ✓ Закрепить to persist the change. Blueprints are saved automatically in `user://orvethra_modular_city_v1.json`, separate from `user://orvethra_city_layout_v1.json`, and reload on game startup. This **prototype works offline without imported GLBs**. Static repeated meshes are drawn in MultiMesh batches, with simple collision geometry; later iterations will add supporting checks, roof snap/room systems, stair navigation polish and polished 3D architectural assets. The earlier whole-building editor remains available under **Редактор города · здания**.
