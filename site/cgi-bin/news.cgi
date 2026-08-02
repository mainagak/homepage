#!/usr/bin/perl

# news.cgi
#
# ../news/*.txt を走査し、記事一覧(idパラメータなし)または記事詳細
# (id=YYYY-MM-DD-タイトル)を生成して返す。下書き状態は持たず、
# ファイルをアップロードした時点で即座に反映される(保守5/5 W4=A)。
#
# 詳細設計: docs/specs/internal-spec-cyberhome.md 4章

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
use NewsLogic;

Common::install_die_handler('news.cgi');

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
    my $script_dir  = Common::resolve_script_dir();
    my $news_dir    = File::Spec->catdir($script_dir, '..', 'news');
    my $header_path = File::Spec->catfile($script_dir, '..', 'templates', 'header.html');
    my $footer_path = File::Spec->catfile($script_dir, '..', 'templates', 'footer.html');

    my $id = $cgi->param('id');

    my $body_html;

    if (defined $id && length $id) {
        # 詳細表示: idはパストラバーサル対策として厳密な正規表現で検証する
        # (download.cgiと同様の考え方、internal-spec-cyberhome.md 4.2節)。
        unless ($id =~ /\A\d{4}-\d{2}-\d{2}-[\w\-]+\z/) {
            print "Status: 400 Bad Request\r\n";
            print "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
            print "不正なリクエストです。\n";
            return;
        }

        my $article_path = File::Spec->catfile($news_dir, "$id.txt");
        unless (-e $article_path && -f $article_path) {
            print "Status: 404 Not Found\r\n";
            print "Content-Type: text/plain; charset=UTF-8\r\n\r\n";
            print "記事が見つかりません。\n";
            return;
        }

        my $article = NewsLogic::parse_article_file($article_path);
        $body_html = NewsLogic::render_detail_html($article);
    }
    else {
        # 一覧表示: 直近10件(NewsLogic::list_article_filesが切り詰め済み)
        my @files = NewsLogic::list_article_files($news_dir);
        my @articles = map { NewsLogic::parse_article_file($_) } @files;
        $body_html = NewsLogic::render_list_html(\@articles);
    }

    my $header_html = _read_fragment($header_path);
    my $footer_html = _read_fragment($footer_path);

    print "Content-Type: text/html; charset=UTF-8\r\n\r\n";
    print $header_html . $body_html . $footer_html;

    return;
}

# _read_fragment($path)
#
# templates/header.html・footer.htmlを文字列として読み込む
# (internal-spec-cyberhome.md 4.3節、単純な文字列連結によるテンプレート)。
# ファイルが存在しない場合は空文字を返す(致命的エラーにはしない)。
sub _read_fragment {
    my ($path) = @_;
    return '' unless -e $path;

    open(my $fh, '<:encoding(UTF-8)', $path) or return '';
    local $/ = undef;
    my $content = <$fh>;
    close $fh;

    return defined $content ? $content : '';
}
