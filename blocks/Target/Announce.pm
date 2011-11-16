## @file
# This file contains the implementation of the Announcement System target.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    15 Nov 2011
# @copy    2011, Chris Page &lt;chris@starforge.co.uk&gt;
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
package Target::Announce;

## @class Target::Announce
# An Announcement System target implementation. Supported arguments are:
#
# - category=&lt;cat&gt;
#
# 'cat' may be either a category name or a category id. If the name is given
# it is internally converted to an ID. In either event, the category must
# be present in the mp_announce_categories table. Category may be specified
# multiple times, in which case the message is marked as being in all specified
# categories.
#
# This class requires the following database tables:
#
# @verbatim
# CREATE TABLE `mp_announce_categories` (
#   `id` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
#   `category` varchar(80) NOT NULL,
#   PRIMARY KEY (`id`)
# ) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Records available announcement categories.' AUTO_INCREMENT=5 ;
#
# INSERT INTO `mp_announce_categories` (`id`, `category`) VALUES
# (1, 'UGT'),
# (2, 'PGT'),
# (3, 'PGR'),
# (4, 'Staff');
#
# CREATE TABLE `mp_messages_announcecats` (
#   `message_id` int(10) unsigned NOT NULL COMMENT 'The message id this is a category for',
#   `cat_id` smallint(5) unsigned NOT NULL COMMENT 'The category id',
#   KEY `message_id` (`message_id`,`cat_id`)
# ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Attaches one or more categories to a message to allow for ea';
#
# CREATE TABLE `mp_messages_announcedata` (
#   `message_id` int(10) unsigned NOT NULL COMMENT 'ID of the message this forms annoucement data for',
#   `open_date` int(10) unsigned DEFAULT NULL COMMENT 'Unix timestamp of the annoucement going visible. NULL means immediately.',
#   `close_date` int(10) unsigned DEFAULT NULL COMMENT 'Unix timestamp of the message being hidden. NULL means it must be manually hidden.',
#   `link` varchar(255) DEFAULT NULL COMMENT 'Optional URL to associate with the annoucement.',
#   KEY `message_id` (`message_id`)
# ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Annoucement-specific data for a message.';
# @endverbatim

use strict;
use base qw(Target); # This class is a Target module
use Logging qw(die_log);
use Utils qw(is_defined_numeric);

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# An overridden constructor, required to correctly parse out settings for the
# message sender.
#
# @param args A hash of arguments to initialise the object with
# @return A blessed reference to the object
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_);

    # If there are any arguments to convert, split and store
    $self -> set_config($self -> {"args"}) if($self && $self -> {"args"});

    return $self;
}


# ============================================================================
#  General interface functions

## @method void set_config($args)
# Set the current configuration to the module to the values in the provided
# args string.
#
# @param args A string containing the new configuration.
sub set_config {
    my $self = shift;
    my $args = shift;

    $self -> {"args"} = $args;

    my @args = split(/;/, $self -> {"args"});

    $self -> {"args"} = [];
    foreach my $arg (@args) {
        my @argbits = split(/,/, $arg);

        my $arghash = {};
        foreach my $argbit (@argbits) {
            my ($name, $value) = $argbit =~ /^(\w+)=(.*)$/;
            $arghash -> {$name} = $value;
        }

        push(@{$self -> {"args"}}, $arghash);
    }
}


## @method $ generate_message($args, $user)
# Generate the string to insert into the message.tem target hook region for
# this target.
#
# @param args A reference to a hash of arguments to use in the form
# @param user A reference to a hash containing the user's data
# @return A string containing the message form fragment.
sub generate_message {
    my $self = shift;
    my $args = shift;
    my $user = shift;

    return $self -> {"template"} -> load_template("target/announce/message.tem", {"***open_date***"     => $args -> {"announce"} -> {"open_date"} || "",
                                                                                  "***close_date***"    => $args -> {"announce"} -> {"close_date"} || "",
                                                                                  "***open_ignore***"   => (defined($args -> {"announce"} -> {"open_date"}) ? "" : 'checked="checked"'),
                                                                                  "***close_ignore***"  => (defined($args -> {"announce"} -> {"close_date"}) ? "" : 'checked="checked"'),
                                                                                  "***announce_link***" => (defined($args -> {"announce"} -> {"announce_link"}) ? $args -> {"announce"} -> {"announce_link"} : "http://"),
                                                                                 });
}


## @method $ generate_message_edit($args)
# Generate the string to insert into the message_edit.tem target hook region for
# this target.
#
# @param args A reference to a hash of arguments to use in the form
# @return A string containing the message edit form fragment.
sub generate_message_edit {
    my $self = shift;
    my $args = shift;

    return $self -> generate_message($args);
}


