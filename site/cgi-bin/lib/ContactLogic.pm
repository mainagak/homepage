package ContactLogic;

# contact.cgi のビジネスロジック(バリデーション・HMACトークン検証・
# 重複送信判定・メール本文組み立て・sendmail呼び出し)。
#
# CGI本体(contact.cgi)からロジックを分離することで、CGI.pm・実際の
# sendmail実行ファイルに依存せずTest::Moreで単体テストできるようにする。
#
# 詳細設計: docs/specs/internal-spec-cyberhome.md 2章・6.2節
# HMACトークンの仕様: docs/specs/internal-spec-integration.md 1章

use v5.16;
use strict;
use warnings;
use utf8;

use Exporter 'import';
use Digest::SHA qw(hmac_sha256_hex);
use Time::Local qw(timelocal);

use Common qw(strip_newlines);

our @EXPORT_OK = qw(
    validate_input
    verify_token
    is_duplicate_submission
    is_business_hours
    build_notification_mail
    build_autoreply_mail
    send_via_sendmail
);

# 運営者宛メールアドレス(暫定値、internal-spec-cyberhome.md 9章の方針通り
# 秘密情報ではないため定数として直接記述する)。
use constant OPERATOR_EMAIL => 'mainagak@gmail.com';

my $EMAIL_RE = qr/^[^@\s]+@[^@\s]+\.[^@\s]+$/;

# validate_input(\%params)
#
# internal-spec-cyberhome.md 2.3節のルールに従い、フォーム入力を検証する。
# 期待する%paramsのキー: last_name, first_name, email, email_confirm,
# message, privacy_agree。
#
# 戻り値: エラーメッセージ(日本語、ユーザー表示用)の配列リファレンス。
# エラーがなければ空の配列リファレンスを返す。
# verify_tokenの検証はこの関数の範囲外(別関数 verify_token() が担当)。
sub validate_input {
    my ($params) = @_;
    $params ||= {};
    my @errors;

    my $last_name  = defined $params->{last_name}  ? $params->{last_name}  : '';
    my $first_name = defined $params->{first_name} ? $params->{first_name} : '';
    my $email          = defined $params->{email}          ? $params->{email}          : '';
    my $email_confirm  = defined $params->{email_confirm}  ? $params->{email_confirm}  : '';
    my $message    = defined $params->{message}    ? $params->{message}    : '';
    my $privacy_agree  = $params->{privacy_agree};

    push @errors, '姓を入力してください' if $last_name eq '';
    push @errors, '名を入力してください' if $first_name eq '';

    if ($email eq '' || $email !~ $EMAIL_RE) {
        push @errors, 'メールアドレスの形式が正しくありません';
    }

    if ($email_confirm ne $email) {
        push @errors, 'メールアドレスが一致しません';
    }

    push @errors, 'お問い合わせ内容を入力してください' if $message eq '';

    push @errors, 'プライバシーポリシーへの同意が必要です' unless $privacy_agree;

    return \@errors;
}

# verify_token($token, $secret)
#
# internal-spec-integration.md 1.2節のロジックをそのまま実装する。
# トークン形式: "<unixtime>.<hmac_sha256_hex>"。
#
# 戻り値: ($is_valid, $reason_code) のリスト。
#   $is_valid が真の場合、$reason_code は undef。
#   偽の場合、$reason_code は以下のいずれか:
#     'missing_token' / 'invalid_token_format' /
#     'token_signature_mismatch' / 'token_expired'
sub verify_token {
    my ($token, $secret) = @_;

    return (0, 'missing_token') unless defined $token && length $token;
    return (0, 'missing_token') unless defined $secret && length $secret;

    my ($ts, $sig) = split(/\./, $token, 2);
    unless (defined $ts && $ts =~ /^\d+$/ && defined $sig && $sig =~ /^[0-9a-f]{64}$/) {
        return (0, 'invalid_token_format');
    }

    my $expected = hmac_sha256_hex($ts, $secret);
    unless ($sig eq $expected) {
        return (0, 'token_signature_mismatch');
    }

    my $now = time();
    if (($now - $ts) > 300 || ($ts - $now) > 60) {
        return (0, 'token_expired');
    }

    return (1, undef);
}

