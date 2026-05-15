# Node 24 说明文件

## 1. 文档目的

本文档用于说明当前仓库中 Node 24 相关 GitHub Action 示例的整体构成、关键指令、构建流程、测试流程，以及从 Node 20 升级到 Node 24 时需要关注的核心点。

本文档覆盖的内容包括：

- Node 24 Action 的目录结构
- `action.yml` 的字段构成
- `package.json` 的脚本与依赖构成
- `src` 与 `dist` 的职责划分
- Workflow 中与 Node 24 相关的关键指令
- 本地构建、测试、运行时校验脚本说明
- 从 Node 20 升级到 Node 24 的关键修改点

## 2. 目录结构说明

当前仓库中和 Node 24 相关的示例主要位于以下目录：

```text
common/
  create-pipeline-context/
    action.yml
    src/index.js
    dist/index.js
    package.json
    package-lock.json
  decide-env/
    action.yml
    src/index.js
    dist/index.js
    package.json
    package-lock.json
  js-action-template/
    action.yml
    src/index.js
    dist/index.js
    package.json
    package-lock.json
scripts/
  build-common-actions.sh
  test-common-actions.sh
  test-node24-action.sh
  verify-action-runtime.sh
.github/workflows/
  node24-action-demo.yml
```

各目录职责如下：

- `common/*/action.yml`：GitHub Action 的入口定义文件
- `common/*/src/index.js`：开发时维护的源代码
- `common/*/dist/index.js`：打包后的产物，GitHub Actions 运行时直接执行
- `common/*/package.json`：依赖、Node 版本、打包脚本定义
- `common/*/package-lock.json`：依赖锁定文件
- `scripts/*.sh`：构建、测试、校验脚本
- `.github/workflows/node24-action-demo.yml`：CI 演示工作流

## 3. 三个 Node 24 Action 的作用

### 3.1 create-pipeline-context

作用：根据输入生成 pipeline context，并输出 JSON 结果。

输入：

- `service`
- `test-parallel-keys`

输出：

- `pipeline-context`
- `test_parallel_keys`

### 3.2 decide-env

作用：根据分支名或 Git ref 判断当前部署环境。

输入：

- `branch-name`
- `github-ref`

输出：

- `environment`
- `deploy_enabled`

### 3.3 js-action-template

作用：作为最小 JavaScript Action 模板，展示 Node 24 下输入、输出和 JSON 解析的基本模式。

输入：

- `name`
- `payload`

输出：

- `message`
- `payload`

## 4. action.yml 的构成说明

以 `common/create-pipeline-context/action.yml` 为例：

```yaml
name: create-pipeline-context
description: Demo JavaScript action upgraded from Node 20 to Node 24

inputs:
  service:
    description: Service name used in the generated context
    required: true
  test-parallel-keys:
    description: Test matrix partition keys as a JSON array
    required: false
    default: '[]'

outputs:
  pipeline-context:
    description: JSON encoded pipeline context
  test_parallel_keys:
    description: Test matrix partition list

runs:
  using: node24
  main: dist/index.js
```

关键字段说明：

- `name`：Action 名称
- `description`：Action 功能描述
- `inputs`：Action 接收的输入参数定义
- `outputs`：Action 输出参数定义
- `runs.using`：指定 GitHub Action 的 JavaScript 运行时版本
- `runs.main`：指定运行入口文件

这里最关键的是：

```yaml
runs:
  using: node24
  main: dist/index.js
```

这表示 GitHub 在执行该 Action 时，会用 Node 24 去执行 `dist/index.js`。

## 5. package.json 的构成说明

以 `common/create-pipeline-context/package.json` 为例：

```json
{
  "name": "create-pipeline-context",
  "version": "1.0.0",
  "private": true,
  "description": "Demo GitHub Action upgraded to the Node 24 runtime.",
  "main": "dist/index.js",
  "license": "UNLICENSED",
  "engines": {
    "node": ">=24"
  },
  "scripts": {
    "build": "ncc build src/index.js -o dist",
    "package": "npm run build"
  },
  "dependencies": {
    "@actions/core": "^1.11.1"
  },
  "devDependencies": {
    "@vercel/ncc": "^0.38.3"
  }
}
```

关键字段说明：

- `main`：包入口，这里指向 `dist/index.js`
- `engines.node`：声明开发和打包时要求的 Node 版本
- `scripts.build`：将 `src/index.js` 打包到 `dist/index.js`
- `scripts.package`：当前等同于 `npm run build`
- `dependencies.@actions/core`：GitHub Action 官方核心库，用于读取 input、设置 output、输出日志和失败状态
- `devDependencies.@vercel/ncc`：将 Node 源码和依赖打包成单文件产物

## 6. src 与 dist 的职责说明

### 6.1 src/index.js

`src/index.js` 是开发时维护的源码文件，主要职责包括：

- 读取 GitHub Action 输入参数
- 做业务逻辑处理
- 设置输出参数
- 输出日志
- 在异常时设置失败状态

### 6.2 dist/index.js

`dist/index.js` 是通过 `ncc build src/index.js -o dist` 生成的打包产物。GitHub Actions 实际执行的是这个文件，而不是 `src/index.js`。

这样设计的目的有两个：

- CI 运行时不依赖源码目录中的模块解析结构
- 发布到仓库时可以直接执行，不需要在 Runner 上重新打包

