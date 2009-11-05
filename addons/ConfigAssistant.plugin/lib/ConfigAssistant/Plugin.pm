package ConfigAssistant::Plugin;

use strict;

use Carp qw( croak );
use MT::Util
  qw( relative_date offset_time offset_time_list epoch2ts ts2epoch format_ts encode_html dirify );
use ConfigAssistant::Util qw( find_theme_plugin find_template_def find_option_def );

sub theme_options {
    my $app     = shift;
    my ($param) = @_;
    my $q       = $app->{query};
    my $blog    = $app->blog;

    $param ||= {};

    my $ts        = $blog->template_set;
    my $plugin    = find_theme_plugin($ts);
    my $cfg       = $app->registry('template_sets')->{$ts}->{options};
    my $types     = $app->registry('config_types');
    my $fieldsets = $cfg->{fieldsets};
    my $scope     = 'blog:' . $app->blog->id;
    
    my $cfg_obj   = $plugin->get_config_hash($scope); 

    require MT::Template::Context;
    my $ctx       = MT::Template::Context->new();

    $fieldsets->{__global} = {
        label => sub { "Global Options"; }
    };

    # this is a localized stash for field HTML
    my $fields;

    foreach my $optname ( 
        sort {
            ( $cfg->{$a}->{order} || 999 )
              <=> ( $cfg->{$b}->{order} || 999 )
        } keys %{$cfg}
     ) {
        next if $optname eq 'fieldsets';
        my $field = $cfg->{$optname};
        if ( my $cond = $field->{condition} ) {
            if ( !ref($cond) ) {
                $cond = $field->{condition} = $app->handler_to_coderef($cond);
            }
            next unless $cond->();
        }

        my $field_id = $ts . '_' . $optname;
        if ( $types->{ $field->{'type'} } ) {
            my $value = delete $cfg_obj->{$field_id};
            my $out;
            $field->{fieldset} = '__global' unless defined $field->{fieldset};
            my $show_label =
              defined $field->{show_label} ? $field->{show_label} : 1;
            $out .=
                '  <div id="field-'
              . $field_id
              . '" class="field field-left-label pkg field-type-'
              . $field->{type} . '">' . "\n";
            $out .= "    <div class=\"field-header\">\n";
            $out .=
                "      <label for=\"$field_id\">"
              . &{ $field->{label} }
              . "</label>\n"
              if $show_label;
            $out .= "    </div>\n";
            $out .= "    <div class=\"field-content\">\n";
            my $hdlr =
              MT->handler_to_coderef( $types->{ $field->{'type'} }->{handler} );
            $out .= $hdlr->( $app, $ctx, $field_id, $field, $value );

            if ( $field->{hint} ) {
                $out .=
                  "      <div class=\"hint\">" . $field->{hint} . "</div>\n";
            }
            $out .= "    </div>\n";
            $out .= "  </div>\n";
            my $fs = $field->{fieldset};
            push @{ $fields->{$fs} }, $out;
        }
        else {
            MT->log(
                {
                    message => 'Unknown config type encountered: '
                      . $field->{'type'}
                }
            );
        }
    }
    my @loop;
    my $count = 0;
    my $html;
    foreach my $set (
        sort {
            ( $fieldsets->{$a}->{order} || 999 )
              <=> ( $fieldsets->{$b}->{order} || 999 )
        } keys %$fieldsets
      )
    {
        next unless $fields->{$set} || $fieldsets->{$set}->{template};
        my $label     = &{ $fieldsets->{$set}->{label} };
        my $innerhtml = '';
        if ( my $tmpl = $fieldsets->{$set}->{template} ) {
            my $txt = $plugin->load_tmpl($tmpl);
            my $filter =
                $fieldsets->{$set}->{format}
              ? $fieldsets->{$set}->{format}
              : '__default__';
            $txt = MT->apply_text_filters( $txt->text(), [$filter] );
            $innerhtml = $txt;
            $html .= $txt;
        }
        else {
            $html .= "<fieldset>";
            $html .= "<h3>" . $label . "</h3>";
            foreach ( @{ $fields->{$set} } ) {
                $innerhtml .= $_;
            }
            $html .= $innerhtml;
            $html .= "</fieldset>";
        }
        push @loop,
          {
            '__first__' => ( $count++ == 0 ),
            id          => dirify($label),
            label       => $label,
            content     => $innerhtml,
          };
    }
    my @leftovers;
    foreach my $field_id (keys %$cfg_obj) {
	push @leftovers, {
	    name => $field_id,
	    value => $cfg_obj->{$field_id},
	};
    }
    $param->{html}       = $html;
    $param->{fieldsets}  = \@loop;
    $param->{leftovers}  = \@leftovers;
    $param->{blog_id}    = $blog->id;
    $param->{plugin_sig} = $plugin->{plugin_sig};
    $param->{saved}      = $q->param('saved');
    return $app->load_tmpl( 'theme_options.tmpl', $param );
}

