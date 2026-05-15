# Node ランタイムアップグレード テスト仕様書

## 試験概要

| 項目 | 内容 |
|---|---|
| 試験日時 | 2026-05-15 |
| 対象ブランチ | `main` |
| 対象コミット | `13048dd` Upgrade Node runtime to 24 |
| 実行 Node バージョン | v24.15.0 |
| 実行コマンド | `copilot -p "$(cat .github/prompts/node-runtime-upgrade.prompt.md)\n\n対象バージョン: 24" --allow-all` |

---

## テスト観点

`copilot -p` コマンドに **対象バージョン: 24** を指定して実行した後、リポジトリ内のすべての Node ランタイム宣言が **node24** に揃うこと、およびビルドと動作確認が通過すること。

---

## テストケース

### TC-01　ランタイム宣言の整合確認

**目的：** `copilot -p` 実行後、全ファイルのランタイム宣言が node20 から node24 に揃っていること

**実行前の状態（node20）：**

| ファイル | 行 | 宣言の種類 | 実行前の値 |
|---|---:|---|---|
| `common/create-pipeline-context/action.yml` | 20 | `runs.using` | `node20` |
| `common/create-pipeline-context/package.json` | 9 | `engines.node` | `>=20` |
| `common/create-pipeline-context/package-lock.json` | 18 | `packages[""].engines.node` | `>=20` |
| `common/decide-env/action.yml` | 21 | `runs.using` | `node20` |
| `common/decide-env/package.json` | 9 | `engines.node` | `>=20` |
| `common/decide-env/package-lock.json` | 18 | `packages[""].engines.node` | `>=20` |
| `common/js-action-template/action.yml` | 20 | `runs.using` | `node20` |
| `common/js-action-template/package.json` | 9 | `engines.node` | `>=20` |
| `common/js-action-template/package-lock.json` | 18 | `packages[""].engines.node` | `>=20` |
| `.github/workflows/node24-action-demo.yml` | 24 | `node-version` | `20` |

**整合確認ログ（実行後）：**

```
All action runtime declarations match Node 24.
```

**実行後の状態（node24）：**

| ファイル | 行 | 宣言の種類 | 更新後の値 | 一致 |
|---|---:|---|---|---|
| `common/create-pipeline-context/action.yml` | 20 | `runs.using` | `node24` | ✅ |
| `common/create-pipeline-context/package.json` | 9 | `engines.node` | `>=24` | ✅ |
| `common/create-pipeline-context/package-lock.json` | 18 | `packages[""].engines.node` | `>=24` | ✅ |
| `common/decide-env/action.yml` | 21 | `runs.using` | `node24` | ✅ |
| `common/decide-env/package.json` | 9 | `engines.node` | `>=24` | ✅ |
| `common/decide-env/package-lock.json` | 18 | `packages[""].engines.node` | `>=24` | ✅ |
| `common/js-action-template/action.yml` | 20 | `runs.using` | `node24` | ✅ |
| `common/js-action-template/package.json` | 9 | `engines.node` | `>=24` | ✅ |
| `common/js-action-template/package-lock.json` | 18 | `packages[""].engines.node` | `>=24` | ✅ |
| `.github/workflows/node24-action-demo.yml` | 24 | `node-version` | `24` | ✅ |

**判定：** ✅ PASS

---

### TC-02　共通アクション ビルド確認

**目的：** 全共通アクションが Node 24 上で正常にビルドできること

**実行ログ：**

```
== building common/create-pipeline-context ==
added 8 packages, and audited 9 packages in 550ms

2 vulnerabilities (1 moderate, 1 high)

> create-pipeline-context@1.0.0 build
> ncc build src/index.js -o dist

ncc: Version 0.38.4
ncc: Compiling file index.js into CJS
949kB  dist/index.js
949kB  [260ms] - ncc 0.38.4

== building common/decide-env ==
added 8 packages, and audited 9 packages in 306ms

2 vulnerabilities (1 moderate, 1 high)

> decide-env@1.0.0 build
> ncc build src/index.js -o dist

ncc: Version 0.38.4
ncc: Compiling file index.js into CJS
948kB  dist/index.js
948kB  [266ms] - ncc 0.38.4

== building common/js-action-template ==
added 8 packages, and audited 9 packages in 294ms

2 vulnerabilities (1 moderate, 1 high)

> js-action-template@1.0.0 build
> ncc build src/index.js -o dist

ncc: Version 0.38.4
ncc: Compiling file index.js into CJS
948kB  dist/index.js
948kB  [245ms] - ncc 0.38.4

All common actions packaged successfully.
```

**判定：** ✅ PASS

---

### TC-03　create-pipeline-context 重点テスト

**目的：** `create-pipeline-context` アクションが Node 24 上で期待通りに動作すること

#### TC-03-1　正常系：必須入力あり

