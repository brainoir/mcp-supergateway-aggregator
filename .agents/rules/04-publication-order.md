---
trigger: model_decision
description: Triggered when the user asks to publish or release a new version of the project.
---
The release process consists of the following mandatory steps:
1. Ensure that the `lhm.plugin.json` manifest explicitly defines the `tools`, `prompts`, and `resources` arrays so that the LobeHub marketplace correctly indexes server capabilities, and verify that the version in `lhm.plugin.json` strictly matches the version in `package.json`.
2. Check for the presence of the LobeHub badge in `README.md`.
3. Commit and push all changes to the GitHub repository (`git commit && git push`). Proceed with publishing a new version to the Marketplace only after the GitHub repository has been successfully updated.
4. Publish the new version using `npx -y @lobehub/market-cli plugin publish --dir .`.
