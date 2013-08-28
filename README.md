# Config Assistant plugin for Movable Type #

_**Upgrade Note:** If you are upgrading from a version prior to 2.1.6, please
make sure to read the upgrade instructions below._

## Table of Contents ##

<!-- ****** PLEASE KEEP THIS UPDATED AND FUNCTIONAL!!!!!!!! ***** -->

* <a href="#overview">Overview</a>
    * <a href="#prerequisites">Prerequisites</a>
    * <a href="#features">Features</a>
* <a href="#installation">Installation</a>
    * <a href="#upgrading_config_assistant">Upgrading Config Assistant</a>
* <a href="#usage">Usage</a>
    * <a href="#permissions">Permissions</a>
    * <a href="#defining_theme_options">Defining Theme Options</a>
    * <a href="#defining_plugin_configuration_settings">Defining Plugin
      Configuration Settings</a>
    * <a href="#fieldsets">Fieldsets</a>
        * <a href="#fieldset_properties">Fieldset Properties</a>
    * <a href="#fields">Fields</a>
        * <a href="#field_properties">Field Properties</a>
        * <a href="#supported_field_types">Supported Field Types</a>
        * <a href="#defining_custom_field_types">Defining Custom Field Types</a>
    * <a href="#defining_template_tags">Defining Template Tags</a>
    * <a href="#deploying_static_content">Deploying Static Content</a>
        * <a href="#preparing_the_static_content">Preparing the Static Content</a>
        * <a href="#config_yaml_keys_static_version_and_skip_static">Config.yaml
          keys: `static_version` and `skip_static`</a>
        * <a href="#automated_static_file_deployment">Automated Static File
          Deployment</a>
        * <a href="#manual_static_file_deployment">Manual Static File
          Deployment</a>
        * <a href="#accessing_static_content">Accessing Static Content</a>
    * <a
      href="#automatically_set_blog_preferences_and_plugin_settings">Automatically
      set Blog Preferences and Plugin Settings</a>
        * <a href="#administrators">Administrators</a>
        * <a href="#developers_and_designers">Developers and Designers</a>
        * <a href="#supported_preferences">Supported Preferences</a>
* <a href="#plugindata">Accessing Stored Data Programmatically</a>
* <a href="#callbacks">Callbacks</a>
    * <a href="#on_single_option_change">On Single Option Change</a>
    * <a href="#on_plugin_option_change">On Plugin Option Change</a>
* <a href="#sample_config_yaml">Sample config.yaml</a>
* <a href="#help_bugs_and_feature_requests">Help, Bugs and Feature Requests</a>
    * <a href="#support">Support</a>
    * <a href="#author">Author</a>

## <a id="overview">Overview</a> ##

The Config Assistant plugin is a powerful platform plugin which significantly
reduces the work necessary to *create and deploy* Melody/Movable Type plugins
and themes.

The plugin streamlines the plugin/theme development process by extending the
grammar of each plugin's YAML-based configuration file (`config.yaml`) to
allow for new and powerful features which previously required a significant
amount of Perl and/or template markup code.

It also makes plugin and theme deployment as easy as dropping a single folder
into the addons or plugins directory eliminating the extra steps previously
foisted upon end users to deploy a plugin/theme's static content.

### <a id="prerequisites">Prerequisites</a> ###

* Movable Type 4.1 or higher
* Movable Type 5.x or higher

### <a id="features">Features</a> ###

Config Assistant provides a number of new features to developers, designers
and admins

* It significantly reduces the work involved in creating user-facing config
  settings forms for themes and plugins and creating template tags to access
  those values from the templates.

* Reduces the number of steps needed for theme/plugin installation and upgrade
  by automatically copying static files into the proper place in the
  `mt-static` folder

* It provides a way for plugin/theme designers to specify desired values for
  related blog preferences and plugin settings and for users to automatically
  apply them. (Previously handled by the AutoPrefs plugin.)

* Automatically adds a "Theme Options" menu item to the Design menu so users
  can easily access theme settings.

All this **without having to know Perl or how to program at all**!

The sample config file below should give you a quick understanding of how you
can begin using this plugin today.

----

## <a id="installation">Installation</a> ##

The latest version of the plugin can be downloaded from the its [Github
repo][] which is now part of the Open Melody user account. [Packaged
downloads][] are also available if you prefer.

Installation follows the [standard plugin installation][] procedures
***EXCEPT*** that the `ConfigAssistant.plugin` directory must be installed
into the **`addons`** directory and **not the `plugins`** directory. If you do
not have an addons directory, you can simply create one in the root of your MT
directory (`$MT_HOME/addons`).

If for whatever reason you *do* install this plugin into your `plugins` folder
as is common with other plugins, Movable Type may produce inexplicable errors.
So please be careful and mindful to follow the above instructions.

### <a id="upgrading_config_assistant">Upgrading Config Assistant</a> ###

If you are upgrading from a previous version of Config Assistant, you should
remove any copy of Config Assistant from your plugins directory if one is
installed there.

    prompt> rm -rf $MT_HOME/plugins/ConfigAssistant

If you are upgrading from a version prior to 2.1.6, then you will also need
to remove the following directory:

    prompt> rm -rf $MT_HOME/addons/ConfigAssistant.plugin

