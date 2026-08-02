package Common;

# 3つのCGI(contact.cgi / download.cgi / news.cgi)から共通で使う
# ユーティリティ関数集。
#
# Cyberhome環境はPerl 5.16・CPAN不可のため、ここではPerl 5.16に標準で
# 同梱されているコアモジュールのみを使う(File::Basename, Cwd, File::Spec,
# Fcntl)。将来関数を追加するときも、CPAN配布モジュールを追加しないこと。
#
# 詳細設計: docs/specs/internal-spec-cyberhome.md 6.1節

use v5.16;
use strict;
use warnings;
use utf8;

use Exporter 'import';
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use File::Spec;
use Fcntl qw(:flock);

our @EXPORT_OK = qw(
    html_escape
    strip_newlines
    resolve_script_dir
    read_secret_file
    render_template
    write_log
    render_error_page
    install_die_handler
    iso8601_now
);

# html_escape($str)
#
# HTMLの特殊文字(& < > ")をエスケープする。ユーザー入力をHTMLへ埋め込む
# 箇所(フォーム再描画・記事本文表示等)では必ずこの関数を通してからHTMLに
# 挿入すること(XSS対策)。$str が undef の場合は空文字を返す。
sub html_escape {
    my ($str) = @_;
    return '' unless defined $str;

    # & を最初に置換しないと、後続の置換で生成した実体参照自体が
    # 二重エスケープされてしまうため、必ず最初に処理する。
    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;
    $str =~ s/"/&quot;/g;

    return $str;
}

# strip_newlines($str)
#
# 文字列中の \r・\n を除去する。メールヘッダー(To/From/Subject/Reply-To等)
# に使うユーザー入力(氏名・メールアドレス)は、必ずこの関数を通してから
# ヘッダーへ組み込むこと(メールヘッダインジェクション対策)。
sub strip_newlines {
    my ($str) = @_;
    return '' unless defined $str;
    $str =~ s/[\r\n]//g;
    return $str;
}

# resolve_script_dir()
#
# 実行中のCGIスクリプト自身(=$0)が置かれているディレクトリを絶対パスで
# 返す。conf/・news/・templates/・Contents/・dl/ 等、他ディレクトリへの
# 相対パスを組み立てる際の基準に使う。
sub resolve_script_dir {
    # dirname($0) してから abs_path() をかける(abs_path($0)を先にやると、
    # $0 が指すファイル自体が存在しない場合に一部のCwd実装で失敗するため、
    # 常に存在するはずのディレクトリ側だけを解決する)。
    return abs_path(dirname($0));
}

# read_secret_file($relative_path)
#
# site/conf/ 配下の非公開ファイル(HMAC共有シークレット等)を読み込み、
# 前後の空白・改行を取り除いた内容を返す。$relative_path は
# site/conf/ からの相対パス(例: "hmac_secret.txt")。
# ファイルが開けない場合は die する(呼び出し元のCGIはinstall_die_handler経由
# で捕捉することを前提とする)。
sub read_secret_file {
    my ($relative_path) = @_;
    my $conf_dir = File::Spec->catdir(resolve_script_dir(), '..', 'conf');
    my $path = File::Spec->catfile($conf_dir, $relative_path);

    open(my $fh, '<:encoding(UTF-8)', $path)
        or die "read_secret_file: cannot open $path: $!";
    local $/ = undef;
    my $content = <$fh>;
    close $fh;

    $content = '' unless defined $content;
    $content =~ s/^\s+//;
    $content =~ s/\s+$//;

    return $content;
}

# render_template($template_path, \%replacements)
#
# HTMLテンプレートファイルを読み込み、プレースホルダーを置換して返す。
# プレースホルダーは2種類をサポートする:
#
#   (1) ブロック型: <!--KEY--> ... <!--/KEY-->
#       開始〜終了マーカーの中身をまるごと$replacements->{KEY}の値に
#       置き換える。値は既にHTML化済みの文字列を渡すこと(この関数は
#       ブロック型の値自体はエスケープしない。例: エラー一覧の<ul>...</ul>)。
#
#   (2) 値型: <!--VALUE:KEY-->
#       単一のプレースホルダーを $replacements->{KEY} の値に置き換える。
#       この関数が自動的に html_escape() を適用する(フォーム再描画時の
#       value="..." 埋め込み等、XSS対策が必要な箇所で使う)。
#
# テンプレートに存在しないKEYを指定してもエラーにはならない(単に無視する)。
# 正規表現の特殊文字を含む値でも安全なよう、置換はindex/substrベースで行い
# s///は使わない(置換値の中に $1 等が含まれていても誤動作しないため)。
sub render_template {
    my ($template_path, $replacements) = @_;
    $replacements ||= {};

    open(my $fh, '<:encoding(UTF-8)', $template_path)
        or die "render_template: cannot open $template_path: $!";
    local $/ = undef;
    my $html = <$fh>;
    close $fh;
    $html = '' unless defined $html;

    for my $key (keys %$replacements) {
        my $value = $replacements->{$key};
        $value = '' unless defined $value;

        # (1) ブロック型 <!--KEY--> ... <!--/KEY-->
        my $begin = "<!--$key-->";
        my $end   = "<!--/$key-->";
        my $begin_pos = index($html, $begin);
        if ($begin_pos >= 0) {
            my $end_pos = index($html, $end, $begin_pos);
            if ($end_pos >= 0) {
                my $block_len = $end_pos + length($end) - $begin_pos;
                substr($html, $begin_pos, $block_len) = $value;
            }
        }

        # (2) 値型 <!--VALUE:KEY--> (自動エスケープ)
        my $value_marker = "<!--VALUE:$key-->";
        my $escaped = html_escape($value);
        my $pos = 0;
        while (($pos = index($html, $value_marker, $pos)) >= 0) {
            substr($html, $pos, length($value_marker)) = $escaped;
            $pos += length($escaped);
        }
    }

    return $html;
}

