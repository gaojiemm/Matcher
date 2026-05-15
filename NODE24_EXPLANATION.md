# Node ランタイムアップグレードツール 設計書

## 1. ドキュメントの目的

本ドキュメントは **Node ランタイムアップグレードツール** の設計書です。
このツールの目標は、`copilot -p` コマンド一つで、リポジトリ内のすべての GitHub Action の Node ランタイム宣言を指定バージョンへ一括アップグレードし、宣言の整合確認・ビルド検証・回帰テストまで自動で完結させることです。ファイルを一つひとつ手動で修正する必要はありません。

本ドキュメントが扱う内容：

- ツールの設計背景と核心となる設計思想
- バージョン宣言の三層体系の設計根拠
- AI 駆動パスの設計意図
- Prompt-as-Spec の設計理念
- 各コンポーネントの責務分担
- アップグレードフローと検証ゲートの設計
- ディレクトリ構造と Action 構成の説明

## 2. 設計背景

GitHub Action の Node ランタイムバージョンは複数のファイルに分散して宣言されており、手動アップグレードでは次のような問題が起きやすい。

- `package.json` を修正したが `action.yml` を忘れた → GitHub が旧バージョンで Action を実行し続ける
- `action.yml` を修正したが CI workflow を同期しなかった → ビルド環境と実行環境のバージョンが不一致になる
- 対象ファイルが増えるほど（複数の Action ディレクトリ）、修正漏れのリスクが線形に増大する

これらの問題に共通する根本原因は、**バージョン宣言が三つの異なる層のファイルに分散しており、手動で同期させる際に体系的な制約がない**ことにある。

このツールの設計目標は、「どのファイルを直さなければならないか」を人間が記憶しなくてもよい、繰り返し実行可能で結果が検証可能なアップグレード機構を提供することである。

---

## 3. 核心設計思想

### 3.1 AI 駆動優先

アップグレードの主経路は、従来のシェルスクリプトではなく AI（GitHub Copilot CLI）による実行である。

```sh
copilot -p "$(cat .github/prompts/node-runtime-upgrade.prompt.md)

対象バージョン: <target>" --allow-all
```

**AI 駆動を選んだ理由：**

- バージョン宣言はドキュメント・README・説明ファイルなど非構造化な場所にも散在しており、正規表現では完全にカバーしにくい
- AI は実行前にスキャン結果をユーザーに提示し、変更範囲を確認する機会を与えられる
- AI はコンテキストを理解できるため、不規則な宣言フォーマットでも正しく認識・更新できる
- プロトコル（アップグレード手順）と AI の能力を組み合わせることで、「スキャン → 確認 → 修正 → 検証 → ビルド → テスト → 報告」の完全なクローズドループが実現できる

---

### 3.2 三層宣言の整合性原則

GitHub Action の Node バージョンは以下の三層で独立して宣言されており、すべてを同時に更新しなければならない。

| 層 | ファイル | フィールド | 役割 |
|---|---|---|---|
| ランタイム層 | `action.yml` | `runs.using: nodeXX` | GitHub が Action を実行する際に使う Node バージョンを決定する |
| 開発/ビルド層 | `package.json` / `package-lock.json` | `engines.node: ">=XX"` | ローカル開発・パッケージング時の Node バージョン要件を宣言する |
| CI 環境層 | `.github/workflows/*.yml` | `node-version: XX` | Runner 上にインストールする Node バージョンを決定する |

**一層だけ変更すると、それぞれ異なる障害モードが発生する：**

- `package.json` だけ変更：開発側の宣言は変わったが、GitHub Action の実際の実行時は旧バージョンのまま
- `action.yml` だけ変更：ランタイムは切り替わったが、ローカルビルドと CI 環境のバージョンが不一致になり、ビルド成果物の信頼性が損なわれる
- workflow だけ変更：CI 環境は変わったが、Action の `runs.using` は旧 runtime を指したままで、実際の実行時に反映されない

**真の意味でのアップグレード = 三層の宣言が同時に一致すること。** これがツールの検証ロジックの設計基盤である。

---

### 3.3 Prompt-as-Spec：プロンプトがアップグレード仕様である