Starting with version 2.0, the AutoPrefs plugin has been merged into Config
Assistant. If you already have the AutoPrefs plugin installed, it will be
disabled by Config Assistant at which point you can remove AutoPrefs from your
`plugins` directory.

----

## <a id="usage">Usage</a> ##

### <a id="permissions">Permissions</a> ###

The ability for a user of Movable Type or Melody to access and modify plugin
and theme options requires them to posses either:

* System administrator priveleges
* The System-level "Manage Plugins" permission
* The "Edit Templates" permission at the blog level

### <a id="defining_theme_options">Defining Theme Options</a> ###

This plugin adds support for a new key in any plugin's `config.yaml` file
called `options`, which is placed as a descendant to a defined template set.
When a user of your plugin applies the corresponding template set then a
"Theme Options" menu item will automatically appear in their "Design" menu.
They can click that menu item to be taken directly to a page on which they can
edit all of their theme's settings.

**Example config:**

    name: My Plugin
    version: 1.5
    id: myplugin
    key: MyPlugin
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



### <a id="defining_plugin_configuration_settings">Defining Plugin Configuration Settings</a> ###

In addition to theme options, you can also define your plugin's configuration
options using the same `options` struct as before but as a root level element.
For example:

    name: My Plugin
    version: 1.0
    id: myplugin
    key: MyPlugin
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

Using this method for plugin options completely obviates the need for
the following `config.yaml` keys:

* `settings`
* `blog_config_template`
* `system_config_template`

### <a id="fieldsets">Fieldsets</a> ###

Fields can be grouped by fieldset, and fieldsets are "tabbed" on the Theme
Options screen. This provides an easy way to organize all of your fields and
present them to the user in a clear fashion.

    options:
        fieldsets:
            homepage:
                label: 'Homepage Options'
                hint: 'These options only affect the home page.'
                order: 1
            feed:
                label: 'Feed Options'
                order: 2

In this example two fieldsets have been defined: `homepage` and `feed`, and
this will generate two tabs of options on the Theme Options screen. Note that
the fieldset keys (in this case `homepage` and `feed`) must be unique within
your theme or plugin.

#### <a id="fieldset_properties">Fieldset Properties</a> ####

* `label` - is the description displayed on the tab, and is also displayed at
  the top of the page.

* `hint` - is a space for you to provide more detail about the contents of
  this fieldset. It is displayed just above all of the fields in this fieldset

* `order` - Use integers to sort the order of your fieldsets on the tabbed
  interface.

### <a id="fields">Fields</a> ###

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

In this example two options, or fields, have been defined: `feedburner_id` and
`use_feedburner`. Note that the option keys (in this case `feedburner_id` and
`use_feedburner`) must be unique within your theme or plugin.

#### <a id="field_properties">Field Properties</a> ####

* `type` - the type of the field. Supported values are: text, textarea,
  select, checkbox, blogs

* `label` - the label to display to the left of the input element

* `show_label` - display the label? (default: yes). This is ideal for
  checkboxes.

* `hint` - the hint text to display below the input element

* `tag` - the template tag that will access the value held by the
  corresponding input element

* `condition` - a code reference that will determine if an option is rendered
  to the screen or not. The handler should return true to show the option, or
  false to hide it.

* `default` - a static value for the option.

* `fieldset` - specify which fieldset a field belongs to.

* `order` - the sort order for the field within its fieldset

* `republish` - a list of template identifiers (delimited by a comma) that
  reference templates that should be rebuilt when a theme option changes.
  Index or archive template types can be specified; specifying other types
  (system, modules, widgets) doesn't work because those don't actually publish
  anything.

  * If the specified template identifier is for an index template, the
    template is simply force republished.
  * If the specified template identifier is for an Entry or Page archive
    template, the most recent Entry or Page is republished. If using cached
    and included modules/widgets then this is enough to refresh them.
  * If the specified template identifier is for another type of archive
    (Category, Yearly, Author, etc) then that template is republished in its
    entirety. Use this with caution: republishing a type of archive can be
    time-consuming. This is best used when there are a known limited number of
    archives (for example, if only four categories will ever exist in your
    blog), and when the Publish Queue is employed for that template type.

* `scope` - (for plugin settings only, all theme options are required to be
  blog specific) determines whether the config option will be rendered at the
  blog level or system level.

* `required` - can be set to `1` to indicate a field as required,
  necessitating a value.

#### <a id="supported_field_types">Supported Field Types</a> ####

Below is a list of acceptable values for the `type` parameter for any defined 
field:

* `asset` - Select an asset from a popup dialog. An additional template tag is
  created for you which gives you access to the asset created for you when the
  file is uploaded. See "Asset Template Tags" below.

  * `filter_class`: filter an asset listing popup by specifying the asset
    class. Popular values are `image`, `audio`, `video`, and `file`, though any
    registered asset type is valid.

* `author` - Select an author from a popup dialog. To appear in the popup, an
  author must have a Role, associating them with the blog in which this field
  is used. This field supports two additional optional keys:

  * `roles` - where a comma-separated list of valid Roles may be supplied to
    filter the popup dialog contents.
  * `all_authors` - if flagged `1` then all authors in the system with post
    permissions or a role (as specified in the above `roles` key) can be
    supplied to filter the popup dialog contents.

* `blogs` - Produces a pull down menu listing every blog in the system.
  *Warning: this is not advisable for large installations as it can
  dramatically impact performance (negatively).*

