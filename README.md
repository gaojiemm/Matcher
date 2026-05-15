# GitHub Actions 向け Problem Matcher デモ

このリポジトリでは、GitHub Actions のカスタム Problem Matcher を使って、通常のコマンドライン出力を Actions UI 上の構造化されたアノテーションに変換する方法を紹介します。特に、Kubernetes の image pull エラーを manifest の該当箇所に紐づけて表示する使い方を想定しています。

## Problem Matcher とは

Problem Matcher を使うと、GitHub Actions はツールの出力からエラーや警告を認識できます。出力の 1 行が設定された正規表現に一致すると、GitHub はその問題をファイル、行番号、列番号に関連付けて、workflow summary やログアノテーションに表示できます。

次のような場面で便利です。

- 固定フォーマットでエラーを出力する社内スクリプトがある
- 完全な GitHub Action を作らずに軽量なアノテーションを使いたい
- CI ログから失敗したソース位置へ直接たどれるようにしたい

## リポジトリ構成

このリポジトリには、すぐに動かせる完全なデモが含まれています。

```text
.github/
	problem-matcher.json
	workflows/
		demo.yml
		node24-action-demo.yml
common/
	create-pipeline-context/
		action.yml
		dist/index.js
		src/index.js
		package.json
	decide-env/
		action.yml
		dist/index.js
		src/index.js
		package.json
	js-action-template/
		action.yml
		dist/index.js
		src/index.js
		package.json
demo/
	example.js
k8s/
	deployment.yaml
scripts/
	build-common-actions.sh
	emit-demo-errors.sh
	emit-imagepull-errors.sh
	test-common-actions.sh
README.md
```

## Node 24 へのアップグレード例

スクリーンショットのような JavaScript ベースの GitHub Action を想定して、`common/create-pipeline-context` に最小構成のサンプルを追加しています。

このサンプルで Node 20 から Node 24 へ上げるときの変更点は次の 3 点です。

- `action.yml` の `runs.using` を `node24` に変更する
- `package.json` の `engines.node` を `>=24` に変更する
- workflow 側でも `actions/setup-node` で `node-version: 24` を使う

Node 20 から 24 へ上げるときの一番重要な変更点は、`action.yml` の `runs.using` です。GitHub Action の JavaScript runtime はここで決まるため、`package.json` だけを 24 にしても upgrade は完了しません。

一方で、`runs.using` だけを変えると依存関係や build 手順の不整合を見落としやすいため、このリポジトリでは次の 3 層をそろえて確認する前提にしています。

- 実行 runtime: `action.yml` の `runs.using`
- 開発 runtime: `package.json` の `engines.node`
- CI runtime: workflow の `actions/setup-node`

追加したサンプルは次の 3 つです。

- `common/create-pipeline-context`: パイプライン用 JSON を出力する action
- `common/decide-env`: ブランチ名からデプロイ先環境を決める action
- `common/js-action-template`: Node 24 ベースの最小 JavaScript action テンプレート

このサンプルは最小実行版ではなく、より実運用に近い構成にしてあります。

- `src/index.js`: メンテナンス対象のソースコード
- `dist/index.js`: GitHub Actions から直接実行される配布物
- `package.json`: `build` と `package` スクリプトを定義
- `package-lock.json`: 依存関係を固定

`.github/workflows/node24-action-demo.yml` ではこの 3 つのローカル action を実際に呼び出して出力まで確認できます。ローカルでは `scripts/test-common-actions.sh` で動作確認、`scripts/build-common-actions.sh` で依存インストールとパッケージングをまとめて実行できます。

## 20 から 24 への upgrade 検証手順

この checkout はすでに Node 24 へ上がった後の状態なので、ここだけでは「Node 20 版が正常だったこと」までは証明できません。upgrade を確認するには、upgrade 前後の 2 つの revision で同じ観点を確認する必要があります。

推奨手順は次のとおりです。

1. upgrade 前の revision を checkout し、`bash scripts/verify-action-runtime.sh 20` を実行する
2. Node 20 環境で、その revision の build と test を実行して正常終了を確認する
3. upgrade 後の revision を checkout し、`bash scripts/verify-action-runtime.sh 24` を実行する
4. Node 24 環境で `bash scripts/build-common-actions.sh` と `bash scripts/test-common-actions.sh` を実行する
5. upgrade 前後で、入力に対する出力仕様が変わっていないことを確認する

現在の revision では、4 の手順はそのまま実行できます。1 と 2 は、Node 20 を使っていた upgrade 前の branch または tag が必要です。

## Matcher の設定

Matcher は `.github/problem-matcher.json` で定義されており、次のパターンを使用します。

```json
{
	"version": "0.2",
	"problemMatcher": [
		{
			"owner": "test-failure",
			"source": "test",
			"applyTo": "allDocuments",
			"fileLocation": ["relative"],
			"pattern": [
				{
					"regexp": "^(.*):(\\d+):(\\d+)\\s+(.*)$",
					"file": 1,
					"line": 2,
					"column": 3,
					"message": 4
				}
			]
		}
	]
}
```