# write_log($log_path, @fields)
#
# @fields をタブ区切りで1行にまとめ、$log_path に追記する。
# flockはベストエフォート(Infra2/5 L1=C確定方針: 失敗してもCGI自体は
# 失敗させず、処理を継続する)。成功時は真、ファイルが開けない場合は
# warnを出した上で偽を返す(dieはしない=ログ書き込み失敗で本処理全体を
# 止めないため)。
sub write_log {
    my ($log_path, @fields) = @_;
    my $line = join("\t", map { defined $_ ? $_ : '' } @fields) . "\n";

    my $fh;
    unless (open($fh, '>>:encoding(UTF-8)', $log_path)) {
        warn "write_log: cannot open $log_path: $!";
        return 0;
    }

    my $locked = eval { flock($fh, LOCK_EX) };
    print {$fh} $line;
    flock($fh, LOCK_UN) if $locked;
    close $fh;

    return 1;
}

# render_error_page($message)
#
# 500エラー用の簡易ページをHTTPヘッダーごと標準出力へ出力する。
# Perlのエラーメッセージ原文・スタックトレースは表示しない
# (情報漏えい防止、internal-spec-cyberhome.md 8.1節)。
sub render_error_page {
    my ($message) = @_;
    $message = 'システムエラーが発生しました。時間をおいて再度お試しください。'
        unless defined $message;

    binmode(STDOUT, ':encoding(UTF-8)');
    print "Status: 500 Internal Server Error\r\n";
    print "Content-Type: text/html; charset=UTF-8\r\n\r\n";
    print '<!DOCTYPE html>' . "\n";
    print '<html lang="ja"><head><meta charset="UTF-8"><title>エラー</title></head><body>' . "\n";
    print '<h1>エラーが発生しました</h1>' . "\n";
    print '<p>' . html_escape($message) . '</p>' . "\n";
    print '</body></html>' . "\n";

    return;
}

# install_die_handler($cgi_name)
#
# $SIG{__DIE__} を設定し、未捕捉のdie(.pmモジュール内部からの予期しない
# dieも含む)をerror_log.txt(cgi-bin直下、3CGI共通)に記録する。
#
# ページ出力(render_error_page)はここでは呼ばない。役割分担として、
# 「ログ記録はdieハンドラ、最終的なページ出力は各CGIのeval側」とする
# (internal-spec-cyberhome.md 8.1節)。$SIG{__DIE__} はevalで捕捉される
# dieに対しても呼ばれるため、ここでページ出力までしてしまうと、
# eval側でもエラーページを出力しようとして二重出力になるおそれがある。
sub install_die_handler {
    my ($cgi_name) = @_;
    $cgi_name = 'unknown' unless defined $cgi_name;

    my $error_log_path;
    my $ok = eval {
        $error_log_path = File::Spec->catfile(resolve_script_dir(), 'error_log.txt');
        1;
    };
    return unless $ok;

    $SIG{__DIE__} = sub {
        my ($die_message) = @_;
        $die_message = '' unless defined $die_message;
        $die_message =~ s/[\r\n]+$//;
        write_log($error_log_path, iso8601_now(), $cgi_name, $die_message);
    };

    return;
}

# iso8601_now()
#
# 現在時刻(サーバーのlocaltime、Cyberhome実機ではJST想定)を
# "YYYY-MM-DDTHH:MM:SS" 形式の文字列で返す。ログのタイムスタンプ列で
# 共通して使う。タイムゾーン情報は付与しない(Infra2/5 L5=C「タイムゾーンの
# ズレは許容範囲」の方針により、ログ用途では厳密なTZ表記を必須としない)。
sub iso8601_now {
    my @t = localtime(time());
    return sprintf(
        '%04d-%02d-%02dT%02d:%02d:%02d',
        $t[5] + 1900, $t[4] + 1, $t[3], $t[2], $t[1], $t[0]
    );
}

1;