# is_duplicate_submission($log_path, $ip, $email, $window_sec)
#
# internal-spec-cyberhome.md 2.4節の重複送信判定。
# $log_path(contact_log.txt)の末尾から遡って読み、$window_sec秒以内に
# 同一の$ip + $emailの組み合わせの行があれば真を返す。
# ファイル全体を読むのではなく、末尾から直近200行のみを対象にする
# (ログ肥大化時の性能劣化を抑えるため)。
sub is_duplicate_submission {
    my ($log_path, $ip, $email, $window_sec) = @_;
    $window_sec = 300 unless defined $window_sec;
    $ip    = '' unless defined $ip;
    $email = '' unless defined $email;

    return 0 unless defined $log_path && -e $log_path;

    my @lines = _tail_lines($log_path, 200);
    my $now = time();

    for my $line (reverse @lines) {
        next unless defined $line && length $line;
        my ($ts_str, $line_ip, $line_email) = split(/\t/, $line);
        next unless defined $ts_str && defined $line_ip && defined $line_email;
        next unless $line_ip eq $ip && $line_email eq $email;

        my $ts_epoch = _parse_iso8601_local($ts_str);
        next unless defined $ts_epoch;

        my $diff = $now - $ts_epoch;
        return 1 if $diff >= 0 && $diff <= $window_sec;
    }

    return 0;
}

# is_business_hours(@localtime_values)
#
# localtime()の戻り値をそのまま引数として受け取り、平日10:00-17:00
# (17:00は含まない)かどうかを判定する。時刻をテストから直接指定できる
# ようにするための設計(internal-spec-cyberhome.md 6.2節)。
sub is_business_hours {
    my (@localtime_values) = @_;
    my (undef, undef, $hour, undef, undef, undef, $wday) = @localtime_values;

    return 0 unless defined $wday && defined $hour;
    return 0 if $wday == 0 || $wday == 6; # 日曜(0)・土曜(6)
    return 0 if $hour < 10 || $hour >= 17;
    return 1;
}

# build_notification_mail(\%params)
#
# 運営者宛の通知メール(ヘッダー+本文)をsendmail -tにそのまま渡せる
# テキスト形式で組み立てて返す(internal-spec-cyberhome.md 2.6節)。
sub build_notification_mail {
    my ($params) = @_;
    $params ||= {};

    my $last_name  = strip_newlines(defined $params->{last_name}  ? $params->{last_name}  : '');
    my $first_name = strip_newlines(defined $params->{first_name} ? $params->{first_name} : '');
    my $email      = strip_newlines(defined $params->{email}      ? $params->{email}      : '');
    my $message    = defined $params->{message} ? $params->{message} : '';

    my $full_name = "$last_name $first_name";
    my $subject = "【FroEduXお問い合わせ】${full_name}様より";

    my $body = <<"BODY";
FroEduXウェブサイトのお問い合わせフォームより、以下の内容で問い合わせがありました。

お名前: $full_name
メールアドレス: $email

【お問い合わせ内容】
$message
BODY

    return _build_mail_text({
        to       => OPERATOR_EMAIL,
        from     => OPERATOR_EMAIL,
        reply_to => $email,
        subject  => $subject,
        body     => $body,
    });
}

# build_autoreply_mail(\%params, $is_business_hours)
#
# 送信者宛の自動返信メールを組み立てて返す(internal-spec-cyberhome.md
# 2.6節)。営業時間外(平日10:00-17:00外)の場合は「翌営業日以降になります」
# という一文を追加する(ラウンド2 B14=B)。
sub build_autoreply_mail {
    my ($params, $is_business_hours) = @_;
    $params ||= {};

    my $last_name  = strip_newlines(defined $params->{last_name}  ? $params->{last_name}  : '');
    my $first_name = strip_newlines(defined $params->{first_name} ? $params->{first_name} : '');
    my $email      = strip_newlines(defined $params->{email}      ? $params->{email}      : '');

    my $full_name = "$last_name $first_name";
    my $subject = '【FroEduX】お問い合わせありがとうございます';

    my $after_hours_note = '';
    unless ($is_business_hours) {
        $after_hours_note = "\n営業時間外のため、返信は翌営業日以降になります。\n";
    }

    my $body = <<"BODY";
${full_name}様

この度はFroEduXへお問い合わせいただき、誠にありがとうございます。
以下の内容でお問い合わせを受け付けいたしました。
担当者より改めてご連絡いたしますので、今しばらくお待ちくださいますようお願い申し上げます。
${after_hours_note}
何卒よろしくお願いいたします。

FroEduX
BODY

    return _build_mail_text({
        to      => $email,
        from    => OPERATOR_EMAIL,
        subject => $subject,
        body    => $body,
    });
}

