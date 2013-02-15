package Net::SMTP::Extended::Basic;

# This bascially is Net::SMTP.

use strict;
use Carp;

use base 'Net::SMTP';

# With TLS
sub is_secure { 0 }

1;

package Net::SMTP::Extended;

use strict;
use Carp;

use constant {
	OPPORTUNISTIC_TLS	=> 1,
	FORCED_TLS		=> 2,
};

# This really is a factory method that instantiates the correct
# instance based on args
sub new {
	my $class = shift;
	my $real_class = ref $class || $class;

	my $host = shift;

	my %args =  @_ ;
	my $my_class;

	if (exists $args{TLS}) {
		$my_class = 'Net::SMTP::Extended::TLS';

		eval {
			local $SIG{__DIE__};
			require Net::SMTP::Extended::TLS;
		};

		return $my_class->new($host, %args);
	} else {
		return Net::SMTP::Extended::Basic->new($host, %args);
	}
}

1;

