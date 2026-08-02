#!/usr/bin/perl

# ContactCgiUtf8Boundary.t
#
# 内部仕様上の契約: contact.cgi は CGI.pm 経由で受け取ったフォーム値を
# 正しくUTF-8としてデコードした上でテンプレート再描画・メール本文組み立て・
# ログ記録に渡さなければならない(internal-spec-cyberhome.md 2章)。
#
# 既存の ContactLogic.t 等(lib/*.pm 単体テスト)は、テストファイル自身が
# `use utf8;` 宣言のもとで書いたソースコードリテラル(例: '山田')を関数に
# 直接渡しており、これは最初からPerl内部表現として正しくデコードされた
# 文字列である。実際のCGI.pmが生成する「パーセントデコードされたバイト列」を
# contact.cgi自身が正しくUTF-8デコードできているか、というCGI境界そのものは
# 一度も検証されていなかった(フェーズ7システムテスト報告
# docs/specs/system-test-report.md「発見した問題1」で発見・記録)。
#
# 本テストは、実際のCGI.pmと同じパーセントデコードアルゴリズム
# (%XX -> バイト単位chr())+ $CGI::PARAM_UTF8 対応を実装した最小限のスタブ
# (fixtures/cgi_stub/CGI.pm、非シップ。site/.ftpdeployignoreで
# cgi-bin/lib/t/ごとFTPデプロイ対象外)をPERL5LIB経由で読み込ませ、
# 実際のcontact.cgiを子プロセスとして起動し、実際にSTDIN経由で
# application/x-www-form-urlencoded・UTF-8バイト列のPOSTボディを渡した上で、
# 出力されるHTMLに日本語が文字化けせず正しく現れることを確認する
# (ContactLogic.pm・Common.pm単体の正しさではなく、contact.cgiがCGI.pmから
# 正しくデコードされた文字列を実際に受け取れているか、という「継ぎ目」自体の
# 回帰テスト)。
#
# privacy_agree をわざと欠落させ、ContactLogic::validate_input() の時点で
# エラーにさせている(_render_rejection() 経由でcontact.htmlが再描画される
# ところまでで止め、verify_token検証以降(site/conf/hmac_secret.txtが必要)
# には到達させないため。UTF-8デコード境界だけに検証範囲を絞れる)。

use v5.16;
use strict;
use warnings;
use utf8;

use Test::More tests => 5;
use File::Temp qw(tempfile);
use File::Spec;
use FindBin;
use Encode qw(encode_utf8);

binmode(Test::More->builder->output, ':encoding(UTF-8)');
binmode(Test::More->builder->failure_output, ':encoding(UTF-8)');

my $cgi_bin_dir = File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, '..', '..'));
my $contact_cgi = File::Spec->catfile($cgi_bin_dir, 'contact.cgi');
my $stub_dir    = File::Spec->rel2abs(File::Spec->catdir($FindBin::Bin, 'fixtures', 'cgi_stub'));

ok(-f $contact_cgi, "contact.cgiが存在する ($contact_cgi)");
ok(-f File::Spec->catfile($stub_dir, 'CGI.pm'), 'CGI.pmスタブが存在する');

my $last_name  = '山田';
my $first_name = '太郎';
my $email      = 'taro@example.com';
my $message    = "お問い合わせ内容のテストです。\n日本語を含みます。";

my %form = (
    last_name     => $last_name,
    first_name    => $first_name,
    email         => $email,
    email_confirm => $email,
    message       => $message,
    # privacy_agree は意図的に省略
);

my $body = join('&', map { _url_encode($_) . '=' . _url_encode($form{$_}) } sort keys %form);
my $body_bytes = encode_utf8($body);

my ($body_fh, $body_file) = tempfile(UNLINK => 1);
binmode($body_fh);
print {$body_fh} $body_bytes;
close $body_fh;

local $ENV{REQUEST_METHOD} = 'POST';
local $ENV{CONTENT_TYPE}   = 'application/x-www-form-urlencoded';
local $ENV{CONTENT_LENGTH} = length($body_bytes);
local $ENV{REMOTE_ADDR}    = '203.0.113.5';
local $ENV{PERL5LIB} = (defined $ENV{PERL5LIB} && length $ENV{PERL5LIB})
    ? "$stub_dir:$ENV{PERL5LIB}"
    : $stub_dir;
delete $ENV{HTTP_REFERER};

my $output = `"$^X" "$contact_cgi" < "$body_file" 2>&1`;

ok(defined $output && length $output, 'contact.cgiが何らかの出力を返す');

my $expected_last_name_bytes  = encode_utf8($last_name);
my $expected_first_name_bytes = encode_utf8($first_name);

ok(index($output, $expected_last_name_bytes) >= 0,
    'contact.cgi: 姓(山田)がCGI境界を通過後も正しいUTF-8バイト列のまま出力に現れる(文字化けしない)');
ok(index($output, $expected_first_name_bytes) >= 0,
    'contact.cgi: 名(太郎)がCGI境界を通過後も正しいUTF-8バイト列のまま出力に現れる(文字化けしない)');

# 実際のCGI.pmと同じアルゴリズムで%XXバイト単位デコードを実装するhelper。
sub _url_encode {
    my ($str) = @_;
    my $bytes = encode_utf8($str);
    $bytes =~ s/([^A-Za-z0-9\-_.~])/sprintf('%%%02X', ord($1))/ge;
    return $bytes;
}
