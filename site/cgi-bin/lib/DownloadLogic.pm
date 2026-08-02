package DownloadLogic;

# download.cgi のビジネスロジック(MIMEタイプ判定・パラメータ検証・
# 書籍別認可判定・アクセスログの月次ローテーション・ログ整形)。
#
# 詳細設計: docs/specs/internal-spec-cyberhome.md 3章・6.3節

use v5.16;
use strict;
use warnings;
use utf8;

use Exporter 'import';
use Common qw(iso8601_now);

our @EXPORT_OK = qw(
    resolve_mime_type
    validate_file_param
    authorize_book_access
    rotate_log_if_needed
    format_access_log_line
);

# 拡張子ハードコード対応表(internal-spec-cyberhome.md 3.3節、
# ラウンド2 A2=A確定。File::MimeInfoはCPAN配布のため使用不可)。
my %MIME_TABLE = (
    pdf  => 'application/pdf',
    doc  => 'application/msword',
    docx => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    xls  => 'application/vnd.ms-excel',
    xlsx => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ppt  => 'application/vnd.ms-powerpoint',
    pptx => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
);

# 書籍別の許可ユーザー一覧(internal-spec-cyberhome.md 3.1節)。
# 実際のユーザー名は運営者が .htpasswd 生成時に決定する。書籍が増えた場合は
# ここに新しいエントリを追加し、.htpasswd への新規ユーザー追加とセットで
# 更新する(保守5/5 Y12=A、Claude Codeへの依頼運用)。
my %BOOK_USERS = (
    book1 => ['book1user'],
    book2 => ['book2user'],
    book3 => ['book3user'],
);

# resolve_mime_type($filename)
#
# 拡張子(大文字小文字を問わない)からMIMEタイプを判定する。対応表にない
# 拡張子・拡張子なしの場合は application/octet-stream にフォールバックする
# (安全側のデフォルト)。
sub resolve_mime_type {
    my ($filename) = @_;
    return 'application/octet-stream' unless defined $filename;

    if ($filename =~ /\.([A-Za-z0-9]+)$/) {
        my $ext = lc($1);
        return $MIME_TABLE{$ext} if exists $MIME_TABLE{$ext};
    }

    return 'application/octet-stream';
}

# validate_file_param($file)
#
# internal-spec-cyberhome.md 3.5節の正規表現でfileクエリパラメータを検証する。
# パストラバーサル(../等)・許可拡張子以外・全角文字混入などを一律に
# 不合格として弾く。合格なら真、不合格なら偽を返す。
sub validate_file_param {
    my ($file) = @_;
    return 0 unless defined $file;
    return $file =~ m{\A(?:book[123])/[A-Za-z0-9_\-]+\.(?:pdf|docx?|xlsx?|pptx?)\z} ? 1 : 0;
}

# authorize_book_access($remote_user, $book)
#
# Apache Basic認証を通過した$remote_user($ENV{REMOTE_USER})が、$book
# ("book1"・"book2"・"book3")のファイルへアクセスする権限を持つかを判定する
# (internal-spec-cyberhome.md 3.1節、Perl側での書籍別認可)。
sub authorize_book_access {
    my ($remote_user, $book) = @_;
    return 0 unless defined $remote_user && length $remote_user;
    return 0 unless defined $book && exists $BOOK_USERS{$book};

    for my $allowed_user (@{ $BOOK_USERS{$book} }) {
        return 1 if $allowed_user eq $remote_user;
    }

    return 0;
}

# rotate_log_if_needed($log_path)
#
# $log_path(dl/access_log.txt)の最終更新月と現在の月を比較し、月が
# 変わっていればアーカイブ(access_log_YYYYMM.txt)へリネームした上で、
# 新規の空ファイルを作成する(internal-spec-cyberhome.md 3.4節)。
# ローテーションが発生した場合は真、不要だった場合(ファイルが存在しない、
# または同月内)は偽を返す。
sub rotate_log_if_needed {
    my ($log_path) = @_;
    return 0 unless defined $log_path && -e $log_path;

    my @mtime = localtime((stat($log_path))[9]);
    my @now   = localtime(time());

    my $file_month = sprintf('%04d%02d', $mtime[5] + 1900, $mtime[4] + 1);
    my $now_month  = sprintf('%04d%02d', $now[5] + 1900, $now[4] + 1);

    return 0 if $file_month eq $now_month;

    my $archive_path = $log_path;
    if ($archive_path =~ /\.txt\z/) {
        $archive_path =~ s/\.txt\z/_$file_month.txt/;
    }
    else {
        $archive_path .= "_$file_month";
    }

    rename($log_path, $archive_path)
        or die "rotate_log_if_needed: cannot rename $log_path to $archive_path: $!";

    open(my $fh, '>', $log_path)
        or die "rotate_log_if_needed: cannot create new $log_path: $!";
    close $fh;

    return 1;
}

# format_access_log_line($remote_user, $remote_addr, $file, $result, $timestamp)
#
# access_log.txt の1行分(タブ区切り)を整形して返す
# (internal-spec-cyberhome.md 3.4節の書式)。$timestamp は省略時
# Common::iso8601_now() を使う(テストで固定タイムスタンプを指定できる
# ようにするための任意引数)。
sub format_access_log_line {
    my ($remote_user, $remote_addr, $file, $result, $timestamp) = @_;
    $timestamp = iso8601_now() unless defined $timestamp;

    $remote_user = '' unless defined $remote_user;
    $remote_addr = '' unless defined $remote_addr;
    $file        = '' unless defined $file;
    $result      = '' unless defined $result;

    return join("\t", $timestamp, $remote_user, $remote_addr, $file, $result);
}

1;
