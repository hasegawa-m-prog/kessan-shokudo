# 初回公開の準備

まだ本番へのデプロイは行っていません。この手順は公開時に利用する設定案です。

## 費用と期限を先に確認する

Renderの無料PostgreSQLは作成後30日で期限を迎えます。10月17日に作成すると11月末の提出には間に合わないため、無料枠のまま継続できる前提にはしません。
無料Webサービスは15分間アクセスがないと停止し、次回アクセス時に起動待ちが発生します。
2026年10月17日、Web月額7ドル＋PostgreSQL月額6.30ドル（1GB）、合計月額13.30ドルの構成で本人の承認を得ました。税金・追加使用料・既存サービスの費用は別です。

公式資料（2026年10月17日確認）：
- https://render.com/docs/free
- https://render.com/pricing
- https://render.com/docs/deploy-rails-8

## 準備するもの

1. Renderへのログインと、対象GitHubリポジトリへの連携権限。
2. 利用期間・費用に合うPostgreSQLとWebサービスのプラン。
3. CIの確認済みコミット。開発中のmainへ自動反映する設定にはしない。

## Webサービスの設定案

| 項目 | 設定 |
| --- | --- |
| Runtime | Ruby |
| Build Command | `bin/render-build.sh` |
| Pre-Deploy Command | `bin/rails db:migrate` |
| Start Command | `bundle exec rails server -b 0.0.0.0 -p $PORT` |
| Health Check | `/up` |
| Auto Deploy | 初回は無効。確認後に手動で反映 |
| RAILS_ENV | `production` |
| RUBY_VERSION | `3.4.11` |
| DATABASE_URL | 同一リージョンのPostgreSQLの内部接続URL。秘密情報として登録 |
| SECRET_KEY_BASE | Render側で生成した十分に長い乱数。チャットやGitHubには貼らない |
| WEB_CONCURRENCY | 最初は `0`（Pumaの単一プロセス） |
| RAILS_MAX_THREADS | `3` |

現在のアプリは暗号化credentialsへサービスの秘密情報を保存していません。環境変数で設定し、`master.key`を公開しません。
有料WebのPre-Deploy Commandで、ビルド成功後・切り替え前にマイグレーションを実行します。データを壊す変更は行わず、今後のスキーマ変更時にはバックアップと互換性を確認します。

## 初回公開の確認

- 公開URLでTOP・登録・ログイン・ログアウトが正常に動く。
- 本番DBに接続できる（`/up`だけではDB接続の確認にはならない）。
- 再読み込み・再ログイン後も登録が維持される。
- HTTPSとCookieのSecure属性が有効である。
- 秘密情報や詳細なエラー画面を表示しない。

初回公開は環境確認のためです。クイズなどの全MVP機能を実装し、本番で通し確認するまでは、MVPレビューを依頼しません。
