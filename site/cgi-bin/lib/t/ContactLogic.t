#!/usr/bin/perl

# ContactLogic.pm の単体テスト(27ケース)。
# 内訳(internal-spec-testing.md 3.1節): validate_input 7、verify_token 5、
# is_duplicate_submission 4、is_business_hours 5、
# build_notification_mail/build_autoreply_mail 4、send_via_sendmail 2。

use v5.16;
use strict;
use warnings;
use utf8;

use Test::More tests => 27;
use File::Temp qw(tempdir);
use File::Spec;
use Digest::SHA qw(hmac_sha256_hex);

use FindBin;
use lib "$FindBin::Bin/..";
use Common;
use ContactLogic;

binmode(Test::More->builder->output, ':encoding(UTF-8)');
binmode(Test::More->builder->failure_output, ':encoding(UTF-8)');

# ==== validate_input (7件) ====

{
    my $errors = ContactLogic::validate_input({
        last_name => '山田', first_name => '太郎',
        email => 'a@example.com', email_confirm => 'a@example.com',
        message => 'こんにちは', privacy_agree => 1,
    });
    is_deeply($errors, [], 'validate_input: すべて正しい入力ではエラーなし');
}

{
    my $errors = ContactLogic::validate_input({
        last_name => '', first_name => '太郎',
        email => 'a@example.com', email_confirm => 'a@example.com',
        message => 'こんにちは', privacy_agree => 1,
    });
    ok((grep { $_ eq '姓を入力してください' } @$errors), 'validate_input: 姓が空欄だとエラー');
}

{
    my $errors = ContactLogic::validate_input({
        last_name => '山田', first_name => '',
        email => 'a@example.com', email_confirm => 'a@example.com',
        message => 'こんにちは', privacy_agree => 1,
    });
    ok((grep { $_ eq '名を入力してください' } @$errors), 'validate_input: 名が空欄だとエラー');
}

{
    my $errors = ContactLogic::validate_input({
        last_name => '山田', first_name => '太郎',
        email => 'not-an-email', email_confirm => 'not-an-email',
        message => 'こんにちは', privacy_agree => 1,
    });
    ok((grep { $_ eq 'メールアドレスの形式が正しくありません' } @$errors),
        'validate_input: メール形式不正でエラー');
}

{
    my $errors = ContactLogic::validate_input({
        last_name => '山田', first_name => '太郎',
        email => 'a@example.com', email_confirm => 'b@example.com',
        message => 'こんにちは', privacy_agree => 1,
    });
    ok((grep { $_ eq 'メールアドレスが一致しません' } @$errors),
        'validate_input: メールアドレス確認欄が不一致でエラー');
}

{
    my $errors = ContactLogic::validate_input({
        last_name => '山田', first_name => '太郎',
        email => 'a@example.com', email_confirm => 'a@example.com',
        message => '', privacy_agree => 1,
    });
    ok((grep { $_ eq 'お問い合わせ内容を入力してください' } @$errors),
        'validate_input: 問い合わせ内容が空欄(境界値1文字未満)だとエラー');
}

{
    my $errors = ContactLogic::validate_input({
        last_name => '山田', first_name => '太郎',
        email => 'a@example.com', email_confirm => 'a@example.com',
        message => 'こんにちは', privacy_agree => 0,
    });
    ok((grep { $_ eq 'プライバシーポリシーへの同意が必要です' } @$errors),
        'validate_input: プライバシー同意未チェックでエラー');
}

# ==== verify_token (5件) ====

my $secret = 'test-shared-secret';

{
    my $ts = time();
    my $sig = hmac_sha256_hex($ts, $secret);
    my ($ok) = ContactLogic::verify_token("$ts.$sig", $secret);
    ok($ok, 'verify_token: 正しいトークンは成功する');
}

{
    my ($ok, $reason) = ContactLogic::verify_token(undef, $secret);
    is($reason, 'missing_token', 'verify_token: トークン欠如はmissing_token');
}

{
    my ($ok, $reason) = ContactLogic::verify_token('not-a-valid-format', $secret);
    is($reason, 'invalid_token_format', 'verify_token: 不正フォーマットはinvalid_token_format');
}

{
    my $ts = time();
    my $wrong_sig = hmac_sha256_hex($ts, 'wrong-secret');
    my ($ok, $reason) = ContactLogic::verify_token("$ts.$wrong_sig", $secret);
    is($reason, 'token_signature_mismatch', 'verify_token: 署名不一致はtoken_signature_mismatch');
}

{
    my $ts = time() - 301; # 300秒を1秒超過
    my $sig = hmac_sha256_hex($ts, $secret);
    my ($ok, $reason) = ContactLogic::verify_token("$ts.$sig", $secret);
    is($reason, 'token_expired', 'verify_token: 300秒超過はtoken_expired(境界値)');
}

# ==== is_duplicate_submission (4件) ====

