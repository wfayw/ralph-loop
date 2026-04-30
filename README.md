# Ralph Loop

用于维护面向 `Codex CLI` 的 Ralph 单故事自治循环。

## 当前仓库包含什么

- `ralph.sh`：Ralph 主循环，默认使用 `codex exec`
- `Makefile`：`ralph-run`、`ralph-validate`、`doctor` 等便捷入口
- `CODEX.md`：每轮迭代喂给 Codex 的提示模板
- `prompt.md` / `CLAUDE.md`：保留上游 Amp / Claude Code 提示模板
- `prd.json.example`：最小 PRD JSON 示例
- `.claude-plugin/`：上游 Claude 插件元数据
- `skills/`：上游 `prd` / `ralph` skills
- `flowchart/`：上游流程图前端源码

运行态文件不提交：`prd.json`、`progress.txt`、`runs/`、`archive/`、`.last-*`。

## 快速开始

```bash
cp prd.json.example prd.json
make ralph-validate
make ralph-run MAX_ITERATIONS=3
```

默认情况下，Ralph 会把当前仓库当作目标仓库执行 `codex exec`。如果要让 Ralph 驱动另一个代码仓库：

```bash
RALPH_REPO_ROOT=/path/to/target/repo make ralph-validate
RALPH_REPO_ROOT=/path/to/target/repo make ralph-run MAX_ITERATIONS=3
```

也可以直接运行脚本：

```bash
./ralph.sh --repo-root /path/to/target/repo --validate
./ralph.sh --repo-root /path/to/target/repo --tool codex 3
```

## 常用环境变量

- `RALPH_REPO_ROOT`：目标仓库根目录，默认是当前 Ralph 仓库根目录
- `RALPH_PRD_FILE`：覆盖默认 `prd.json`
- `RALPH_PROGRESS_FILE`：覆盖默认 `progress.txt`
- `RALPH_CODEX_MODEL`：指定 Codex 模型
- `RALPH_CODEX_SANDBOX=read-only|workspace-write|danger-full-access`：覆盖 Codex sandbox
- `RALPH_FAIL_ON_MAX_ITERATIONS=1`：达到迭代上限时返回非零退出码

## 行为说明

1. 每轮读取 `prd.json` 中 `passes=false` 的最高优先级 story
2. 渲染 `CODEX.md`，把 PRD 与 progress 的实际路径写入提示
3. 在 `RALPH_REPO_ROOT` 指定的目标仓库根目录执行 `codex exec`
4. 每轮只处理一个 story，并要求 agent 做最小相关验证
5. 当最后一行输出精确等于 `<promise>COMPLETE</promise>` 时提前结束

默认运行模式使用 `codex exec --dangerously-bypass-approvals-and-sandbox`。需要收紧权限时，显式设置 `RALPH_CODEX_SANDBOX`。

## 运行结果

- 结构化进度：`progress.txt`
- 当前故事状态：`prd.json`
- 最后一条 agent 输出：`.last-message.txt`
- 完整运行日志：`runs/*.log`

## 文档

- 使用说明：`docs/runbooks/ralph-codex-usage.md`
