package ConfigAssistant::Util;

use strict;
use base 'Exporter';

our @EXPORT_OK =
  qw( find_theme_plugin find_template_def find_option_def find_option_plugin );

sub find_template_def {
    my ( $id, $set ) = @_;
    my $r = MT->registry('template_sets');
    foreach
      my $type (qw(widget_sets widget index module individual system archive))
    {
        if ( $r->{$set}->{'templates'}->{$type} ) {
            my $def = $r->{$set}->{'templates'}->{$type}->{$id};
            if ($def) {
                $def->{type} = $type;
                return $def;
            }
        }
    }
    return undef;
}

sub find_option_def {
    my ( $app, $id ) = @_;
    my $opt;

    # First, search the current template set's theme options
    if ( $app->blog ) {
        my $set = $app->blog->template_set;
        $id =~ s/^($set)_//;
        my $r = MT->registry('template_sets');
        if ( $r->{$set}->{'options'} ) {
            foreach ( keys %{ $r->{$set}->{'options'} } ) {
                $opt = $r->{$set}->{'options'}->{$id} if ( $id eq $_ );
            }
        }
    }

    # Next, if a theme option was not found, search plugin options
    unless ($opt) {
        my $r = MT->registry('options');
        if ($r) {
            foreach ( keys %{$r} ) {
                $opt = $r->{$id} if ( $id eq $_ );
            }
        }
    }
    return $opt;
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

sub find_option_plugin {
    my ($opt_name) = @_;
    for my $sig ( keys %MT::Plugins ) {
        my $plugin = $MT::Plugins{$sig};
        my $obj    = $MT::Plugins{$sig}{object};
        my $r      = $obj->{registry};
        my @opts   = keys %{ $r->{'options'} };
        foreach (@opts) {
            return $obj if ( $opt_name eq $_ );
        }
    }
    return undef;
}

1;
