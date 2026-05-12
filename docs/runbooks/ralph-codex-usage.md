# Ralph for Codex 使用说明

- 状态：`stable`
- 主题：`ralph-for-codex`
- 适用范围：独立 `ralph-loop` 仓库，可通过 `RALPH_REPO_ROOT` 驱动任意目标仓库

## 1. 这份说明解决什么问题

本文档说明如何使用独立维护的 Ralph Loop，通过 `Codex CLI` 执行单故事自治循环。

## 2. 前置条件

至少需要：

- `git`
- `codex`
- `python3`

先检查环境：

```bash
make doctor
```

## 3. 快速开始

### 3.1 生成本地 PRD

```bash
cp prd.json.example prd.json
```

### 3.2 验证 Codex 接线

```bash
make ralph-validate
```

如需驱动其他代码仓库：

```bash
RALPH_REPO_ROOT=/path/to/target/repo make ralph-validate
```

### 3.3 启动 Ralph

```bash
make ralph-run MAX_ITERATIONS=3
```

默认行为：

1. 从 `prd.json` 读取故事列表
2. 从 `CODEX.md` 读取 Codex 提示模板
3. 在 `RALPH_REPO_ROOT` 指定的目标仓库根目录执行 `codex exec`
4. 每轮只处理一个 `passes=false` 的最高优先级故事
5. 如果本次只是达到 `MAX_ITERATIONS` 且仍有剩余 story，命令默认正常退出并保留已落盘的 `progress.txt` / `prd.json`

## 4. 常用路径

- PRD：`prd.json`
- 示例：`prd.json.example`
- 进度日志：`progress.txt`
- 提示模板：`CODEX.md`
- 完整运行日志：`runs/*.log`

目标项目的长期 PRD、任务拆解、专利材料和设计文档应整理到目标项目仓库；`ralph-loop` 只保留当前运行所需的本地 `prd.json`、`progress.txt` 和运行日志。

## 5. 常用环境变量

- `RALPH_REPO_ROOT`：覆盖默认目标仓库根目录
- `RALPH_PRD_FILE`：覆盖默认 PRD 文件路径
- `RALPH_PROGRESS_FILE`：覆盖默认进度文件路径
- `RALPH_CODEX_MODEL`：指定 Codex 模型
- `RALPH_CODEX_SANDBOX=read-only|workspace-write|danger-full-access`：显式覆盖 sandbox
- `RALPH_FAIL_ON_MAX_ITERATIONS=1`：达到迭代上限但未全部完成时返回非零退出码

## 6. 说明

当前保留的是：

1. 基于上游 `snarktank/ralph` 的最小循环
2. 针对 `Codex CLI` 的提示模板和入口适配
3. 独立仓库维护方式
