# Деплой на selenoid.autotests.cloud

Публичный Selenoid для курсов и примеров: **Selenium WebDriver** + **Playwright WebSocket**.

| Путь | Как подключаться |
|------|------------------|
| `/` (UI) | `https://selenoid.autotests.cloud` |
| `/wd/hub` | `https://selenoid.autotests.cloud/wd/hub` |
| `/playwright/` | Create Session в UI или `wss://selenoid.autotests.cloud/playwright/playwright-chromium/1.61.1?enableVNC=true&enableVideo=true` |
| `/status` | UI-shaped JSON (`.state`, `.version` = **selenoid-ui** stamp) |
| `/hub/status` | raw hub capacity (total/used/browsers; без `.version`) |
| `/wd/hub/status` | W3C hub status — **версия hub** в `.value.message` (basic auth) |
| `:4445` | прямой hub API для CI |

Справочный полный конфиг: [`nginx-selenoid.conf`](nginx-selenoid.conf).

## Endpoints

| Назначение | URL |
|------------|-----|
| Selenium | `https://selenoid.autotests.cloud/wd/hub` |
| Playwright | `wss://selenoid.autotests.cloud/playwright/playwright-chromium/1.61.1?enableVNC=true&enableVideo=true` |
| UI | `https://selenoid.autotests.cloud/` |
| Status (UI) | `https://selenoid.autotests.cloud/status` — `.version` = UI, не hub |
| Hub status | `https://selenoid.autotests.cloud/hub/status` |
| Hub version | `https://selenoid.autotests.cloud/wd/hub/status` (auth) → `Selenoid v2.1.7 built at …` |
| Video | `https://selenoid.autotests.cloud/video/` |

Текущие pin’ы `deploy.sh`: hub **v2.1.7**, UI **v2.1.1** (есть release assets; `selenoid-ui` v2.1.6 — пустой релиз), cm **v2.1.6**.

### Переменные для тестов

```bash
export SELENOID_URL=https://selenoid.autotests.cloud/wd/hub
export PW_TEST_CONNECT_WS_ENDPOINT=wss://selenoid.autotests.cloud/playwright/playwright-chromium/1.61.1?enableVNC=true&enableVideo=true
export SELENOID_HOST=selenoid.autotests.cloud
```

---

## Автодеплой (GitHub Actions)

