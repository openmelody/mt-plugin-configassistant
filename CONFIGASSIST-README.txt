# Configuration Assistant
# Author: Byrne Reese
# Copyright 2008 Six Apart, Ltd.
# License: Artistic, licensed under the same terms as Perl itself

OVERVIEW

This plugin is prototype for how to allow theme and plugin developers to easily 
surface a form within Movable Type for configuring their theme/plugin and the
corresponding template tags that can be used within a template WITHOUT HAVING
TO USE PERL AT ALL!

This plugin works by allowing a developer to use their plugin's configuration
file as a means for defining what the various settings and form elements they
would like to expose to a user.

See the SAMPLE CONFIG YAML below for an idea of how this works.

PREREQUISITES

- Movable Type 4.1 or higher

INSTALLATION

  1. Unpack the ConfigAssistant archive.
  2. Copy the contents of ConfigAssistant/plugins into /path/to/mt/plugins/

REFERENCE

The data structure for input form elements is relatively straight forward.
This plugin adds support for a new registry key called "plugin_config".

The plugin_config element has a child element which corresponds the plugin's
id. It is this element under which all the various fields are defined under
"fieldsets". 

Each plugin can have multiple fieldsets, or grouping of input parameters.
Each fieldset should have a unique key or identifier.

Under each fieldset is a sequence of fields.

Each field supports the following properties:

  * type - the type of the field. Supported values are: text, textarea, select,
           checkbox
  * label - the label to display to the left of the input element
  * hint - the hint text to display below the input element
  * tag - the template tag that will access the value held by the corresponding
          input element
  * values - valid only for fields of type "select" - this contains a comma 
             delimitted list of values to present in the pull down menu
  * rows - valid only for fields of type "textarea" - this corresponds to the
           number of rows of text displayed for the text area input element

In order to surface the form under your plugin's settings area, you will need
to define a blog configuration template like so:

    blog_config_template: '<mt:PluginConfigForm id="MyPluginID">'

TEMPLATE TAGS

Each plugin configuration field can define a template tag by which a designer
or developer can access its value. If a tag name terminates in a question mark
then the system will interpret the tag as a block element. Here are two example
configs:

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
      My feedburner id is <mt:FeedburnerID>.
    <mt:Else>
      Feedburner is disabled!
    </mt:IfFeedburner>

SAMPLE CONFIG YAML

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

SUPPORT

http://forums.movabletype.org/codesixapartcom/project-support/