## 7. Workflow 中 Node 24 相关指令说明

文件：`.github/workflows/node24-action-demo.yml`

关键部分如下：

```yaml
- name: Setup Node 24
  uses: actions/setup-node@v4
  with:
    node-version: 24
```

这段的作用是：

- 在 GitHub Runner 上准备 Node 24 运行环境
- 保证构建、脚本执行和本地 action 调用所依赖的 Node 版本一致

另外，workflow 中通过如下方式调用本地 action：

```yaml
- name: Run upgraded local action
  id: pipeline-context
  uses: ./common/create-pipeline-context
```

说明：

- `uses: ./common/create-pipeline-context` 表示调用当前仓库中的本地 Action
- 该 Action 的真实入口由对应目录下的 `action.yml` 决定

## 8. 构建脚本说明

### 8.1 build-common-actions.sh

命令：

```bash
bash scripts/build-common-actions.sh
```

作用：

- 进入每个 action 目录
- 执行 `npm ci`
- 执行 `npm run package`
- 生成最新的 `dist/index.js`

脚本中的关键指令：

- `set -euo pipefail`
  - `-e`：任何命令失败时立即退出
  - `-u`：使用未定义变量时报错
  - `-o pipefail`：管道中任一命令失败则整体失败
- `npm ci`
  - 严格按照 `package-lock.json` 安装依赖
  - 适合 CI 场景
- `npm run package`
  - 调用 `package.json` 中定义的 `package` 脚本

## 9. 测试脚本说明

### 9.1 test-node24-action.sh

命令：

```bash
bash scripts/test-node24-action.sh
```

作用：

- 只测试 `create-pipeline-context`
- 覆盖正常输入
- 覆盖缺少必填参数
- 覆盖非法 JSON 输入

该脚本验证的是单个 action 的基本行为是否符合预期。

### 9.2 test-common-actions.sh

命令：

```bash
bash scripts/test-common-actions.sh
```

作用：

- 测试三个 action 的成功路径
- 读取 `GITHUB_OUTPUT` 输出文件
- 校验关键输出值是否存在

该脚本适合做本地回归验证。

## 10. 运行时一致性检查脚本说明

### 10.1 verify-action-runtime.sh

命令：

```bash
bash scripts/verify-action-runtime.sh 24
```

作用：

- 检查所有 `action.yml` 的 `runs.using` 是否为 `node24`
- 检查所有 `package.json` 的 `engines.node` 是否为 `>=24`
- 检查 workflow 中的 `node-version` 是否为 `24`

这个脚本用于检查“声明是否一致”，不直接验证业务逻辑是否正确。

## 11. Node 20 升级到 Node 24 的关键点

从 Node 20 升级到 Node 24，至少要同步修改以下三处：

1. `action.yml` 中的 `runs.using`
2. `package.json` 中的 `engines.node`
3. workflow 中的 `node-version`

如果只改其中一处，通常会出现以下问题：

- 只改 `package.json`：开发环境声明变了，但 GitHub Action 实际运行时仍可能不是 Node 24
- 只改 `action.yml`：运行时切了，但本地开发和 CI 构建版本可能不一致
- 只改 workflow：CI 环境变了，但 Action 声明仍旧指向旧 runtime

因此，真正的升级不是“改一个数字”，而是让三层声明同时一致。

## 12. 推荐执行顺序

### 12.1 本地构建

```bash
bash scripts/build-common-actions.sh
```

### 12.2 本地功能验证

```bash
bash scripts/test-node24-action.sh
bash scripts/test-common-actions.sh
```

### 12.3 运行时声明检查

```bash
bash scripts/verify-action-runtime.sh 24
```

### 12.4 GitHub Actions 验证

将代码推送后，执行：

- `.github/workflows/node24-action-demo.yml`

## 13. 关于“升级测试”的说明

当前仓库已经是 Node 24 版本，因此它能证明的是：

- 当前 Node 24 配置一致
- 当前 Node 24 构建通过
- 当前 Node 24 测试通过

但它不能单独证明：

- 升级前的 Node 20 版本一定是正常的

如果要验证“Node 20 可以正常升级到 Node 24”，应该按以下流程进行：

1. 切到升级前 revision
2. 用 Node 20 执行构建和测试
3. 确认 Node 20 基线通过
4. 切回升级后 revision
5. 用 Node 24 执行构建和测试
6. 确认升级后行为与预期一致

## 14. 常用命令汇总

### 安装依赖并打包

```bash
bash scripts/build-common-actions.sh
```

### 测单个 action

```bash
bash scripts/test-node24-action.sh
```

### 测三个 action

```bash
bash scripts/test-common-actions.sh
```

### 检查当前仓库是否声明为 Node 24

```bash
bash scripts/verify-action-runtime.sh 24
```

## 15. 总结

这套 Node 24 示例的完整链路如下：

- `src/index.js` 编写源码
- `npm run build` 通过 `ncc` 打包到 `dist/index.js`
- `action.yml` 通过 `runs.using: node24` 声明运行时
- workflow 通过 `actions/setup-node` 指定 Node 24 环境
- 本地脚本用于构建、功能测试和运行时声明检查

如果后续还需要扩展更多 Node 24 Action，建议继续保持这套结构统一：

- Action 定义统一
- 构建脚本统一
- 测试脚本统一
- runtime 校验统一
