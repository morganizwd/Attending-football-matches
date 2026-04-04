# Посещение футбольных матчей (Attending Football Matches)

Мобильное приложение для учёта посещения футбольных матчей по геолокации. Дипломный MVP на **Flutter + Firebase**.

---

## Содержание

1. [Что нужно установить на компьютер](#1-что-нужно-установить-на-компьютер)
2. [Клонирование и первый запуск](#2-клонирование-и-первый-запуск)
3. [Настройка Firebase (обязательно)](#3-настройка-firebase-обязательно)
4. [Запуск приложения](#4-запуск-приложения)
5. [Сборка APK для Android](#5-сборка-apk-для-android)
6. [Первый администратор](#6-первый-администратор)
7. [Настройки в приложении](#7-настройки-в-приложении)
8. [Константы логики (геолокация)](#8-константы-логики-геолокация)
9. [Структура проекта](#9-структура-проекта)
10. [Типичные проблемы](#10-типичные-проблемы)
11. [Внешние API (реальные матчи)](#11-внешние-api-реальные-матчи)

---

## 1. Что нужно установить на компьютер

| Инструмент | Зачем |
|------------|--------|
| **Git** | Клонировать репозиторий |
| **Flutter SDK** (stable) | Сборка и запуск (`flutter doctor` должен быть без критичных ошибок для вашей цели) |
| **Android Studio** (рекомендуется) | Android SDK, эмулятор, сборка APK |
| **Google Chrome** | Запуск веб-версии (`flutter run -d chrome`) |
| **Аккаунт Firebase** | Backend: Auth, Firestore |

**Windows (опционально):** для сборки **нативного Windows-приложения** нужен **Visual Studio** с рабочей нагрузкой **«Разработка классических приложений на C++»**. Для **Chrome** и **Android** это не обязательно.

**Windows:** для симлинков плагинов Flutter включите **Режим разработчика** (Параметры → Конфиденциальность и безопасность → Для разработчиков).

---

## 2. Клонирование и первый запуск

```bash
git clone <url-репозитория>
cd Attending-football-matches
flutter pub get
```

Проверка окружения:

```bash
flutter doctor -v
```

- Для **Android**: в `flutter doctor` должна быть настроена цепочка **Android toolchain** (установлен SDK через Android Studio или вручную).
- Если папок `android/` / `ios/` нет (редкий случай), создайте оболочку проекта в корне:

```bash
flutter create . --project-name attending_football_matches
```

Затем снова `flutter pub get`.

---

## 3. Настройка Firebase (обязательно)

### 3.1. Создание проекта в Firebase Console

1. Зайдите на [Firebase Console](https://console.firebase.google.com/).
2. Создайте проект (или выберите существующий).

### 3.2. Подключение приложений

**Android**

1. **Add app** → **Android**.
2. **Package name** должен совпадать с `applicationId` в `android/app/build.gradle.kts` (по умолчанию: `com.example.attending_football_matches`).
3. Скачайте **`google-services.json`** и положите в **`android/app/`** (рядом с `build.gradle.kts`).

**Web (для запуска в Chrome)**

1. **Add app** → **Web**.
2. Скопируйте из конфига **`apiKey`** и **`appId`**.
3. Откройте **`lib/firebase_options.dart`** и подставьте значения в `DefaultFirebaseOptions.web` (вместо плейсхолдеров).

**iOS** (если понадобится): скачайте `GoogleService-Info.plist` в `ios/Runner/` по инструкции Firebase.

### 3.3. Authentication

1. **Build** → **Authentication** → **Get started**.
2. **Sign-in method** → включите **Email/Password** (при необходимости — Anonymous).

### 3.4. Cloud Firestore

1. **Build** → **Firestore Database** → создайте базу (режим для разработки можно выбрать тестовый, затем замените правила).
2. **Rules**: скопируйте содержимое **`firestore.rules`** из репозитория в редактор правил и нажмите **Publish**.

### 3.5. Индексы Firestore

При первых запросах Firebase может показать ссылку «создать индекс». В частности, для фильтра **«Только мои матчи»** нужен составной индекс по коллекции **`intents`**:

- поле **`userId`** (Ascending)
- поле **`createdAt`** (Descending или Ascending — как в запросе)

Создайте индекс по ссылке из ошибки в консоли или импортируйте **`firestore.indexes.json`**, если используете Firebase CLI.

### 3.6. Что уже настроено в репозитории (Android)

- Подключён плагин **Google Services** для чтения `google-services.json`.
- Для пакета **flutter_local_notifications** включён **core library desugaring** в `android/app/build.gradle.kts`.
- В **`AndroidManifest.xml`** объявлены разрешения на геолокацию (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`).

После правок Firebase пересоберите проект: `flutter clean && flutter pub get`.

---

## 4. Запуск приложения

Все команды выполняются из **корня проекта** (где лежит `pubspec.yaml`).

### 4.1. Список устройств

```bash
flutter devices
```

Пример вывода: `SM ... (mobile) • RF8T80QFSWZ • android-arm64` — **ID устройства** — это средняя колонка (`RF8T80QFSWZ`).

### 4.2. Запуск в режиме отладки

```bash
flutter run
```

Выберите номер устройства из списка или укажите явно:

```bash
flutter run -d chrome
flutter run -d windows
flutter run -d <device_id>
```

### 4.3. Запуск в Chrome (веб)

```bash
flutter run -d chrome
```

Нужны заполненные **`lib/firebase_options.dart`** для Web и включённый веб-приложение в Firebase.

### 4.4. Запуск на Android-телефоне (USB)

1. На телефоне: **Настройки** → **О телефоне** — 7 раз нажмите **Номер сборки** (режим разработчика).
2. **Настройки** → **Для разработчиков** → включите **Отладка по USB**.
3. Подключите USB, разрешите отладку на запросе телефона.
4. На ПК:

```bash
flutter devices
flutter run -d <device_id>
```

### 4.5. Release на телефоне (как у пользователя)

```bash
flutter run --release -d <device_id>
```

Удобно для проверки производительности и геолокации без отладчика.

---

## 5. Сборка APK для Android

Убедитесь, что **`flutter doctor`** видит **Android SDK** (через Android Studio).

```bash
flutter pub get
flutter build apk --release
```

Готовый файл:

- `build/app/outputs/flutter-apk/app-release.apk`

Уменьшить размер (несколько APK под ABI):

```bash
flutter build apk --release --split-per-abi
```

Установка через ADB:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

---

## 6. Первый администратор

1. Зарегистрируйтесь в приложении (email/password).
2. В **Firestore** откройте коллекцию **`users`**, документ с **`uid`** вашего пользователя.
3. Установите поле **`isAdmin`**: `true` (boolean).
4. Перезапустите приложение — внизу появится вкладка **Админ**.

---

## 7. Настройки в приложении

- **Тема**: Профиль → «Тема приложения» (системная / светлая / тёмная).
- **Размер шрифта**: Профиль → «Размер шрифта» (слайдер). Значение сохраняется локально на устройстве (`shared_preferences`).

---

## 8. Константы логики (геолокация)

Файл **`lib/core/constants.dart`**:

| Константа | Смысл |
|-----------|--------|
| `stadiumProximityMeters` | Радиус (м), внутри которого пользователь считается у стадиона (по умолчанию 500). |
| `minutesBeforeMatchStart` | За сколько минут до начала матча разрешена проверка геолокации. |
| `minutesAfterMatchStart` | Сколько минут после начала матча ещё учитывается посещение. |
| `locationCheckIntervalSeconds` | Интервал фоновых проверок (если используется). |

---

## 9. Структура проекта

| Путь | Назначение |
|------|------------|
| `lib/core/` | Тема (`theme.dart`), константы |
| `lib/models/` | Модели данных |
| `lib/services/` | Auth, Location, Attendance, Notifications, Theme, TextScale, `football_api/` (API-Football, football-data.org), геокодинг арен |
| `lib/features/` | Экраны: auth, home, matches, history, profile, admin, achievements |
| `firestore.rules` | Правила безопасности Firestore |
| `firestore.indexes.json` | Описание составных индексов |
| `android/app/google-services.json` | Конфиг Firebase для Android |
| `lib/firebase_options.dart` | Опции Firebase для Web (и при необходимости можно расширить) |

---

## 10. Типичные проблемы

### Белый экран в Chrome / ошибка FirebaseOptions

Заполните **`lib/firebase_options.dart`** для Web и добавьте веб-приложение в Firebase. В `main.dart` для веба используется `DefaultFirebaseOptions.web`.

### Белый экран / краш на Android при старте

- Проверьте, что **`google-services.json`** лежит в **`android/app/`** и совпадает package name приложения.
- В проекте должен быть применён плагин **com.google.gms.google-services** (см. `android/settings.gradle.kts` и `android/app/build.gradle.kts`).

### Ошибка сборки: `flutter_local_notifications requires core library desugaring`

В **`android/app/build.gradle.kts`** должны быть включены desugaring и зависимость `desugar_jdk_libs` (уже в репозитории).

### `The query requires an index` (Firestore)

Откройте ссылку из ошибки в консоли Firebase и создайте индекс, либо задеплойте индексы из `firestore.indexes.json`.

### Геолокация: кнопка крутится, нет разрешения

- В манифесте должны быть `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION`.
- При первом нажатии должен появиться системный диалог; если нет — проверьте настройки приложения на телефоне.

### Сборка Windows: symlink / Visual Studio

- Включите **режим разработчика** (симлинки).
- Для `flutter run -d windows` установите **Visual Studio** с рабочей нагрузкой **Desktop development with C++**.
- Если при сборке **CMake** пишет про *«Compatibility with CMake &lt; 3.5 has been removed»* (Firebase C++ SDK), в проекте уже задан обходной флаг в `windows/CMakeLists.txt` для **CMake 4.x**. После обновления Flutter/Firebase выполните `flutter clean` и снова `flutter run -d windows`.

### Предупреждения Gradle `source value 8 is obsolete`

Это предупреждения от старых зависимостей; сборка обычно всё равно успешна. На результат `flutter build apk` можно не ориентироваться, если в конце есть `Built ... app-release.apk`.

---

## 11. Внешние API (реальные матчи)

Список матчей в приложении объединяет **локальные матчи из Firestore** (админка) и **данные внешних API**, если заданы ключи.

### Переменные: `.env` и `--dart-define`

При старте вызывается `loadDotEnv()` (`lib/core/env_loader.dart`). В репозитории всегда есть шаблон **`assets/env/env.example`** (подключён в `pubspec.yaml`), поэтому сборка не падает из‑за отсутствующего файла.

**Приоритет:** непустое значение из **dotenv** (файлы) → иначе **`--dart-define`** при сборке.

**Вариант A — корневой `.env` (Windows / macOS / Linux, не веб):** в **режиме отладки** (`flutter run`) приложение **само** читает файл `.env` из **корня проекта** (рядом с `pubspec.yaml`), его **не** обязательно добавлять в `assets`. После изменения `.env` сделайте **полный перезапуск** (не только hot reload).

**Вариант B — `assets/env/local.env` (в т.ч. Chrome / web):** в браузере **нет** доступа к файлу `.env` на диске. Скопируйте `assets/env/env.example` → `assets/env/local.env`, заполните ключи, добавьте в `pubspec.yaml`:

```yaml
  assets:
    - assets/images/
    - assets/env/env.example
    - assets/env/local.env
```

`assets/env/local.env` указан в `.gitignore`, в git не попадает.

**После клонирования репозитория** без файла `assets/env/local.env` сборка упадёт (файл указан в `pubspec.yaml`). Скопируйте шаблон и вставьте ключи:

```bash
copy assets\env\env.example assets\env\local.env
# отредактируйте local.env
```

Без `local.env` приложение читает только **`assets/env/env.example`** — для веба ключи тогда задавайте через **`--dart-define`**.

### API-Football (api-sports.io)

Регистрация: [API-Football](https://www.api-football.com/) — ключ передаётся заголовком `x-apisports-key`.

Пример запуска (несколько лиг через запятую):

```bash
flutter run --dart-define=API_FOOTBALL_KEY=ВАШ_КЛЮЧ ^
  --dart-define=API_FOOTBALL_LEAGUE_IDS=39,140,78,61
```

По умолчанию, если `API_FOOTBALL_LEAGUE_IDS` не задан, используется лига **39** (Premier League). Справочник ID лиг — в документации API-Football.

Матчи получаются за диапазон **примерно −14…+60 дней** от текущей даты, с учётом **сезона** (европейский календарь июль–июнь).

### football-data.org

Регистрация: [football-data.org](https://www.football-data.org/) — токен в заголовке `X-Auth-Token`.

```bash
flutter run --dart-define=FOOTBALL_DATA_TOKEN=ВАШ_ТОКЕН
```

Запрос: `GET /v4/matches` с параметрами `dateFrom` / `dateTo`. В ответе обычно **нет координат арены** — для геолокации приложение может **геокодировать** название арены (см. ниже).

### Как это работает в приложении

- У матчей из API идентификаторы с префиксами **`af_`** (API-Football) и **`fde_`** (football-data.org).
- Если заданы **оба** источника, дубликаты одной и той же игры (те же команды и то же время начала, с точностью до минуты) **склеиваются**; приоритет у матча из **Firestore**, затем у первого успешно загруженного внешнего источника.
- **Геолокация и фото стадиона для API-матчей**: если API вернуло название арены, приложение пытается найти координаты через веб-геокодинг (Nominatim, fallback на `geocoding`) и фото стадиона (Unsplash при наличии `UNSPLASH_ACCESS_KEY`, иначе Wikimedia). Результаты кэшируются.
- **История и достижения**: при засчитывании посещения по матчу из API в документ `attendances` пишутся поля **`matchHomeTeamSnapshot`**, **`matchAwayTeamSnapshot`**, **`matchLeagueSnapshot`**, чтобы заголовок матча отображался без документа в коллекции `matches`.

### Flutter Web (Chrome) и CORS

В **браузере** запросы к внешним API идут с вашего `http://localhost:…` — сервер должен явно разрешать такой origin (заголовок `Access-Control-Allow-Origin`). У **football-data.org** в типичной конфигурации это **не совпадает** с `localhost` с портом, поэтому в коде **запросы к football-data.org на Web отключены** (на Windows/Android/iOS они выполняются как обычно).

**API-Football** в Chrome может заработать или тоже упасть по CORS — зависит от политики api-sports. Если список матчей из сети **пустой** при работающих ключах, запустите **`flutter run -d windows`** или сборку на **телефоне**.

### Сборка APK с ключами

```bash
flutter build apk --release ^
  --dart-define=API_FOOTBALL_KEY=ВАШ_КЛЮЧ ^
  --dart-define=API_FOOTBALL_LEAGUE_IDS=39,235
```

(На macOS/Linux вместо `^` используйте перенос строки `\`.)

---

## Возможности приложения (кратко)

- Матчи: поиск, фильтр «только мои», вкладки предстоящие / прошедшие, отметка «идёт сейчас»; опционально — **реальные расписания** из API-Football и/или football-data.org.
- Геолокация: проверка у стадиона в заданном окне времени.
- История, профиль, достижения, таблица лидеров.
- Админ: стадионы (в т.ч. фото и карта), матчи, достижения.
- Карта стадиона (OpenStreetMap), уведомления о матче.

---

## Лицензия

Учебный проект. Использование — на усмотрение автора.