Workflow [`.github/workflows/deploy.yml`](../.github/workflows/deploy.yml) в [qa-guru/selenoid.autotests.cloud](https://github.com/qa-guru/selenoid.autotests.cloud):

| Триггер | Когда |
|---------|-------|
| `workflow_dispatch` | **Ручной деплой** — Actions → deploy → Run workflow (версия стека и git ref опциональны) |
| `repository_dispatch: deploy-selenoid` | Вызов из внешнего CI (payload: `version`, опционально `ref`) |

### Secrets (Settings → Secrets → Actions в qa-guru/selenoid.autotests.cloud)

| Secret | Пример | Описание |
|--------|--------|----------|
| `SELENOID_DEPLOY_HOST` | `136.243.89.21` | SSH-хост (**IP сервера**, не CNAME — DNS может указывать на прокси) |
| `SELENOID_DEPLOY_USER` | `selenoid` | Пользователь в группе `docker` |
| `SELENOID_DEPLOY_KEY` | ed25519 private key | Ключ только для Actions → `/home/selenoid/.ssh/authorized_keys` |

Опционально — Variables:

| Variable | Default | Описание |
|----------|---------|----------|
| `SELENOID_CONFIG_DIR` | `/opt/selenoid` | Каталог конфигурации на сервере |
| `SELENOID_PUBLIC_URL` | `https://selenoid.autotests.cloud` | URL для smoke test (не IP — иначе nginx отдаёт чужой cert) |

После настройки secrets: [Actions → deploy → Run workflow](https://github.com/qa-guru/selenoid.autotests.cloud/actions/workflows/deploy.yml) — обновит сервер до выбранной версии стека.

---

## Ручной деплой на сервере

### Первый раз (bootstrap)

```bash
# на сервере, от root
sudo DEPLOY_USER=selenoid ./deploy/bootstrap.sh
# перелогиниться, чтобы применилась группа docker
```

### Обновление стека

```bash
# из клона qa-guru/selenoid.autotests.cloud на сервере
./deploy/deploy.sh
```

Или скачать скрипт с GitHub:

```bash
curl -sL https://raw.githubusercontent.com/qa-guru/selenoid.autotests.cloud/main/deploy/deploy.sh -o deploy.sh
chmod +x deploy.sh
./deploy.sh
```

Или из клона репозитория:

```bash
./deploy/deploy.sh
```

Быстрое обновление без полного `deploy.sh`:

```bash
./deploy/remote-update.sh
```

Pin версии (опционально; default hub **v2.1.7**, UI **v2.1.1**, cm **v2.1.6**):

```bash
SELENOID_VERSION=v2.1.7 SELENOID_UI_VERSION=v2.1.1 CM_VERSION=v2.1.6 ./deploy/deploy.sh
```

### Проверка

```bash
./deploy/smoke-remote.sh https://selenoid.autotests.cloud
# hub revision assertion (default EXPECTED_HUB_VERSION=v2.1.7):
# curl -u user1:1234 -fsSL …/wd/hub/status | jq -r .value.message
```

---

## Nginx (selenoid.autotests.cloud)

Реальный конфиг на сервере: **`/etc/nginx/sites-available/selenoid`**

| Порт | `location` | Куда |
|------|------------|------|
| 443 | `/` | `127.0.0.1:8080` (UI) |
| 443 | `/wd/hub` | `127.0.0.1:8080` (UI → hub) |
| 443 | `/playwright/` | `127.0.0.1:8080` (UI → hub) |
| 443 | `/status` | `127.0.0.1:8080` (UI JSON; `.version` = UI stamp) |
| 443 | `/hub/status` | `127.0.0.1:4444` (raw hub capacity) |
| 443 | `/wd/hub/status` | через UI → hub (auth; версия hub в message) |
| 4445 | `/` | `127.0.0.1:4444` (hub) — CI |

Не проксируйте `/wd/hub` и `/playwright/` напрямую на hub:443 — проксируйте через selenoid-ui.
Не сверяйте версию hub по публичному `/status.version` — это stamp selenoid-ui.

Справочные файлы: [`nginx-selenoid.conf`](nginx-selenoid.conf), [`sync-nginx.sh`](sync-nginx.sh).

Применить вручную (если CI не смог из‑за sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/qa-guru/selenoid.autotests.cloud/main/deploy/nginx-selenoid.conf -o /tmp/nginx-selenoid.conf
curl -fsSL https://raw.githubusercontent.com/qa-guru/selenoid.autotests.cloud/main/deploy/sync-nginx.sh -o /opt/selenoid/bin/sync-nginx.sh
chmod +x /opt/selenoid/bin/sync-nginx.sh
sudo NGINX_CONF_SRC=/tmp/nginx-selenoid.conf /opt/selenoid/bin/sync-nginx.sh
```

После `bootstrap.sh` пользователь `selenoid` может вызывать `sync-nginx.sh` без пароля.

### Очистка видео на сервере

Скрипт [`cleanup-videos.sh`](cleanup-videos.sh) удаляет `.mp4` старше 6 месяцев из `/opt/selenoid/video`. На проде — в root crontab (ежемесячно).

---

## Структура на сервере

```
/opt/selenoid/          # SELENOID_CONFIG_DIR
  browsers.json
  bin/selenoid
  bin/selenoid-ui
  video/
  logs/
/home/selenoid/cm       # бинарник cm (только у пользователя selenoid)
```

Деплой и `cm` — **только от пользователя `selenoid`**, не от root и не из home других пользователей.

---

## Релизы стека

| Версия | Документация |
|--------|--------------|
| v2.1.0 | [RELEASE_v2.1.0.md](RELEASE_v2.1.0.md) — **prod deploy repo** |
| v2.0.9 | [RELEASE_v2.0.9.md](RELEASE_v2.0.9.md) — **docs refresh** |
| v2.0.8 | [RELEASE_v2.0.8.md](RELEASE_v2.0.8.md) — **stack aligned** |
| v2.0.7 | [RELEASE_v2.0.7.md](RELEASE_v2.0.7.md) — **prod verified** |
| v2.0.6 | [RELEASE_v2.0.6.md](RELEASE_v2.0.6.md) |
| v2.0.2 | [RELEASE_v2.0.2.md](RELEASE_v2.0.2.md) |
| v2.0.1 | [RELEASE_v2.0.1.md](RELEASE_v2.0.1.md) |
| v2.0.0 | [RELEASE_v2.0.0.md](RELEASE_v2.0.0.md) |
