# dptm6 (dclpdftonemerge for DCL 6)

このgemは、[地球流体電脳ライブラリ](https://www.gfd-dennou.org/library/dcl/)（DCL）によって描画・出力したPDFファイルのトーン（塗りつぶし）の断片を結合してファイルを軽くするコマンド `dptm6` を提供します。

DCLはバージョン5まで独自のPostScriptファイルを出力していましたが、バージョン6から[cairo](https://www.cairographics.org)を用いたPDF出力に変更されました。以前のバージョン用のアプリケーション `dptm2` は[GFD電脳Ruby小物置き場](http://davis.gfd-dennou.org/rubygadgets/ja/?%28Application%29+DCLのPSファイルのトーンを結合する2)で公開しています。

## インストール

Rubyがインストールされた環境で以下のコマンドを実行してください。

    $ gem install dptm6

## 使い方

大前提として、このコマンドはDCLで出力して未編集のPDFに対してのみ正しく動作します。

基本的な使い方は、コマンドの後ろに変換したいPDFファイルを指定するだけです。変換後のファイル名は、元の名前に番号を付け加えたものになります。（番号は既存のファイルを上書きしないように選ばれます）

```
$ ls *.pdf
dcl.pdf

$ dptm6  dcl.pdf
$ ls *.pdf
dcl.pdf  dcl_1.pdf

$ dptm6  dcl.pdf
$ ls *.pdf
dcl.pdf  dcl_1.pdf  dcl_2.pdf
```

出力するファイル名を指定することもできます。入力ファイルの全ページをつなげたPDFができます。

    $ dptm6  -o dcl-merged.pdf  dcl-a.pdf dcl-b.pdf dcl-c.pdf

入力ファイルの一部ページだけを抽出することもできます。（先頭を0ページ目と数えます）

    $ dptm6  input.pdf[0,5...2,8..-1]   #=> [0,5,4,3,8,9,...,n-1]

その他の説明はヘルプを参照してください。だたし、現在は開発時のデバッグ用オプションしかありません。

    $ dptm6  -h

## ライセンス

このgemは、[MITライセンス](https://opensource.org/licenses/MIT)の条件の下でオープンソースとして利用可能です。
