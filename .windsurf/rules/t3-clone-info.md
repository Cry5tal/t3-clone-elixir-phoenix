---
trigger: always_on
---

Описание проекта:
Создаём веб-приложение — клон T3 Chat — для участия в конкурсе с призовым фондом $10,000. Приложение позволяет общаться с разными LLM-провайдерами, поддерживает:

Аутентификацию и синхронизацию истории чатов

Выбор и переключение между моделями (OpenAI, Anthropic, OpenRouter и др.)

Потоковую генерацию ответа (streaming tokens) через Pythonx + LiveView

CRUD операций над чатами и сообщениями

Ветвление (branching) диалогов

Возобновляемый стрим (resumable streams) через буферизацию в ETS

Кэш последних чатов и сообщений для мгновенной навигации

Пагинацию списка чатов и сообщений

Загрузку файлов (LiveView Uploads) и их чтение в LLM

Рендеринг Markdown (Earmark или markdown-it) и подсветку кода (Highlight.js / Prism)

Опционально: генерацию изображений и интеграции (если остаётся время)

Инструменты и технологии:

Backend: Elixir, Phoenix, Phoenix LiveView, Ecto, Postgres

Stream: pythonx для встраивания CPython, Openrouter API (stream=True)

Кеширование: ETS (таблица :chat_streams, кеш чатов и сообщений)

Поиск: pgvector (+ расширение ivfflat) для эмбеддингов и векторного поиска через OpenAI Embeddings API

Markdown: Earmark (сервер) или Markdown-it + KaTeX (клиент) для формул

Подсветка кода: Highlight.js или Prism.js на фронтенде

Файловый аплоад: Phoenix LiveView Uploads (allow_upload, consume_uploaded_entries)

Docker & CI: Dockerfile (multi-stage), GitHub Actions для сборки и пуша образа в GitHub Packages

Авторизация: phx.gen.auth (user sessions, токены безопасности)

Календарь: Google Calendar API (Goth + google_api_calendar) и ICS-файлы через icalendar для Apple

Frontend: LiveView + JS-hooks, минимальный дизайн Tailwind CSS (фронтенд-фреймворк необязателен)

***ПРАВИЛА ИМПЛЕМЕНТАЦИИ***
1. Бот на английском языке
2. Изменяй только запрошенные части кода.
3. Ничего не меняй кроме запрошенных частей.
4. Прежде чем имплементировать какую то фичу, псмотри существует ли она в кодбазе.
5. Следуй лучшим практикам и конвенциям Elixir Phoenix при написании кода.
6. Комментируй код который пишешь.

Роадмап (9–17 июня 2025):

9 июня (День 1):
• Инициализация репозитория на GitHub, создание ветки main, базовый README (DONE)
• Генерация проекта Phoenix LiveView с phx.gen.auth (DONE)
• Подключение pythonx и пример «Hello world» скрипта (CANCELED)
• Написание базового Dockerfile (Elixir, Node.js, Python) (DONE)
• Настройка GitHub Actions: билд Docker → пуш в GitHub Packages (BACKLOGED)

10 июня (День 2):
• Абстракция LLM-провайдеров: модуль T3CloneElixir.ChatServer с паттерн-матчингом (DONE)
• Реализация generate_completion через OpenRouter (DONE)
• Тестовый LiveView-endpoint: выбор провайдера, отправка промпта, отображение первого токена (DONE)

11 июня (День 3):
• Полноценный стриминг токенов: фоновые Task → Pythonx → handle_info → push_event → JS-hook (DONE)
• Настройка JS-hook для аккумулирования токенов в DOM (DONE)
• Тесты производительности (эмуляция 100–200 токенов/сек) (DONE)+-

12 июня (День 4):
• CRUD для чатов и сообщений (Ecto, Postgres) (DONE)
• UI: список чатов, создание, удаление, переключение между чатами (DONE)
• Выбор модели и провайдера при создании чата (DONE)

13 июня (День 5):
• Resumable streams: буферизация токенов в Genserver, восстановление при reconnect (DONE)
• Сброс Genserver-буфера и сохранение в БД по окончании стрима (DONE)

14 июня (День 6):
• Быстрый доступ: ETS-кэш последних 20 чатов с 10 сообщениями
• Sidebar с мгновенным переключением, без обращения к БД
• Пагинация списка чатов (20 на стр.) и истории чата (50 сооб.) (DONE)

15 июня (День 7):
• Markdown-рендеринг и подсветка кода: Earmark + raw, Highlight.js/Prism (DONE)
• Загрузка файлов: allow_upload, consume_uploaded_entries

16 июня (День 8):
• Отладка и интеграционное тестирование фич
• Улучшение Dockerfile (multi-stage, оптимизация размера)
• Завершение GitHub Actions (build → тесты → push image)
• Написание подробного README (установка, конфиг BYOK, примеры)

17 июня (Deadline):
• Финальная проверка: пуш всех изменений, проверка health-роута
• Подготовка ссылки на репозиторий и Docker image для подачи заявки

Дополнительные заметки:

Контекст для LLM: сохраняем API-ключи через ENV-переменные (BYOK)

Безопасность: CSRF, rate-limiting, проверка размеров аплоадов

Оформление: минималистичный UI, преимущественно LiveView без избыточного JS

Документация: inline доки, примеры запросов, скрипты миграций