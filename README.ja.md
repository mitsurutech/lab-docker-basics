# Docker Compose で学ぶ Docker 入門ラボ：壊れたサービスを直しながらコンテナ、ログ、再起動を学ぶ

[English](README.md) | [Français](README.fr.md) | [日本語](README.ja.md) | [Español](README.es.md)

[![check](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml/badge.svg)](https://github.com/mitsurutech/lab-docker-basics/actions/workflows/check.yml)

授業でそのまま使える**初心者向けの Docker ラボ**です。学校やカレッジが生徒一人ひとりに専用のデータベース、コンテナ、ブラウザー上のターミナルを渡せる [MitsuruTech ラーニングプラットフォーム](https://mitsurutech.co.uk/ja/learning)で提供しています。生徒には3つのコンテナからなる小さなスタックが渡され、そのうち1つは**わざと壊してあります**。生徒はログを読んで止まった理由を突き止め、正常なコンテナの中をのぞき、足りない設定を直し、サービスを再起動して、正常に立ち上がるのを確かめます。使うのは `docker ps`、`docker logs`、`docker exec`、`docker restart` で、本物の Docker 上で行い、何もインストールせず、他の人のマシンに害が及ぶこともありません。

ファイルは `docker-compose` ファイルの `compose.yaml` 1つで、標準の公開イメージだけで作られています（Dockerfile は一切ありません）。自分のマシンでもプラットフォームでも同じように動き、プラットフォームでは生徒ごとにインターネットへの出口がない専用のコピーが使えます。

## 生徒がすること

1. **動いているものを見る。** `docker ps` は `web` と `cache` の2つのサービスを表示します。worker がありません。`docker ps -a` なら worker も表示され、状態は `Exited (1)` です。止まったコンテナは、削除するまで残っています。
2. **ログを読む。** `docker logs worker` が、止まった理由を正確に教えてくれます。設定ファイルに `QUEUE_HOST` の行がなく、`QUEUE_HOST` はキューを持つサービスの名前です。
3. **正常な隣のコンテナの中を見る。** `docker exec -it web sh` で `web` コンテナの中のシェルが開きます。このコンテナは worker とフォルダー（**名前付きボリューム**）を共有しています。`cat /settings/worker.conf` で、worker が読んだファイルが見えます。
4. **直す。** そのシェルから `/settings/worker.conf` に `QUEUE_HOST=cache` の行を追加します。名前を間違えると、ログに別の、同じくらいわかりやすいエラーが出ます。これもよい練習です。
5. **再起動する。** `docker restart worker` のあと、`docker ps` で `Up` と `(healthy)` が表示され、`docker logs worker` でジョブが完了していくのが見えます。`docker exec cache valkey-cli get jobs_done` で、キューのカウントが増えていくのがわかります。
6. **何が残るかを見る。** `web` が配信するページは、起動時にそのコンテナ自身のファイルシステムに書き込まれたものです。同じコンテナがもう一度起動するので `docker restart` では残りますが、ラボを停止してから起動し直すと消えます。`worker.conf` を入れた名前付きボリュームは残るので、直した内容は残ります。

## 中身

| サービス | イメージ | メモリ | 内容 |
| --- | --- | --- | --- |
| `web` | [`nginx:1.27-alpine`](https://hub.docker.com/_/nginx) | 64 MB | Web ページを配信し、共有の設定フォルダーを `/settings/` に一覧表示します |
| `cache` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 64 MB | worker がジョブを取り出すキュー（Redis プロトコルを話す Valkey） |
| `worker` | [`valkey/valkey:8.1-alpine`](https://hub.docker.com/r/valkey/valkey) | 32 MB | キューの場所を教えられると、数秒ごとに完了したジョブをキューに数えます |

3つは `settings` という名前付きボリュームを1つ共有します。`web` は初めて起動したときにここへ `worker.conf` を書き込み、変更もできます。`worker` は読むことしかできません。どちらのイメージもバージョンを固定しており（`latest` は使いません）、授業のあいだにラボが変わることはありません。測定した実行では、サービスは起動の約4秒後に正常になり、アイドル時のメモリ使用量は3つ合わせて約 17 MB でした。

サービスのすることはすべて compose ファイルの `entrypoint:` の行に書いてあるので、全部読めます。ここでは何もビルドしません。

## プラットフォームで使う

[MitsuruTech ラーニングプラットフォーム](https://mitsurutech.co.uk/ja/learning)では、生徒一人ひとりにラボの専用コピーが渡され、ブラウザー上でその隣にターミナルが開きます。**そのターミナルの `docker` は制限付きです。** `docker ps`、`docker logs`、`docker exec`、`docker restart` はラボのサービスに対して動き、作成、プル、ビルド、削除はできません。このラボはまさにそれだけでできているので、生徒が Dockerfile を書く必要は一度もありません。

**試すには：** [コンテナのページ](https://mitsurutech.co.uk/ja/container)を開き、**サンプルラボ**の中からこのラボを見つけて「起動」を押します。試すだけならアカウントは不要です。マニュアルの[lab-docker-basics のページ](https://mitsurutech.co.uk/ja/help/lab-docker-basics)で手順を説明していて、**Docker Basics** という短いレッスンでも順を追って進められます。

**クラスの課題として出すには：**

1. モジュールで、タイプが**ラボ**の課題を作り、**GitHub リポジトリ**を選びます。
2. `https://github.com/mitsurutech/lab-docker-basics` とブランチ `main` を指定します。compose ファイルは既定の `compose.yaml` です。ファイルを変更したいときは、先にリポジトリをフォークしてください。
3. 公開します。各生徒のコピーは公開したコミットから始まるので、あとからここを変更しても、すでに出したラボは変わりません。
4. 何を提出するかを課題に書き（[教員向け](#教員向け)を参照）、他の課題と同じように配布します。

残りはヘルプマニュアルの[コンテナラボのガイド](https://mitsurutech.co.uk/ja/help/labs)をご覧ください。compose ファイルに書けること、コピーごとのメモリ、教員が生徒のコピーを開き、見て、採点する方法を説明しています。

まだカレッジのアカウントがありませんか？ 生徒50人までなら[最初の1年は無料](https://mitsurutech.co.uk/ja/pricing)で、[登録](https://mitsurutech.co.uk/ja/signup)にはメールアドレスだけが必要です。

## 自分のマシンで動かす

Compose プラグイン付きの Docker が必要です。初回の起動でイメージをダウンロードします。

```bash
docker compose -f compose.yaml -f local.yaml up
```

<http://localhost:8080> を開くと、`web` が配信するページが見えます。`local.yaml` はそのポートを `127.0.0.1` だけに公開するので、ラボには自分のコンピューターからだけ到達でき、ほかのどこからも到達できません。自分のマシンでは Docker の全機能が使えるので、コマンドはプロジェクトのコンテナ名を使った同じものです（`docker compose ps -a`、`docker compose logs worker`、`docker compose exec web sh`、`docker compose restart worker`）。`Ctrl-C` で止め、`docker compose -f compose.yaml -f local.yaml down -v` で削除します。

## 教員向け

このラボには自動採点するものはありません。生徒が証拠を提出し、ほかのラボと同じように教員が採点します。

**壊れたサービスが偶然には出せない証拠を求めてください。** 直す前の `docker ps -a` の出力と、直した後の `docker ps` の出力、何が悪いかを教えてくれたログの行、そして自分が書いたファイルのうちラボを停止しても残るのはどれか、なぜか、を述べた一文です。最後の一文で、コンテナ自身のファイルシステムとボリュームの違い、つまりこのラボが教えたい考え方を理解したかどうかがわかります。

**コースの中での位置づけ。** コンピューティング、ネットワーク、DevOps の単元でのコンテナ入門に向いています。コンテナとは何か、動いているものの読み方、サービスが何が悪いかをどう伝えるか、残すべきデータがなぜボリュームにあるのか、を扱います。正確な文言はご自身の認定機関の単元でご確認ください。ここでは引用していません。

**誰が何を見るか。** コピーは、起動した生徒本人だけのものです。そのモジュールを教える教職員は、生徒が何をしたかを見るためにコピーを開くことができ、生徒の作業を開くとアクセスログに記録されます。このログは生徒本人が読めます。

## ラボでできないこと

ラボにはインターネットへの出口がまったくなく、中のどれも出口を必要としません。プラットフォームのターミナルでは、生徒はコンテナの起動、プル、ビルド、削除や、ボリュームとネットワークの直接の操作はできません。それらのコマンドは、その旨の文言とともに拒否されます。授業で次に話すのによい話題で、自分のマシンでは動きます。

## トラブルシューティング

- **`docker ps` に worker が表示されない。** それが狙いです。止まっているのです。`docker ps -a` を使ってください。
- **直したあとに worker がまた止まる。** `docker logs worker` を読んでください。ラボのサービスにない名前は、そのように報告されます。`cache` を使ってください。
- **自分のマシンでポート 8080 がすでに使われている。** `local.yaml` の左側の数字を、たとえば `127.0.0.1:8081:80` のように変えて、そのポートを開いてください。

## ラボの検査

`test/check.sh` は、プラットフォームのランナーが各サービスを起動するのと同じ方法でラボを起動し（root のサービスに返される権限以外のすべての capability を外し、`no-new-privileges`、プロセス数の上限、メモリの上限を設定し、インターネットへの出口なし）、そのあと生徒がすることを行います。止まった worker のログを読み、`web` のシェルから間違った名前、続いて正しい名前を書き込み、正常になるまで worker を再起動し、ラボを停止して起動し直したあとに名前付きボリュームだけが残ることを確かめます。Docker が必要で、push のたびに実行されます。それが先頭のバッジです。

```bash
test/check.sh
```

## バージョンとライセンス

[nginx](https://nginx.org) は BSD-2-Clause ライセンス、Redis のオープンソースのフォークである [Valkey](https://valkey.io) は BSD-3-Clause ライセンスです。イメージは `nginx:1.27-alpine` と `valkey/valkey:8.1-alpine` で、公開レジストリから無変更で実行しており、どちらもこのリポジトリでは配布していません。

## ライセンス

この作品は [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) でライセンスされています。Mitsuru Technologies Ltd のクレジットを表示し、商用に使わず、これをもとに作ったものを同じライセンスで共有するなら、学習と授業のために共有・改変できます。全文は `LICENSE` ファイルにあります。

## 提供元

[Mitsuru Technologies](https://mitsurutech.co.uk/ja) が [MitsuruTech ラーニングプラットフォーム](https://mitsurutech.co.uk/ja/learning)のために作りました。学校とカレッジ向けに、Python、Java、Go、Node、SQL、Linux をブラウザーで学べ、コンテナラボ、GitHub からデプロイする Web アプリ、自動採点されるクイズがそろっています。アカウントなしで、[プレイグラウンド](https://mitsurutech.co.uk/ja/playground)でコードを試せます。

同じところのほかのラボ：[lab-juice-shop](https://github.com/mitsurutech/lab-juice-shop)、[lab-dvwa](https://github.com/mitsurutech/lab-dvwa)、[lab-webgoat](https://github.com/mitsurutech/lab-webgoat)、[lab-mysql-phpmyadmin](https://github.com/mitsurutech/lab-mysql-phpmyadmin)、[lab-git-gitea](https://github.com/mitsurutech/lab-git-gitea)、[lab-sample](https://github.com/mitsurutech/lab-sample)。
