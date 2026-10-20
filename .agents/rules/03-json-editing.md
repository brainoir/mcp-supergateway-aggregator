---
trigger: glob
globs: lhm.plugin.json, package.json
---
When editing manifest files, strictly preserve their structure and key order if one was originally established. Validate JSON syntax before saving and use specialized tools (such as `replace_file_content` for surgical replacements) instead of full file rewrites to avoid corrupting the configuration.
