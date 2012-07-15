#!/usr/bin/env perl
use Test::Mojo;
use Test::More tests => 11;
use Mojolicious::Lite;
$|++;
use lib '../lib';

my $t = Test::Mojo->new;

my $app = $t->app;

$app->mode('production');

$app->plugin('Piwik' => {
  url => 'sojolicio.us/piwik'
});

like($app->piwik_tag, qr{'s://sojolicio.us/piwik/'}, 'URL');
like($app->piwik_tag, qr{setSiteId',1}, 'SiteId');

like($app->piwik_tag(2), qr{'s://sojolicio.us/piwik/'}, 'URL');
like($app->piwik_tag(2), qr{setSiteId',2}, 'SiteId');

like($app->piwik_tag(
  2 => 'http://sojolicio.us/piwik/piwik.php'
), qr{'s://sojolicio.us/piwik/'}, 'URL');
like($app->piwik_tag(
  2 => 'http://sojolicio.us/piwik/piwik.php'
), qr{setSiteId',2}, 'SiteId');

like($app->piwik_tag(
  3 => 'https://sojolicio.us/piwik/piwik.js'
), qr{'s://sojolicio.us/piwik/'}, 'URL');
like($app->piwik_tag(
  3 => 'http://sojolicio.us/piwik/piwik.js'
), qr{setSiteId',3}, 'SiteId');

like($app->piwik_tag(
  4 => 'sojolicio.us/piwik'
), qr{'s://sojolicio.us/piwik/'}, 'URL');
like($app->piwik_tag(
  4 => 'sojolicio.us/piwik'
), qr{setSiteId',4}, 'SiteId');

$app->mode('development');

$app->plugin('Piwik' => {
  url => 'sojolicio.us/piwik'
});

ok(!$app->piwik_tag, 'Development mode');
