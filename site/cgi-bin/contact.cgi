#!/usr/bin/perl

# contact.cgi
#
# 問い合わせフォーム(../contact.html)からのPOST送信を受け付け、
# Refererチェック → 入力バリデーション → HMACトークン検証
# (reCAPTCHA検証を代行したVercel側が発行したトークン) → 重複送信判定
# → sendmailでの通知メール・自動返信メール送信 → contact_log.txtへの
# 記録、という一連の処理を行う。
#
# ビジネスロジックは lib/ContactLogic.pm・lib/Common.pm に分離してあり、
# このファイル自体はCGI入出力の配線のみを担当する(Test::Moreでの単体
# テスト対象は lib/ 配下、このファイル自体はユニットテスト対象外)。
#
# 詳細設計: docs/specs/internal-spec-cyberhome.md 2章

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
use ContactLogic;

# 自ドメイン以外からのPOSTを弾くための許可Refererプレフィックス
# (internal-spec-cyberhome.md 2.9節、CSRF対策)。
use constant ALLOWED_REFERER_PREFIX => 'https://jyoho1.web.cyberhome.ne.jp/';

Common::install_die_handler('contact.cgi');

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
    binmode(STDOUT, ':encoding(UTF-8)');

    my $cgi = CGI->new;
    my $script_dir     = Common::resolve_script_dir();
    my $contact_html   = File::Spec->catfile($script_dir, '..', 'contact.html');
    my $log_path       = File::Spec->catfile($script_dir, 'contact_log.txt');
    my $error_log_path = File::Spec->catfile($script_dir, 'contact_error_log.txt');

    my %params = (
        last_name     => scalar $cgi->param('last_name'),
        first_name    => scalar $cgi->param('first_name'),
        email         => scalar $cgi->param('email'),
        email_confirm => scalar $cgi->param('email_confirm'),
        message       => scalar $cgi->param('message'),
        privacy_agree => scalar $cgi->param('privacy_agree'),
        verify_token  => scalar $cgi->param('verify_token'),
    );

    # ステップ2: Refererチェック(空は許可、値がある場合のみ自ドメインと照合)
    my $referer = $ENV{HTTP_REFERER};
    if (defined $referer && length $referer) {
        my $prefix = ALLOWED_REFERER_PREFIX;
        unless (index($referer, $prefix) == 0) {
            _render_rejection($contact_html, \%params,
                ['検証に失敗しました。お手数ですが最初からやり直してください。']);
            return;
        }
    }

    # ステップ3: 各フィールドのバリデーション
    my $errors = ContactLogic::validate_input(\%params);
    if (@$errors) {
        _render_rejection($contact_html, \%params, $errors);
        return;
    }

    # ステップ4: verify_tokenの検証(常にfail-closed)
    my $secret = Common::read_secret_file('hmac_secret.txt');
    my ($token_ok) = ContactLogic::verify_token($params{verify_token}, $secret);
    unless ($token_ok) {
        _render_rejection($contact_html, \%params,
            ['検証に失敗しました。reCAPTCHAを再度確認してください']);
        return;
    }

    my $remote_addr = $ENV{REMOTE_ADDR} || '';

    # ステップ5: 重複送信判定(送信元IP+メールアドレス、300秒)
    if (ContactLogic::is_duplicate_submission($log_path, $remote_addr, $params{email}, 300)) {
        _render_rejection($contact_html, \%params,
            ['直前に同じ内容の送信を受け付けています。しばらく時間をおいて再度お試しください。']);
        return;
    }

    # ステップ6: 受付ログ記録(送信結果によらずこの時点で記録する)
    Common::write_log(
        $log_path,
        Common::iso8601_now(),
        $remote_addr,
        $params{email},
        Common::strip_newlines("$params{last_name} $params{first_name}"),
        'accepted',
    );

    # ステップ7: 営業時間判定
    my @localtime_now = localtime(time());
    my $business_hours = ContactLogic::is_business_hours(@localtime_now);

    # ステップ8: sendmail呼び出し(通知メール+自動返信メール)
    my $notification_mail = ContactLogic::build_notification_mail(\%params);
    my $autoreply_mail    = ContactLogic::build_autoreply_mail(\%params, $business_hours);

    my $notification_ok = ContactLogic::send_via_sendmail($notification_mail);
    my $autoreply_ok    = ContactLogic::send_via_sendmail($autoreply_mail);

    if ($notification_ok && $autoreply_ok) {
        # ステップ9: PRGパターンでcontact-thanks.htmlへリダイレクト
        print "Status: 302 Found\r\n";
        print "Location: ../contact-thanks.html\r\n\r\n";
        return;
    }

    # ステップ10: sendmail失敗時
    Common::write_log(
        $error_log_path,
        Common::iso8601_now(),
        $remote_addr,
        $params{email},
        'sendmail failed (notification=' . ($notification_ok ? 'ok' : 'ng')
            . ', autoreply=' . ($autoreply_ok ? 'ok' : 'ng') . ')',
    );

    print "Content-Type: text/html; charset=UTF-8\r\n\r\n";
    print "<!DOCTYPE html>\n<html lang=\"ja\"><head><meta charset=\"UTF-8\">"
        . "<title>送信エラー</title></head><body>\n";
    print "<p>送信に失敗しました。時間をおいて再度お試しください。</p>\n";
    print "</body></html>\n";

    return;
}

# ステップ11: バリデーション・トークン・重複判定いずれかのreject時の再描画
# (internal-spec-cyberhome.md 2.8節、contact.htmlを唯一の情報源とする)。
sub _render_rejection {
    my ($contact_html, $params, $errors) = @_;

    my $error_html = '';
    if (@$errors) {
        $error_html = "<ul class=\"error-list\">\n"
            . join("\n", map { '<li>' . Common::html_escape($_) . '</li>' } @$errors)
            . "\n</ul>\n";
    }

    my %replacements = (
        CONTACT_ERRORS => $error_html,
        last_name      => $params->{last_name},
        first_name     => $params->{first_name},
        email          => $params->{email},
        email_confirm  => $params->{email_confirm},
        message        => $params->{message},
    );

    my $html = Common::render_template($contact_html, \%replacements);

    print "Content-Type: text/html; charset=UTF-8\r\n\r\n";
    print $html;

    return;
}
