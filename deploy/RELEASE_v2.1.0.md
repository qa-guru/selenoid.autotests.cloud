# qa-guru Selenoid Stack — Release v2.1.0

| Компонент | Release | Статус |
|-----------|---------|--------|
| **Deploy** | [v2.1.0](https://github.com/qa-guru/selenoid.autotests.cloud/releases/tag/v2.1.0) | отдельный репозиторий prod-деплоя |
| **cm** | [v2.0.9](https://github.com/qa-guru/cm/releases/tag/v2.0.9) | без изменений |
| Selenoid hub | [v2.0.9](https://github.com/qa-guru/selenoid/releases/tag/v2.0.9) | без изменений |
| Selenoid UI | [v2.0.9](https://github.com/qa-guru/selenoid-ui/releases/tag/v2.0.9) | без изменений |
| Playwright images | `qaguru/playwright-*:1.61.1` | без изменений |

Предыдущий стек: [v2.0.9](RELEASE_v2.0.9.md)

---

## Что нового в v2.1.0

Инфраструктурный релиз: **деплой на prod вынесен из qa-guru/cm в отдельный репозиторий** [qa-guru/selenoid.autotests.cloud](https://github.com/qa-guru/selenoid.autotests.cloud).

| Изменение | Описание |
|-----------|----------|
| **selenoid.autotests.cloud** | Скрипты деплоя, nginx, CI (`deploy.yml`), release notes стека |
| **cm** | Только сборка, релиз и Docker-образ установщика — без prod-деплоя |
| **GitHub Actions** | Prod-деплой: Actions → [deploy](https://github.com/qa-guru/selenoid.autotests.cloud/actions/workflows/deploy.yml) в этом репозитории |
| **Бинарники стека** | По-прежнему **v2.0.9** (cm, hub, UI) — изменений кода нет |

---

## Деплой

GitHub Actions в [qa-guru/selenoid.autotests.cloud](https://github.com/qa-guru/selenoid.autotests.cloud):

- **ref:** `v2.1.0` — скрипты и конфиги из этого релиза
- **version:** `v2.0.9` — теги cm / hub / UI (или пусто — default в `deploy.sh`)

Вручную на сервере (от пользователя `selenoid`):

```bash
SELENOID_VERSION=v2.0.9 SELENOID_UI_VERSION=v2.0.9 ./deploy/deploy.sh
```

Проверка:

```bash
./deploy/smoke-remote.sh https://selenoid.autotests.cloud
```

---

## Эндпоинты

| Протокол | URL |
|----------|-----|
| Selenium | `https://selenoid.autotests.cloud/wd/hub` |
| Playwright | `wss://selenoid.autotests.cloud/playwright/playwright-chromium/1.61.1` |
| UI | `https://selenoid.autotests.cloud/` |
| Status | `https://selenoid.autotests.cloud/status` |

WebDriver Edge: `browserName: msedge` или `MicrosoftEdge`, `browserVersion: 145.0`.
