
package ConfigAssistant::Init;

use strict;

# Say hey, but we really just wanted the module loaded.
sub init_app { 
    my $plugin = shift;
    my ($app) = @_;
    return if $app->id eq 'wizard';

    my $r = $plugin->registry;
    if ($app->id eq 'cms') {
	# load menu item for theme options
    }
    $r->{tags} = sub { load_tags($plugin) };
    
    1;
}

sub load_tags {
    my $app = MT->app;
    my $cfg = $app->registry('plugin_config');
    my $tags = {};
    foreach my $plugin_id (keys %$cfg) {
	my $plugin_cfg = $cfg->{$plugin_id};
	my $p = delete $cfg->{$plugin_id}->{'plugin'};
	foreach my $key (keys %$plugin_cfg) {
	    my $fieldset = $plugin_cfg->{$key};
	    delete $fieldset->{'label'};
	    foreach my $field_id (keys %$fieldset) {
		my $field = $fieldset->{$field_id};
		my $tag = $field->{tag};
		if ($tag =~ s/\?$//) {
		    $tags->{block}->{$tag} = sub { 
			$_[0]->stash('field', $field_id);
			$_[0]->stash('plugin_ns', $p->id);
			runner('_hdlr_field_cond', 'ConfigAssistant::Plugin', @_); 
		    };
		} elsif ($tag ne '') {
		    $tags->{function}->{$tag} = sub { 
			$_[0]->stash('field', $field_id);
			$_[0]->stash('plugin_ns', $p->id);
			runner('_hdlr_field_value', 'ConfigAssistant::Plugin', @_); 
		    };
		}
	    }
	}
    }
    $tags->{function}{'PluginConfigForm'} = '$ConfigAssistant::ConfigAssistant::Plugin::tag_config_form';
    return $tags;
}

sub runner {
    my $method = shift;
    my $class = shift;
    eval "require $class;";
    if ($@) { die $@; $@ = undef; return 1; }
    my $method_ref = $class->can($method);
    my $plugin = MT->component("ConfigAssistant");
    return $method_ref->($plugin, @_) if $method_ref;
    die $plugin->translate("Failed to find [_1]::[_2]", $class, $method);
}

1;

