package ConfigAssistant::Util;

use strict;
use base 'Exporter';

our @EXPORT_OK = qw( find_theme_plugin find_template_def find_option_def );

sub find_template_def {
    my ($id,$set) = @_;
    my $r      = MT->registry('template_sets');
    foreach my $type (qw(widget_sets widget index module individual system archive)) {
	if ($r->{$set}->{'templates'}->{$type}) {
	    my $def = $r->{$set}->{'templates'}->{$type}->{$id};
	    if ( $def ) {
		$def->{type} = $type;
		return $def;
	    }
	}
    }
    return undef;
}

sub find_option_def {
    my ($id,$set) = @_;
    $id =~ s/^($set)_//;
    my $r = MT->registry('template_sets');
    return unless $r->{$set}->{'options'};
    foreach (keys %{$r->{$set}->{'options'}}) {
#	MT->log({ message => "Found option '$id' in $set." });
	return $r->{$set}->{'options'}->{$id} if ($id eq $_);
    }
}

sub find_theme_plugin {
    my ($set) = @_;
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @sets   = keys %{ $r->{'template_sets'} };
        foreach (@sets) {
            return $obj if ( $set eq $_ );
        }
    }
    return undef;
}

1;
