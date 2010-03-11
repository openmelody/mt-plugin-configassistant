This plugin is allows theme and plugin developers to easily surface a form 
within Movable Type for configuring their theme/plugin. In addition, it allows
theme and plugin developers to define template tags by which they can access
the values entered in by their users directly within their templates.

All this **without having to know perl or how to program at all**!

This plugin works by allowing a developer to use their plugin's configuration
file as a means for defining what the various settings and form elements they
would like to expose to a user.

If Config Assistant is being used within the context of a theme, then users of 
your theme will automatically have a "Theme Options" menu item added to their 
design menu so they can easily access the settings you define.

Config Assistant can also work with "static" content to make deploying your plugin 
or theme easier. (If you've installed many plugins, you know that you must often 
copy content to `[MT Home]/plugins/` and `[MT Home]/mt-static/plugins/` -- Config 
Assistant can help simplify this!) In addition to copying static files to their 
`mt-static` home, plugin-specific template tags are created for the plugin's static 
file path and static web path location.

The sample config file below should give you a quick understanding of how you
can begin using this plugin today.

# Prerequisites

* Movable Type 4.1 or higher

# Installation

This plugin is installed [just like any other Movable Type Plugin](http://www.majordojo.com/2008/12/the-ultimate-guide-to-installing-movable-type-plugins.php).

# Reference and Documentation

## Using Config Assistant for Theme Options

This plugin adds support for a new element in any plugin's `config.yaml` file called
`options`, which is placed as a descendant to a defined template set. When a user of 
your plugin applies the corresponding template set then a "Theme Options" menu item
will automatically appear in their "Design" menu. They can click that menu item to 
be taken directly to a page on which they can edit all of their theme's settings.
The `static_version` root-level element will trigger Config Assistant to copy files 
to the `mt-static/support/plugins/[plugin key]/` folder, and the `skip\_static` 
root-level element will let you specify files _not_ to copy..

    id: MyPluginID
    name: My Plugin
    version: 1.0
    schema_version: 1
    static_version: 1
    template_sets:
        my_awesome_theme:
            options:
                fieldsets:
                    homepage:
                        label: 'Homepage Options'
                    feed:
                        label: 'Feed Options'
                feedburner_id:
                    type: text
                    label: "Feedburner ID"
                    hint: "This is the name of your Feedburner feed."
                    tag: 'MyPluginFeedburnerID'
                    fieldset: feed
                use_feedburner:
                    type: checkbox
                    label: "Use Feedburner?"
                    tag: 'IfFeedburner?'
                    fieldset: feed
                posts_for_frontfoor:
                    type: text
                    label: "Entries on Frontdoor"
                    hint: 'The number of entries to show on the front door.'
                    tag: 'FrontdoorEntryCount'
                    fieldset: homepage
                    condition: > 
                      sub { return 1; }
    skip_static:
        - index.html
        - readme.txt
        - .psd
        - .zip

## Using Config Assistant for Plugin Settings

To use Config Assistant as the rendering and enablement platform for plugin
settings, use the same `options` struct you would for theme options, but use
it as a root level element. The `static` element is also valid here. For example:

    id: MyPluginID
    name: My Plugin
    version: 1.0
    schema_version: 1
    static_version: 1
    options:
      fieldsets:
        homepage:
          label: 'Homepage Options'
        feed:
          label: 'Feed Options'
      feedburner_id:
        type: text
        label: "Feedburner ID"
        hint: "This is the name of your Feedburner feed."
        tag: 'MyPluginFeedburnerID'
        fieldset: feed
    skip_static:
        - index.html
        - readme.txt
        - .psd
        - .zip

Using this method for plugin options completely obviates the need for developers 
to specify the following elements in their plugin's config.yaml files:

* `settings`
* `blog_config_template`
* `system_config_template`

## Fields

Each field definition supports the following properties:

* `type` - the type of the field. Supported values are: text, textarea, select,
  checkbox, blogs
* `label` - the label to display to the left of the input element
* `show_label` - display the label? (default: yes). This is ideal for checkboxes.
* `hint` - the hint text to display below the input element
* `tag` - the template tag that will access the value held by the corresponding
  input element
* `condition` - a code reference that will determine if an option is rendered
  to the screen or not. The handler should return true to show the option, or false
  to hide it.
* `default` - a static value or a code reference which will determine the proper
   default value for the option
* `order` - the sort order for the field within its fieldset
* `republish` - a list of template identifiers (delimitted by a comma) that reference
  templates that should be rebuilt when a theme option changes
* `scope` - (for plugin settings only, all theme options are required to be
  blog specific) determines whether the config option will be rendered at the blog
  level or system level.

### Supported Field Types

Below is a list of acceptable values for the `type` parameter for any defined 
field:

* `text` - Produces a simple single line text box.

* `textarea` - Produces a multi-line text box. You can specify the `rows` sibling 
  element to control the size/height of the text box.

* `select` - Produces a pull-down menu or arbitrary values. Those values are
  defined by specifying a sibling element called `values` which should contain 
  a comma delimitted list of values to present in the pull down menu

* `checkbox` - Produces a single checkbox, ideal for boolean values.

* `blogs` - Produces a pull down menu listing every blog in the system.
  *Warning: this is not advisable for large installations as it can dramatically
  impact performance (negatively).*

* `radio-image` - Produces a javascript enabled list of radio buttons where 
  each "button" is an image. Note that this version of the radio type supports
  a special syntax for the `values` attribute. See example below.

* `tagged-entries` - Produces a pull down menu of entries tagged a certain way.
  This type supports the following additional attributes: `lastn` and `tag-filter`.

* `entry` - Produces the ability to select a single entry via a small pop-up 
  dialog. In the dialog, the user will be permitted to search the system via
  keyword for the entry they are looking for. This field type supports the 
  field property of `all_blogs`, a boolean value which determines whether the 
  user will be constricted to searching entries in the current blog, or all
  blogs on the system.

* `colorpicker` - Produces a color wheel pop-up for selecting a color or hex value.

* `file` - Allows a user to upload a file, which in turn gets converted into an
  asset. An additional field property is supported for file types: `destination`
  which can be used to customize the path/url of the uploaded file. See "Example
  File" below. Files uploaded are uploaded into a path relative to the
  mt-static/support directory.

**Example File**

The `file` type allows theme admins to upload files via their Theme Options screen.
The file, or files, uploaded get imported into the system's asset manager. The
path where the uploaded file will be stored can be customized via the `destination`
field option.

Allowable file format tokens:

* `%e` - Will generate a random string of characters. The default length of the 
  string is 8, but can be customized using the following syntax, `%{n}e` where "n"
  is an integer representing the length of the string.

Example:

   my_keyfile:
     type: file
     label: 'My Private Key'
     hint: 'A private key used for signing PayPal buttons.'
     tag: 'PrivatePayPalKey'
     destination: my_theme/%{10}e

**Example Radio Image**

The `radio-image` type supports a special syntax for the `values` attribute. 
The list of radio button is a comma-limitted list of image/value pairs (delimitted 
by a colon). Got that? The images you reference are all relative to Movable Type's
mt-static directory. Confused? I think a sample will make it perfectly clear:

      homepage_layout:
        type: radio-image
        label: 'Homepage Layout'
        hint: 'The layout for the homepage of your blog.'
        tag: 'HomepageLayout'
        values: >
          "plugins/Foo/layout-1.png":"Layout 1","plugins/Foo/layout-2.png":"Layout 2"

### Defining Custom Field Types

To define your own form field type, you first need to register your type and 
type handler in your plugin's `config.yaml` file, like so:

    config_types:
      my_custom_type:
        handler: $MyPlugin::MyPlugin::custom_type_hdlr

Then in `lib/MyPlugin.pm` you would implement your handler. Here is an example handler
that outputs the HTML for a HTML pulldown or select menu:

    sub custom_type_hdlr {
      my $app = shift;
      my ($field_id, $field, $value) = @_;
      my $out;
      my @values = split(",",$field->{values});
      $out .= "      <ul>\n";
      foreach (@values) {
          $out .= "<li><input type=\"radio\" name=\"$field_id\" value=\"$_\"".
	     ($value eq $_ ? " checked=\"checked\"" : "") ." class=\"rb\" />".$_."</li>\n";
      }
      $out .= "      </ul>\n";
      return $out;
    }

With these two tasks complete, you can now use your new config type in your template set:

    template_sets:
      my_theme:
        label: 'My Theme'
        options:
          layout:
            type: my_custom_type
            values: foo,bar,baz
            label: 'My Setting'
            default: 'bar'

## Defining Template Tags

Each plugin configuration field can define a template tag by which a designer
or developer can access its value. If a tag name terminates in a question mark
then the system will interpret the tag as a conditional block element. Here are 
two example fields:

    feedburner_id:
        type: text
        label: "Feedburner ID"
        hint: "This is the name of your Feedburner feed."
        tag: 'FeedburnerID'
    use_feedburner:
        type: checkbox
        label: "Use Feedburner?"
        tag: 'IfFeedburner?'

And here are corresponding template tags that make use of these configuration
options:

    <mt:IfFeedburner>
      My feedburner id is <$mt:FeedburnerID$>.
    <mt:Else>
      Feedburner is disabled!
    </mt:IfFeedburner>

## Deploying Static Content

### Preparing the Static Content

If you've installed many plugins, you know that you must often copy content 
to `[MT Home]/plugins/` and `[MT Home]/mt-static/plugins/`. For new users 
this can be a confusing task, and for experienced users it's one more 
annoying step that has to be done. But no more! Config Assistant can be used 
to help your plugin or theme copy static content to its permanent home in the 
`mt-static/` folder!

Within your plugin, use the `static\_version` root-level key to cause Config 
Assistant to work with your static content. This key should be an integer, and 
should be incremented when you've changed your static content and want it to 
be re-copied.

If you want to exclude some of your static content from the copy process, 
you can specify this with the `skip\_static` root-level key, as in the 
previous example.

    skip_static:
        - index.html
        - readme.txt
        - .psd
        - .zip

`skip\_static` builds an array of items to be excluded, which is signified 
with a leading dash and space. Files can be a partial match, so specifying an 
extension (such as `.psd`) will cause all files with `.psd` to _not_ be copied.
`skip\_static` is not a required key.

Lastly, you'll need to be sure to set the `schema\_version` key. You may 
already be using this for your plugin or theme. Incrementing the 
`schema_version` will trigger Movable Type and Melody to run an upgrade, 
which is when Config Assistant will deploy static content.

On the filesystem side, you will want to create your folder and file structure 
inside of a `static` folder in your plugin envelope. Any files inside of this 
static folder (except those items matching `skip\_static`) will be copied 
during installation.

### Installing the Static Content

When installing your new plugin or theme, the `schema_version` will trigger 
Movable Type or Melody to run an upgrade. During the upgrade, Config 
Assistant will copy static content to the `mt-static/support/plugins/` 
folder, and will create a folder for its contents. (For example, after 
installing Config Assistant, its static files can be found in 
`mt-static/support/plugins/ConfigAssistant/`.)

Note that the `mt-static/support/` folder must have adequate permissions to 
be writable by the web server; Movable Type and Melody will warn you if it 
does not. Also note that this path is different from where you often install 
static content, in `mt-static/plugins/`.

### Plugin-Specific Static Template Tags

Two template tags are created for your plugin or theme, to help you type less 
and keep code clean: `[Plugin ID]StaticFilePath` and 
`[Plugin ID]StaticWebPath`. For example, Config Assistant makes available 
`ConfigAssistantStaticFilePath` and `ConfigAssistantStaticWebPath`.

These tags will output the file path and the URL to a plugin's static content, 
based on the `StaticFilePath` and `StaticWebPath` configuration directives. 
These tags are really just shortcuts. You could use either of the following to 
publish a link to the image `photo.jpg` in your theme, for example:

    <mt:StaticWebPath>support/plugins/MyPlugin/images/photo.jpg
    <mt:MyPluginStaticWebPath>images/photo.jpg

both of which would output

    http://example.com/mt/mt-static/support/plugins/MyPlugin/images/photo.jpg

## Callbacks

Config Assistant supports a number of callbacks to give developers the ability
to respond to specific change events for options at a theme and plugin level.
All of these callbacks are in the `options_change` callback family.

### On Single Option Change

Config Assistant defines a callback which can be
triggered when a specific theme option changes value or when any theme option 
changes value. To register a callback for a specific theme option, you would use
the following syntax:

    callbacks:
      options_change.option.<option_id>: $MyPlugin::MyPlugin::handler

To register a callback to be triggered when *any* theme option changes, you would 
use this syntax:

    callbacks:
      options_change.option.*: $MyPlugin::MyPlugin::handler

When the callback is invoked, it will be invoked with the following input parameters:

* `$app` - A reference to the MT::App instance currently in-context.
* `$option_hash` - A reference to a hash containing the name/value pairs representing
  this modified theme option in the registry.
* `$old_value` - The value of the option prior to being modified.
* `$new_value` - The value of the option after being modified.

**Example**

    sub my_handler {
      my ($app, $option, $old, $new) = @_;
      MT->log({ message => "Changing " . $option->label . " from $old to $new." });
    }

**Note: The callback is invoked after the new value has been inserted into the config
hash, but prior to the hash being saved. This gives developers the opportunity to change
the value of the config value one last time before being committed to the database.**

### On Plugin Option Change

Config Assistat has the ability to trigger a callback when any option within a 
plugin changes. To register a callback of this nature you would use the following
syntax:

    callbacks:
      options_change.plugin.<plugin_id>: $MyPlugin::MyPlugin::handler

When the callback is invoked, it will be invoked with the following input parameters:

* `$app` - A reference to the MT::App instance currently in-context.
* `$plugin` - A reference to the plugin object that was changed

# Sample config.yaml

    id: MyPluginID
    name: My Plugin
    version: 1.0
    schema_version: 1
    static_version: 1
    blog_config_template: '<mt:PluginConfigForm id="MyPluginID">'
    plugin_config:
        MyPluginID:
            fieldset_1:
                label: "This is a label for my fieldset"
                description: "This is some text to display below my fieldset label"
                feedburner_id:
                    type: text
                    label: "Feedburner ID"
                    hint: "This is the name of your Feedburner feed."
                    tag: 'MyPluginFeedburnerID'
    skip_static:
        - index.html
        - readme.txt
        - .psd
        - .zip

# Support

http://forums.movabletype.org/codesixapartcom/project-support/

# Info

This plugin is not necessary in Melody, as this is core component of that platform.

Configuration Assistant Plugin for Movable Type and Melody
Author: Byrne Reese   
Copyright 2008 Six Apart, Ltd.   
Copyright 2009 Byrne Reese   
License: Artistic, licensed under the same terms as Perl itself   

