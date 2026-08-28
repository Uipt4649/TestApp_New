# Echo.me Chatbot Backend

推しの名前から、Sony Music公式サイト、Bandsintown、Ticketmaster、YouTube、登録済みアーティスト公式サイトの公開情報を取得して統一形式で返すFastAPIバックエンドです。APIキーはiOSアプリへ保存しません。

日本向けには、Sony Music公式検索で入力名を厳密に照合し、同社の公式ライブ情報に掲載された今後の日程を取得します。Sony Music側の標準アーティストページに掲載されているアーティストは個別登録やAPIキーなしで検索できます。YOASOBIとRADWIMPSの既存取得処理も維持しています。取得結果は既存キャッシュに保存され、検索のたびに巡回しません。

## ローカル起動

通常はXcodeで`TestApp_New`をRunすると、共有SchemeのPre-actionがバックエンドを自動起動します。既に起動している場合はそのプロセスを利用します。

初回のみ依存関係を準備します。

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
cp .env.example .env
```

シミュレータから`localhost`へ接続するだけなら、`BACKEND_APP_TOKEN`は空欄のままで利用できます。ループバック以外の接続には認証回避を適用しません。

実機から接続する場合は、`BACKEND_APP_TOKEN`に次のようなランダム値を設定してください。

```bash
openssl rand -hex 32
```

環境変数を読み込んで起動します。

```bash
set -a
source .env
set +a
uvicorn app.main:app --reload
```

手動起動せずXcodeに任せる場合、`.env`を保存した時点で準備完了です。起動ログは`$TMPDIR/echome-backend.log`に出力されます。

シミュレータは既定で `http://localhost:8000` へ接続するため、Xcode Schemeの追加設定は不要です。

実機ではRun用環境変数 `CHATBOT_BASE_URL` にMacのLAN内アドレス（例: `http://192.168.1.10:8000`）、`CHATBOT_APP_TOKEN`にバックエンドと同じトークンを設定し、バックエンドを次のように起動します。

```bash
uvicorn app.main:app --reload --host 0.0.0.0
```

Sony Music公式情報だけを利用する場合、外部APIキーの設定は不要です。取得対象は公式検索と公式ライブ情報に掲載されたデータに限られ、未掲載の公演を推測して登録することはありません。

ほかの取得元も併用する場合は、必要なものだけを設定してください。

- `BANDSINTOWN_APP_ID`
- `TICKETMASTER_API_KEY`
- `YOUTUBE_API_KEY`

`YOUTUBE_API_KEY`を設定すると、アーティスト名と一致するか、名前に`Official`などの公式接尾辞が付いたチャンネルの今後のライブ配信を検索します。配信開始日時が確認できた公開動画のみをカレンダー候補にします。

無料クォータを守るため、YouTube検索結果は既定で24時間キャッシュし、バックエンド1プロセスあたりの検索を1日80回までに制限します。上限値は無料枠を超える方向には変更できません。

### YouTube Data APIの無料設定

1. Google Cloud Consoleでプロジェクトを作成する
2. 「APIとサービス」から`YouTube Data API v3`だけを有効にする
3. 「認証情報」からAPIキーを作成する
4. APIキーの「APIの制限」を`YouTube Data API v3`に限定する
5. `.env`の`YOUTUBE_API_KEY`へ設定する

公開されている配信予定の読み取りにはOAuth同意画面やユーザーログインは不要です。Google Cloudの課金アカウントはリンクせず、既定の無料クォータだけを利用します。クォータ到達時は検索が失敗するだけで、自動課金へ移行しません。

`GEMINI_ARTIST_EXTRACTION_ENABLED=true`にすると、Geminiを自然文からの推し名抽出に利用します。既定では余計なAPI利用を避けるため無効です。未設定または失敗時は、入力文字列から定型表現を除いて検索します。

### AI Web検索候補

GeminiのGoogle検索グラウンディングを使う補助プロバイダーも実装されていますが、既定では無効です。有効にするには課金条件を確認したうえで、次を設定します。

```env
GEMINI_API_KEY=your-key
GEMINI_GROUNDED_SEARCH_ENABLED=true
GEMINI_GROUNDED_MODEL=gemini-3.1-flash-lite
GEMINI_MONTHLY_GROUNDED_REQUEST_LIMIT=400
```

AI検索は出典URLがあり、未来2年以内の日付が確認できる候補だけを返します。AI候補には`requires_confirmation=true`を付け、iOSアプリは自動でカレンダーへ登録しません。APIやYouTube由来の確定情報が重複した場合は、AI候補より確定情報を優先します。

月間上限はSQLiteへ永続化され、再起動しても引き継がれます。ただし、Google検索グラウンディングは有料サービスであり、この上限は予期しない大量利用を抑える安全装置であって無料を保証するものではありません。`GEMINI_GROUNDED_SEARCH_ENABLED=false`の間はAI Web検索リクエストを一切送りません。

## テスト

```bash
pytest
```

## セキュリティ

- `.env`をGitへ追加しない
- APIキーをSwiftコードやInfo.plistへ書かない
- 公開サーバーではHTTPSのみを使用する
- LANや公開環境では `ALLOW_LOOPBACK_WITHOUT_TOKEN=false` にする
- `BACKEND_APP_TOKEN`は漏洩時に交換する
- Difyで使用していた既存キーは管理画面から無効化する
