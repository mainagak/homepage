#!/usr/bin/perl

# Common.pm の単体テスト(14ケース)。
# 内訳(internal-spec-testing.md 3.1節): html_escape 4、strip_newlines 2、
# render_template 2、write_log 2、resolve_script_dir 1、read_secret_file 2、
# render_error_page/install_die_handler 1。

use v5.16;
use strict;
use warnings;
use utf8;

use Test::More tests => 14;
use File::Temp qw(tempdir);
use File::Spec;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

use FindBin;
use lib "$FindBin::Bin/..";
use Common;

binmode(Test::More->builder->output, ':encoding(UTF-8)');
binmode(Test::More->builder->failure_output, ':encoding(UTF-8)');

# ---- html_escape (4件) ----
is(Common::html_escape('<script>alert(1)</script>'),
    '&lt;script&gt;alert(1)&lt;/script&gt;',
    'html_escape: <script>タグがエスケープされる');

is(Common::html_escape('A & B'), 'A &amp; B',
    'html_escape: & が最初にエスケープされ二重エスケープしない');

is(Common::html_escape('"quoted"'), '&quot;quoted&quot;',
    'html_escape: ダブルクォートがエスケープされる');

is(Common::html_escape(undef), '', 'html_escape: undefは空文字を返す');

# ---- strip_newlines (2件) ----
is(Common::strip_newlines("foo\r\nBcc: evil\@example.com"),
    'fooBcc: evil@example.com',
    'strip_newlines: メールヘッダインジェクション試行文字列から改行が除去される');

is(Common::strip_newlines(undef), '', 'strip_newlines: undefは空文字を返す');

# ---- render_template (2件) ----
{
    my $dir = tempdir(CLEANUP => 1);
    my $template_path = File::Spec->catfile($dir, 'template.html');
    open(my $fh, '>:encoding(UTF-8)', $template_path) or die $!;
    print {$fh} qq{<!--CONTACT_ERRORS--><!--/CONTACT_ERRORS--><input value="<!--VALUE:last_name-->">};
    close $fh;

    my $html = Common::render_template($template_path, {
        CONTACT_ERRORS => '<ul><li>エラーです</li></ul>',
        last_name      => '山田',
    });

    is($html, '<ul><li>エラーです</li></ul><input value="山田">',
        'render_template: ブロック型・値型プレースホルダーが両方置換される');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $template_path = File::Spec->catfile($dir, 'template.html');
    open(my $fh, '>:encoding(UTF-8)', $template_path) or die $!;
    print {$fh} qq{<input value="<!--VALUE:message-->">};
    close $fh;

    my $html = Common::render_template($template_path, {
        message => '<script>alert(1)</script>',
    });

    is($html, '<input value="&lt;script&gt;alert(1)&lt;/script&gt;">',
        'render_template: 値型プレースホルダーはhtml_escapeされる(XSS対策の回帰テスト)');
}

# ---- write_log (2件) ----
{
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = File::Spec->catfile($dir, 'test_log.txt');

    my $ok = Common::write_log($log_path, '2026-08-02T10:00:00', '127.0.0.1', 'foo@example.com', 'accepted');
    ok($ok, 'write_log: 追記に成功する');

    open(my $fh, '<:encoding(UTF-8)', $log_path) or die $!;
    my @lines = <$fh>;
    close $fh;
    chomp @lines;

    is($lines[0], "2026-08-02T10:00:00\t127.0.0.1\tfoo\@example.com\taccepted",
        'write_log: タブ区切りの1行が期待通りに書き込まれる');
}

# ---- resolve_script_dir (1件) ----
{
    my $expected = dirname(abs_path($0));
    is(Common::resolve_script_dir(), $expected,
        'resolve_script_dir: 実行中スクリプト自身のディレクトリ(絶対パス)を返す');
}

# ---- read_secret_file (2件) ----
{
    my $fake_site_dir = tempdir(CLEANUP => 1);
    my $fake_cgi_bin  = File::Spec->catdir($fake_site_dir, 'cgi-bin');
    my $fake_conf     = File::Spec->catdir($fake_site_dir, 'conf');
    mkdir $fake_cgi_bin or die $!;
    mkdir $fake_conf or die $!;

    my $secret_path = File::Spec->catfile($fake_conf, 'hmac_secret.txt');
    open(my $fh, '>:encoding(UTF-8)', $secret_path) or die $!;
    print {$fh} "  mysecretvalue123  \n";
    close $fh;

    local $0 = File::Spec->catfile($fake_cgi_bin, 'fake.cgi');
    my $secret = Common::read_secret_file('hmac_secret.txt');
    is($secret, 'mysecretvalue123',
        'read_secret_file: 前後の空白・改行を除去した内容を返す');
}

{
    my $fake_site_dir = tempdir(CLEANUP => 1);
    my $fake_cgi_bin  = File::Spec->catdir($fake_site_dir, 'cgi-bin');
    mkdir $fake_cgi_bin or die $!;
    # conf/ ディレクトリ自体を作らない = ファイルが存在しないケース

    local $0 = File::Spec->catfile($fake_cgi_bin, 'fake.cgi');
    eval { Common::read_secret_file('does_not_exist.txt') };
    ok($@, 'read_secret_file: ファイルが存在しない場合はdieする');
}

# ---- render_error_page / install_die_handler (1件) ----
{
    my $dir = tempdir(CLEANUP => 1);
    my $capture_path = File::Spec->catfile($dir, 'stdout_capture.txt');

    # render_error_page() は内部で明示的に binmode(STDOUT, ...) するため、
    # select()による切り替えではなく実際のSTDOUT自体を一時的に差し替える
    # (実ファイルへのリダイレクトのみがファイルディスクリプタの複製として
    # 確実に機能するため、インメモリのスカラーファイルハンドルは使わない)。
    open(my $real_stdout_copy, '>&', \*STDOUT) or die "cannot dup STDOUT: $!";
    open(STDOUT, '>', $capture_path) or die "cannot redirect STDOUT: $!";

    Common::render_error_page('テストエラーメッセージ');

    open(STDOUT, '>&', $real_stdout_copy) or die "cannot restore STDOUT: $!";

    open(my $fh, '<:encoding(UTF-8)', $capture_path) or die $!;
    local $/;
    my $output = <$fh>;
    close $fh;

    Common::install_die_handler('Common.t');

    my $render_ok  = (defined $output && $output =~ /Status: 500 Internal Server Error/) ? 1 : 0;
    my $handler_ok = (ref($SIG{__DIE__}) eq 'CODE') ? 1 : 0;

    ok($render_ok && $handler_ok,
        'render_error_page: 500ステータスを出力し、install_die_handlerでSIG{__DIE__}にコードリファレンスが設定される');
}
