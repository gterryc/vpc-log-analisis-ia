### 📌 Commit Message Convention

This project follows the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) specification to keep a clean and understandable history. Please use the following prefixes when writing commit messages:

| Prefix      | Description                           |
|-------------|---------------------------------------|
| `feat:`     | A new feature                         |
| `fix:`      | A bug fix                             |
| `docs:`     | Documentation-only changes            |
| `style:`    | Code formatting (no logic change)     |
| `refactor:` | Code changes without fixing a bug or adding a feature |
| `test:`     | Adding or updating tests              |
| `chore:`    | Minor changes (configs, tools, etc.)  |
| `perf:`     | Performance improvement               |
| `build:`    | Build system or dependency changes    |
| `ci:`       | Changes to CI/CD workflow             |

Example:
```
feat: add RDS subnet group support
fix: correct EIP association bug
docs: update README with usage instructions
```

Use the **imperative mood** in the message (e.g., _add_, _fix_, _update_, not _added_, _fixed_).

---
# 📦 CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Semantic Versioning](https://semver.org/).

---

## [0.1.0] - 2025-07-01
### Added
- Initial commit
