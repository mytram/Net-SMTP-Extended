package Net::SMTP::Extended::TLS;

use strict;
use Carp;

use IO::Socket::SSL 1.831;
use Net::Cmd;

use base qw(IO::Socket::SSL Net::SMTP::Extended::Basic);

sub new {
	my $class = shift;
	my $real_class = ref $class || $class;
	my $host = shift;

	my %args = @_;

	my $smtp = Net::SMTP::Extended::Basic->new($host, %args);

	my $rv = $real_class->starttls($smtp, \%args);
	if (!$rv) {
		return if $args{TLS} == Net::SMTP::Extended::FORCED_TLS;
	}

	return unless $smtp;
}

sub starttls {
	my $class = shift;
	my $smtp = shift;
	my $args = shift;

	my $config = $args->{SSL_config};
	$config = $args->{TLS_config} unless $config;

	if ( !$config ) {
		# Use non verify
		$config = { SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE, };

	}
	if (defined $smtp->support('STARTTLS', 500, [ "Command unknown: 'STARTTLS'" ] )) {
		if ($smtp->command('STARTTLS')->response == Net::Cmd::CMD_OK) {
			# handshake
			my $rv = $class->start_SSL(
				$smtp,
				%$config,
			);
			return $rv;
			# helo again?
		}
	}

	return;
}

sub is_secure { 1 }

1;
