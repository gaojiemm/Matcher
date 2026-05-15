# Node ランタイムアップグレード テスト仕様書

## 試験概要

| 項目 | 内容 |
|---|---|
| 試験日時 | 2026-05-15 |
| 対象ブランチ | `chore/node-runtime-24` |
| 対象コミット | `5ca9776` Upgrade Node runtime to 24 |
| 実行 Node バージョン | v24.15.0 |
| 実行方法 | `copilot -p "$(cat .github/prompts/node-runtime-upgrade.prompt.md)\n\n対象バージョン: 24" --allow-all` |

---

## AI 実行プラン（セッション記録）

AI が自動生成した実行計画は次の 3 ステップです。

1. すべてのランタイム宣言とドキュメントが Node 24 を指していることを確認する
2. リポジトリのランタイム確認・ビルド・アクション検証スクリプトを実行する
3. 要求されたメッセージでコミットする（ファイル変更がない場合は空コミットを使用する）

---

## テストケース

### TC-01　ランタイム宣言の整合確認

**目的：** 全ファイルのランタイム宣言が Node 24 に揃っていること

**確認対象ファイル：**

| ファイル | フィールド | 期待値 |
|---|---|---|
| `common/create-pipeline-context/action.yml` | `runs.using` | `node24` |
| `common/decide-env/action.yml` | `runs.using` | `node24` |
| `common/js-action-template/action.yml` | `runs.using` | `node24` |
| `common/create-pipeline-context/package.json` | `engines.node` | `>=24` |
| `common/decide-env/package.json` | `engines.node` | `>=24` |
| `common/js-action-template/package.json` | `engines.node` | `>=24` |
| `common/create-pipeline-context/package-lock.json` | `packages[""].engines.node` | `>=24` |
| `common/decide-env/package-lock.json` | `packages[""].engines.node` | `>=24` |
| `common/js-action-template/package-lock.json` | `packages[""].engines.node` | `>=24` |
| `.github/workflows/node24-action-demo.yml` | `node-version` | `24` |

**実行ログ：**

```
All action runtime declarations match Node 24.
```

**判定：** ✅ PASS

---

### TC-02　共通アクション ビルド確認

**目的：** 全共通アクションが Node 24 上で正常にビルドできること

**実行ログ：**

```
== building common/create-pipeline-context ==
added 8 packages, and audited 9 packages in 473ms
> create-pipeline-context@1.0.0 build
> ncc build src/index.js -o dist
ncc: Version 0.38.4
ncc: Compiling file index.js into CJS
949kB  dist/index.js
949kB  [240ms] - ncc 0.38.4

== building common/decide-env ==
added 8 packages, and audited 9 packages in 295ms
> decide-env@1.0.0 build
> ncc build src/index.js -o dist
948kB  dist/index.js
948kB  [258ms] - ncc 0.38.4

== building common/js-action-template ==
added 8 packages, and audited 9 packages in 524ms
> js-action-template@1.0.0 build
> ncc build src/index.js -o dist
948kB  dist/index.js
948kB  [223ms] - ncc 0.38.4

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
pipeline-context<<ghadelimiter_...
{"service":"matcher-demo","runtime":"node24","generatedAt":"2026-05-15T08:42:37.654Z","testParallelKeys":["unit-1","unit-2"]}
...
test_parallel_keys<<ghadelimiter_...
["unit-1","unit-2"]
...
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
pipeline-context<<...
{"service":"matcher-demo","runtime":"node24","generatedAt":"2026-05-15T08:42:39.433Z","testParallelKeys":["unit-1","unit-2"]}
test_parallel_keys<<...
["unit-1","unit-2"]
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
environment<<...
staging
deploy_enabled<<...
true
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
message<<...
Hello, matcher-demo from Node 24.
payload<<...
{"feature":"runtime-check"}
```

**判定：** ✅ PASS

**TC-04 総合判定：** ✅ All common Node 24 action tests passed.

---

## 総合判定

| テストケース | 内容 | 結果 |
|---|---|---|
| TC-01 | ランタイム宣言の整合確認 | ✅ PASS |
| TC-02 | 共通アクション ビルド確認 | ✅ PASS |
| TC-03 | create-pipeline-context 重点テスト（3 ケース） | ✅ PASS |
| TC-04 | 全共通アクション 回帰テスト（3 アクション） | ✅ PASS |

**最終判定：✅ Node 24 へのアップグレードが正常に完了しました。**

---

## 備考

- ローカル Node バージョン（v24.15.0）が対象バージョン（24）と一致しているため、実機による検証が完了しています。
- `npm audit` で moderate 1 件・high 1 件の脆弱性が報告されていますが、これはアップグレード作業とは無関係の既存の依存関係の問題です。
