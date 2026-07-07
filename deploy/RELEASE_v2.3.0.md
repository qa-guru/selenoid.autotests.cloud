# Release v2.3.0 — qaguru WebDriver Firefox + Edge

Prod `browsers.json`: Firefox and Edge WebDriver migrated from `twilio/selenoid:*` to `qaguru/webdriver-*`.

| Browser | Hub default | Warm image | Min image |
|---------|-------------|------------|-----------|
| Firefox | `151.0` | `qaguru/webdriver-firefox:151` | `:151-min` |
| Edge | `145.0` | `qaguru/webdriver-msedge:145` | `:145-min` |

Also available: Firefox `150.0` / `150.0-min`, Edge `144.0` / `144.0-min`.

Removed from catalog: `twilio/selenoid:firefox_stable_*`, `twilio/selenoid:edge_stable_*`.

Path for all WebDriver nodes: `/` (direct geckodriver / msedgedriver, not Selenium server `/wd/hub`).

Images: [browser-image releases](https://github.com/qa-guru/browser-image/releases) (`webdriver/firefox-*`, `webdriver/msedge-*`).