* `category` - Produces the ability to select a single category via a
  drop-down listing. This field supports additional optional keys:

  * `multiple` - set to `1` to create a multi-select listing, allowing multiple
    categories to be selected.
  * `show_children` - set to `1` to include child categories, in addition to
    parent.

* `checkbox` - Produces a single checkbox, ideal for boolean values, or a set
  of checkboxes. When using this type to display multiple checkboxes, use the
  `values` field option to provide a list of checkbox labels/values. Use the
  `delimiter` field option to specify how your list of checkbox options are
  separated. See "Working with Checkboxes."

* `colorpicker` - Produces a color wheel pop-up for selecting a color or hex
  value.

* `datetime` - Produces a date and time selection dialog for selecting a
  timestamp.

* `entry` - Produces the ability to select a single entry or many entries via
  a small pop-up dialog. In the dialog, the user will be permitted to search
  the system via keyword for the entry they are looking for. This field type
  supports additional properties:

  * `all_blogs` - a boolean value which determines whether the user will be
    constricted to searching/selecting entries in the current blog, or all
    blogs on the system.
  * `multiple` - a boolean value which allows multiple entries to be selected.
  * `inactive_area` - a boolean value which adds a separate area to store
    selected entry or entries but not publish them -- useful when you need to
    temporarily remove an item from the home page, for example.

  When the keys `multiple` or `inactive_area` are true, selected entries can
  be sorted by drag and drop, making it easy to order content.

* `entry_or_page` - Operates identically to the `entry` config type except 
  that it allows the ability to select either an Entry or Page (or any 
  combination of Entries and Pages). The same `all_blogs`, `multiple`, and
  `inactive_area` keys are also supported.

* `file` - Allows a user to upload a file, which in turn gets converted into
  an asset. An additional field property is supported for file types:
  `destination` which can be used to customize the path/url of the uploaded
  file. See "Example File" below. Files uploaded are uploaded into a path
  relative to the mt-static/support directory. Also, for each option of type
  file that defined, an additional template tag is created for you which gives
  you access to the asset created for you when the file is uploaded. See
  "Asset Template Tags" below.

* `folder` - Produces the ability to select a single folder via a drop-down
  listing. This field supports additional optional keys:

   * `multiple` - set to `1` to create a multi-select listing, allowing multiple
     folders to be selected.
   * `show_children` - set to `1` to include child folders, in addition to
     parent.

* `link-group` - Produces an ordered list of links manually entered by the
  user. Options of this type will have defined for them an additional template
  tag to make it easier to loop over the links entered by the user in your
  templates. See "Link Group Template Tags" below.

* `page` - Operates identically to the `entry` type except that it allows the
  ability to select Pages instead of Entries. The same `all_blogs`,
  `multiple`, and `inactive_area` keys are also supported.

* `radio` - Produces a set of radio buttons of arbitrary values. Those values
  are defined by specifying a sibling element called `values` which should
  contain a comma delimited list of values to present as radio buttons.
  Optionally use the `delimiter` key to specify a value separator: `,` (comma)
  is the default; `;` (semicolon) is a good alternative if the field values
  contain a comma, for example.

* `radio-image` - Produces a javascript enabled list of radio buttons where
  each "button" is an image. Note that this version of the radio type supports
  a special syntax for the `values` attribute. See example below.

* `select` - Produces a pull-down menu of arbitrary values. Those values are
  defined by specifying a sibling element called `values` which should contain
  a comma delimited list of values to present in the pull down menu.
  Optionally use the `delimiter` key to specify a value separator: `,` (comma)
  is the default; `;` (semicolon) is a good alternative if the field values
  contain a comma, for example.

* `separator` - Sometimes you will want to divide your options into smaller
  sections, and the `separator` facilitates that. This is a special type of
  field because there is no editable form to interact with and is
  informational only. Only the `label`, `hint`, `order`, and `fieldset` keys
  are valid with this field type.

* `tagged-entry` - Produces a pull down menu of entries tagged a certain
  way. This type supports the following additional attributes: `lastn` and
  `tag-filter`.

* `text` - Produces a simple single line text box.

* `textarea` - Produces a multi-line text box. You can specify the `rows`
  sibling element to control the size/height of the text box.

* `text-group` - Produces an ordered list of text labels manually entered by
  the user. Options of this type will have defined for them an additional
  template tag to make it easier to loop over the text items entered by the
  user in your templates. See "Text Group Template Tags" below.

** Entry, Page, and Entry Or Page Tags **

These three field types basically work the same, so the YAML used in your
theme will look similar, too. Consider this example:

    my_favorite_entries:
        label: 'My Favorite Entries'
        type: entry
        multiple: 1
        inactive_area: 1
        tag: Faves

This will build a field that allows for the selection of favorite Entries.
With the `multiple` key set many entries can be selected, and drag and drop to
sort the order of the selected entries will be available. With the
`inactive_area` key set Entries can be dragged to the inactive area,
preventing them from being published in the My Favorite Entries section, but
keeping them ready for easy re-use. (Note that moving Entries to the inactive
area does not unpublish them, it simply doesn't publish them where the `Faves`
tag is used.)

To publish My Favorite Entries a special block tag is available. Append
`Entries` to the tag defined to access all of the Entry context tags. Example:

    <mt:FavesEntries>
        <p><a href="<mt:EntryPermalink>"><mt:EntryTitle></a></p>
    </mt:FavesEntries>

