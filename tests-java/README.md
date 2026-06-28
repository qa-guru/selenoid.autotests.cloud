# UI tests (Java)

Автотесты для [one-page-form](https://qa-guru.github.io/one-page-form/) на Selenide и JUnit 5.

**Эталон для разработки** в automator-репозитории: правки инфраструктуры и стиля тестов здесь, затем синхронизация в `templates/project-tests/` (см. корневой `README.md`).

`LoginTests.java` — образец стиля (шаги, Allure-аннотации, `[data-testid=…]`). **Не копируется** в bootstrap-шаблон и не попадает в новые GitHub-репозитории автоматически.

## Prerequisites

- Java 21
- Google Chrome installed locally

## Run tests

From this directory:

```bash
./gradlew test
```

Run all tests in a feature class:

```bash
./gradlew test --tests tests.LoginTests
```

Run a single test method:

```bash
./gradlew test --tests tests.LoginTests.successfulAuthorizationTest
```

Open the HTML report after a run:

```bash
open build/reports/tests/test/index.html
```

## What is tested (эталон)

| @Feature     | Class        | Page         | Methods |
|--------------|--------------|--------------|---------|
| Авторизация  | `LoginTests` | `login.html` | `successfulAuthorizationTest`, `wrongPasswordAuthorizationTest` |

Страницы открываются с GitHub Pages: `https://qa-guru.github.io/one-page-form/`.

## Naming (как в сгенерированных project repo)

- **Класс** — по `@Feature`: `LoginTests`, `RegistrationTests`, …
- **Метод** — по сценарию: `successfulAuthorizationTest`, `wrongPasswordAuthorizationTest`
- **Один класс — несколько `@Test`**: новый кейс той же фичи добавляется в существующий класс

## Project layout

```
tests-java/
├── build.gradle
├── gradlew
├── gradlew.bat
├── gradle/wrapper/
└── src/test/
    ├── java/
    │   ├── tests/
    │   │   ├── TestBase.java
    │   │   └── LoginTests.java      # образец стиля, только здесь
    │   ├── config/
    │   └── annotations/
    └── resources/
        └── config/
            └── local.properties
```

## Sync to template

Инфраструктуру синхронизируй в `templates/project-tests/`, **исключая** эталонные тесты:

```bash
rsync -a --delete \
  --exclude build/ --exclude .gradle/ --exclude bin/ \
  --exclude allure-results/ --exclude history.jsonl --exclude known.json \
  --exclude src/test/java/tests/LoginTests.java \
  tests-java/ templates/project-tests/
```

## Configuration

Browser settings live in `TestBase.java` and `src/test/resources/config/*.properties`:

- **Browser:** Chrome (default)
- **Window size:** 1920×1280
- **Base URL:** `https://qa-guru.github.io/one-page-form/` (override via `baseUrl` in properties)

## Dependencies

- Selenide 7.16.2
- JUnit Jupiter 5.11.4
