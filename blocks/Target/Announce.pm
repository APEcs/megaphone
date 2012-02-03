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
# An Announcement System target implementation. This class implements a Target
# that allows messages to be displayed on the SoCS website in various annoucement
# boxes tailored to specific groups of users (UGT, PGT, PGR, Staff, etc).
# Supported destination arguments are:
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
# CREATE TABLE IF NOT EXISTS `mp_messages_announcedata` (
#  `message_id` int(10) unsigned NOT NULL COMMENT 'ID of the message this forms annoucement data for',
#  `open_date` int(10) unsigned DEFAULT NULL COMMENT 'Unix timestamp of the annoucement going visible. NULL means immediately.',
#  `close_date` int(10) unsigned DEFAULT NULL COMMENT 'Unix timestamp of the message being hidden. NULL means it must be manually hidden.',
#  `show_close` tinyint(1) unsigned NOT NULL COMMENT 'Should the close date be shown?',
#  `announce_link` varchar(255) DEFAULT NULL COMMENT 'Optional URL to associate with the annoucement.',
#  `show_link` tinyint(1) unsigned NOT NULL COMMENT 'Should the link be shown, or replaced with "link"?',
#  KEY `message_id` (`message_id`)
#) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Annoucement-specific data for a message.';

use strict;
use base qw(Target); # This class is a Target module
use Logging qw(die_log);
use Utils qw(is_defined_numeric);
use POSIX qw(floor);

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

    $self -> {"linkopts"}  = { "0" => $self -> {"template"} -> replace_langvar("MESSAGE_ANN_SHOWLINK0"),
                               "1" => $self -> {"template"} -> replace_langvar("MESSAGE_ANN_SHOWLINK1"),
    };
    $self -> {"closeopts"} = { "0" => $self -> {"template"} -> replace_langvar("MESSAGE_ANN_SHOWCLSE0"),
                               "1" => $self -> {"template"} -> replace_langvar("MESSAGE_ANN_SHOWCLSE1"),
    };

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

    my @argbits = split(/;/, $args);

    $self -> {"args"} = {};
    foreach my $arg (@argbits) {
        my ($name, $value) = $arg =~ /^(\w+)=(.*)$/;
        # Concatenate arguments with the same name
        if($self -> {"args"} -> {$name}) {
            $self -> {"args"} -> {$name} .= ",$value";
        } else {
            $self -> {"args"} -> {$name} = $value;
        }
    }
}


## @method $ generate_link_option($selected)
# Generate the dropdown through which the user may select whether to show the
# link or to replace it with "link".
#
# @param selected The selected option (0 = show full, 1 = show 'link')
# @return A string containing the link options.
sub generate_link_option {
    my $self     = shift;
    my $selected = shift;
    my $options  = "";

    foreach my $id (sort(keys(%{$self -> {"linkopts"}}))) {
        $options .= '<option value="'.$id.'"';
        $options .= ' selected="selected"' if($id == $selected);
        $options .= '>'.$self -> {"linkopts"} -> {$id}."</option>\n";
    }

    return $options;
}


