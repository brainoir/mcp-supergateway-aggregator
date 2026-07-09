---
trigger: model_decision
description: Triggered when the user asks to publish or release a new version of the project.
---
Процесс релиза состоит из следующих обязательных этапов:
1. Обязательно убедись, что в манифесте `lhm.plugin.json` явно описаны массивы `tools`, `prompts` и `resources`, чтобы маркетплейс LobeHub корректно проиндексировал возможности сервера.
2. Проверь наличие бейджа LobeHub в `README.md`.
3. Закоммить и отправь все изменения в репозиторий GitHub (`git commit && git push`). Только после успешного обновления GitHub переходи к публикации новой версии на Marketplace.
4. Опубликуй новую версию с помощью `npx -y @lobehub/market-cli plugin publish --dir .`.