The same capabilities exist for the Entry, Page, and Entry or Page field
types, and the capabilities function the same way for each. Regardless of
using the Entry, Page, or Entry or Page field type, `Entries` is appended to
access the entry/page context.

**Category and Folder Tags**

Assuming this option:

    header_categories:
        label: HeaderCategories
        type: category_list
        show_children: 0
        tag: HeaderCategories

There are two ways this can be accessed. The raw string (comma-separated) of
category IDs can be returned with a function tag (`<$mt:HeaderCategories$>`).
Appending Categories or Folders to the end of the tag name turns it into a
block tag that supports all of the Category (or Folder) tags. For example:

    <mt:HeaderCategoriesCategories>
        <mt:If name="__first__">
            <ul>
        </mt:If>
                <li>
                    <a href="<$mt:CategoryArchiveLink$>"><$mt:ArchiveLabel$></a>
                </li>
        <mt:If name="__last__">
            </ul>
        </mt:If>
    </mt:HeaderCategories>

That will generate an unordered listed of categories suitable for a top-level
navigation menu.

The following template variables are set:

* `__first__` True only if the current category is the first.
* `__last__`  True only if the current category is the last.
* `__odd__`   True only if the current iteration of the category loop is odd.
* `__even__`  True only if the current iteration of the category loop is even.
* `__index__` Returns the current index of the category loop.
* `__size__`  Returns the number of categories.

This loop also supports the "glue" attribute. The value of this attribute, if
set, will be put at the end of every iteration of the loop until the very last
iteration. It functions identically to the "glue" attribute provided by core
template tags.

**Date/Time Fields**

Assuming this option:

    event_end_date:
        label: Event End Date
        type: datetime
        tag: MyThemeEndDate

This tag can be accessed like any other Melody date tag:

    <mt:MyThemeEndDate/> <!--July 7, 2011 11:33 PM-->

    <mt:MyThemeEndDate format="%Y-%m-%d@%H:%M:%S %p"/> <!--2011-07-07@23:33:29 PM -->

**Link Group Tags**

For each option of type `link-group` that is defined, two template tags are
defined. The first is the one specified by the user using the `tag` parameter
associated with the option in the `config.yaml`. This template tag will be
useless to most users as it will return a JSON encoded data structure
containing all the links entered by the user.

The second template tag is the useful one. It is called `<TAGNAME>Links`. This
template tag is a container or block tag that loops over each of the links
entered by the user. Inside each iteration of the loop the following template
variables are defined for you:

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
        <li>
            <a href="<$mt:var name="link_url"$>">
                <$mt:var name="link_label"$>
            </a>
        </li>
        <mt:if name="__last__"></ul></mt:if>
      <mt:Else>
        I have no favorite links.
      </mt:MyFavoritesLinks>
    </p>

**Text Group Tags**

For each option of type `text-group` that is defined, two template tags are
defined. The first is the one specified by the user using the `tag` parameter
associated with the option in the `config.yaml`. This template tag will be
useless to most users as it will return a JSON encoded data structure
containing all the links entered by the user.

The second template tag is the useful one. It is called `<TAGNAME>Items`. This
template tag is a container or block tag that loops over each of the links
entered by the user. Inside each iteration of the loop the following template
variables are defined for you:

* `__first__` True only if the current link is the first one in the list.
* `__last__` - True only if the current link is the last one in the list.
* `label` - The label associated with the current item.

For example, look at this `config.yaml`:

    my_links:
        type: text-group
        label: 'My List'
        tag: 'MyList'

This will create two template tags:

1. `<$mt:MyList$>`
2. `<mt:MyListItems></mt:MyListItems>`

You can use them like so:

    <p>My favorite things are: 
      <mt:MyListItems>
        <mt:if name="__first__"><ul></mt:if>
        <li>
            <$mt:var name="label"$>
        </li>
        <mt:if name="__last__"></ul></mt:if>
      <mt:Else>
        I have no favorite things.
      </mt:MyListItems>
    </p>

**Asset Template Tags**

For each option of type `asset` and `file` that is defined, two template tags
are defined. The first is the one specified by the user using the `tag`
parameter associated with the option in the `config.yaml`. This template tag
will return the Asset ID of the asset created for you.

The second template tag is `<TAGNAME>Asset`. This template tag is a container
or block tag that adds the uploaded asset to the current context allowing you
to use all of the asset related template tags in conjunction with the uploaded
file. For example, look at this `config.yaml`:

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

The `file` type allows theme admins to upload files via their Theme Options
screen. The file, or files, uploaded get imported into the system's asset
manager. The path where the uploaded file will be stored can be customized via
the `destination` field option.

Allowable file format tokens:

* `%e` - Will generate a random string of characters. The default length of
  the string is 8, but can be customized using the following syntax, `%{n}e`
  where "n" is an integer representing the length of the string.

Example:

    my_keyfile:
        type: file
        label: 'My Private Key'
        hint: 'A private key used for signing PayPal buttons.'
        tag: 'PrivatePayPalKey'
        destination: my_theme/%{10}e

If you specify the `scope` Field Property as in the example below, the file
path will be written to the local blog, not the Theme's support directory.
This can be helpful to separate files on a blog-by-blog basis.