`.github/prompts/node-runtime-upgrade.prompt.md` は使い捨てのスクリプトではなく、**リポジトリとともにバージョン管理されるアップグレードプロトコル**である。

設計意図：

- このファイルが「このリポジトリで Node ランタイムアップグレードを一回実行する」とはどういうことかを定義している
- スキャン範囲・更新ルール・検証基準・成功判定条件を規定している
- 誰がどのタイミングで同じ prompt を使ってアップグレードしても、動作が予測可能である
- アップグレードプロトコル自体の変更（たとえばスキャンパターンの追加）はこのファイルを修正することで反映され、口頭の取り決めに依存しない

このアプローチの利点：アップグレードツールの仕様がコード化されており、レビュー・テスト・メンテナンスが可能になる。

プロトコルの核心ステップ（詳細は `.github/prompts/node-runtime-upgrade.prompt.md` を参照）：

1. 対象バージョンを確認する
2. リポジトリ内のすべてのバージョン宣言をスキャンし、現状テーブルを提示する
3. （任意）feature ブランチを作成する
4. すべての宣言ファイルを更新する
5. ファイルを再読み込みして整合性を検証し、更新後状態テーブルを提示する
6. ビルドおよび動作確認を実施し、結果テーブルで報告する（コマンド詳細は非表示）
7. すべて通過で成功宣言、失敗した場合は自動修正後に再検証する

---

### 3.4 バージョン非依存設計

このツールは特定の Node バージョン番号に縛られることなく、任意の目標バージョンに対して使用できる設計である。

**具体的な実現方法：**

- prompt ファイルは `対象バージョン: <target>` パラメータを受け取る
- テストスクリプト内では `node -p "process.versions.node.split('.')[0]"` で現在実行中の Node メジャーバージョンを動的に取得し、ハードコードした数値は使わない

これにより、Node 24 から Node 26 へアップグレードする際に、**テストコード自体は修正不要**で、宣言ファイルのアップグレードのみで対応できる。アップグレード中に「宣言は直したがテストの期待値を直し忘れた」という問題を防ぐことができる。

---

### 3.5 検証ゲート設計：失敗しても成功とは宣言しない

アップグレードの成功判定には明確なゲート条件が設定されており、すべて通過して初めて完了とみなす。

| 検証フェーズ | 検証内容 |
|---|---|
| 宣言整合性 | すべての action.yml / package.json / workflow 内のバージョン宣言が一致している |
| ビルド検証 | すべての Action が対象 Node バージョンで正常にパッケージングできる |
| 重点機能検証 | コア Action の正常入力・必須パラメータ欠落・不正 JSON の三経路 |
| 回帰検証 | 三つの Action のメインパスの出力が期待通りである |

あるステップで失敗した場合、AI は問題を自動修正してそのステップから再検証を行い、すべて通過するか自動修復が不可能と判断されるまで継続する。

---

## 4. ディレクトリ構造

リポジトリ内でアップグレードツールに関連するファイルの配置は以下の通り。

```text
.github/
  prompts/
    node-runtime-upgrade.prompt.md   ← アップグレードプロトコル定義（Prompt-as-Spec）
  workflows/
    node24-action-demo.yml           ← CI デモワークフロー（CI 環境層の宣言を含む）
common/
  create-pipeline-context/
    action.yml                       ← ランタイム層の宣言
    src/index.js                     ← 開発・保守用ソースコード
    dist/index.js                    ← パッケージング成果物（GitHub Actions が実際に実行）
    package.json                     ← 開発/ビルド層の宣言
    package-lock.json                ← 依存関係ロック（バージョン宣言を同期）
  decide-env/
    （同じ構成）
  js-action-template/
    （同じ構成）
```

各ファイル/ディレクトリの責務：

- `common/*/action.yml`：GitHub Action のエントリ定義、**ランタイム層**のバージョン宣言の所在
- `common/*/src/index.js`：開発時に保守するソースコード（GitHub が直接実行するわけではない）
- `common/*/dist/index.js`：パッケージング後の成果物、GitHub Actions ランタイムが直接実行する
- `common/*/package.json`：依存関係・**開発/ビルド層**の Node バージョン宣言・ビルドスクリプト定義
- `common/*/package-lock.json`：依存関係ロックファイル。`packages[""].engines` にもバージョン宣言が含まれるため必ず同期する
- `.github/prompts/node-runtime-upgrade.prompt.md`：AI アップグレードプロトコル定義（Prompt-as-Spec）
- `.github/workflows/node24-action-demo.yml`：CI ワークフロー、**CI 環境層**のバージョン宣言の所在

