package CGI;

# 最小限のCGI.pmスタブ(テスト専用、非シップ)。
#
# Cyberhome実機同等のCGI.pmはこの開発/CI環境にインストールされていない
# (フェーズ6チェックポイント16・フェーズ7システムテスト報告と同じ制約)。
# 実際のCGI.pmの挙動のうち、本テストが検証したい範囲(application/x-www-
# form-urlencoded POSTボディのパース、$CGI::PARAM_UTF8のオン/オフによる
# デコード有無)だけを忠実に再現する。
#
# 重要: 実際のCGI.pmの既定動作は「%XXパーセントエンコードをバイト単位で
# chr()に戻すだけで、UTF-8としてのデコードは行わない」。$CGI::PARAM_UTF8が
# 真の場合のみ、デコード後の文字列に対してさらにEncode::decode('UTF-8', ...)
# を適用する。この2段階の違いこそが、本テストで再現したい文字化けバグの
# 根本原因(site/cgi-bin/contact.cgi が後者を有効化していなかった)である。
#
# このファイルはsite/.ftpdeployignoreでcgi-bin/lib/t/ごと除外されており、
# Cyberhome実機へは配置されない。実際のcontact.cgi等の`use CGI;`が本番で
# 解決するのはCPAN配布の本物のCGI.pmであり、このスタブではない。

use v5.16;
use strict;
use warnings;

our $PARAM_UTF8 = 0;

sub new {
    my ($class) = @_;
    my $method = $ENV{REQUEST_METHOD} || '';
    my $raw = '';

    if (uc($method) eq 'POST') {
        my $len = $ENV{CONTENT_LENGTH};
        $len = 0 unless defined $len && $len =~ /^\d+$/;
        if ($len > 0) {
            read(STDIN, $raw, $len);
        }
    } else {
        $raw = defined $ENV{QUERY_STRING} ? $ENV{QUERY_STRING} : '';
    }

    my %params = _parse_urlencoded($raw);

    if ($PARAM_UTF8) {
        require Encode;
        for my $key (keys %params) {
            $params{$key} = [map { Encode::decode('UTF-8', $_) } @{$params{$key}}];
        }
    }

    return bless { params => \%params }, $class;
}

sub param {
    my ($self, $name) = @_;
    return keys %{$self->{params}} unless defined $name;

    my $list = $self->{params}{$name};
    return unless $list;
    return wantarray ? @$list : $list->[0];
}

sub _parse_urlencoded {
    my ($raw) = @_;
    $raw = '' unless defined $raw;

    my %out;
    for my $pair (split /[&;]/, $raw) {
        next unless length $pair;
        my ($key, $value) = split /=/, $pair, 2;
        $value = '' unless defined $value;
        $key   = _unescape($key);
        $value = _unescape($value);
        push @{$out{$key}}, $value;
    }

    return %out;
}

# 実際のCGI.pmと同じく、'+' を空白に、'%XX' をバイト単位のchr()に戻す。
# UTF-8としてのデコードはここでは一切行わない(それが本物のCGI.pmの
# 既定動作であり、$CGI::PARAM_UTF8指定時のみ呼び出し元でさらにデコードする)。
sub _unescape {
    my ($str) = @_;
    return '' unless defined $str;
    $str =~ tr/+/ /;
    $str =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;
    return $str;
}

1;
