#!/usr/bin/env perl
use Test::Mojo;
use Test::More;
use Mojolicious::Lite;
use Mojo::JSON;
use Data::Dumper;
use utf8;

my $t = Test::Mojo->new;

my $app = $t->app;

$app->mode('production');

$app->plugin(Piwik => {
  url => 'sojolicious.example/piwik',
  site_id => 2
});

is($app->piwik_tag('as-script'), '', 'No script embedded');

# Define shortcut
ok(any('/piwik/tracker.js')->piwik('track_script'), 'Track script is set');

like($app->piwik_tag('as-script'), qr!http://sojolicious\.example/piwik/matomo\.js!);
like($app->piwik_tag('as-script'), qr!/piwik/tracker\.js!);

$t->get_ok('/piwik/tracker.js')
  ->status_is(200)
  ->content_like(qr!'http://sojolicious\.example/piwik/matomo\.php'!)
  ->content_like(qr!'setSiteId',2!)
  ->header_is('Content-Type','application/javascript')
  ->header_is('Cache-Control', 'max-age=10800')
  ;

get '/track' => sub {
  shift->render(
    inline => '<%= piwik_tag "as-script" %>'
  );
};

$t->get_ok('/track')
  ->status_is(200)
  ->element_exists('script:nth-of-type(2)[src="http://sojolicious\.example/piwik/matomo.js"]')
  ->element_exists('script:nth-of-type(1)[src$=/piwik/tracker.js]')
  ->element_exists('script:nth-of-type(1)[src^=http://]')
  ;

done_testing;

__END__