# send_via_sendmail($mail_text, $sendmail_path)
#
# シェルを経由しないリスト形式のopenで/usr/sbin/sendmailを呼び出す
# (コマンドインジェクション対策、internal-spec-cyberhome.md 2.6節)。
# $sendmail_path はテスト時にダミーの実行可能ファイルへ差し替えるための
# 引数(省略時は本番既定値 /usr/sbin/sendmail)。
sub send_via_sendmail {
    my ($mail_text, $sendmail_path) = @_;
    $sendmail_path = '/usr/sbin/sendmail' unless defined $sendmail_path;
    $mail_text = '' unless defined $mail_text;

    my $pid = open(my $mail_fh, '|-', $sendmail_path, '-t', '-oi');
    unless ($pid) {
        warn "send_via_sendmail: cannot start $sendmail_path: $!";
        return 0;
    }

    binmode($mail_fh, ':encoding(UTF-8)');
    print {$mail_fh} $mail_text;
    my $close_ok = close($mail_fh);
    my $exit_status = $?;

    return ($close_ok && $exit_status == 0) ? 1 : 0;
}

# ---- 以下、モジュール内部限定のヘルパー(exportしない) ----

sub _build_mail_text {
    my ($fields) = @_;

    my @headers;
    push @headers, "To: $fields->{to}"             if defined $fields->{to};
    push @headers, "From: $fields->{from}"         if defined $fields->{from};
    push @headers, "Reply-To: $fields->{reply_to}" if defined $fields->{reply_to};
    push @headers, "Subject: $fields->{subject}"   if defined $fields->{subject};
    push @headers, 'MIME-Version: 1.0';
    push @headers, 'Content-Type: text/plain; charset=UTF-8';

    my $body = defined $fields->{body} ? $fields->{body} : '';

    return join("\n", @headers) . "\n\n" . $body;
}

sub _tail_lines {
    my ($path, $n) = @_;

    open(my $fh, '<:raw', $path) or return ();
    my $size = -s $fh;
    if (!defined $size || $size == 0) {
        close $fh;
        return ();
    }

    my $chunk_size = 4096;
    my $buffer = '';
    my $pos = $size;

    while ($pos > 0) {
        my $read_size = $pos >= $chunk_size ? $chunk_size : $pos;
        $pos -= $read_size;
        seek($fh, $pos, 0);
        my $chunk;
        read($fh, $chunk, $read_size);
        $buffer = $chunk . $buffer;

        my $newline_count = ($buffer =~ tr/\n/\n/);
        last if $newline_count > $n || $pos == 0;
    }
    close $fh;

    # \n はUTF-8のマルチバイト文字の一部にはなり得ないバイト(0x0A)なので、
    # バイナリモードのまま split しても文字化けの心配はない。
    my @lines = split(/\n/, $buffer);
    @lines = @lines[-$n .. -1] if scalar(@lines) > $n;

    return map { _decode_utf8_bytes($_) } @lines;
}

# _tail_lines()で読んだバイト列をUTF-8文字列としてデコードする。
# Encodeモジュール(コア同梱)を使うが、モジュール冒頭でuse Encode;すると
# 常時ロードになるため、ここでのみ遅延ロードする。
sub _decode_utf8_bytes {
    my ($bytes) = @_;
    return $bytes unless defined $bytes;
    require Encode;
    return Encode::decode('UTF-8', $bytes, Encode::FB_DEFAULT());
}

sub _parse_iso8601_local {
    my ($ts_str) = @_;
    return undef unless defined $ts_str;
    return undef unless $ts_str =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})$/;
    my ($y, $mo, $d, $h, $mi, $s) = ($1, $2, $3, $4, $5, $6);

    my $epoch = eval { timelocal($s, $mi, $h, $d, $mo - 1, $y - 1900) };
    return $epoch;
}

1;
