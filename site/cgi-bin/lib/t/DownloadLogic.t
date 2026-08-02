#!/usr/bin/perl

# DownloadLogic.pm の単体テスト(21ケース)。
# 内訳: resolve_mime_type 8、validate_file_param 6(book3対応追加分含む)、
# authorize_book_access 4(book3対応追加分含む)、rotate_log_if_needed 2、
# format_access_log_line 1。

use v5.16;
use strict;
use warnings;
use utf8;

use Test::More tests => 21;
use File::Temp qw(tempdir);
use File::Spec;
use POSIX qw(mktime);

use FindBin;
use lib "$FindBin::Bin/..";
use Common;
use DownloadLogic;

binmode(Test::More->builder->output, ':encoding(UTF-8)');
binmode(Test::More->builder->failure_output, ':encoding(UTF-8)');

# ==== resolve_mime_type (8件、対応表7拡張子+未知拡張子) ====

is(DownloadLogic::resolve_mime_type('book1/sample.pdf'), 'application/pdf',
    'resolve_mime_type: pdf');
is(DownloadLogic::resolve_mime_type('book1/sample.doc'), 'application/msword',
    'resolve_mime_type: doc');
is(DownloadLogic::resolve_mime_type('book1/sample.docx'),
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'resolve_mime_type: docx');
is(DownloadLogic::resolve_mime_type('book2/sample.xls'), 'application/vnd.ms-excel',
    'resolve_mime_type: xls');
is(DownloadLogic::resolve_mime_type('book2/sample.xlsx'),
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'resolve_mime_type: xlsx');
is(DownloadLogic::resolve_mime_type('book2/sample.ppt'), 'application/vnd.ms-powerpoint',
    'resolve_mime_type: ppt');
is(DownloadLogic::resolve_mime_type('book2/sample.pptx'),
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'resolve_mime_type: pptx');
is(DownloadLogic::resolve_mime_type('book1/sample.zip'), 'application/octet-stream',
    'resolve_mime_type: 未知の拡張子はapplication/octet-streamにフォールバック');

# ==== validate_file_param (5件) ====

ok(DownloadLogic::validate_file_param('book1/sample.pdf'),
    'validate_file_param: 正常系(book1/sample.pdf)は合格');

ok(!DownloadLogic::validate_file_param('../../etc/passwd'),
    'validate_file_param: パストラバーサル(../../etc/passwd)は不合格');

ok(!DownloadLogic::validate_file_param('book1/../book2/x.pdf'),
    'validate_file_param: book1/../book2/x.pdf のようなトラバーサルは不合格');

ok(!DownloadLogic::validate_file_param('book1/資料.pdf'),
    'validate_file_param: 全角文字を含むファイル名は不合格');

ok(!DownloadLogic::validate_file_param('book1/sample.exe'),
    'validate_file_param: 許可拡張子以外は不合格');

ok(DownloadLogic::validate_file_param('book3/bonus.pdf'),
    'validate_file_param: 正常系(book3/bonus.pdf)は合格');

# ==== authorize_book_access (4件) ====

ok(DownloadLogic::authorize_book_access('book1user', 'book1'),
    'authorize_book_access: book1ユーザーがbook1ファイルにアクセス→許可');

ok(!DownloadLogic::authorize_book_access('book1user', 'book2'),
    'authorize_book_access: book1ユーザーがbook2ファイルにアクセス→拒否');

ok(!DownloadLogic::authorize_book_access('unknown_user', 'book1'),
    'authorize_book_access: 未知のユーザー名→拒否');

ok(DownloadLogic::authorize_book_access('book3user', 'book3'),
    'authorize_book_access: book3ユーザーがbook3ファイルにアクセス→許可');

# ==== rotate_log_if_needed (2件) ====

{
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = File::Spec->catfile($dir, 'access_log.txt');

    open(my $fh, '>', $log_path) or die $!;
    print {$fh} "old content\n";
    close $fh;

    # 最終更新月を2ヶ月前に人為的に設定する
    my @now = localtime(time());
    my $past_epoch = mktime($now[0], $now[1], $now[2], 1, $now[4] - 2, $now[5]);
    utime($past_epoch, $past_epoch, $log_path) or die "utime failed: $!";

    my @past_lt = localtime($past_epoch);
    my $archive_suffix = sprintf('%04d%02d', $past_lt[5] + 1900, $past_lt[4] + 1);
    my $archive_path = File::Spec->catfile($dir, "access_log_$archive_suffix.txt");

    my $rotated = DownloadLogic::rotate_log_if_needed($log_path);

    ok($rotated && -e $archive_path && -e $log_path && -s $log_path == 0,
        'rotate_log_if_needed: 過去月のログはarchive_log_YYYYMM.txtへリネームされ、新規の空ファイルが作られる');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = File::Spec->catfile($dir, 'access_log.txt');

    open(my $fh, '>', $log_path) or die $!;
    print {$fh} "current month content\n";
    close $fh;
    # mtimeはデフォルトで「今」なので同月内のまま

    my $rotated = DownloadLogic::rotate_log_if_needed($log_path);

    ok(!$rotated, 'rotate_log_if_needed: 同月内の呼び出しではリネームが発生しない');
}

# ==== format_access_log_line (1件) ====

is(
    DownloadLogic::format_access_log_line('book1user', '203.0.113.5', 'book1/sample.pdf', 'ok', '2026-08-02T10:00:00'),
    "2026-08-02T10:00:00\tbook1user\t203.0.113.5\tbook1/sample.pdf\tok",
    'format_access_log_line: タブ区切りの期待通りの書式で整形される'
);
