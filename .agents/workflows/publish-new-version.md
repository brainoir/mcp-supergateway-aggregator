# Description
Workflow for correctly publishing a new version of the plugin.

# Instructions
1. **Version Verification:** Before committing, ensure that `package.json` and `lhm.plugin.json` specify strictly identical versions.
2. **GitHub Synchronization:** Check `git status` and commit project files explicitly (personal files and logs are in `.gitignore` and must not enter the commit), then push changes to the remote GitHub repository (`git push`).
3. **LobeHub Publishing:** After updating GitHub, invoke the `/lobehub-mcp-publisher` skill to properly publish the plugin to the marketplace (command `lhm plugin publish --dir .`).
