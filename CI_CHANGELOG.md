# CI 模板变更报告

## 概要
本次修改针对仓库中的可复用 GitHub Actions 工作流进行了结构性优化，目标是提高并行能力、构建速度与稳定性，已完成并提交到工作区。

## 修改的文件
- .github/workflows/reusable-ci.yml
- starter/.github/workflows/ci.yml

## 主要改动
- 将原本单一的 `lint-and-build` 串行步骤拆分为多个并行 job：`node-check`、`java-check`、`php-check`、`python-check`、`go-check`、`dotnet-check`、`docker-check`。
- 新增 `layer1-aggregate` job，汇总各语言检查结果并决定是否失败（保持原有失败逻辑的一致性）。
- 为 Java 增加 Maven (`~/.m2/repository`) 与 Gradle (`~/.gradle/caches`, `~/.gradle/wrapper`) 缓存，使用 `actions/cache@v4` 减少依赖下载时间。
- 修复并移除 `setup-java` 中不可靠的 GH 表达式（此前存在语法/表达式风险）。
- 修改 `starter/.github/workflows/ci.yml` 的 `concurrency.group` 为 `${{ github.workflow }}-${{ github.ref_name }}`，减少不同 workflow/分支间误取消的概率。

## 建议的后续优化（可选）
1. 固定关键 action 的具体次版本或 commit SHA，例如 `actions/checkout@v4.4.0` 或使用 SHA，以提高可重复性。  
2. 对常用语言（例如 Node/Java）引入更细粒度的缓存键策略（包含 lockfile hash + OS + 工具版本），以提高缓存命中率。  
3. 为大仓库或 monorepo 使用 matrix/paths-filter 优化，避免对无关子项目触发不必要检查。  
4. 在 repo 中加入 `yamllint` 或 CI-side lint 检查以捕获语法问题（推荐在本仓库外的 CI 上验证一次）。

## 如何本地或远程验证修改
- 使用 `yamllint` 检查语法（需 Python 环境）：

```bash
pip install yamllint
yamllint .github/workflows/reusable-ci.yml
```

- 使用 `act` 在本地模拟 GitHub Actions（需 Docker）：

```bash
# 安装 act 后（参考 https://github.com/nektos/act）
act -j repo-hygiene
act -j layer1-aggregate
```

- 将修改推送到一个测试分支并在 GitHub 上打开 PR，观察 Actions 运行（推荐在私人或测试仓库先试运行）。

## 联系与回退
- 若需要回退到原始版本，可查看 git 历史并还原 `.github/workflows/reusable-ci.yml`。  
- 若要我继续：我可以（A）固定 action 版本并提交，或（B）为仓库添加 `yamllint` CI 检查。请选择一项或告诉我你的优先级。

---
生成于：2026-04-22