Example:

    my_keyfile:
        type: file
        label: 'My Private Key'
        hint: 'A private key used for signing PayPal buttons.'
        tag: 'PrivatePayPalKey'
        scope: blog
        destination: my_theme/%{10}e

**Example Radio Image**

The `radio-image` type supports a special syntax for the `values` attribute
which allows you to associate an image with each choice:

    values: "IMGRELPATH":"LABEL", "IMGRELPATH2":"LABEL2"

In the above, each `IMGRELPATH` represents the path to an image relative to
Movable Type's mt-static directory and each `LABEL` is the accompanying label
for the option. The path and label are separated by a colon and each combined
value is separated by a comma.

For example, `radio-images` defining a homepage layout for a plugin `Foo`
might look like this:

    homepage_layout:
        type: radio-image
        label: 'Homepage Layout'
        hint: 'The layout for the homepage of your blog.'
        tag: 'HomepageLayout'
        values: "plugins/Foo/layout-1.png":"Layout 1","plugins/Foo/layout-2.png":"Layout 2"

The above will present the user with two radio buttons labelled Layout 1 and
Layout 2 accompanied by a representative image demonstrating each option.

_FIXME: Insert screenshot_

**Working with Checkboxes**

The option type of `checkbox` has two modes:

* a boolean mode (a single checkbox either on or off)
* a multi-select mode (multiple choices and options)

A single checkbox is ideal when needing to collect boolean values from users.
For example, here is a theme option to enable/disable advertising on a web
site:

    enable_ads:
      type: checkbox
      label: 'Enable Advertising?'
      hint: 'Check this box to display advertising on your web site'
      tag: 'IfAdsEnabled?'

Your template tag should then be:

    <mt:IfAdsEnabled>
       <!-- insert ad javascript -->
    </mt:IfAdsEnabled>

Sometimes however you need to use checkboxes to allow the user to select
multiple options that all relate to one another. Here is an example of how to
use this field to allow users to specify which areas of a site should have ads
enabled:

    enable_ads:
      type: checkbox
      label: 'Enable Advertising?'
      hint: 'Check this box if you want advertising to be displayed on your web site'
      tag: 'AdsEnabled'
      delimiter: ';'
      values: 'Homepage;System: Profile, Reg, Auth;Entries;Pages'

You can then check to see if the theme option contains a specific value like
so:

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

#### <a id="defining_custom_field_types">Defining Custom Field Types</a> ####

To define your own form field type, you first need to register your type and
type handler in your plugin's `config.yaml` file, like so:

    config_types:
      my_custom_type:
        handler: $MyPlugin::MyPlugin::custom_type_hdlr

Then in `plugins/MyPlugin/lib/MyPlugin.pm` you would implement your handler.
Here is an example handler that outputs the HTML for a HTML pulldown or select
menu:

    sub custom_type_hdlr {
      my $app = shift;
      my ($field_id, $field, $value) = @_;
      my @values = split( ",", $field->{values} );
      my $class  = 'class="rb"';
      my $type   = 'type="radio"';
      my @options;
      foreach my $opt (@values) {
          my $checked = $opt eq $value ? " checked=\"checked\"" : "";
          push( @options, qq(
            <input $type name="$field_id" value="$opt" $checked $class /> $opt
          ));
      }
      return '<ul><li>', join("</li>\n<li>", @options), '</li></ul>';
    }

With these two tasks complete, you can now use your new config type in your
template set:

    template_sets:
      my_theme:
        label: 'My Theme'
        options:
          layout:
            type: my_custom_type
            values: foo,bar,baz
            label: 'My Setting'
            default: 'bar'

### <a id="defining_template_tags">Defining Template Tags</a> ###

Each plugin configuration field can define a template tag by which a designer
or developer can access its value. If a tag name terminates in a question mark
then the system will interpret the tag as a conditional block element. Here
are two example fields:

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

### <a id="deploying_static_content">Deploying Static Content</a> ###

If you've installed many plugins, you know that you must often move static
content to a separate folder under `[MT Home]/mt-static/plugins/`. This often
confuses new users and is an annoyance to experienced users. Hence, we added a
feature to Config Assistant to eliminate the hassle.

#### <a id="preparing_the_static_content">Preparing the Static Content</a> ####

To enable this feature in your plugin, put all of your static content into a
folder named `static` inside of your plugin envelope. As you can see below,
you can assemble your static content in whatever folder hierarchy you wish.

    MyPrettyPlugin/
        config.yaml
        lib/
            MyPrettyPlugin/
                Plugin.pm
        static/
            [[static files go here]]
            css/
                main.css
                ie.css
            js/
                myplugin.js
            [...SNIP...]

#### <a id="config_yaml_keys_static_version_and_skip_static">Config.yaml keys: `static_version` and `skip_static`</a> ####

_**NOTE:** We are seriously considering dropping support for this feature. If
you use `skip_static` and wish for us to continue supporting it, please drop
us a line_

Then, within your plugin's `config.yaml`, assign an integer to the root-level
`static_version` key:

    name: My Plugin
    version: 1.0
    id: myplugin
    key: MyPlugin
    static_version: 1
    [...SNIP...]

Any time an update includes a change to files or folder underneath the
`static` directory, you should increment the `static_version` value to trigger
automated deployment for your users.

