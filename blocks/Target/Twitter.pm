## @file
# This file contains the implementation of the twitter message target.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    29 Sept 2011
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
package Target::Twitter;

## @class
# A simple twitter target implementation. Supported arguments are:
#
# consumer_key=<key>
# consumer_secret=<key>
# access_token=<key>
# access_token_secret=<key>
#
# All arguments are REQUIRED, otherwise the send will fail. Requires two
# tables in the database:
#
# CREATE TABLE `mp_messages_tweetmode` (
#   `message_id` int(10) unsigned NOT NULL COMMENT 'ID of the message this is specifying the tweet mode for',
#   `tweetmode_id` tinyint(3) unsigned NOT NULL COMMENT 'The selected tweet mode.',
#   KEY `message_id` (`message_id`)
# ) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Records which twitter modes was selected for each message';
#
# CREATE TABLE `mp_twitter_modes` (
#   `id` tinyint(3) unsigned NOT NULL AUTO_INCREMENT,
#   `mode` varchar(40) NOT NULL COMMENT 'The name of the twitter post mode',
#   `send_func` varchar(80) NOT NULL COMMENT 'The Target::Twitter send function implementing this mode',
#   PRIMARY KEY (`id`)
# ) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Supported twitter postmodes, and the name of the send func' AUTO_INCREMENT=3;
#
# INSERT INTO `mp_twitter_modes` (`id`, `mode`, `send_func`) VALUES
# (1, 'Truncate to fit into one tweet', 'send_truncate'),
# (2, 'Split into multiple tweets', 'send_split');

use strict;
use base qw(Target); # This class is a Target module
use Logging qw(die_log);
use Net::Twitter::Lite;


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

    my @argbits = split(/;/, $self -> {"args"});

    $self -> {"args"} = {};
    foreach my $arg (@argbits) {
        my ($name, $value) = $arg =~ /^(\w+)=(.*)$/;

        $self -> {"args"} -> {$name} = $value;
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

    return $self -> {"template"} -> load_template("target/twitter/message.tem",
                                                  {"***twittermode***" => $self -> build_twittermode($args -> {"tweet_mode"}),
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

    my $twitterh = $self -> {"dbh"} -> prepare("SELECT mode FROM ".$self -> {"settings"} -> {"database"} -> {"twittermodes"}."
                                                   WHERE id = ?");
    $twitterh -> execute($args -> {"tweet_mode"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute twitter query: ".$self -> {"dbh"} -> errstr);

    my $twitterr = $twitterh -> fetchrow_arrayref();
    $outfields -> {"twittermode"} = $twitterr ? $twitterr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADTWEETMODE");

    return $self -> {"template"} -> load_template("target/twitter/message_confirm.tem",
                                                  {"***twittermode***" => $outfields -> {"twittermode"},
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
# data in the args hash in the appropraite tables in the database.
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

    my $twitterh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages_tweet"}."
                                                VALUES(?, ?)");
    $twitterh -> execute($mess_id, $args -> {"tweet_mode"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute twitter insert: ".$self -> {"dbh"} -> errstr);
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

    my $tweeth = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} ->  {"messages_tweet"}."
                                              WHERE message_id = ?");
    $tweeth -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute twitter lookup query: ".$self -> {"dbh"} -> errstr);

    my $tweetr = $tweeth -> fetchrow_hashref();
    die_log($self -> {"cgi"} -> remote_host(), "No tweet mode set for message: ".$self -> {"dbh"} -> errstr) if(!$tweetr);

    $message -> {"tweet_mode"} = $tweetr -> {"tweet_mode"};
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

    # Check that the selected twitter mode is valid...
    ($args -> {"tweet_mode"}, $error) = $self -> validate_options("tweet_mode", {"required" => 1,
                                                                                 "source"   => $self -> {"settings"} -> {"database"} -> {"twittermodes"},
                                                                                 "where"    => "WHERE id = ?",
                                                                                 "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_TWITTER")});

    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    return $errors;
}



# ============================================================================
#  Message send functions

## @method $ send($message)
# Attempt to send the specified message as an email.
#
# @param message A reference to a hash containing the message to send.
# @return undef on success, an error message on failure.
sub send {
    my $self      = shift;
    my $message   = shift;

    my $nt = Net::Twitter::Lite->new(
        consumer_key        => $self -> {"args"} -> {"consumer_key"},
        consumer_secret     => $self -> {"args"} -> {"consumer_secret"},
        access_token        => $self -> {"args"} -> {"access_token"},
        access_token_secret => $self -> {"args"} -> {"access_token_secret"},
        ssl => 1,
        );

    $nt -> update($message -> {"message"});
}


# ============================================================================
#  Internal stuff

## @method $ build_twittermode($default)
# Generate the options to show for the twittermode dropdown.
#
# @param default The option to have selected by default.
# @return A string containing the twittermode option list.
sub build_twittermode {
    my $self    = shift;
    my $default = shift;

    # Ask the database for the available twittermodees
    my $twittermodeh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"twittermodes"}."
                                                    ORDER BY id");
    $twittermodeh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute twittermode lookup: ".$self -> {"dbh"} -> errstr);

    # now build the twittermode list...
    my $twittermodelist = "";
    while(my $twittermode = $twittermodeh -> fetchrow_hashref()) {
        # pick the first real twittermode, if we have no default set
        $default = $twittermode -> {"id"} if(!defined($default));

        $twittermodelist .= '<option value="'.$twittermode -> {"id"}.'"';
        $twittermodelist .= ' selected="selected"' if($twittermode -> {"id"} == $default);
        $twittermodelist .= '>'.$twittermode -> {"mode"}."</option>\n";
    }

    return $twittermodelist;
}

1;