| 入力 | 値 |
|---|---|
| `INPUT_SERVICE` | `matcher-demo` |
| `INPUT_TEST_PARALLEL_KEYS` | `["unit-1","unit-2"]` |

**実行ログ：**

```
== success case ==
Generated pipeline context for matcher-demo on Node 24.
pipeline-context={"service":"matcher-demo","runtime":"node24","generatedAt":"2026-05-15T02:25:28.559Z","testParallelKeys":["unit-1","unit-2"]}
test_parallel_keys=["unit-1","unit-2"]
```

**判定：** ✅ PASS

#### TC-03-2　異常系：必須入力なし

| 入力 | 値 |
|---|---|
| `INPUT_SERVICE` | （未設定） |

**期待動作：** エラー終了し、エラーメッセージを出力

**実行ログ：**

```
== missing required input ==
::error::Input required and not supplied: service
```

**判定：** ✅ PASS

#### TC-03-3　異常系：JSON 不正入力

| 入力 | 値 |
|---|---|
| `INPUT_SERVICE` | `matcher-demo` |
| `INPUT_TEST_PARALLEL_KEYS` | `not-json` |

**期待動作：** エラー終了し、JSON パースエラーを出力

**実行ログ：**

```
== invalid test-parallel-keys ==
::error::Invalid test-parallel-keys: Unexpected token 'o', "not-json" is not valid JSON
```

**判定：** ✅ PASS

**TC-03 総合判定：** ✅ All local action tests passed.

---

### TC-04　全共通アクション 回帰テスト

**目的：** 全 3 アクションが Node 24 上でそれぞれの正常系を通過すること

#### TC-04-1　create-pipeline-context

**実行ログ：**

```
== create-pipeline-context success ==
Generated pipeline context for matcher-demo on Node 24.
pipeline-context<<ghadelimiter_dbccd11e-c15a-4902-a7e3-80993d7d7104
{"service":"matcher-demo","runtime":"node24","generatedAt":"2026-05-15T13:39:02.525Z","testParallelKeys":["unit-1","unit-2"]}
ghadelimiter_dbccd11e-c15a-4902-a7e3-80993d7d7104
test_parallel_keys<<ghadelimiter_b53d8894-bd79-48e4-9ab8-3d71a04aa4bd
["unit-1","unit-2"]
ghadelimiter_b53d8894-bd79-48e4-9ab8-3d71a04aa4bd
```

**判定：** ✅ PASS

#### TC-04-2　decide-env

| 入力 | 値 |
|---|---|
| `INPUT_BRANCH_NAME` | `release/2026.05` |

**実行ログ：**

```
== decide-env success ==
Selected staging for branch release/2026.05.
environment<<ghadelimiter_5148bddc-1352-4090-8b2e-3f18a5e32928
staging
ghadelimiter_5148bddc-1352-4090-8b2e-3f18a5e32928
deploy_enabled<<ghadelimiter_ef3f49ed-39a5-4a09-9e0c-c4b3cf61ed61
true
ghadelimiter_ef3f49ed-39a5-4a09-9e0c-c4b3cf61ed61
```

**判定：** ✅ PASS

#### TC-04-3　js-action-template

| 入力 | 値 |
|---|---|
| `INPUT_NAME` | `matcher-demo` |
| `INPUT_PAYLOAD` | `{"feature":"runtime-check"}` |

**実行ログ：**

```
== js-action-template success ==
Hello, matcher-demo from Node 24.
message<<ghadelimiter_cc33c904-3f4b-45d9-ace4-ae44d0e65c8a
Hello, matcher-demo from Node 24.
ghadelimiter_cc33c904-3f4b-45d9-ace4-ae44d0e65c8a
payload<<ghadelimiter_9c757802-5616-4a76-8096-f19f120bf92b
{"feature":"runtime-check"}
ghadelimiter_9c757802-5616-4a76-8096-f19f120bf92b
```

**判定：** ✅ PASS

**TC-04 総合判定：** ✅ All common Node 24 action tests passed.

---

## 総合判定

| テストケース | 内容 | 結果 |
|---|---|---|
| TC-01 | ランタイム宣言の整合確認（node20 → node24） | ✅ PASS |
| TC-02 | 共通アクション ビルド確認 | ✅ PASS |
| TC-03 | create-pipeline-context 重点テスト（3 ケース） | ✅ PASS |
| TC-04 | 全共通アクション 回帰テスト（3 アクション） | ✅ PASS |

**最終判定：✅ Node 24 へのアップグレードが正常に完了しました。**

---

## 備考

- ローカル Node バージョン（v24.15.0）が対象バージョン（24）と一致しているため、実機による検証が完了しています。
- `npm audit` で moderate 1 件・high 1 件の脆弱性が報告されていますが、これはアップグレード作業とは無関係の既存の依存関係の問題です。