If you want to exclude some of your static content from the copy process, you
can specify this with the `skip_static` root-level key, as in the examples.

    name: My Plugin
    version: 1.0
    id: myplugin
    key: MyPlugin
    static_version: 1
    skip_static:
        - index.html
        - readme.txt
        - .psd
        - .zip

The specified items are matched against the content in your static directory
so specifying an extension (such as `.psd`) will cause all files with `.psd`
to _not_ be copied.

#### <a id="automated_static_file_deployment">Automated Static File Deployment</a> ####

When a user first installs a plugin or theme using the `static_version` key or
installs an upgrade with a higher `static_version` value, Config Assistant
will recognize it and trigger MT/Melody's upgrade process during which it
deploys the contents of the `static` folder into a folder under
`mt-static/support`.

Of course, this relies on proper permissions being set on the
`mt-static/support/` folder, but both Melody and Movable Type use this folder
as well and issue warnings if it is not writeable by the webserver. (Note:
This is the reason Config Assistant switched to using this path instead of the
more traditional `mt-static/plugins/*`)

#### <a id="manual_static_file_deployment">Manual Static File Deployment</a> ####

During the course of development or general use, developers and admins may
force a resynchronization of the static files by running the static copy
utility, `addons/ConfigAssistant.pack/tools/static-copy`. If you wish, you can
symlink or even copy it to your `MT_HOME/tools` for easier access.

Future versions of Config Assistant will likely contain enhanced features
which auto-detect changes to static content making this completely
unnecessary.

#### <a id="accessing_static_content">Accessing Static Content</a> ####

You'll note that in the sections above, we omitted details about the *exact*
location of the deployed static content but simply said it's somewhere
underneath `mt-static/support`. This was completely intentional as Config
Assistant provides you with a better way to access the static content in
templates and plugin code.

In templates, you can use either of the two following tags:

* `mt:PluginStaticWebPath` - Analog to `mt:StaticWebPath`, this generates a
  URL pointing to the folder containing static content for a plugin specified
  by the `component` attribute. Example:   
   
        <img src="<$mt:PluginStaticWebPath component="myplugin"$>images/photo.jpg">