{
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = File::Spec->catfile($dir, 'contact_log.txt');
    my $now = Common::iso8601_now();

    Common::write_log($log_path, $now, '203.0.113.1', 'dup@example.com', '山田 太郎', 'accepted');

    my $is_dup = ContactLogic::is_duplicate_submission($log_path, '203.0.113.1', 'dup@example.com', 300);
    ok($is_dup, 'is_duplicate_submission: 同一IP+同一メールが直近にあれば重複と判定');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = File::Spec->catfile($dir, 'contact_log.txt');

    my @old_time = localtime(time() - 301); # 300秒を1秒超過(重複ではない境界値)
    my $ts = sprintf('%04d-%02d-%02dT%02d:%02d:%02d',
        $old_time[5] + 1900, $old_time[4] + 1, $old_time[3], $old_time[2], $old_time[1], $old_time[0]);

    Common::write_log($log_path, $ts, '203.0.113.1', 'dup@example.com', '山田 太郎', 'accepted');

    my $is_dup = ContactLogic::is_duplicate_submission($log_path, '203.0.113.1', 'dup@example.com', 300);
    ok(!$is_dup, 'is_duplicate_submission: 300秒を1秒超えると重複ではない(境界値)');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = File::Spec->catfile($dir, 'contact_log.txt');
    my $now = Common::iso8601_now();

    Common::write_log($log_path, $now, '203.0.113.1', 'dup@example.com', '山田 太郎', 'accepted');

    my $is_dup = ContactLogic::is_duplicate_submission($log_path, '203.0.113.2', 'dup@example.com', 300);
    ok(!$is_dup, 'is_duplicate_submission: IPだけ異なる場合は重複としない');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $log_path = File::Spec->catfile($dir, 'contact_log.txt');
    my $now = Common::iso8601_now();

    Common::write_log($log_path, $now, '203.0.113.1', 'dup@example.com', '山田 太郎', 'accepted');

    my $is_dup = ContactLogic::is_duplicate_submission($log_path, '203.0.113.1', 'other@example.com', 300);
    ok(!$is_dup, 'is_duplicate_submission: メールアドレスだけ異なる場合は重複としない');
}

# ==== is_business_hours (5件) ====

sub _lt {
    # (sec, min, hour, mday, mon, year_offset_from_1900, wday)
    my (%args) = @_;
    return (0, $args{min} // 0, $args{hour}, 15, 0, 126, $args{wday});
}

ok(ContactLogic::is_business_hours(_lt(hour => 10, min => 0, wday => 1)),
    'is_business_hours: 月曜10:00は営業時間内(境界値)');

ok(ContactLogic::is_business_hours(_lt(hour => 16, min => 59, wday => 5)),
    'is_business_hours: 金曜16:59は営業時間内(境界値)');

ok(!ContactLogic::is_business_hours(_lt(hour => 17, min => 0, wday => 3)),
    'is_business_hours: 17:00は営業時間外(境界値)');

ok(!ContactLogic::is_business_hours(_lt(hour => 9, min => 59, wday => 3)),
    'is_business_hours: 9:59は営業時間外(境界値)');

ok(!ContactLogic::is_business_hours(_lt(hour => 12, min => 0, wday => 0)),
    'is_business_hours: 日曜は昼間でも営業時間外');

# ==== build_notification_mail / build_autoreply_mail (4件) ====

{
    my $mail = ContactLogic::build_notification_mail({
        last_name => "山田\r\n", first_name => "太郎\n",
        email => "a\@example.com", message => 'テストです',
    });
    like($mail, qr/^Subject: 【FroEduXお問い合わせ】山田 太郎様より$/m,
        'build_notification_mail: 氏名に混入した改行がヘッダー内で除去されている');
}

{
    my $mail = ContactLogic::build_notification_mail({
        last_name => '山田', first_name => '太郎',
        email => 'a@example.com', message => 'テストです',
    });
    like($mail, qr/Subject: 【FroEduXお問い合わせ】山田 太郎様より/,
        'build_notification_mail: 件名フォーマットが仕様通り');
}

{
    my $mail = ContactLogic::build_autoreply_mail(
        { last_name => '山田', first_name => '太郎', email => 'a@example.com' },
        1, # 営業時間内
    );
    unlike($mail, qr/営業時間外のため/, 'build_autoreply_mail: 営業時間内では時間外文言が追加されない');
}

{
    my $mail = ContactLogic::build_autoreply_mail(
        { last_name => '山田', first_name => '太郎', email => 'a@example.com' },
        0, # 営業時間外
    );
    like($mail, qr/営業時間外のため、返信は翌営業日以降になります/,
        'build_autoreply_mail: 営業時間外では時間外文言が追加される');
}

# ==== send_via_sendmail (2件) ====

{
    my $dir = tempdir(CLEANUP => 1);
    my $dummy_path = File::Spec->catfile($dir, 'dummy_sendmail_ok.pl');
    open(my $fh, '>', $dummy_path) or die $!;
    print {$fh} "#!/usr/bin/perl\nwhile (<STDIN>) { } exit 0;\n";
    close $fh;
    chmod 0755, $dummy_path;

    my $ok = ContactLogic::send_via_sendmail("To: a\@example.com\n\nbody\n", $dummy_path);
    ok($ok, 'send_via_sendmail: ダミーsendmailが正常終了すれば成功を返す');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $dummy_path = File::Spec->catfile($dir, 'dummy_sendmail_fail.pl');
    open(my $fh, '>', $dummy_path) or die $!;
    print {$fh} "#!/usr/bin/perl\nwhile (<STDIN>) { } exit 1;\n";
    close $fh;
    chmod 0755, $dummy_path;

    my $ok = ContactLogic::send_via_sendmail("To: a\@example.com\n\nbody\n", $dummy_path);
    ok(!$ok, 'send_via_sendmail: ダミーsendmailが異常終了すれば失敗を返す');
}
