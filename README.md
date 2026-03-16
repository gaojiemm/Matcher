# GitHub Actions 向け Problem Matcher デモ

このリポジトリでは、GitHub Actions のカスタム Problem Matcher を使って、通常のコマンドライン出力を Actions UI 上の構造化されたアノテーションに変換する方法を紹介します。

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
demo/
	example.js
scripts/
	emit-demo-errors.sh
README.md
```

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
2. 一致する診断メッセージを出力するスクリプトを実行する
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

			- name: Emit demo diagnostics
				run: bash scripts/emit-demo-errors.sh

			- name: Remove problem matcher
				if: always()
				run: echo '::remove-matcher owner=test-failure::'
```

ジョブが実行されると、`scripts/emit-demo-errors.sh` の出力が Actions のログ上で `demo/example.js` に対するアノテーションとして表示されるはずです。

## デモスクリプトの出力

デモスクリプトは次の行を出力します。

```text
demo/example.js:4:3 Unexpected console usage in demo check
demo/example.js:9:10 Missing validation before request execution
demo/example.js:14:5 Hard-coded fallback should be removed
```

`demo/example.js` は実在するファイルなので、GitHub Actions は各アノテーションを実際のファイル位置に関連付けられます。

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

## 今後の改善案

このデモは、たとえば次のように拡張できます。

- warning と error を別々の matcher 定義で扱えるようにする
- スタックトレースやグループ化されたテスト出力向けに複数行パターンを追加する
- 別のツール形式に対応した 2 つ目の matcher を追加する
- スクリプトの出力形式が互換性を維持していることを確認する小さなテストステップを追加する

## 参考資料

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Problem Matchers Documentation](https://docs.github.com/en/actions/using-workflows/workflow-commands-for-github-actions#problem-matchers)