* `mt:PluginStaticFilePath` - Analog to `mt:StaticFilePath`, this generates an
  absolute file path to the same which is useful for server-side includes or
  other server-based access. (**IMPORTANT**: For security reasons, it's best
  not to surface details about a user's filesystem to the site's visitors.
  Please use this wisely.**). Example:   
  
        <?php 
          include('<$mt:PluginStaticFilePath
                        component="myplugin"
                              cat="php/css.php"$>');
        ?>  

From your plugin's Perl code, you can access the above locations using static
methods in `ConfigAssistant::Util` which expect an MT::Plugin or MT::Component
object instance as an argument:

    use ConfigAssistant::Util
        qw( plugin_static_web_path plugin_static_file_path);

    my $static_url  = plugin_static_web_path( $plugin );
    my $static_path = plugin_static_file_path( $plugin );
    
### <a id="automatically_set_blog_preferences_and_plugin_settings">Automatically set Blog Preferences and Plugin Settings</a> ###

If you are familiar with the old AutoPrefs plugin, you know how this feature
works: AutoPrefs was merged with Config Assistang and provides the same
features.

#### <a id="administrators">Administrators</a> ####

For the most part, admins never interact with this plugin directly. All an
admin needs to do is re-apply their theme or reset their templates, and if the
theme they apply supports this plugin and this plugin is installed, then the
blog's preferences will automagically be setup. If a new blog is created with
a theme that includes preferences and setting, the blog's preferences will
automagically be setup.

Alternatively, visit Preferences > Chooser in a blog to assign a set of
preferences and settings to that blog.

#### <a id="developers_and_designers">Developers and Designers</a> ####

Developers and designers can use this plugin to automatically apply a set of
blog preferences to a blog when a user resets their blog templates. The format
for specifying these preferences is as following:

First, within your `config.yaml`, you need to define a preferences group. Each
preferences group has a unique identifier (corresponding to the group's
registry key). Then provide some additional descriptive meta data about the
preferences group and finally provide a list of all the preferences you want
to set. For example:

    name: 'My Plugin'
    version: 1.0

    blog_preferences:
        my_config:
            label: "My Awesome Theme Preferred Config"
            description: "This is a packaging of my preferred theme settings."
            order: 100
            preferences:
                file_extension: php
                allow_comments_html: 0

Setting many preferences can grow your `config.yaml` quickly and make it hard
to read. The `preferences` key can also reference another yaml file which
holds all of your preferences:

    blog_preferences:
        my_config:
            label: "My Awesome Theme Preferred Config"
            description: "This is a packaging of my preferred theme settings."
            order: 100
            preferences: my_awesome_theme_prefs.yaml

In the example above, the preference group ID is `my_config`. Once the
preferences group has been defined, then it can be referenced by a template
set as follows:

    template_sets:
        my_awesome_theme:
            blog_preferences: my_config
            templates:
                index:
                    main_index:
                        label: 'Main Index'

You can also use this plugin to inject data into an `MT::PluginData` record.
This allows for themes to auto-configure plugins as well.

    blog_preferences:
        my_config:
            label: "Byrne's Preferred Config"
            description: "This is a packaging on my preferred settings for a blog."
            order: 100
            plugin_data:
                FacebookCommenters:
                    facebook_app_secret: xxxxxx
                    facebook_app_key: xxxxxx
            preferences:
                file_extension: php
                allow_comments_html: 0

*Note: This will only configure blog level plugin settings. System level
settings for plugins must be configured manually. This seems like a reasonable
restriction to keep plugins from obliterating configs inadvertently.*

#### <a id="supported_preferences">Supported Preferences</a> ####

Below is a list of all the supported preferences and their default value.
There is no need to specify a default preference in your `config.yaml` unless
you intend to override the default.

* `allow_anon_comments` (default: 0) - Allow anonymous comments on the blog.
* `allow_comment_html` (default: 1) - Allow HTML to be used within comments.
* `allow_commenter_regist` (default: 1) - Allow visitors to register for new
  accounts from the sign in screen.
* `allow_comments_default` (default: 1) - Turn on comments by default for new
  entries.
* `allow_pings` (default: 1) - Global toggle for TrackBacks.
* `allow_pings_default` (default: 1) - Turn on TrackBacks by default for new
  entries.
* `allow_reg_comments` (default: 1) - Global toggle for comments.
* `allow_unreg_comments` (default: 0) - 
* `archive_type` (default: '') - 
* `archive_type_preferred` (default: '') - 
* `autodiscover_links` (default: 0) - 
* `autolink_urls` (default: 1) - 
* `basename_limit` (default: 100) - 
* `captcha_provider` (default: *null*) - 
* `cc_license` (default: *null*) - 
* `commenter_authenticators` (default: ) - Determines which authentication
  options are enabled by default. The value of this property should be a comma
  delimited list of acceptable values. Acceptable values are:
  * MovableType
  * OpenID
  * LiveJournal
  * Vox
  * Google
  * Yahoo
  * AIM 
  * WordPress - requires WordPress Auth plugin
  * Twitter - requires Twitter Commenters plugin
  * Facebook - requires Facebook Connect plugin
* `convert_paras` (default: *default text format*) - 
* `convert_paras_comments` (default: 1) - 
* `custom_dynamic_templates` (default: 'none') - 
* `days_on_index` (default: 0) - 
* `email_new_comments` (default: 1) - 
* `email_new_pings` (default: 1) - 
* `entries_on_index` (default: 10) - 
* `file_extension` (default: 'html') - 
* `follow_auth_links` (default: 1) - 
* `image_default_align` (default: *null*) - 
* `image_default_constrain` (default: *null*) - 
* `image_default_thumb` (default: *null*) - 
* `image_default_width` (default: *null*) - 
* `image_default_popup` (default: *null*) - 
* `image_default_wrap_text` (default: *null*) - 
* `image_default_wunits` (default: *null*) - 
* `include_cache` (default: 0) - Turns on/off template module caching for the
  blog.
* `include_system` (default: 0) - Determines what SSI include system to use.
  Acceptable values are:
  * php
  * jsp
  * asp
  * shtml
* `internal_autodiscovery` (default: 0) - 
* `is_dynamic` (default: 0) - 
* `junk_folder_expiry` (default: 14) - In days.
* `junk_score_threshold` (default: 0) - 
* `language` (default: *derived from config file, or from server*) - 
* `manual_approve_commenters` (default: 0) - 
* `moderate_pings` (default: 1) - 
* `moderate_unreg_comments` (default: 2) - Controls the commenting and
  moderation policy for the blog. Acceptable values range from 0 to 3. They
  are:
  * 0 - Immediately approve comments from anyone
  * 1 - Immediately approve comments from none
  * 2 - Immediately approve comments from trusted commenters only
  * 3 - Immediately approve comments from any authenticated commenter
* `nofollow_urls` (default: 1) - 
* `nwc_smart_replace` (default: ) - 
* `nwc_replace_field` (default: ) - 
* `ping_blogs` (default: 0) - 
* `ping_google` (default: 0) - 
* `ping_others` (default: 0) - 
* `ping_technorati` (default: 0) - 
* `ping_weblogs` (default: 0) - 
* `remote_auth_token` (default: ) - 
* `require_comment_emails` (default: 0) - 
* `require_typekey_emails` (default: 0) - 
* `sanitize_spec` (default: 0) - 
* `server_offset` (default: *determined from config file or server*) - 
* `sort_order_comments` (default: 'ascend') - 
* `sort_order_posts` (default: 'descend') - 
* `status_default` (default: 2)
    *  1 = unpublished
    *  2 = published
    *  3 = review
    *  4 = scheduled
    *  5 = junk
* `update_pings` (default: *null*) - 
* `use_comment_confirmation` (default: 1) - 
* `welcome_msg` (default: 0) - 
* `words_in_excerpt` (default: 40) - 

## <a id="plugindata">Accessing Stored Data Programmatically</a> ##

Plugin developers may wish to use Config Assistant to make it easy for users
to specific config options for their plugin. These options are traditionally
set under the Plugin Preferences area of Melody or the Tools > Plugins area in
Movable Type. For options defined in this way, developers may then need to
access the stored option value using Perl inside of their plugin. Let's look
at how to do this using the MT::PluginData class.

First let's look at a config.yaml. It is important to note that one can define
an `options` registry key outside the context of a template set. When you do
this, you are creating theme agnostic options. The following is an excerpt
from the Photo Gallery plugin for Movable Type:

    options:
      suppress_create_entry:
        type: 'checkbox'
        label: 'Suppress Create Entry button and menu items for this blog?'
        tag: 'IfSuppressCreateEntry?'
        scope: blog
        default: 1
      suppress_manage_assets:
        type: 'checkbox'
        label: 'Suppress Manage Assets menu items for this blog?'
        tag: 'IfSuppressManageAssets?'
        scope: blog
        default: 1

Then inside of the plugin's application logic, these values are accessed in
this way:

     my $plugin = MT->component("PhotoGallery");
     my $suppress = $plugin->get_config_value( 'suppress_create_entry',
              'blog:' . $app->blog->id );

System level (global) options are accessed this way:

     my $plugin = MT->component("PhotoGallery");
     my $suppress = $plugin->get_config_value( 'suppress_create_entry' );

## <a id="callbacks">Callbacks</a> ##

Config Assistant supports a number of callbacks to give developers the ability
to respond to specific change events for options at a theme and plugin level.
All of these callbacks are in the `options_change` callback family.

### <a id="on_single_option_change">On Single Option Change</a> ###

Config Assistant defines a callback which can be triggered when a specific
theme option changes value or when any theme option changes value. To register
a callback for a specific theme option, you would use the following syntax:

    callbacks:
      options_change.option.<option_id>: $MyPlugin::MyPlugin::handler

To register a callback to be triggered when *any* theme option changes, you
would use this syntax:

    callbacks:
        options_change.option.*: $MyPlugin::MyPlugin::handler

When the callback is invoked, it will be invoked with the following input
parameters:

* `$cb` - The MT::Callback object for the current callback.
* `$app` - An object instance for the currently running app, most likely, but
  not necessarily, an MT::App subclass.
* `$option_hash` - A reference to a hash containing the name/value pairs
  representing this modified theme option in the registry.
* `$old_value` - The value of the option prior to being modified.
* `$new_value` - The value of the option after being modified.

**Example**

    sub my_handler {
        my ($cb, $app, $option_hash, $old_value, $new_value) = @_;
        $app->log({
            message => "Changing "
                     . $option_hash->{label}
                     . " from $old_value to $new_value."
        });
        # ...SNIP...
    }

_**Note:** The callback is invoked after the new value has been inserted into
the config hash, but prior to the hash being saved. This gives developers the
opportunity to change the value of the config value one last time before being
committed to the database.**_

### <a id="on_plugin_option_change">On Plugin Option Change</a> ###

Config Assistant has the ability to trigger a callback when any option within
a plugin changes. To register a callback of this nature you would use the
following syntax, replacing `<plugin_id>` with your plugin's `id` attribute
value and `<handler>` with a typical handler reference:

    callbacks:
        options_change.plugin.<plugin_id>: <handler>

For example:

    callbacks:
        options_change.plugin.MyPlugin: $MyPlugin::MyPlugin::handler

When the callback is invoked, it will be invoked with the following input
parameters:

* `$cb` - The MT::Callback object for the current callback.
* `$app` - An object instance for the currently running app, most likely, but
  not necessarily, an MT::App subclass.
* `$plugin` - A reference to the plugin object that was changed

_FIXME: Does `$plugin` refer to an `MT::Plugin` or `MT::PluginSettings`
object? The former is unnecessary as you can get the same thing from
`$cb->plugin`. It seems like we should be passing the full options hashref as
well as a "changed values" hashref._

----

## <a id="sample_config_yaml">Sample config.yaml</a> ##

    name: My Plugin
    version: 1.0
    id: myplugin
    key: MyPlugin
    schema_version: 1
    static_version: 1

    skip_static:
        - index.html
        - readme.txt
        - .psd
        - .zip

    blog_config_template: '<mt:PluginConfigForm id="myplugin">'

    plugin_config:
        MyPluginID:
            fieldset_1:
                label: "This is a label for my fieldset"
                hint: "This is displayed below the fieldset label"
                feedburner_id:
                    type: text
                    label: "Feedburner ID"
                    hint: "This is the name of your Feedburner feed."
                    tag: 'MyPluginFeedburnerID'

----

## <a id="help_bugs_and_feature_requests">Help, Bugs and Feature Requests</a> ##

If you are having problems installing or using the plugin, please check out
our general knowledge base and help ticket system at [help.endevver.com][].

### <a id="support">Support</a> ###

If you know that you've encountered a bug in the plugin or you have a request
for a feature you'd like to see, you can file a ticket in the [Config
Assistant project][Lighthouse] in our issue tracking system and we'll get to
it as soon as possible.

### <a id="author">Author</a> ###

This plugin was originally created by [Byrne Reese][] of [Endevver, LLC][]. It
was later gifted to the [Open Melody Software Group][] for bundling with
Melody and further development by the Melody Community.

[help.endevver.com]:            http://help.endevver.com
[Byrne Reese]:                  http://majordojo.com
[Endevver, LLC]:                http://endevver.com
[Open Melody Software Group]:   http://openmelody.org
[Github repo]:
   http://github.com/openmelody/mt-plugin-configassistant
[Packaged downloads]:
   http://github.com/openmelody/mt-plugin-configassistant/downloads
[Standard plugin installation]:
   http://tinyurl.com/easy-plugin-install
[Lighthouse]:
   http://openmelody.lighthouseapp.com/projects/68651/overview

Copyright 2008 Six Apart, Ltd.   
Copyright 2009-2010 Byrne Reese   
License: Artistic, licensed under the same terms as Perl itself   