## @method $ generate_close_option($selected)
# Generate the dropdown through which the user may select whether to show the
# close date or not;
#
# @param selected The selected option (0 = hide, 1 = show)
# @return A string containing the show options.
sub generate_close_option {
    my $self     = shift;
    my $selected = shift;
    my $options  = "";

    foreach my $id (sort(keys(%{$self -> {"closeopts"}}))) {
        $options .= '<option value="'.$id.'"';
        $options .= ' selected="selected"' if($id == $selected);
        $options .= '>'.$self -> {"closeopts"} -> {$id}."</option>\n";
    }

    return $options;
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
    my ($format_open, $format_close);

    $format_open = $self -> {"template"} -> format_time($args -> {"announce"} -> {"open_date"}, "%d/%m/%Y %H:%M")
        if($args -> {"announce"} -> {"open_date"});

    $format_close = $self -> {"template"} -> format_time($args -> {"announce"} -> {"close_date"}, "%d/%m/%Y %H:%M")
        if($args -> {"announce"} -> {"close_date"});

    return $self -> {"template"} -> load_template("target/announce/message.tem", {"***open_date***"      => $args -> {"announce"} -> {"open_date"} || "",
                                                                                  "***close_date***"     => $args -> {"announce"} -> {"close_date"} || "",
                                                                                  "***open_date_fmt***"  => $format_open,
                                                                                  "***close_date_fmt***" => $format_close,
                                                                                  "***open_ignore***"    => (defined($args -> {"announce"} -> {"open_date"}) ? "" : 'checked="checked"'),
                                                                                  "***close_ignore***"   => (defined($args -> {"announce"} -> {"close_date"}) ? "" : 'checked="checked"'),
                                                                                  "***show_close***"     => $self -> generate_close_option($args -> {"announce"} -> {"show_close"}),
                                                                                  "***announce_link***"  => (defined($args -> {"announce"} -> {"announce_link"}) ? $args -> {"announce"} -> {"announce_link"} : "http://"),
                                                                                  "***show_link***"      => $self -> generate_link_option($args -> {"announce"} -> {"show_link"}),
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

    $outfields -> {"show_close"} = $self -> {"closeopts"} -> {$args -> {"announce"} -> {"show_close"}};
    $outfields -> {"show_link"}  = $self -> {"linkopts"}  -> {$args -> {"announce"} -> {"show_link"}};

    return $self -> {"template"} -> load_template("target/announce/message_confirm.tem", {"***open_date***"     => $outfields -> {"open_date"},
                                                                                          "***close_date***"    => $outfields -> {"close_date"},
                                                                                          "***show_close***"    => $outfields -> {"show_close"},
                                                                                          "***announce_link***" => $args -> {"announce"} -> {"announce_link"},
                                                                                          "***show_link***"     => $outfields -> {"show_link"},
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

    # Store the simple stuff first...
    my $storeh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"message_andata"}."
                                              VALUES(?, ?, ?, ?, ?, ?)");
    $storeh -> execute($mess_id,
                       $args -> {"announce"} -> {"open_date"},
                       $args -> {"announce"} -> {"close_date"},
                       $args -> {"announce"} -> {"show_close"},
                       $args -> {"announce"} -> {"announce_link"},
                       $args -> {"announce"} -> {"show_link"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute announcement data insert query: ".$self -> {"dbh"} -> errstr);

    my $catstoreh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"message_ancats"}."
                                                 VALUES(?, ?)");

    # Now the categrories set for the announcement need to be recorded. Go
    # through each selected destination, and if it corresponds to an announcement
    # target, pull out its categories...
    my $cathash = {};
    foreach my $dest (@{$args -> {"targset"}}) {
        my @cats = $self -> get_destination_categories($dest);

        # if any categories were returned, add them to the database
        foreach my $cat (@cats) {
            # Avoid adding the same category twice
            if(!$cathash -> {$cat}) {
                $cathash -> {$cat} = 1;

                $catstoreh -> execute($mess_id, $cat)
                    or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute announcement category insert query: ".$self -> {"dbh"} -> errstr);
            }
        }
    }
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

    # Pull in the dates and link...
    my $fetch = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"message_andata"}."
                                             WHERE message_id = ?");
    $fetch -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute announcement data query: ".$self -> {"dbh"} -> errstr);

    $message -> {"announce"} = $fetch -> fetchrow_hashref();
    die_log($self -> {"cgi"} -> remote_host(), "Unable to obtain announcement data for message $msgid")
        if(!$message -> {"announce"});

    # And now the category ids (probably not needed, but we have them anyway)
    my $cath = $self -> {"dbh"} -> prepare("SELECT cat_id FROM ".$self -> {"settings"} -> {"database"} -> {"message_ancats"}."
                                            WHERE message_id = ?");
    $cath -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute announcement category query: ".$self -> {"dbh"} -> errstr);

    my $cats = [];
    while(my $catr = $cath -> fetchrow_arrayref()) {
        push(@{$cats}, $catr -> [0]);
    }

    $message -> {"announce"} -> {"categories"} = $cats;
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

    # Check whether the open or close date has been set
    foreach my $mode ("open", "close") {
        if(defined($self -> {"cgi"} -> param($mode."_ignore"))) {
            $args -> {"announce"} -> {$mode."_date"} = undef; # set it explicitly to avoid ambiguity
        } else {
            $args -> {"announce"} -> {$mode."_date"} = is_defined_numeric($self -> {"cgi"}, $mode."_date");

            # If we have no value for the date, complain - it must be explicitly disabled if no value is needed
            $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_NO".uc($mode))})
                if(!$args -> {"announce"} -> {$mode."_date"});

            # round down to nearest minute if it is set
            $args -> {"announce"} -> {$mode."_date"} = int(floor($args -> {"announce"} -> {$mode."_date"} / 60) * 60)
                if($args -> {"announce"} -> {$mode."_date"});
        }
    }

    # If we have start and end dates, check that end is later than start
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADDATES")})
        if($args -> {"announce"} -> {"open_date"} && $args -> {"announce"} -> {"close_date"} &&
           ($args -> {"announce"} -> {"open_date"} >= $args -> {"announce"} -> {"close_date"}));

    # Show the close date?
    $args -> {"announce"} -> {"show_close"} = $self -> {"cgi"} -> param("show_close") ? 1 : 0;

    # Link handling...
    ($args -> {"announce"} -> {"announce_link"}, $error) = $self -> validate_string("announce_link", {"required" => 0,
                                                                                                      "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_ANN_LINK"),
                                                                                                      "minlen"   => 7,
                                                                                                      "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error})
        if($error);

    # If the field is just "http://", empty it as the user hasn't entered anything.
    $args -> {"announce"} -> {"announce_link"} = ''
        if($args -> {"announce"} -> {"announce_link"} =~ /^https?:\/\/$/i);

    # Check the link appears valid if specified. The regexp is a hideous, shambling abomination. I recommend averting your eyes.
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADLINK")})
        if($args -> {"announce"} -> {"announce_link"} &&
           $args -> {"announce"} -> {"announce_link"} !~ m{^https?://[-\w]+(?:\.[-\w]+)+(?:/(?:[-\w]+/)*[-.\w]*(?:\?(?:[-\w~!\$+|.,*:;]|%[a-f\d]{2,4})+=(?:[-\w~!\$+|.,*:]|%[a-f\d]{2,4})*(?:&(?:[-\w~!\$+|.,*:;]|%[a-f\d]{2,4})+=(?:[-\w~!\$+|.,*:]|%[a-f\d]{2,4})*)*)?(?:\#(?:[-\w~!\$+|&.,*:;=]|%[a-f\d]{2,4})*)?)?$}io);

    # Link show mode
    $args -> {"announce"} -> {"show_link"} = $self -> {"cgi"} -> param("show_link") ? 1 : 0;

    return $errors;
}


## @method $ generate_messagelist_visibility($message)
# Generate the fragment to display in the 'visibility' column of the user
# message list for the specified message.
#
# @param message The message being processed.
# @return A string containing the HTML fragment to show in the visibility column.
sub generate_messagelist_visibility {
    my $self    = shift;
    my $message = shift;

    if($self -> announcement_is_open($message)) {
        return $self -> {"template"} -> load_template("target/announce/msglist_open.tem");
    } else {
        return $self -> {"template"} -> load_template("target/announce/msglist_closed.tem");
    }
}


## @method $ generate_messagelist_ops($message, $args)
# Generate the fragment to display in the 'ops' column of the user
# message list for the specified message.
#
# @param message The message being processed.
# @param args    Additional arguments to use when filling in fragment templates.
# @return A string containing the HTML fragment to show in the ops column.
sub generate_messagelist_ops {
    my $self    = shift;
    my $message = shift;
    my $args    = shift;

    if($self -> announcement_is_open($message)) {
        return $self -> {"template"} -> load_template("target/announce/msgop_close.tem", $args);
    }
    return "";
}


## @method $ known_op()
# Determine whether the target module can understand the operation specified
# in the query string. This function allows UserMessages to determine which
# Target modules understand operations added by targets during generate_messagelist_ops().
#
# @return true if the Target module can understand the operation, false otherwise.
sub known_op {
    my $self = shift;

    # Only support one operation: "close announcement".
    return defined($self -> {"cgi"} -> param("closeann"));
}


## @method @ process_op($message)
# Perform the query-stringspecified operation on a message. This allows Target
# modules to implement the operations added as part of generate_messagelist_ops().
#
# @param message A reference to a hash containing the message data.
# @return A string containing a status update message to show above the list, and
#         a flag specifying whether the returned string is an error message or not.
sub process_op {
    my $self    = shift;
    my $message = shift;

    if(defined($self -> {"cgi"} -> param("closeann"))) {
        $self -> close_announcement($message);

        return ($self -> {"template"} -> load_template("target/announce/closed.tem"), 0);
    }
    return ("", 0);
}


# Note that this class is unusual in that it never actually 'sends' its messages; they
# simply get recorded in the database and marked as "sent, visible" so that the php
# script may pick up the message when called from the main website code.

# ============================================================================
#  Internal stuff

## @method private @ get_destination_categories($dest)
# Obtain an array of announcement categories for the specified destination.
# If the destination is not an Announce target, this returns an empty list.
#
# @param dest The destination to obtain the category list for.
# @return An array of category ids, or an empty list if none are set.
sub get_destination_categories {
    my $self = shift;
    my $dest = shift;
    my @cats = ();

    # Fetch the argument for the specified destination, provided that its
    # target is this module
    my $desth = $self -> {"dbh"} -> prepare("SELECT d.args
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"recip_targs"}." AS d,
                                                  ".$self -> {"settings"} -> {"database"} -> {"targets"}." AS t
                                             WHERE d.id = ?
                                             AND t.id = d.target_id
                                             AND t.module_id = ?");
    $desth -> execute($dest, $self -> {"modid"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute destination argument lookup: ".$self -> {"dbh"} -> errstr);

    # Take all the found targets (there should only be one, but better to be safe)
    # and concatenate all their argument lists together...
    my $arglist = "";
    while(my $dest = $desth -> fetchrow_arrayref()) {
        $arglist .= ";" if($arglist && $arglist !~ /;$/);
        $arglist .= $dest -> [0];
    }

    # Break on parameter boundaries
    my @args = split(/;/, $arglist);
    foreach my $arg (@args) {
        # Is this a category arg?
        if($arg =~ /^category\s*=\s*/) {
            # nuke the category, so we just have a list of categories left
            $arg =~ s/^category\s*=\s*//;

            # Split the categories up, and shove them into the cats array
            my @argcats = split(/,/, $arg);
            push(@cats, @argcats);
        }
    }

    # Convert categories to category ids if needed
    my $cath = $self -> {"dbh"} -> prepare("SELECT id
                                            FROM ".$self -> {"settings"} -> {"database"} -> {"announce_cats"}."
                                            WHERE category LIKE ?");
    foreach my $cat (@cats) {
        # Assume non-numerics are category names rather than ids
        if($cat !~ /^\d+$/) {
            $cath -> execute($cat)
                or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute category lookup: ".$self -> {"dbh"} -> errstr);

            my $catr = $cath -> fetchrow_arrayref();
            die_log($self -> {"cgi"} -> remote_host(), "Destination '$dest' includes unknown category '$cat'. Unable to continue")
                if(!$catr);

            # Modify-in-place is a handy thing indeed...
            $cat = $catr -> [0];
        }
    }

    return @cats;
}


## @method private $ announcement_is_open($message)
# Determine whether the specified message represents a currently open
# announcement.
#
# @param message A reference to a hash containing the message data.
# @return true if the message is open, false otherwise.
sub announcement_is_open {
    my $self    = shift;
    my $message = shift;

    my $now = time();

    # If the message is not visible, it is closed by definition, otherwise it is
    # only open if the current time falls within open <= now < close
    return 0 if(!$message -> {"visible"} ||
                ($message -> {"announce"} -> {"open_date"} && ($now < $message -> {"announce"} -> {"open_date"})) ||
                ($message -> {"announce"} -> {"close_date"} && ($now >= $message -> {"announce"} -> {"close_date"})));

    return 1;
}


## @method private void close_announcement($message)
# Close the announcement specified. This will set the timestamp on the announcement
# to one second before this function was called (to avoid race conditions with the
# UI).
#
# @param message A reference to a hash containing the announcement message.
sub close_announcement {
    my $self    = shift;
    my $message = shift;

    my $closeh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"message_andata"}."
                                              SET close_date = ?
                                              WHERE message_id = ?");
    # Update the message hash, so that anyone using it again sees the close date set
    $message -> {"announce"} -> {"close_date"} = time() - 1;

    # and update the database..
    $closeh -> execute($message -> {"announce"} -> {"close_date"}, $message -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute announcement data update query: ".$self -> {"dbh"} -> errstr);
}

1;
