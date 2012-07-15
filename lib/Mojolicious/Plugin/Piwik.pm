package Mojolicious::Plugin::Piwik;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::ByteStream 'b';

our $VERSION = '0.01';

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
      my $c = shift;

      # Do not embed
      return '' unless $embed;

      my $site_id   = shift || $plugin_param->{site_id} || 1;
      my $piwik_url = shift || $plugin_param->{url};

      # Clear url
      for ($piwik_url) {
	s{^https?://}{}i;
	s{piwik\.(?:php|js)$}{}i;
	s{(?<!/)$}{/};
      };

      # No piwik url
      return '' unless $piwik_url;

      # Create piwik tag
      b('<script type="text/javascript">' .
        'var _paq=_paq||[];' .
        '(function(){var u=\'http\'+((document.location.protocol==\'https:\')' .
        "?'s://$piwik_url':'://$piwik_url');".
        'with(_paq){' .
	"push(['setSiteId',$site_id]);" .
        "push(['setTrackerUrl',u+'piwik.php']);" .
	"push(['trackPageView'])};" .
	'var d=document,' .
	'g=d.createElement(\'script\'),' .
	's=d.getElementsByTagName(\'script\')[0];' .
	'with(g){' .
	'type=\'text/javascript\';' .
	'defer=async=true;' .
	'src=u+\'piwik.js\';' .
	'parentNode.insertBefore(g,s)' .
        '}})();' .
	'</script>');
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

=head1 DEPENDENCIES

L<Mojolicious>.


=head1 AVAILABILITY

  https://github.com/Akron/Mojolicious-Plugin-Piwik


=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012, Nils Diewald.

This program is free software, you can redistribute it
and/or modify it under the same terms as Perl.

=cut
