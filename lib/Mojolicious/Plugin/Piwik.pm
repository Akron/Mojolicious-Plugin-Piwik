package Mojolicious::Plugin::Piwik;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';
use Mojo::UserAgent;


our $VERSION = '0.05';


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

      # No piwik url
      return b('<!-- No Piwik-URL given -->') unless $url;

      # Clear url
      for ($url) {
	s{^https?://}{}i;
	s{piwik\.(?:php|js)$}{}i;
	s{(?<!/)$}{/};
      };

      # Todo: See http://piwik.org/docs/javascript-tracking/
      #       http://piwik.org/docs/ecommerce-analytics/

      # Create piwik tag
      b(<<"SCRIPTTAG")->squish;
<script type="text/javascript">var _paq=_paq||[];(function(){var
u='http'+((document.location.protocol=='https:')?'s':'')+'://$url';
with(_paq){push(['setSiteId',$site_id]);push(['setTrackerUrl',u+'piwik.php']);
push(['trackPageView'])};var
d=document,g=d.createElement('script'),s=d.getElementsByTagName('script')[0];
if(!s){s=d.getElementsByTagName('head')[0].firstChild};
with(g){type='text/javascript';defer=async=true;
src=u+'piwik.js';s.parentNode.insertBefore(g,s)}})();</script>
<noscript><img src="http://${url}piwik.php?idSite=${site_id}&amp;rec=1" alt=""
style="border:0" /></noscript>
SCRIPTTAG
    });

  $mojo->helper(
    piwik_api => sub {
      my ($c, $method, $param, $cb) = @_;

      my $url        = delete $param->{url} || $plugin_param->{url};

      # Token Auth
      my $token_auth = delete $param->{token_auth} ||
	               $plugin_param->{token_auth} || 'anonymous';

      my $site_id = $param->{site_id} ||
	            $param->{idSite}  ||
                    $plugin_param->{site_id} || 1;

      delete @{$param}{qw/site_id idSite format module method/};

      $url = Mojo::URL->new($url);
      $url->query(
	module => 'API',
	method => $method,
	format => 'JSON',
	idSite => ref $site_id ? join(',', @$site_id) : $site_id,
	token_auth => $token_auth
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

      # Range with periods
      if ($param->{period}) {

	# Delete period
	my $period = lc(delete $param->{period});

	# Delete date
	my $date = delete $param->{date};

	# Get range
	if ($period eq 'range') {
	  $date = ref $date ? join(',', @$date) : $date;
	};

	if ($period =~ /^(?:day|week|month|year|range)$/) {
	  $url->query({
	    period => $period,
	    date => $date
	  });
	};
      };


      # Todo: Filter

      # Create Mojo::UserAgent
      my $ua = Mojo::UserAgent->new(max_redirects => 2);

      $url->scheme('https') if $param->{secure};

      # Merge query
      $url->query($param);

      warn $url->to_string;

      # Todo: json errors!

      # Blocking
      unless ($cb) {
	my $tx = $ua->get($url);
	return $tx->res->json if $tx->success;
	return;
      }

      # Non-Blocking
      else {
	$ua->get(
	  $url => sub {
	    my ($ua, $tx) = @_;
	    my $json = $tx->res->json if $tx->success;
	    $cb->($json);
	  });
	Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
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
Defaults to C<1> if Mojolicious is in production mode,
defaults to C<0> otherwise.

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
instance. Defaults to the site id and the url of the plugin
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