## @method $ generate_message_confirm($args, $outfields)
# Generate the string to insert into the message_confirm.tem target hook region
# for this target.
#
# @param args      A reference to a hash of arguments to use in the form
# @param outfields A reference to a hash of output values.
# @return A string containing the message confirm form fragment.
sub generate_message_confirm {
    my $self      = shift;
    my $args      = shift;
    my $outfields = shift;

    # Start off assuming that the open and close date controls are disabled.
    $outfields -> {"open_date"}  = $self -> {"template"} -> replace_langvar("MESSAGE_ANN_OPENIGN");
    $outfields -> {"close_date"} = $self -> {"template"} -> replace_langvar("MESSAGE_ANN_CLOSEIGN");

    # Now replace them with real values if needed
    $outfields -> {"open_date"} = $self -> {"template"} -> format_time($args -> {"announce"} -> {"open_date"})
        if($args -> {"announce"} -> {"open_date"});

    $outfields -> {"close_date"} = $self -> {"template"} -> format_time($args -> {"announce"} -> {"close_date"})
        if($args -> {"announce"} -> {"close_date"});

    return $self -> {"template"} -> load_template("target/announce/message_confirm.tem", {"***open_date***"     => $outfields -> {"open_date"},
                                                                                          "***close_date***"    => $outfields -> {"close_date"},
                                                                                          "***announce_link***" => $args -> {"announce"} -> {"announce_link"},
                                                                                 });
}


## @method $ generate_message_abort($args, $outfields)
# Generate the string to insert into the message_abort.tem target hook region
# for this target.
#
# @param args      A reference to a hash of arguments to use in the form
# @param outfields A reference to a hash of output values.
# @return A string containing the message abort form fragment.
sub generate_message_abort {
    my $self      = shift;
    my $args      = shift;
    my $outfields = shift;

    return $self -> generate_message_confirm($args, $outfields);
}


## @method $ generate_message_view($args, $outfields)
# Generate the string to insert into the message_view.tem target hook region
# for this target.
#
# @param args      A reference to a hash of arguments to use in the form
# @param outfields A reference to a hash of output values.
# @return A string containing the message view form fragment.
sub generate_message_view {
    my $self      = shift;
    my $args      = shift;
    my $outfields = shift;

    return $self -> generate_message_confirm($args, $outfields);
}


## @method void store_message($args, $user, $mess_id, $prev_id)
# Store the data for this target. This will store any target-specific
# data in the args hash in the appropriate tables in the database.
#
# @param args    A reference to a hash containing the message data.
# @param user    A reference to a hash containing the user's data.
# @param mess_id The ID of the message being stored.
# @param prev_id If set, this is the ID of the message that the current
#                mess_id is an edit of.
sub store_message {
    my $self    = shift;
    my $args    = shift;
    my $user    = shift;
    my $mess_id = shift;
    my $prev_id = shift;

    # Does nothing
}


## @method void get_message($msgid, $message)
# Populate the specified message hash with data specific to this target.
# This will pull any data appropriate for the current target out of
# the database and shove it into the message hash.
#
# @param msgid   The ID of the message to fetch the data for.
# @param message A reference to the hash into which the data should be written.
sub get_message {
    my $self    = shift;
    my $msgid   = shift;
    my $message = shift;

    # Does nothing.
}


## @method $ validate_message($args)
# Validate this target's settings in the posted data, and store them in
# the provided args hash.
#
# @param args A reference to a hash into which the Target's data should be stored.
# @return A string containing any error messages encountered during validation.
sub validate_message {
    my $self = shift;
    my $args = shift;
    my ($error, $errors) = ("", "");

    my $errtem = $self -> {"template"} -> load_template("blocks/error_entry.tem");

    # Check whether the open date has been set
    foreach my $mode ("open", "close") {
        if(defined($self -> {"cgi"} -> param($mode."_ignore"))) {
            $args -> {"announce"} -> {$mode."_date"} = undef; # set it explicitly to avoid ambiguity
        } else {
            $args -> {"announce"} -> {$mode."_date"} = is_defined_numeric($self -> {"cgi"}, $mode."_date");

            # If we have no value for the date, complain - it must be explicitly disabled if no value is needed
            $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_NO".uc($mode))})
                if(!$args -> {"announce"} -> {$mode."_date"});
        }
    }

    # If we have start and end dates, check that end is later than start
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADDATES")})
        if($args -> {"announce"} -> {"open_date"} && $args -> {"announce"} -> {"close_date"} &&
           ($args -> {"announce"} -> {"open_date"} >= $args -> {"announce"} -> {"close_date"}));

    # Link handling...
    ($args -> {"announce"} -> {"announce_link"}, $error) = $self -> validate_string("announce_link", {"required" => 0,
                                                                                                      "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_ANN_LINK"),
                                                                                                      "minlen"   => 7,
                                                                                                      "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # Check the link appears valid if specified. The regexp is a hideous, shambling abomination. I recommend averting your eyes.
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADLINK")})
        if($args -> {"announce"} -> {"announce_link"} &&
           $args -> {"announce"} -> {"announce_link"} !~ m{^https?://[-\w]+(?:\.[-\w]+)+(?:/(?:[-\w]+/)*[-.\w]*(?:\?(?:[-\w~!\$+|.,*:;]|%[a-f\d]{2,4})+=(?:[-\w~!\$+|.,*:]|%[a-f\d]{2,4})*(?:&(?:[-\w~!\$+|.,*:;]|%[a-f\d]{2,4})+=(?:[-\w~!\$+|.,*:]|%[a-f\d]{2,4})*)*)?(?:\#(?:[-\w~!\$+|&.,*:;=]|%[a-f\d]{2,4})*)?)?$}io);

    return $errors;
}


# Note that this class is unusual in that it never actually 'sends' its messages; they
# simply get recorded in the database and marked as "sent, visible" so that the php
# script may pick up the message when called from the main website code.
1;
