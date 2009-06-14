package ConfigAssistant::Util;

use strict;
use base 'Exporter';

our @EXPORT_OK = qw( find_theme_plugin );

sub find_theme_plugin {
    my ($set) = @_;
    for my $sig ( keys %MT::Plugins ) {
	my $plugin = $MT::Plugins{$sig};
	my $obj = $MT::Plugins{$sig}{object};
	my $r = $obj->{registry};
	my @sets = keys %{$r->{'template_sets'}};
	foreach (@sets) {
	    return $obj if ($set eq $_);
	}
    }
    return undef;
}

1;
