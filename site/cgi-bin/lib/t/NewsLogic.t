#!/usr/bin/perl

# NewsLogic.pm の単体テスト(7ケース)。
# 内訳(internal-spec-testing.md 3.1節): list_article_files 2、
# parse_article_file 3、render_list_html/render_detail_html 2。

use v5.16;
use strict;
use warnings;
use utf8;

use Test::More tests => 7;
use File::Temp qw(tempdir);
use File::Spec;

use FindBin;
use lib "$FindBin::Bin/..";
use Common;
use NewsLogic;

binmode(Test::More->builder->output, ':encoding(UTF-8)');
binmode(Test::More->builder->failure_output, ':encoding(UTF-8)');

# ==== list_article_files (2件) ====

{
    my $dir = tempdir(CLEANUP => 1);
    for my $day (1 .. 11) {
        my $fname = sprintf('2026-08-%02d-記事.txt', $day);
        open(my $fh, '>:encoding(UTF-8)', File::Spec->catfile($dir, $fname)) or die $!;
        print {$fh} "タイトル$day\nお知らせ\n本文\n";
        close $fh;
    }

    my @files = NewsLogic::list_article_files($dir);
    is(scalar(@files), 10, 'list_article_files: 11件中10件のみ返る(直近10件)');

    my ($first_basename) = $files[0] =~ m{([^/\\]+)\z};
    is($first_basename, '2026-08-11-記事.txt',
        'list_article_files: ソート順は新しい日付が先頭になる');
}

# ==== parse_article_file (3件) ====

{
    my $dir = tempdir(CLEANUP => 1);
    my $path = File::Spec->catfile($dir, '2026-08-01-記事1.txt');
    open(my $fh, '>:encoding(UTF-8)', $path) or die $!;
    print {$fh} "タイトルその1\nイベント\n本文1行目\n\n本文2段落目\n";
    close $fh;

    my $article = NewsLogic::parse_article_file($path);
    is($article->{category}, 'イベント', 'parse_article_file: 正しいカテゴリ行はそのまま採用される');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $path = File::Spec->catfile($dir, '2026-08-02-記事2.txt');
    open(my $fh, '>:encoding(UTF-8)', $path) or die $!;
    print {$fh} "タイトルその2\n本文がここから始まる(カテゴリ行省略)\n";
    close $fh;

    my $article = NewsLogic::parse_article_file($path);
    is($article->{category}, 'お知らせ',
        'parse_article_file: カテゴリ行が省略されると既定値「お知らせ」になる');
}

{
    my $dir = tempdir(CLEANUP => 1);
    my $path = File::Spec->catfile($dir, '2026-08-03-記事3.txt');
    open(my $fh, '>:encoding(UTF-8)', $path) or die $!;
    print {$fh} "タイトルその3\n未知のカテゴリ文字列\n本文の続き\n";
    close $fh;

    my $article = NewsLogic::parse_article_file($path);
    ok($article->{category} eq 'お知らせ' && $article->{body} =~ /未知のカテゴリ文字列/,
        'parse_article_file: 認識できないカテゴリ文字列は本文の一部とみなされ、カテゴリは既定値「お知らせ」になる');
}

# ==== render_list_html / render_detail_html (2件) ====

{
    my $html = NewsLogic::render_list_html([
        { id => '2026-08-01-記事', title => '<script>alert(1)</script>', category => 'お知らせ' },
    ]);
    like($html, qr/&lt;script&gt;alert\(1\)&lt;\/script&gt;/,
        'render_list_html: タイトルに含まれるHTML特殊文字がエスケープされる');
}

{
    my $html = NewsLogic::render_detail_html({
        title => '通常の記事', category => 'お知らせ',
        body  => "<b>太字ではない</b>\n\n次の段落です",
    });
    like($html, qr/&lt;b&gt;太字ではない&lt;\/b&gt;/,
        'render_detail_html: 本文に含まれるHTML特殊文字がエスケープされる');
}
