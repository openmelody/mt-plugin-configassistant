The Config Assistant plugin does many things:

* It allows theme and plugin developers to easily surface a form within 
  Movable Type for configuring their theme/plugin.
* It allows theme and plugin developers to define template tags by which they
  can access the values entered in by their users directly within their
  templates.
* It helps users install a theme or plugin by copying static files into the
  `mt-static` folder, simplifying installation.

All this **without having to know perl or how to program at all**!

This plugin works by allowing a developer to use their plugin's configuration
file as a means for defining what the various settings and form elements they
would like to expose to a user.

Config Assistant will also automatically add a "Theme Options" menu item to the 
user's Design menu so they can easily access the settings you define.

Config Assistant can also work with "static" content to make deploying your plugin 
or theme easier. (If you've installed many plugins, you know that you must often 
copy content to `[MT Home]/plugins/` and `[MT Home]/mt-static/plugins/` -- Config 
Assistant can help simplify this!) In addition to copying static files to their 
`mt-static` home, plugin-specific template tags are created for the plugin's static 
file path and static web path location.

The sample config file below should give you a quick understanding of how you
can begin using this plugin today.

# Prerequisites

* Movable Type 4.1 or higher (Include 5.0)

# Installation

This plugin is installed [just like any other Movable Type Plugin](http://www.majordojo.com/2008/12/the-ultimate-guide-to-installing-movable-type-plugins.php).

One important note is that this plugin should be installed into Movable Type's 
`addons` directory. Installing this plugin into any other directory will 
potentially cripple your installation. So please be careful. 

Also be aware that if you are upgrading from a previous version, you should 
remove any copy of Config Assistant from your plugins directory if one is 
installed there.

# Reference and Documentation

## Using Config Assistant for Theme Options

This plugin adds support for a new element in any plugin's `config.yaml` file called
`options`, which is placed as a descendant to a defined template set. When a user of 
your plugin applies the corresponding template set then a "Theme Options" menu item
will automatically appear in their "Design" menu. They can click that menu item to 
be taken directly to a page on which they can edit all of their theme's settings.

The `static_version` root-level element will trigger Config Assistant to copy files 
to the `mt-static/support/plugins/[plugin key]/` folder, and the `skip\_static` 
root-level element will let you specify files _not_ to copy.

    id: MyPluginID
    name: My Plugin
    version: 1.0
    static_version: 1
    template_sets:
        my_awesome_theme:
            base_path: 'templates'
            label: 'My Awesome Theme'
            options:
                fieldsets:
                    homepage:
                        label: 'Homepage Options'
                        hint: 'These options only affect the home page.'
                        order: 1
                    feed:
                        label: 'Feed Options'
                        order: 2
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
                    required: 1
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

## Fieldsets

Fields can be grouped by fieldset, and fieldsets are "tabbed" on the Theme Options screen. This provides an easy way to organize all of your fields and present them to the user in a clear fashion.

    options:
        fieldsets:
            homepage:
                label: 'Homepage Options'
                hint: 'These options only affect the home page.'
                order: 1
            feed:
                label: 'Feed Options'
                order: 2

In this example two fieldsets have been defined: `homepage` and `feed`, and this will generate two tabs of options on the Theme Options screen. Note that the fieldset keys (in this case `homepage` and `feed`) must be unique within your theme or plugin.

### Fieldset Properties

* `label` - is the description displayed on the tab, and is also displayed at the top of the page.
* `hint` - is a space for you to provide more detail about the contents of this fieldset. It is displayed just above all of the fields in this fieldset
* `order` - Use integers to sort the order of your fieldsets on the tabbed interface.

## Fields

Fields are easily defined with properties.

    options:
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

In this example two options, or fields, have been defined: `feedburner_id` and `use_feedburner`. Note that the option keys (in this case `feedburner_id` and `use_feedburner`) must be unique within your theme or plugin.

### Field Properties

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
* `fieldset` - specify which fieldset a field belongs to.
* `order` - the sort order for the field within its fieldset
* `republish` - a list of template identifiers (delimited by a comma) that reference
  templates that should be rebuilt when a theme option changes
* `scope` - (for plugin settings only, all theme options are required to be
  blog specific) determines whether the config option will be rendered at the blog
  level or system level.
* `required` - can be set to `1` to indicate a field as required, necessitating a
  value.

### Supported Field Types

Below is a list of acceptable values for the `type` parameter for any defined 
field:

* `text` - Produces a simple single line text box.

* `textarea` - Produces a multi-line text box. You can specify the `rows` sibling 
  element to control the size/height of the text box.

* `select` - Produces a pull-down menu of arbitrary values. Those values are
  defined by specifying a sibling element called `values` which should contain 
  a comma delimited list of values to present in the pull down menu.

* `radio` - Produces a set of radio buttons of arbitrary values. Those values
  are defined by specifying a sibling element called `values` which should 
  contain a comma delimited list of values to present as radio buttons.

* `checkbox` - Produces a single checkbox, ideal for boolean values, or a set
  of checkboxes. When using this type to display multiple checkboxes, use the
  `values` field option to provide a list of checkbox labels/values. Use the
  `delimiter` field option to specify how your list of checkbox options are
  separated. See "Working with Checkboxes."

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

* `page` - Operates identically to the `entry` type except that it pulls up a list
  of pages in the selected blog (as opposed to entries).

* `category` - Produces the ability to select a single category via a drop-down 
  listing.

* `folder` - Produces the ability to select a single folder via a drop-down 
  listing.

* `colorpicker` - Produces a color wheel pop-up for selecting a color or hex value.

* `link-group` - Produces an ordered list of links manually entered by the user.
  Options of this type will have defined for them an additional template tag
  to make it easier to loop over the links entered by the user in your templates.
  See "Link Group Template Tags" below.

* `file` - Allows a user to upload a file, which in turn gets converted into an
  asset. An additional field property is supported for file types: `destination`
  which can be used to customize the path/url of the uploaded file. See "Example
  File" below. Files uploaded are uploaded into a path relative to the
  mt-static/support directory. Also, for each option of type file that defined,
  an additional template tag is created for you which gives you access to the 
  asset created for you when the file is uploaded. See "Asset Template Tags" 
  below.

* `separator` - Sometimes you will want to divide your options into smaller
  sections, and the `separator` facilitates that. This is a special type of
  field because there is no editable form to interact with and is
  informational only. Only the `label`, `hint`, `order`, and `fieldset` keys 
  are valid with this field type.

**Link Group Tags**

For each option of type `link-group` that is defined, two template tags are defined.
The first is the one specified by the user using the `tag` parameter associated
with the option in the `config.yaml`. This template tag will be useless to most users
as it will return a JSON encoded data structure containing all the links entered by
the user.

The second template tag is the useful one. It is called `<TAGNAME>Links`. This template 
tag is a container or block tag that loops over each of the links entered by the user.
Inside each iteration of the loop the following template variables are defined for you:

* `__first__` True only if the current link is the first one in the list.
* `__last__` - True only if the current link is the last one in the list.
* `link_label` - The label associated with the current link.
* `link_url` - The URL associated with the current link.

For example, look at this `config.yaml`:

    my_links:
        type: link-group
        label: 'My Favorite Links'
        tag: 'MyFavorites'

This will create two template tags:

1. `<$mt:MyFavorites$>`
2. `<mt:MyFavoritesLinks></mt:MyFavoritesLinks>`

You can use them like so:

    <p>My favorite links are: 
      <mt:MyFavoritesLinks>
        <mt:if name="__first__"><ul></mt:if>
        <li><a href="<$mt:var name="link_url"$>"><$mt:var name="link_label"$></a></li>
        <mt:if name="__last__"></ul></mt:if>
      <mt:Else>
        I have no favorite links.
      </mt:MyFavoritesLinks>
    </p>

**Asset Template Tags**

For each option of type `file` that is defined, two template tags are defined.
The first is the one specified by the user using the `tag` parameter associated
with the option in the `config.yaml`. This template tag will return the Asset ID
of the asset created for you.

The second template tag is `<TAGNAME>Asset`. This template tag is a container or
block tag that adds the uploaded asset to the current context allowing you to
use all of the asset related template tags in conjunction with the uploaded file.
For example, look at this `config.yaml`:

    my_keyfile:
        type: file
        label: 'My Private Key'
        hint: 'A private key used for signing PayPal buttons.'
        tag: 'PrivatePayPalKey'
        destination: my_theme/%{10}e

This will create two template tags:

1. `<$mt:PrivatePayPalKey$>`
2. `<mt:PrivatePayPalKeyAsset></mt:PrivatePayPalKeyAsset>`

You can use them like so:

    <p>The asset ID of my key file is: <$mt:PrivatePayPalKey$></p>
    <p>The URL to my key file is: 
      <mt:PrivatePayPalKeyAsset>
        <$mt:AssetURL$>
      </mt:PrivatePayPalKeyAsset>
    </p>

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
The list of radio button is a comma-delimited list of image/value pairs (delimited 
by a colon). Got that? The images you reference are all relative to Movable Type's
mt-static directory. Confused? I think a sample will make it perfectly clear:

    homepage_layout:
        type: radio-image
        label: 'Homepage Layout'
        hint: 'The layout for the homepage of your blog.'
        tag: 'HomepageLayout'
        values: >
          "plugins/Foo/layout-1.png":"Layout 1","plugins/Foo/layout-2.png":"Layout 2"

**Working with Checkboxes**

The option type of `checkbox` has two modes:

* a boolean mode (a single checkbox either on or off)
* a multi-select mode (multiple choices and options)

A single checkbox is ideal when needing to collect boolean values from users. For 
example, here is a theme option to enable/disable advertising on a web site:

    enable_ads:
      type: checkbox
      label: 'Enable Advertising?'
      hint: 'Check this box if you want advertising to be displayed on your web site'
      tag: 'IfAdsEnabled?'

Your template tag should then be:

    <mt:IfAdsEnabled>
       <!-- insert ad javascript -->
    </mt:IfAdsEnabled>

Sometimes however you need to use checkboxes to allow the user to select multiple
options that all relate to one another. Here is an example of how to use this field
to allow users to specify which areas of a site should have ads enabled:

    enable_ads:
      type: checkbox
      label: 'Enable Advertising?'
      hint: 'Check this box if you want advertising to be displayed on your web site'
      tag: 'AdsEnabled'
      delimiter: ';'
      values: 'Homepage;System: Profile, Reg, Auth;Entries;Pages'

You can then check to see if the theme option contains a specific value like so:

    <mt:AdsEnabledContains value="System: Profile, Reg, Auth">
       <!-- insert ad javascript -->
    <mt:else>
       <!-- do nothing? -->
    </mt:AdsEnabledContains>

Or you can loop over all the selected values that have been checked:

    <ul>
    <mt:AdsEnabledLoop>
      <li>You checked <$mt:var name="value"$>.</li>
    </mt:AdsEnabledLoop>
    </ul>


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

Within your plugin, use the `static_version` root-level key to cause Config 
Assistant to work with your static content. This key should be an integer, and 
should be incremented when you've changed your static content and want it to 
be re-copied.

If you want to exclude some of your static content from the copy process, 
you can specify this with the `skip_static` root-level key, as in the 
examples.

    skip_static:
        - index.html
        - readme.txt
        - .psd
        - .zip

`skip_static` builds an array of items to be excluded, which is signified 
with a leading dash and space. Files can be a partial match, so specifying an 
extension (such as `.psd`) will cause all files with `.psd` to _not_ be copied.
`skip_static` is not a required key.

On the filesystem side, you will want to create your folder and file structure 
inside of a `static` folder in your plugin envelope. Any files inside of this 
static folder (except those items matching `skip_static`) will be copied 
during installation.

### Installing the Static Content

When installing your new plugin or theme, the `static_version` will trigger 
Movable Type or Melody to run an upgrade. During the upgrade, Config 
Assistant will copy static content to the `mt-static/support/plugins/` 
folder, and will create a folder for its contents. (For example, after 
installing Config Assistant, its static files can be found in 
`mt-static/support/plugins/configassistant/`.)

Note that the `mt-static/support/` folder must have adequate permissions to 
be writable by the web server; Movable Type and Melody will warn you if it 
does not. Also note that this path is different from where you often install 
static content, in `mt-static/plugins/`.

Developers may have reason to reinstall the static content; this can be done 
by running `./tools/static-copy`.

### Plugin-Specific Static Template Tags

Two template tags are created for your plugin or theme, to help you type less 
and keep code clean: `PluginStaticFilePath` and 
`PluginStaticWebPath`. Use them with the `component` argument and supply your 
plugin's ID to link to your static content. For example, Config Assistant can 
use `<mt:PluginStaticFilePath component="configassistant">` and 
`<mt:ConfigAssistantStaticWebPath component="configassistant">`.

These tags will output the file path and the URL to a plugin's static content, 
based on the `StaticFilePath` and `StaticWebPath` configuration directives. 
These tags are really just shortcuts. You could use either of the following to 
publish a link to the image `photo.jpg` in your theme, for example:

    <mt:StaticWebPath>support/plugins/MyPlugin/images/photo.jpg
    <mt:PluginStaticWebPath component="MyPlugin">images/photo.jpg

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
                hint: "This is some text to display below my fieldset label"
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

http://help.endevver.com/

# Info

This plugin is not necessary in Melody, as this is core component of that platform.

Configuration Assistant Plugin for Movable Type and Melody
Author: Byrne Reese   
Copyright 2008 Six Apart, Ltd.   
Copyright 2009-2010 Byrne Reese   
License: Artistic, licensed under the same terms as Perl itself   