---

## 5. サンプル Action コンポーネント

リポジトリには三つのサンプル Action があり、Node ランタイムアップグレード後の実際の動作を示している。これら三つがアップグレードツールの検証対象でもある。

### 5.1 create-pipeline-context

役割：入力をもとに pipeline context を生成し、JSON 結果を出力する。

入力：

- `service`
- `test-parallel-keys`

出力：

- `pipeline-context`
- `test_parallel_keys`

### 5.2 decide-env

役割：ブランチ名または Git ref からデプロイ先環境を判定する。

入力：

- `branch-name`
- `github-ref`

出力：

- `environment`
- `deploy_enabled`

### 5.3 js-action-template

役割：最小構成の JavaScript Action テンプレートとして、Node ランタイム上での入力・出力・JSON パースの基本パターンを示す。

入力：

- `name`
- `payload`

出力：

- `message`
- `payload`

---

## 6. action.yml の構成（ランタイム層の宣言）

`action.yml` は GitHub Action のエントリ定義ファイルであり、三層の宣言の中で**最も重要**な層である。

**重要性の理由：`runs.using` が、GitHub が Action を実行する際に使う Node バージョンを決定するからである。** `package.json` だけ変更して `action.yml` を変更しなければ、GitHub は旧バージョンで実行し続ける。

`common/create-pipeline-context/action.yml` を例にとると：

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

主要フィールドの説明：

- `runs.using`：GitHub Action の JavaScript ランタイムバージョンを指定する（**ランタイム層のコアフィールド**）
- `runs.main`：実行エントリファイルを指定し、常にパッケージング成果物 `dist/index.js` を指す
- `inputs` / `outputs`：Action のインターフェース定義

アップグレード時の `runs.using` の変化：`node20` → `node24` → `node26` …

---

## 7. package.json の構成（開発/ビルド層の宣言）

`package.json` の `engines.node` は開発・パッケージング時に要求する Node バージョンを宣言しており、**開発/ビルド層**の宣言の所在である。

`common/create-pipeline-context/package.json` を例にとると：

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

主要フィールドの説明：

- `engines.node`：**開発/ビルド層のコアフィールド**、Node バージョン要件を宣言する
- `scripts.build`：`ncc` で `src/index.js` を `dist/index.js` にパッケージングする
- `scripts.package`：現状は `npm run build` と等価
- `dependencies.@actions/core`：GitHub Action 公式コアライブラリ。input の読み取り・output の設定・ログ出力・失敗状態の設定に使用する
- `devDependencies.@vercel/ncc`：Node ソースコードと依存関係を単一ファイルの成果物にパッケージングするツール

アップグレード時の `engines.node` の変化：`>=20` → `>=24` → `>=26` …

**注意：** `package-lock.json` の `packages[""].engines.node` も同様に修正する必要がある。そうしないと、厳格モードでのバージョンチェックでエラーが発生する。

---

## 8. src と dist の責務

### 8.1 設計意図

GitHub Actions は、Runner 上で Action のコードが直接実行可能である必要があり、追加の `npm install` には依存できない。
そのため、`src/index.js` と `dist/index.js` は別々の責務を担っている。

- **`src/index.js`**：開発時に保守するソースコード。可読性優先で、`node_modules` の依存関係を参照する
- **`dist/index.js`**：`ncc build` で生成した単一ファイルのパッケージング成果物。すべての依存関係を含んでおり、GitHub Actions がこのファイルを直接実行する

### 8.2 ncc でパッケージングする理由

- CI Runner 上での実行がソースコードディレクトリのモジュール解決構造に依存しない
- パッケージング成果物をリポジトリにコミットすれば Runner 上で直接実行可能で、`npm install` を再実行する必要がない
- 単一ファイルの成果物は Runner のファイル I/O を減らし、実行速度が向上する

