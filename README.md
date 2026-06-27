# selenoid.autotests.cloud

Production-деплой публичного Selenoid: **https://selenoid.autotests.cloud**

| Компонент | GitHub | Роль на prod |
|-----------|--------|--------------|
| **cm** | [qa-guru/cm](https://github.com/qa-guru/cm) | Установщик: скачивает hub/UI, `browsers.json`, browser-образы |
| **selenoid** | [qa-guru/selenoid](https://github.com/qa-guru/selenoid) | Hub (релизы → бинарник на сервере) |
| **selenoid-ui** | [qa-guru/selenoid-ui](https://github.com/qa-guru/selenoid-ui) | UI (релизы → бинарник на сервере) |
| **playwright-image** | [qa-guru/playwright-image](https://github.com/qa-guru/playwright-image) | Playwright browser nodes (`docker pull`) |
| **этот репозиторий** | [qa-guru/selenoid.autotests.cloud](https://github.com/qa-guru/selenoid.autotests.cloud) | Скрипты деплоя, nginx, CI, release notes стека |

В **cm** остаются только сборка, релиз и публикация Docker-образа. Деплой на сервер — отсюда.

## Быстрый старт

| Действие | Как |
|----------|-----|
| **Ручной деплой** | GitHub → Actions → [deploy](https://github.com/qa-guru/selenoid.autotests.cloud/actions/workflows/deploy.yml) → Run workflow |
| **Перезагрузка nginx** | Actions → [nginx-reload](https://github.com/qa-guru/selenoid.autotests.cloud/actions/workflows/nginx-reload.yml) |
| **Деплой на сервере** | `./deploy/deploy.sh` (из клона этого репозитория) |
| **Smoke test** | `./deploy/smoke-remote.sh https://selenoid.autotests.cloud` |

Полная документация: [`deploy/README.md`](deploy/README.md).

## Локальная разработка стека

Монорепозиторий с исходниками hub/UI/cm — отдельно (selenoid-home). Канонический `browsers.json` синхронизируется сюда скриптом `scripts/sync-cm-browsers.sh` в том репозитории → `deploy/browsers-production.json`.