# Code for this method taken from MT::CMS::Plugin
sub save_config {
    my $app = shift;

    my $q          = $app->param;
    my $plugin_sig = $q->param('plugin_sig');
    my $profile    = $MT::Plugins{$plugin_sig};
    my $blog_id    = $q->param('blog_id');
    return unless $blog_id; # this works one within the context of a blog, no system plugin settings

    $app->blog( MT->model('blog')->load($blog_id) ) if $blog_id;

    $app->validate_magic or return;
    return $app->errtrans("Permission denied.")
        unless $app->user->can_manage_plugins
            or ($blog_id
            and $app->user->permissions($blog_id)->can_administer_blog);

    my $param;
    my @params = $q->param;
    foreach (@params) {
        next if $_ =~ m/^(__mode|return_args|plugin_sig|magic_token|blog_id)$/;
        $param->{$_} = $q->param($_);
    }
    if ( $profile && $profile->{object} ) {
        my $plugin = $profile->{object};
        $plugin->error(undef);
	my $scope = $blog_id ? 'blog:' . $blog_id : 'system';

#        $plugin->save_config( \%param, $scope );

	# BEGIN - contents of MT::Plugin->save_config
	my $pdata = $plugin->get_config_obj($scope);
	$scope =~ s/:.*//;
	my @vars = $plugin->config_vars($scope);
	my $data = $pdata->data() || {};

	my $repub_queue;
	foreach my $var (@vars) {
	    my $old = $data->{$var};
	    my $new = $param->{$var};
	    my $has_changed = $new && ($old ne $new);
	    my $opt = find_option_def($var,$app->blog->template_set);
	    if ($has_changed && $opt && $opt->{'republish'}) {
		foreach (split(',',$opt->{'republish'})) {
		    $repub_queue->{$_} = 1;
		}
	    }
	    $data->{$var} = $new ? $new : undef;
	    if ($has_changed) {
		$app->run_callbacks( 'theme_options_change.'.$var, $app, $opt, $old, $new );
		$app->run_callbacks( 'theme_options_change.*', $app, $opt, $old, $new );
	    }    
	}
	foreach (keys %$repub_queue) {
	    my $tmpl = MT->model('template')->load({
		blog_id => $blog_id,
		identifier => $_,
            });
	    next unless $tmpl;
	    MT->log({ blog_id => $blog_id, message => "Config Assistant: Republishing " . $tmpl->name });
	    $app->rebuild_indexes(
		Blog     => $app->blog,
		Template => $tmpl,
		Force    => 1,
		);
	}
	$pdata->data($data);
	MT->request('plugin_config.'.$plugin->id, undef);
	$pdata->save() or die $pdata->errstr;
	# END - contents of MT::Plugin->save_config

        if ( $plugin->errstr ) {
            return $app->error("Error saving plugin settings: " . $plugin->errstr);
        }
    }

    $app->add_return_arg( saved => 1 );
    $app->call_return;
}