この Matcher は、コマンド出力が次の形式であることを前提にしています。

```text
path/to/file.ext:line:column message
```

例:

```text
src/example.js:12:5 Unexpected token
tests/login.spec.ts:34:9 Assertion failed: expected 200, received 500
```

## 仕組み

この正規表現では次の 4 つの値を取得します。

1. ファイルパス
2. 行番号
3. 列番号
4. メッセージ本文

ログの 1 行が一致すると、GitHub Actions はそのファイル位置に紐づいたアノテーションを作成します。`fileLocation` は `relative` に設定されているため、出力されるファイルパスはリポジトリルートからの相対パスである必要があります。

## Workflow での使い方

特別な `::add-matcher::` コマンドを使うことで、実行時に Matcher を読み込めます。

このリポジトリには、`.github/workflows/demo.yml` に動作するサンプルがすでに含まれています。

この workflow は次の 3 つを行います。

1. Matcher を登録する
2. image pull エラーを problem matcher 形式で出力するスクリプトを実行する
3. ジョブの最後に Matcher を削除する

Workflow の内容:

```yaml
name: Problem Matcher Demo

on:
	workflow_dispatch:
	push:

jobs:
	demo:
		runs-on: ubuntu-latest
		steps:
			- name: Checkout
				uses: actions/checkout@v4

			- name: Register problem matcher
				run: echo '::add-matcher::.github/problem-matcher.json'

			- name: Emit image pull diagnostics
				run: bash scripts/emit-imagepull-errors.sh

			- name: Remove problem matcher
				if: always()
				run: echo '::remove-matcher owner=test-failure::'
```

ジョブが実行されると、`scripts/emit-imagepull-errors.sh` の出力が Actions のログ上で `k8s/deployment.yaml` に対するアノテーションとして表示されるはずです。

## Image Pull エラーの出力例

image pull 用のデモスクリプトは次の行を出力します。

```text
k8s/deployment.yaml:17:18 Failed to pull image 'ghcr.io/example/private-app:missing': rpc error: code = NotFound desc = failed to pull and unpack image
k8s/deployment.yaml:17:18 ErrImagePull: pull access denied or repository does not exist
k8s/deployment.yaml:17:18 ImagePullBackOff: back-off pulling image 'ghcr.io/example/private-app:missing'
```

`k8s/deployment.yaml` は実在するファイルなので、GitHub Actions は各アノテーションを実際のファイル位置に関連付けられます。

## なぜこの形で出すのか

Kubernetes や CI の実行ログにそのまま出る `ErrImagePull` や `ImagePullBackOff` は、そのままでは GitHub Actions 上でソース位置に紐づきません。

そこで、次のように `file:line:column message` の形に変換して出力します。

```text
k8s/deployment.yaml:17:18 ErrImagePull: pull access denied or repository does not exist
```

こうしておくと、manifest の `image:` 行に直接アノテーションを付けられます。image pull の問題を「どの定義が原因か」に結びつけて見せたい場合は、このやり方が実用的です。

## ローカル出力のルール

独自のスクリプトやテストランナーをこの Matcher に対応させたい場合は、設定された形式どおりに行を出力する必要があります。

一致する例:

```text
src/app.py:18:2 Undefined variable 'user_id'
```

一致しない例:

```text
Error in src/app.py on line 18: Undefined variable 'user_id'
```

2 つ目の例は、設定された正規表現に一致しないため認識されません。

## よくある利用ケース

- カスタムテストハーネス
- 社内用リンター
- ビルドスクリプト
- マイグレーションや検証用スクリプト
- ファイルベースの診断を出力するモノレポ向けツール

## デバッグのヒント

GitHub Actions 上でアノテーションが表示されない場合は、次の点を確認してください。

1. 出力を行う前に `::add-matcher::` で matcher ファイルを読み込んでいるか
2. ログに出しているパスがリポジトリルートからの相対パスになっているか
3. 出力行に行番号と列番号の両方が含まれているか
4. 出力形式が regexp と完全に一致しているか
5. 対象ファイルが checkout 済みの workspace 内に実在するか

## デモの実行方法

Matcher の動作を確認するには、次の手順を実行します。

1. このリポジトリを GitHub に push する
2. Actions タブを開く
3. `Problem Matcher Demo` workflow を実行する、または `main` への push で起動する
4. ジョブのログを開いて生成されたアノテーションを確認する

ローカルで出力だけ確認したい場合は、次のコマンドを実行します。

```bash
bash scripts/emit-imagepull-errors.sh
```

## 今後の改善案

このデモは、たとえば次のように拡張できます。

- warning と error を別々の matcher 定義で扱えるようにする
- スタックトレースやグループ化されたテスト出力向けに複数行パターンを追加する
- 別のツール形式に対応した 2 つ目の matcher を追加する
- スクリプトの出力形式が互換性を維持していることを確認する小さなテストステップを追加する

## 参考資料

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Problem Matchers Documentation](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#problem-matchers)