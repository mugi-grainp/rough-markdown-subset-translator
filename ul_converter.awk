#!/usr/bin/awk -f

# ul_converter.awk
# Markdownの箇条書きリストだけをHTMLタグに変換する

BEGIN {
    # ある深さのリストを処理中であるかのフラグ
    is_list_processing[1] = 0
}

# 行頭の箇条書き
# アスタリスク・ハイフン・プラス記号を箇条書きの冒頭とする
$0 ~ /^[\*+\-] / {
    process_list(1)
}

function process_list(list_depth) {
    # 当該階層のリスト処理をここから始める場合は開始タグを打つ
    if (is_list_processing[list_depth] != 1) {
        print "<ul>"
        is_list_processing[list_depth] = 1
    }

    line = $0

    # (リストの深さ - 1) * 4文字分の行頭スペースを削る
    for (i = 0; i < list_depth; i++) {
        line = gensub(/^ {4}/, "", 1, line)
    }
    # リストを表す行頭文字を削る
    line = gensub(/^[\*+\-] /, "", 1, line)

    while (1) {
        # 次の行を読み込み、同時にファイル終端に達していないかどうかのフラグを得る
        eof_status = getline

        # ファイル終端、または空行に行き当たったらリスト1個の終わりとする
        if (eof_status == 0 || $0 == "") {
            print "<li>" line "</li>"
            print "</ul>"

            # 全ての深さについてリスト処理の終了を設定
            for (i = 0; i < list_depth; i++) {
                is_list_processing[i] = 0
            }
            return
        }

        # 次のリストの始まりを検出した場合
        if ($0 ~ /^ *[\*+\-] /) {
            # ネスト段階を計算する
            pos = match($0, /^ {1,}/)
            next_depth = int((RLENGTH / 4)) + 1

            # ネスト段階の変化による分岐
            if (next_depth - list_depth == 0) {
                # 同一レベル
                print "<li>" line "</li>"
                line = gensub(/^ *[\*+\-] /, "", 1, $0)
            } else if (next_depth - list_depth == 1) {
                # 1つ深い
                print "<li>" line
                process_list(list_depth + 1)
                print "</li>"

                # 最終行 or 空行検出によりリスト処理が終了している場合は、閉じタグを打つ
                if (is_list_processing[list_depth] == 0) {
                    print "</ul>"
                }
                return
            } else if (next_depth - list_depth == -1) {
                # 1つ浅い
                print "<li>" line "</li>"
                line = gensub(/^ *[\*+\-] /, "", 1, $0)
                print "</ul>"
                print "<li>" line
                is_list_processing[list_depth] = 0
                return
            }
        } else {
            # 途中で改行された1項目の続きなので、先頭のインデントを取り除いて連結する
            line = line gensub(/^ */, "", 1, $0)
        }
    }
}
