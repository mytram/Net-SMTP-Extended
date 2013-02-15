use lib "lib";
use lib "../lib";

use Net::Server::Mail::ESMTP;
use Net::SMTP::Extended;

use constant {
	OK       => 250,
	DEFER    => 450,
	NORETRY  => 250, # Drop the message silently so that it doesn't bounce
};

my $host = '127.0.0.1';
my $port = 9988;

my @tests;
my @socks;
my $sender = 'sender@example.com';
my $recip1 = 'recip1@example.com';
my $recip2 = 'recip2@example.com';

my $data =<< "EOS";
Subject: test message
From: <$sender>
To: <$recip1>
To: <$recip2>

hello world.

EOS

push @tests, [ 'Opportunistic TLS but not secure', sub {
	my $s = Net::SMTP::Extended->new($host, Port => $port, Hello => 'localhost',
		TLS	=> Net::SMTP::Extended::TLS_OPPORTUNISTIC,
	);

	ok (ref $s eq 'Net::SMTP::Extended::Basic', "Basic");
	ok ($s->isa('Net::SMTP'), "Is a Net::SMTP");
	ok ($s, "New smtp client");

	ok ($s->peerhost eq $host, "peerhost is $host");
	ok ($s->peerport eq $port, "peerport is $port");

	ok (!$s->is_secure, "is not secure");

	lives_ok ( sub { $s->mail($sender) }, "mail");
	lives_ok ( sub { $s->to($recip1, $recip2) }, "to");
	lives_ok ( sub { $s->data($data) }, "data");


	lives_ok ( sub { $s->mail($sender) }, "mail");
	lives_ok ( sub { $s->to($recip1, $recip2) }, "to");
	lives_ok ( sub { $s->data() }, "data");
	lives_ok ( sub { $s->datasend("Say something") }, "datasend");
	lives_ok ( sub { $s->dataend() }, "dataend");

	ok ($s->hello('localhost'), "Can hello");
	ok ($s->command('EHLO localhost')->response == Net::Cmd::CMD_OK, "Can command EHLO");

	ok ($s->command('STARTTLS')->response == Net::Cmd::CMD_ERROR, "Cannot command STARTTLS");

	$s->quit;

       return 1;
}, { DATA => sub {
	# processing
	my ( $session, $message ) = @_;

	my $s = $session->get_sender();

	$s eq $sender or die "Sender is not $sender";
	diag($sender);
	my @recipients = $session->get_recipients();
	my %recips = map { $_ => 1 } @recipients;

	$recips{$recip1} or die "cannot find $recip1";
	diag($recip1);
	$recips{$recip2} or die "Cannot find $recip2";
	diag($recip2);

	$$message or die "Cannot find message";
	diag($$message);

	return (1, OK, 'Success!');
}}];

my $smtp_s = IO::Socket::INET->new(
	Listen		=> 1,
	LocalAddr	=> $host,
        LocalPort	=> $port,
	Proto		=> 'tcp',
	Timeout		=> 5,
) or die "Cannot create sock on $port: $!";

sub process_test {
	my $sock	= shift;
	my $tc_id	= shift;
	my $test	= shift;

	my $client = $sock->accept;
	push @socks, $client;
	my $smtp = new Net::Server::Mail::ESMTP(
		socket       => $client,
		idle_timeout => 300,
	) or die "Cannot create ESMTP";

	diag ("Accepted client for $tc_id: " . $test->[0]);

	$smtp->set_callback( DATA => $test->[2]{DATA} || sub {} );

	diag("Processing");

	$smtp->process();

	diag("Done");

	$client->close;
	shift @socks;
}

my $ppid = $$;
my $pid = fork();
if (!defined $pid) {
	die $!;
} elsif ($pid) {
	# child process - server
	my $id = 0;
	for (@tests) {
		$id++;
		my $tc = sprintf("Test%02d", $id);
		eval { process_test($smtp_s, $tc, $_); };
		if ($@) {
			diag("kill 9, $pid (child)");
			kill 9, $pid;
			last;
		}
	}

	wait;
	exit;
} else {
	# child tests
	use Test::Most tests => 17;

	for my $test (@tests) {
		my $rv;
		eval {
			$rv = $test->[1]->();
		};
		if ($@ || !$rv) {
			# kill the server
			diag ("Error: $@");
			diag ("kill 9, $ppid (server)");
			kill 9, $ppid;
			last;
		}
	}

	done_testing;

	exit;
}

END {
	$_->close for @socks;
}


