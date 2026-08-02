#!/usr/bin/perl

# download.cgi
#
# cgi-bin/.htaccess の <Files "download.cgi"> ブロックでApache Basic認証
# (dl/.htpasswd)を通過した後に起動する。認証(authentication、Apache層)と
# 認可(authorization、書籍別アクセス制御、Perl層)を分離しており、
# このスクリプトは後者を DownloadLogic::authorize_book_access() で行う。
#
# 詳細設計: docs/specs/internal-spec-cyberhome.md 3章

use v5.16;
use strict;
use warnings;
use utf8;

use CGI;
use File::Basename qw(dirname);
use Cwd qw(abs_path);
use File::Spec;

use lib dirname(abs_path($0)) . '/lib';
use Common;
use DownloadLogic;

Common::install_die_handler('download.cgi');

eval {
    main();
    1;
} or do {
    Common::render_error_page(
        'システムエラーが発生しました。時間をおいて再度お試しいただくか、'
      . '時間をおいても解決しない場合はお手数ですがお問い合わせフォームより'
      . 'ご連絡ください。'
    );
};

exit 0;

sub main {
    my $cgi = CGI->new;
    my $script_dir   = Common::resolve_script_dir();
    my $contents_dir = File::Spec->catdir($script_dir, '..', 'Contents');
    my $access_log   = File::Spec->catfile($script_dir, '..', 'dl', 'access_log.txt');

    my $file        = $cgi->param('file');
    my $remote_user = defined $ENV{REMOTE_USER} ? $ENV{REMOTE_USER} : '';
    my $remote_addr = defined $ENV{REMOTE_ADDR} ? $ENV{REMOTE_ADDR} : '';

    DownloadLogic::rotate_log_if_needed($access_log);

    # ステップ3: パストラバーサル対策(不正な file パラメータは一律400)
    unless (DownloadLogic::validate_file_param($file)) {
        _log_result($access_log, $remote_user, $remote_addr, defined $file ? $file : '', 'bad_request');
        binmode(STDOUT, ':encoding(UTF-8)');
        print "Status: 400 Bad Request\r\n";
        print "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
        print "不正なリクエストです。\n";
        return;
    }

    my ($book) = $file =~ m{\A(book[123])/};

    # ステップ4: 書籍別認可チェック
    unless (DownloadLogic::authorize_book_access($remote_user, $book)) {
        _log_result($access_log, $remote_user, $remote_addr, $file, 'forbidden_wrong_book');
        binmode(STDOUT, ':encoding(UTF-8)');
        print "Status: 403 Forbidden\r\n";
        print "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
        print "このファイルへのアクセス権限がありません。\n";
        return;
    }

    my @path_parts = split(m{/}, $file);
    my $full_path = File::Spec->catfile($contents_dir, @path_parts);

    # ステップ5: ファイル存在確認
    unless (-e $full_path && -f $full_path) {
        _log_result($access_log, $remote_user, $remote_addr, $file, 'not_found');
        binmode(STDOUT, ':encoding(UTF-8)');
        print "Status: 404 Not Found\r\n";
        print "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
        print "ファイルが見つかりません。\n";
        return;
    }

    # ステップ6: MIMEタイプ判定
    my $mime_type = DownloadLogic::resolve_mime_type($full_path);
    my $file_size = -s $full_path;
    my ($basename) = $file =~ m{([^/]+)\z};

    open(my $fh, '<:raw', $full_path)
        or die "download.cgi: cannot open $full_path: $!";

    # ステップ7: HTTPヘッダー出力
    print "Content-Type: $mime_type\r\n";
    print "Content-Disposition: attachment; filename=\"$basename\"\r\n";
    print "Content-Length: $file_size\r\n\r\n";

    # ステップ8: バイナリストリーム出力
    binmode(STDOUT);
    my $buffer;
    while (read($fh, $buffer, 65536)) {
        print STDOUT $buffer;
    }
    close $fh;

    # ステップ9: アクセスログ成功記録
    _log_result($access_log, $remote_user, $remote_addr, $file, 'ok');

    return;
}

sub _log_result {
    my ($access_log, $remote_user, $remote_addr, $file, $result) = @_;
    Common::write_log(
        $access_log,
        DownloadLogic::format_access_log_line($remote_user, $remote_addr, $file, $result),
    );
    return;
}