sub type_text {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    return
        "      <input type=\"text\" name=\"$field_id\" value=\""
      . encode_html($value, 1) # The additional "1" will escape HTML entities properly
      . "\" class=\"full-width\" />\n";
}

sub type_textarea {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    $out .= "      <textarea name=\"$field_id\" class=\"full-width\" rows=\""
      . $field->{rows} . "\" />";
    $out .= encode_html($value, 1); # The additional "1" will escape HTML entities properly
    $out .= "</textarea>\n";
    return $out;
}

sub type_entry {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $entry = MT->model('entry')->load($value);
    my $entry_name = $entry ? $entry->title : '';
    my $blog_id = $field->{all_blogs} ? 0 : $app->blog->id;
    unless ($ctx->var('entry_chooser_js')) {
	$out .= <<EOH;
    <script type="text/javascript">
        function insertCustomFieldEntry(html, val, id) {
            \$('#'+id).val(val);
            try {
                \$('#'+id+'_preview').html(html);
            } catch(e) {
                log.error(e);
            };
        }
    </script>
EOH
      $ctx->var('entry_chooser_js',1);
    }
    $out .= <<EOH;
<div class="pkg">
  <input name="$field_id" id="$field_id" class="hidden" type="hidden" value="$value" />
  <button type="submit"
          onclick="return openDialog(this.form, 'ca_config_entry', 'blog_id=$blog_id&edit_field=$field_id')">Choose Entry</button>
  <div id="${field_id}_preview" class="preview">
    $entry_name
  </div>
</div>
EOH
    return $out;
}

sub type_tagged_entry {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $lastn = $field->{lastn} || 10;
    my $tag = $field->{tag};

    my (%terms,%args);
    $terms{blog_id} = $app->blog->id unless $field->{blog_id} eq 'all';
    $args{lastn} = $lastn;
    my @filters;
    my $class = 'MT::Entry';
    if (my $tag_arg = $field->{tag_filter}) {
        require MT::Tag;
        require MT::ObjectTag;

        my $terms;
        if ($tag_arg !~ m/\b(AND|OR|NOT)\b|\(|\)/i) {
            my @tags = MT::Tag->split(',', $tag_arg);
            $terms = { name => \@tags };
            $tag_arg = join " or ", @tags;
        }
        my $tags = [ MT::Tag->load($terms, {
                    binary => { name => 1 },
                    join => ['MT::ObjectTag', 'tag_id', { %terms, object_datasource => $class->datasource }]
        }) ];
	require MT::Template::Context;
	my $ctx = MT::Template::Context->new;
        my $cexpr = $ctx->compile_tag_filter($tag_arg, $tags);
        if ($cexpr) {
            my @tag_ids = map { $_->id, ( $_->n8d_id ? ( $_->n8d_id ) : () ) } @$tags;
            my $preloader = sub {
                my ($entry_id) = @_;
                my $cterms = {
                    tag_id            => \@tag_ids,
                    object_id         => $entry_id,
                    object_datasource => $class->datasource,
                    %terms,
                };
                my $cargs = {
                    %args,
                    fetchonly => ['tag_id'],
                    no_triggers => 1,
                };
                my @ot_ids = MT::ObjectTag->load( $cterms, $cargs ) if @tag_ids;
                my %map;
                $map{ $_->tag_id } = 1 for @ot_ids;
                \%map;
            };
            push @filters, sub { $cexpr->( $preloader->( $_[0]->id ) ) };
        }
    }

    my @entries;
    my $iter = MT->model('entry')->load_iter(\%terms, \%args);
    my $i = 0; my $j = 0;
    my $n = $field->{lastn};
    ENTRY: while (my $e = $iter->()) {
      for (@filters) {
	  next ENTRY unless $_->($e);
      }
      push @entries, $e;
      $i++;
      last if $n && $i >= $n;
    }
    $out .= "      <select name=\"$field_id\">\n";
    $out .=
	'        <option value=""'
	. ( !$value || $value eq ""  ? " selected" : "" )
	. ">None selected</option>\n";
    my $has_selected = 0;
    foreach (@entries) {
	$has_selected = 1 if $value eq $_->id;
        $out .=
            '        <option value="'.$_->id.'"'
          . ( $value eq $_->id ? " selected" : "" )
          . ">".$_->title.($field->{blog_id} eq 'all' ? " (".$_->blog->name.")" : "")."</option>\n";
    }
    if ($value && !$has_selected) {
	my $e = MT->model('entry')->load( $value );
	if ($e) {
	    $out .=
		'        <option value="'.$e->id.'" selected>'.$e->title
		. ($field->{blog_id} eq 'all' ? " (".$e->blog->name.")" : "")."</option>\n";
	}
    }
    $out .= "      </select>\n";
    return $out;
}

