# ralph-loop Working Notes

## Scope
- 本文件作用域覆盖当前独立仓库及其全部子目录。
- 修改本仓库内容时，优先遵循本文件的项目级约束。

## Role
- 当前仓库不承载旧的 Python Ralph loop runtime。
- 当前仓库用于维护独立的 `snarktank/ralph` 适配版执行入口，尽量保留上游结构，并默认使用 `Codex CLI`。

## Working Rules
- 这里优先放 Ralph 自身运行所需的脚本、模板、示例 PRD、上游附属结构与使用说明。
- 具体目标项目的 PRD、任务拆解、专利材料和设计文档应放在目标项目仓库，不要长期放在 `ralph-loop`。
- 不要在本仓库重新引入旧的 `src/ralph_loop_service` Python 服务分层。
- 针对 Codex 的适配优先保持“薄封装”：尽量复用上游 Ralph 的单循环思路，不要再演化回长驻服务。
- 如果某个 Ralph 任务同时维护 `prd.json` 和 `tasks/*.md` 两份背景工件，原型 PRD/导航页/prototype zip 绑定与“当前剩余差异”摘要必须双向同步；已完成 stories 不应继续留在“未完成差异”基线里。

## Documentation Hygiene
- 修改执行方式、样例 PRD、提示模板或命令入口时，同步更新 `README.md`、`DIRECTORY.md` 与 `docs/runbooks/`。

## Validation
- 优先通过 `make ralph-validate` 做最小验证，确认 `codex exec` 能在目标仓库根目录正常工作。
- 如需真实执行循环，使用 `make ralph-run MAX_ITERATIONS=<n>`，并先准备好 `prd.json`。
- 驱动其他代码仓库时，通过 `RALPH_REPO_ROOT=/path/to/repo` 或 `./ralph.sh --repo-root /path/to/repo` 指定目标仓库。
