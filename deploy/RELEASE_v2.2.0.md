# Release v2.2.0 — qaguru WebDriver Chrome

Prod `browsers.json`: Chrome WebDriver migrated from `twilio/selenoid:chrome_stable_*` to `qaguru/webdriver-chrome`.

| Hub version | Docker image | Use |
|-------------|--------------|-----|
| `149.0` *(default)* | `qaguru/webdriver-chrome:149` | prod UI, VNC |
| `149.0-min` | `qaguru/webdriver-chrome:149-min` | CI headless |
| `148.0` / `148.0-min` | `qaguru/webdriver-chrome:148` / `:148-min` | regression |

Removed from chrome catalog: `twilio/*`, `selenoid/vnc_chrome:128.0`.

Firefox / Edge / Playwright blocks unchanged in this release.

Images: [browser-image releases](https://github.com/qa-guru/browser-image/releases) (`webdriver/chrome-149`, `webdriver/chrome-149-min`).
