package Mojolicious::Plugin::Piwik;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::UserAgent;


our $VERSION = '0.03';


# Register plugin
sub register {
  my ($plugin, $mojo, $plugin_param) = @_;

  $plugin_param ||= {};

  # Load parameter from Config file
  if (my $config_param = $mojo->config('Piwik')) {
    $plugin_param = { %$config_param, %$plugin_param };
  };

  my $embed = $plugin_param->{embed} //
    ($mojo->mode eq 'production' ? 1 : 0);

  # Add helper
  $mojo->helper(
    piwik_tag => sub {

      # Do not embed
      return '' unless $embed;

      shift;

      my $site_id = shift || $plugin_param->{site_id} || 1;
      my $url     = shift || $plugin_param->{url};

      # Clear url
      for ($url) {
	s{^https?://}{}i;
	s{piwik\.(?:php|js)$}{}i;
	s{(?<!/)$}{/};
      };

      # No piwik url
      return '' unless $url;

      # Todo: See http://piwik.org/docs/javascript-tracking/

      # http://piwik.org/docs/ecommerce-analytics/

      # Create piwik tag
      b(<< "SCRIPTTAG")->squish;
<script type="text/javascript">var _paq=_paq||[];(function(){var
u='http'+((document.location.protocol=='https:')?'s':'')+'://$url';
with(_paq){push(['setSiteId',$site_id]);push(['setTrackerUrl',u+'piwik.php']);
push(['trackPageView'])};var
d=document,g=d.createElement('script'),s=d.getElementsByTagName('script')[0];
with(g){type='text/javascript';defer=async=true;
src=u+'piwik.js';parentNode.insertBefore(g,s)}})();</script>
SCRIPTTAG
    });

  $mojo->helper(
    piwik_api => sub {
      my ($c, $method, $param, $cb) = @_;

      my $url     = delete $param->{url} || $plugin_param->{url};
      my $site_id = $param->{site_id} ||
	            $param->{idSite} ||
                    $plugin_param->{site_id} || 1;

      delete @{$param}{qw/site_id idSite format module method/};

      $url = Mojo::URL->new($url);
      $url->query(
	module => 'API',
	method => $method,
	format => 'JSON',
	idSite => ref $site_id ? join(',', @$site_id) : $site_id
      );

      # Urls as array
      if ($param->{urls}) {
	if (ref $param->{urls}) {
	  my $i = 0;
	  foreach (@{$param->{urls}}) {
	    $url->query('urls[' . $i++ . ']' => $_);
	  };
	}
	else {
	  $url->query(urls => $param->{urls});
	};
	delete $param->{urls};
      };

      # Todo: Range with dates
      # Todo: Filter

      # Create Mojo::UserAgent
      my $ua = Mojo::UserAgent->new(max_redirects => 2);

      # Token Auth
      my $token_auth = delete $param->{token_auth} ||
	               $plugin_param->{token_auth} || 'anonymous';
      $url->scheme('https') if $param->{secure};

      # Todo: json errors!

      # Blocking
      unless ($cb) {
	my $tx = $ua->get($url);
	return $tx->res->json if $tx->success;
	return;
      }

      # Asynchronous
      else {
	$ua->get(
	  $url => sub {
	    my ($ua, $tx) = @_;
	    my $json = $tx->res->json if $tx->success;
	    $cb->($json);
	  });
      };
    });
};


1;


__END__

=pod

=head1 NAME

Mojolicious::Plugin::Piwik - Use Piwik in your Mojolicious app


=head1 SYNOPSIS

  $app->plugin(Piwik => {
    url => 'piwik.sojolicio.us',
    site_id => 1
  });

  # Or in your config file
  {
    Piwik => {
      url => 'piwik.sojolicio.us',
      site_id => 1
    }
  }

  # In Template
  %= piwik_tag


=head1 DESCRIPTION

L<Mojolicious::Plugin::Piwik> is a simple plugin for embedding
Piwik Analysis to your Mojolicious app.


=head1 METHODS

=head2 C<register>

  # Mojolicious
  $app->plugin(Piwik => {
    url => 'piwik.sojolicio.us',
    site_id => 1
  });

  # Mojolicious::Lite
  plugin 'Piwik' => {
    url => 'piwik.sojolicio.us',
    site_id => 1
  };

Called when registering the plugin.
Accepts the following parameters:

=over 2

=item C<url>

URL of your Piwik instance.

=item C<site_id>

The id of the site to monitor. Defaults to 1.

=item C<embed>

Activates or deactivates the embedding of the script tag.
Defaults to 1 if Mojolicious is in production mode,
defaults to 0 otherwise.

=item C<token_auth>

Token for authentication. Used for the Piwik API.

=back


=head1 HELPERS

=head2 C<piwik_tag>

  %= piwik_tag
  %= piwik_tag 1
  %= piwik_tag 1, 'piwik.sojolicio.us'

Renders a script tag that asynchronously loads the Piwik
javascript file from your Piwik instance.
Accepts optionally a site id and the url of your Piwik
instance. Defaults to the side id and the url of the plugin
registration.

=head2 C<piwik_api>

  # In Controller - blocking ...
  my $json = $c->piwik_api(
    'Actions.getPageUrl' => {
      token_auth => 'MyToken',
      idSite => [4,7],
      period => 'day',
      date   => 'today'
    }
  );

  # ... or async
  $c->piwik_api(
    'Actions.getPageUrl' => {
      token_auth => 'MyToken',
      idSite => [4,7],
      period => 'day',
      date   => 'today'
    } => sub {
      my $json = shift;
      ...
    }
  );

Sends a Piwik API request and returns the response as an object
(the decoded JSON response). Accepts the API method, a hash reference
with request parameters as described by the
L<Piwik API|http://piwik.org/docs/analytics-api/reference/>, and
optionally a callback, if the request is meant to be non-blocking.

In addition to the parameters of the API reference, the following
parameters are allowed:

=over 2

=item C<url>

The url of your Piwik instance. Defaults to the url of the plugin
registration.

=item C<secure>

Boolean value that indicates a request using the https scheme.
Defaults to false.

=back

C<idSite> is an alias of C<site_id> and defaults to the id
of the plugin registration.
Some parameters are allowed to be array references instead of string values,
for example C<idSite> and C<urls>.


=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-Piwik


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012, Nils Diewald.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