sub type_radio {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my @values = split( ",", $field->{values} );
    $out .= "      <ul>\n";
    foreach (@values) {
        $out .=
            "        <li><input type=\"radio\" name=\"$field_id\" value=\"$_\""
          . ( $value eq $_ ? " checked=\"checked\"" : "" )
          . " class=\"rb\" />"
          . $_
          . "</li>\n";
    }
    $out .= "      </ul>\n";
    return $out;
}

sub type_radio_image {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my $static = $app->config->StaticWebPath;
    $out .= "      <ul class=\"pkg\">\n";
    while ( $field->{values} =~ /\"([^\"]*)\":\"([^\"]*)\",?/g ) {
        $out .=
            "        <li><input type=\"radio\" name=\"$field_id\" value=\"$2\""
          . ( $value eq $2 ? " checked=\"checked\"" : "" )
          . " class=\"rb\" />"
          . "<img src=\""
          . $static
          . $1
          . "\" /><br />$2"
          . "</li>\n";
    }
    $out .= "      </ul>\n";
    return $out;
}

sub type_select {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my @values = split( ",", $field->{values} );
    $out .= "      <select name=\"$field_id\">\n";
    foreach (@values) {
        $out .=
            "        <option"
          . ( $value eq $_ ? " selected" : "" )
          . ">$_</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
}

sub type_blogs {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    my @blogs = MT->model('blog')->load( {}, { sort => 'name' } );
    $out .= "      <select name=\"$field_id\">\n";
    $out .=
        "        <option value=\"0\" "
      . ( 0 == $value ? " selected" : "" )
      . ">None Selected</option>\n";
    foreach (@blogs) {
        $out .=
            "        <option value=\""
          . $_->id . "\" "
          . ( $value == $_->id ? " selected" : "" ) . ">"
          . $_->name
          . "</option>\n";
    }
    $out .= "      </select>\n";
    return $out;
}

sub type_checkbox {
    my $app = shift;
    my ( $ctx, $field_id, $field, $value ) = @_;
    my $out;
    $out .= "      <input type=\"checkbox\" name=\"$field_id\" value=\"1\" "
      . ( $value ? "checked " : "" ) . "/>\n";
    return $out;
}

sub _hdlr_field_value {
    my $plugin = shift;
    my ( $ctx, $args ) = @_;
    my $plugin_ns = $ctx->stash('plugin_ns');
    my $field     = $ctx->stash('field')
      or return _no_field($ctx);
    $plugin = MT->component($plugin_ns);    # is this necessary?

    my $value;
    my $blog    = $ctx->stash('blog');
    if ( !$blog ) {
	my $blog_id = $ctx->var('blog_id');
        $blog = MT->model('blog')->load($blog_id);
    }
    if ( $blog && $blog->id ) {
        $value = $plugin->get_config_value( $field, 'blog:' . $blog->id );
    }
    else {
        $value = $plugin->get_config_value($field);
    }
    return $args->{default} if ( $args->{default} && (!$value || $value eq '' ));
    return $value;
}

sub _hdlr_field_cond {
    my $plugin = shift;
    my ( $ctx, $args ) = @_;
    my $plugin_ns  = $ctx->stash('plugin_ns');
    my $field      = $ctx->stash('field')
      or return _no_field($ctx);
    my $blog    = $ctx->stash('blog');
    if ( !$blog ) {
	my $blog_id = $ctx->var('blog_id');
        $blog = MT->model('blog')->load($blog_id);
    }
    $plugin = MT->component($plugin_ns); # load the theme plugin
    my $value = $plugin->get_config_value( $field, 'blog:' . $blog->id );
    if ($value) {
        return $ctx->_hdlr_pass_tokens(@_);
    }
    else {
        return $ctx->_hdlr_pass_tokens_else(@_);
    }
}

sub _no_field {
    return $_[0]->error(
        MT->translate(
"You used an '[_1]' tag outside of the context of the correct content; ",
            $_[0]->stash('tag')
        )
    );
}

sub tag_config_form {
    my ( $ctx, $args, $cond ) = @_;
    my $app  = MT->app;
    my $html = '';
    my $id   = $args->{'id'};
    my $cfg  = $app->registry( 'plugin_config', $id );
    my $seen;
    foreach my $key ( sort keys %$cfg ) {
        my $plugin   = delete $cfg->{$key}->{'plugin'};
	my $scope    = 'blog:' . $app->blog->id;
	my $cfg_obj  = $plugin->get_config_hash($scope); 
        my $fieldset = $cfg->{$key};
        $html .= "<fieldset>\n";
        my $label = delete $fieldset->{'label'};
        if ($label) {
            $html .= "  <h3>" . &$label . "</h3>\n";
        }
        my $fs_text = delete $fieldset->{'description'};
        if ($fs_text) {
            $html .= "  <p>" . &$fs_text . "</p>\n";
        }
        foreach my $field_id ( sort keys %$fieldset ) {
            my $field = $fieldset->{$field_id};
	    $seen->{$field_id} = 1;
#            my $value =
#              $plugin->get_config_value( $field_id, $scope );
            my $value = $cfg_obj->{$field_id};
            my $show_label =
              $field->{'show_label'} ? &{ $field->{'show_label'} } : 1;
            $html .=
                '  <div id="'
              . $field_id
              . '" class="field field-left-label pkg">' . "\n";
            $html .= "    <div class=\"field-header\">\n";
            $html .=
                "      <label for=\"$id-$field_id\">"
              . &{ $field->{'label'} }
              . "</label>\n"
              if $show_label;
            $html .= "    </div>\n";
            $html .= "    <div class=\"field-content\">\n";

            if ( $field->{'type'} eq 'text' ) {
                $html .=
                    "      <input type=\"text\" name=\"$field_id\" value=\""
                  . encode_html($value, 1) # The additional "1" will escape HTML entities properly
                  . "\" class=\"full-width\" />\n";

            }
            elsif ( $field->{'type'} eq 'textarea' ) {
                $html .=
"      <textarea name=\"$field_id\" class=\"full-width\" rows=\""
                  . $field->{rows} . "\" />";
                $html .= encode_html($value, 1); # The additional "1" will escape HTML entities properly
                $html .= "</textarea>\n";

            }
            elsif ( $field->{'type'} eq 'radio' ) {
                my @values = split( ",", $field->{values} );
                $html .= "      <ul>\n";
                foreach (@values) {
                    $html .=
"        <li><input type=\"radio\" name=\"$field_id\" value=\"$_\""
                      . ( $value eq $_ ? " checked=\"checked\"" : "" )
                      . " class=\"rb\" />"
                      . $_
                      . "</li>\n";
                }
                $html .= "      </ul>\n";

            }
            elsif ( $field->{'type'} eq 'select' ) {
                my @values = split( ",", $field->{values} );
                $html .= "      <select name=\"$field_id\">\n";
                foreach (@values) {
                    $html .=
                        "        <option"
                      . ( $value eq $_ ? " selected" : "" )
                      . ">$_</option>\n";
                }
                $html .= "      </select>\n";

            }
            elsif ( $field->{'type'} eq 'checkbox' ) {
                $html .=
"      <input type=\"checkbox\" name=\"$field_id\" value=\"1\" "
                  . ( $value ? "checked " : "" ) . "/>\n";

            }
            elsif ( $field->{'type'} eq 'blogs' ) {
                my @blogs = MT->model('blog')->load( {}, { sort => 'name' } );
                $html .= "      <select name=\"$field_id\">\n";
                $html .=
                    "        <option value=\"0\" "
                  . ( 0 == $value ? " selected" : "" )
                  . ">None Selected</option>\n";
                foreach (@blogs) {
                    $html .=
                        "        <option value=\""
                      . $_->id . "\" "
                      . ( $value == $_->id ? " selected" : "" ) . ">"
                      . $_->name
                      . "</option>\n";
                }
                $html .= "      </select>\n";
            }

            if ( $field->{hint} ) {
                $html .= "      <br /><span>" . $field->{hint} . "</span>\n";
            }
            $html .= "    </div>\n";
            $html .= "  </div>\n";
        }
	foreach (keys %$cfg_obj) {
	    $html .= '<input type="hidden" name="'.$_.'" value="'.encode_html($cfg_obj->{$_}).'" />'."\n"
		unless $seen->{$_};
	}
    }
    return $html;
}

sub list_entry_mini {
    my $app = shift;

    my $blog_id = $app->param('blog_id') || 0;

    my $type = 'entry';
    my $pkg = $app->model($type) or return "Invalid request.";

    my %terms;
    $terms{blog_id} = $blog_id if $blog_id;
    $terms{status} = MT::Entry::RELEASE();
    
    my %args = (
        sort      => 'authored_on',
        direction => 'descend',
    );

    my $plugin = MT->component('ConfigAssistant') or die "OMG NO COMPONENT!?!";
    my $tmpl = $plugin->load_tmpl('entry_list.mtml');
    return $app->listing({
        type => 'entry',
        template => $tmpl,
        params => {
	    panel_searchable => 1,
            edit_blog_id     => $blog_id,
            edit_field       => $app->param('edit_field'),
            search           => $app->param('search'),
            blog_id          => $blog_id,
        },
        code => sub {
            my ($obj, $row) = @_;
            $row->{'status_' . lc MT::Entry::status_text($obj->status)} = 1;
            $row->{entry_permalink} = $obj->permalink
                if $obj->status == MT::Entry->RELEASE();
            if (my $ts = $obj->authored_on) {
                my $date_format = MT::App::CMS->LISTING_DATE_FORMAT();
                my $datetime_format = MT::App::CMS->LISTING_DATETIME_FORMAT();
                $row->{created_on_formatted} = format_ts($date_format, $ts, $obj->blog,
                    $app->user ? $app->user->preferred_language : undef);
                $row->{created_on_time_formatted} = format_ts($datetime_format, $ts, $obj->blog,
                    $app->user ? $app->user->preferred_language : undef);
                $row->{created_on_relative} = relative_date($ts, time, $obj->blog);
            }
            return $row;
        },
        terms => \%terms,
        args  => \%args,
        limit => 10,
    });
}

sub select_entry {
    my $app = shift;

    my $entry_id = $app->param('id')
        or return $app->errtrans('No id');
    my $entry = MT->model('entry')->load($entry_id)
        or return $app->errtrans('No entry #[_1]', $entry_id);
    my $edit_field = $app->param('edit_field')
        or return $app->errtrans('No edit_field');

    my $plugin = MT->component('ConfigAssistant') or die "OMG NO COMPONENT!?!";
    my $tmpl = $plugin->load_tmpl('select_entry.mtml', {
        entry_id    => $entry->id,
        entry_title => $entry->title,
        edit_field  => $edit_field,
    });
    return $tmpl;
}

1;

__END__

