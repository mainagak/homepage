package NewsLogic;

# news.cgi のビジネスロジック(記事ファイル走査・寛容パース・
# 一覧/詳細HTML断片の生成)。
#
# 詳細設計: docs/specs/internal-spec-cyberhome.md 4章・6.4節

use v5.16;
use strict;
use warnings;
use utf8;

use Exporter 'import';
use File::Spec;
use Encode qw(decode_utf8);

use Common qw(html_escape);

our @EXPORT_OK = qw(
    list_article_files
    parse_article_file
    render_list_html
    render_detail_html
);

# 記事ファイル2行目として認識するカテゴリ(external-spec.md確定の3カテゴリ)。
# これ以外の文字列が2行目に書かれていた場合は本文の一部とみなし、
# カテゴリは既定値(お知らせ)にフォールバックする(寛容なパーサー、
# internal-spec-cyberhome.md 4.1節)。
my %VALID_CATEGORIES = map { $_ => 1 } ('お知らせ', 'イベント', 'メディア掲載');
my $DEFAULT_CATEGORY = 'お知らせ';

# list_article_files($dir)
#
# $dir(site/news/)配下の *.txt をファイル名の降順(=日付降順、命名規則
# YYYY-MM-DD-タイトル.txt のため文字列比較で正しく日付順になる)にソートし、
# 直近10件のみのフルパスを返す(internal-spec-cyberhome.md 4.2節、
# ページネーションなし)。
sub list_article_files {
    my ($dir) = @_;
    return () unless defined $dir;

    opendir(my $dh, $dir) or return ();
    # readdir() はファイルシステムから生バイト列を返す(utf8フラグなし)ため、
    # 日本語ファイル名を正しく扱うために明示的にUTF-8としてデコードする
    # (Cyberhomeのファイルシステムのエンコーディングは architecture.md
    # 「追加質問5」で実機確認事項として記録済み、本実装はUTF-8を前提とする)。
    my @files = grep { /\.txt\z/ } map { decode_utf8($_) } readdir($dh);
    closedir $dh;

    return () unless @files;

    my @sorted = sort { $b cmp $a } @files;
    my $limit = scalar(@sorted) > 10 ? 10 : scalar(@sorted);
    my @top = @sorted[0 .. $limit - 1];

    return map { File::Spec->catfile($dir, $_) } @top;
}

# parse_article_file($path)
#
# 記事テキストファイルを解析する(internal-spec-cyberhome.md 4.1節)。
#   1行目: タイトル
#   2行目: カテゴリ(お知らせ/イベント/メディア掲載のいずれかと完全一致
#          しない場合は本文の一部とみなし、カテゴリは既定値にする)
#   3行目以降(または2行目以降): 本文。空行が段落区切り。
#
# 戻り値: { id, title, category, body } のハッシュリファレンス。
# id はファイル名から拡張子を除いたもの(例: "2026-08-01-お知らせ")。
sub parse_article_file {
    my ($path) = @_;

    open(my $fh, '<:encoding(UTF-8)', $path)
        or die "parse_article_file: cannot open $path: $!";
    my @lines = <$fh>;
    close $fh;

    chomp @lines;

    my $title = shift(@lines);
    $title = '' unless defined $title;

    my $category = $DEFAULT_CATEGORY;
    if (@lines && defined $lines[0] && exists $VALID_CATEGORIES{ $lines[0] }) {
        $category = shift(@lines);
    }

    my $body = join("\n", @lines);
    $body =~ s/\A\n+//;

    my ($volume, $dirs, $basename) = File::Spec->splitpath($path);
    $basename =~ s/\.txt\z//;

    return {
        id       => $basename,
        title    => $title,
        category => $category,
        body     => $body,
    };
}

# render_list_html(\@articles)
#
# 記事一覧のHTML断片を生成する(タイトル・カテゴリはXSS対策のため
# html_escapeする)。
sub render_list_html {
    my ($articles) = @_;
    $articles ||= [];

    my @items;
    for my $article (@$articles) {
        my $id       = html_escape($article->{id});
        my $title    = html_escape($article->{title});
        my $category = html_escape($article->{category});
        push @items,
            qq{<li><span class="news-category">$category</span> }
          . qq{<a href="news.cgi?id=$id">$title</a></li>};
    }

    return "<ul class=\"news-list\">\n" . join("\n", @items) . "\n</ul>\n";
}

# render_detail_html($article)
#
# 記事詳細のHTML断片を生成する。本文は空行(2つ以上の連続改行)で
# 段落に分割し、それぞれをhtml_escapeした上で<p>タグにする。
sub render_detail_html {
    my ($article) = @_;
    $article ||= {};

    my $title    = html_escape($article->{title});
    my $category = html_escape($article->{category});
    my $body     = defined $article->{body} ? $article->{body} : '';

    my @paragraphs = split(/\n{2,}/, $body);
    my $body_html = join("\n", map { '<p>' . html_escape($_) . '</p>' } @paragraphs);

    return "<article>\n"
         . "<h2>$title</h2>\n"
         . "<p class=\"news-category\">$category</p>\n"
         . "$body_html\n"
         . "</article>\n";
}

1;