---

## 9. Workflow 内のバージョン宣言（CI 環境層）

ファイル：`.github/workflows/node24-action-demo.yml`

該当箇所：

```yaml
- name: Setup Node 24
  uses: actions/setup-node@v4
  with:
    node-version: 24
```

**設計意図：** CI 層は `action.yml` の `runs.using` と一致させなければならない。CI が Node 24 でビルドして Action が `node20` を宣言していた場合、ビルド成果物の互換性が保証できない。

また、workflow 内ではローカル Action を次の方法で呼び出している。

```yaml
- name: Run upgraded local action
  id: pipeline-context
  uses: ./common/create-pipeline-context
```

`uses: ./` はリポジトリ内のローカル Action を呼び出すことを意味する。GitHub は該当ディレクトリの `action.yml` を読み込み、`runs.using` に指定されたバージョンで `runs.main` のファイルを実行する。

---

## 10. アップグレード実行手順

```bash
copilot -p "$(cat .github/prompts/node-runtime-upgrade.prompt.md)

対象バージョン: <target>" --allow-all
```

AI は `.github/prompts/node-runtime-upgrade.prompt.md` に定義されたプロトコルに従って実行する。

1. リポジトリ内のすべてのバージョン宣言をスキャンし、現状をテーブルで提示する
2. すべての宣言ファイルを更新する
3. 整合性を再検証し、更新後状態テーブルを提示する
4. ビルド + テストを実行し、結果テーブルで報告する
5. すべて通過で成功を宣言し、いずれかのステップが失敗した場合は自動修正後に再検証する

---

## 11. アップグレード対象範囲と検証境界

### 11.1 ツールが対象とする範囲

| 対象 | 宣言フィールド | ツールの対象か |
|---|---|---|
| `common/*/action.yml` | `runs.using` | ✅ |
| `common/*/package.json` | `engines.node` | ✅ |
| `common/*/package-lock.json` | `packages[""].engines.node` | ✅ |
| `.github/workflows/node24-action-demo.yml` | `node-version` | ✅ |
| `README.md` / 説明ドキュメント | バージョン記述テキスト | ✅ |
| `src/index.js` のビジネスロジック | — | ❌（業務ロジックは変更しない） |

### 11.2 宣言の整合 ≠ アップグレード成功

AI のアップグレード成功判定は以下の四ステップをすべて通過する必要がある。

1. ✅ すべての宣言が一致している（整合確認）
2. ✅ ビルドが通過している
3. ✅ ビルド後の機能確認が通過している
4. ✅ 回帰確認が通過している

### 11.3 アップグレード前後の比較検証について

「Node X から Node Y へのアップグレード自体が回帰を引き起こしていないか」を検証するには：

1. アップグレード前の revision に切り替え、Node X 環境でビルド + テストを実行し、ベースラインが通過することを確認する
2. アップグレード後の revision に切り替え、Node Y 環境でビルド + テストを実行し、アップグレード後の動作が期待通りであることを確認する

---

## 12. コマンドリファレンス

| 目的 | コマンド |
|---|---|
| AI 駆動アップグレード | `copilot -p "$(cat .github/prompts/node-runtime-upgrade.prompt.md)\n\n対象バージョン: <target>" --allow-all` |

---

## 13. 設計まとめ

このツールの核心となる設計理念は以下の六点にまとめられる。

1. **AI 駆動優先**：`copilot -p` + prompt ファイル一つのコマンドでアップグレード作業が完結する
2. **三層宣言の整合性**：`action.yml` / `package.json` / workflow の三層を必ず同時に更新する
3. **Prompt-as-Spec**：アップグレードプロトコルを prompt ファイルの形でリポジトリにバージョン管理し、繰り返し可能・保守可能・レビュー可能にする
4. **バージョン非依存設計**：任意の目標バージョンに対して使用でき、テストコードはハードコードしたバージョン番号に依存しない
5. **検証ゲート**：宣言整合 + ビルド通過 + 機能テスト + 回帰テストの四ステップをすべて通過して初めてアップグレード成功とみなす
6. **バージョン非依存**：同じコマンドで Node 20→24・24→26 など任意のバージョン跳躍に対応できる
