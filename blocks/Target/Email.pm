## @file
# This file contains the implementation of the email message target.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    21 Sept 2011
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
package Target::Email;

## @class Target::Email
# A simple email target implementation. Supported arguments are:
#
# - to=&lt;address list&gt;  - specify a list of recipient addresses (comma separated)
# - reply-to=&lt;address&gt; - specify the address that replies should go to, if not
#                              specified, replies will go to the From: address (the message owner).
# - cc=&lt;address list&gt;  - specify a list of cc recipients (comma separated)
# - bcc=&lt;address list&gt; - specify a list of bcc recipients (comma separated)
#
# Repeat arguments are concatenated, so these are equivalent:
#
# - to=addressA;to=addressB
# - to=addressA,addressB

use strict;
use base qw(Target); # This class is a Target module
use HTML::Entities;

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
        # Concatenate arguments with the same name
        if($self -> {"args"} -> {$name}) {
            $self -> {"args"} -> {$name} .= ",$value";
        } else {
            $self -> {"args"} -> {$name} = $value;
        }
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

    # fill in the default reply-to if not set.
    if(!defined($args -> {"replyto_id"})) {
        $args -> {"replyto_id"}    = 0;
        $args -> {"replyto_other"} = $user -> {"email"};
    }

    return $self -> {"template"} -> load_template("target/email/message.tem", {"***cc1***"          => $args -> {"cc"}  ? $args -> {"cc"} -> [0]  : "",
                                                                               "***cc2***"          => $args -> {"cc"}  ? $args -> {"cc"} -> [1]  : "",
                                                                               "***cc3***"          => $args -> {"cc"}  ? $args -> {"cc"} -> [2]  : "",
                                                                               "***cc4***"          => $args -> {"cc"}  ? $args -> {"cc"} -> [3]  : "",
                                                                               "***bcc1***"         => $args -> {"bcc"} ? $args -> {"bcc"} -> [0] : "",
                                                                               "***bcc2***"         => $args -> {"bcc"} ? $args -> {"bcc"} -> [1] : "",
                                                                               "***bcc3***"         => $args -> {"bcc"} ? $args -> {"bcc"} -> [2] : "",
                                                                               "***bcc4***"         => $args -> {"bcc"} ? $args -> {"bcc"} -> [3] : "",
                                                                               "***replyto_other***"=> $args -> {"replyto_other"},
                                                                               "***replyto***"      => $self -> build_replyto($args -> {"replyto_id"}),
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

    return $self -> {"template"} -> load_template("target/email/message_edit.tem", {"***cc1***"          => $args -> {"cc"}  ?  $args -> {"cc"} -> [0]  : "",
                                                                                    "***cc2***"          => $args -> {"cc"}  ?  $args -> {"cc"} -> [1]  : "",
                                                                                    "***cc3***"          => $args -> {"cc"}  ?  $args -> {"cc"} -> [2]  : "",
                                                                                    "***cc4***"          => $args -> {"cc"}  ?  $args -> {"cc"} -> [3]  : "",
                                                                                    "***bcc1***"         => $args -> {"bcc"} ?  $args -> {"bcc"} -> [0] : "",
                                                                                    "***bcc2***"         => $args -> {"bcc"} ?  $args -> {"bcc"} -> [1] : "",
                                                                                    "***bcc3***"         => $args -> {"bcc"} ?  $args -> {"bcc"} -> [2] : "",
                                                                                    "***bcc4***"         => $args -> {"bcc"} ?  $args -> {"bcc"} -> [3] : "",
                                                                                    "***cc2hide***"      => $args -> {"cc"}  ? ($args -> {"cc"} -> [1]  ? "" : "hide") : "hide",
                                                                                    "***cc3hide***"      => $args -> {"cc"}  ? ($args -> {"cc"} -> [2]  ? "" : "hide") : "hide",
                                                                                    "***cc4hide***"      => $args -> {"cc"}  ? ($args -> {"cc"} -> [3]  ? "" : "hide") : "hide",
                                                                                    "***bcc2hide***"     => $args -> {"bcc"} ? ($args -> {"bcc"} -> [1] ? "" : "hide") : "hide",
                                                                                    "***bcc3hide***"     => $args -> {"bcc"} ? ($args -> {"bcc"} -> [2] ? "" : "hide") : "hide",
                                                                                    "***bcc4hide***"     => $args -> {"bcc"} ? ($args -> {"bcc"} -> [3] ? "" : "hide") : "hide",
                                                                                    "***replyto_other***"=> $args -> {"replyto_other"},
                                                                                    "***replyto***"      => $self -> build_replyto($args -> {"replyto_id"}),
                                                  });
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
    my $tem;

    $tem -> {"cc"}  = $self -> {"template"} -> load_template("target/email/message_confirm_cc.tem");
    $tem -> {"bcc"} = $self -> {"template"} -> load_template("target/email/message_confirm_bcc.tem");

    # work out the bcc/cc fields....
    foreach my $mode ("cc", "bcc") {
        for(my $i = 0; $i < 4; ++$i) {
            # Append the cc/bcc if it is set...
            $outfields -> {$mode} .= $self -> {"template"} -> process_template($tem -> {$mode}, {"***data***" => encode_entities($args -> {$mode} -> [$i])})
                if($args -> {$mode} -> [$i]);
        }
    }

    # Get the replyto sorted
    if($args -> {"replyto_id"} == 0) {
        $outfields -> {"replyto"} = $args -> {"replyto_other"};
    } else {
        my $replytoh = $self -> {"dbh"} -> prepare("SELECT email FROM ".$self -> {"settings"} -> {"database"} -> {"replytos"}."
                                                   WHERE id = ?");
        $replytoh -> execute($args -> {"replyto_id"})
            or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto query: ".$self -> {"dbh"} -> errstr);

        my $replytor = $replytoh -> fetchrow_arrayref();
        $outfields -> {"replyto"} = $replytor ? $replytor -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADREPLYTO");
    }

    return $self -> {"template"} -> load_template("target/email/message_confirm.tem", {"***cc***"      => $outfields -> {"cc"},
                                                                                       "***bcc***"     => $outfields -> {"bcc"},
                                                                                       "***replyto***" => $outfields -> {"replyto"}});
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

    foreach my $mode ("cc", "bcc") {
        my $insh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages_$mode"}."
                                                VALUES(?, ?)");
        foreach my $address (@{$args -> {$mode}}) {
            next if(!$address); # skip ""

            $insh -> execute($mess_id, $address)
                or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute $mode insert: ".$self -> {"dbh"} -> errstr);
        }
    }

    my $replytoh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages_reply"}."
                                                VALUES(?, ?, ?)");
    $replytoh -> execute($mess_id, $args -> {"replyto_id"}, $args -> {"replyto_other"})
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto insert: ".$self -> {"dbh"} -> errstr);
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

    # now get the cc/bcc lists
    foreach my $mode ("cc", "bcc") {
        my $cch = $self -> {"dbh"} -> prepare("SELECT address FROM ".$self -> {"settings"} -> {"database"} -> {"messages_$mode"}."
                                               WHERE message_id = ?");
        $cch -> execute($msgid)
            or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute $mode lookup query: ".$self -> {"dbh"} -> errstr);

        $message -> {$mode} = [];
        while(my $cc = $cch -> fetchrow_arrayref()) {
            push(@{$message -> {$mode}}, $cc -> [0]);
        }
    }

    my $replyh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} ->  {"messages_reply"}."
                                              WHERE message_id = ?");
    $replyh -> execute($msgid)
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto lookup query: ".$self -> {"dbh"} -> errstr);

    my $replyr = $replyh -> fetchrow_hashref();
    $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "No reply-to set for message: ".$self -> {"dbh"} -> errstr) if(!$replyr);

    $message -> {"replyto_id"}    = $replyr -> {"replyto_id"};
    $message -> {"replyto_other"} = $replyr -> {"replyto_other"};
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

    # Check the cc and bcc fields are valid emails, if set
    my $addressre = '[\w\.-]+\@([\w-]+\.)+\w+'; # regexp used to check email addresses...
    foreach my $mode ("cc", "bcc") {
        $args -> {$mode} = [];
        # Four field each for cc and bcc...
        for(my $i = 1; $i <= 4; ++$i) {
            ($args -> {$mode} -> [$i - 1], $error) = $self -> validate_string($mode.$i, {"required"   => 0,
                                                                                         "default"    => "",
                                                                                         "nicename"   => $self -> {"template"} -> replace_langvar("MESSAGE_".uc($mode)),
                                                                                         "maxlen"     => 255});
            # Fix up <, >, and "
            $args -> {$mode} -> [$i - 1] = decode_entities($args -> {$mode} -> [$i - 1]);

            # If we have an error, store it, otherwise check the address is valid
            if($error) {
                $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error});
            } else {
                # Split the field for validation
                my @addresses = split(/,/, $args -> {$mode} -> [$i - 1]);

                # Check each address is valid.
                foreach my $address (@addresses) {
                    $address =~ s/^\s*(.*?)\s*$/$1/; # trim trailing or leading whitespace

                    if($address !~ /^.*?<$addressre>$/ && $address !~ /^$addressre$/) {
                        # Emails can have 'real name' junk as well as straight addresses
                        $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADEMAIL", {"***name***" => $self -> {"template"} -> replace_langvar("MESSAGE_".uc($mode))." $i (".encode_entities($args ->{$mode} -> [$i -1]).")" })});
                        last;
                    }
                }
            }
        } # for(my $i = 1; $i <= 4; ++$i)
    } # foreach my $mode ("cc", "bcc")

    # Check that the selected reply-to is valid...
    # Has the user selected the 'other reply-to' option? If so, check they enetered a prefixe
    if($self -> {"cgi"} -> param("replyto_id") == 0) {
        $args -> {"replyto_id"} = 0;
        ($args -> {"replyto_other"}, $error) = $self -> validate_string("replyto_other", {"required" => 1,
                                                                                          "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_REPLYTO"),
                                                                                          "minlen"   => 1,
                                                                                          "maxlen"   => 255});
        # check that the replyto is valid
        $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADEMAIL", {"***name***" => $self -> {"template"} -> replace_langvar("MESSAGE_REPLYTO")})})
            if($args -> {"replyto_other"} !~ /^.*?<$addressre>$/ && $args -> {"replyto_other"} !~ /^$addressre$/);

    # User has selected a prefix, check it is valid
    } else {
        $args -> {"replyto_other"} = undef;
        ($args -> {"replyto_id"}, $error) = $self -> validate_options("replyto_id", {"required" => 1,
                                                                                     "source"   => $self -> {"settings"} -> {"database"} -> {"replytos"},
                                                                                     "where"    => "WHERE id = ?",
                                                                                     "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_REPLYTO")});
    }
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
    my $outfields = {};

    # Get the user's data
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($message -> {"user_id"});
    $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to get user details for message ".$message -> {"id"}) if(!$user);

    # work out the bcc/cc fields....
    foreach my $mode ("cc", "bcc") {
        $outfields -> {$mode} = join(",", @{$message -> {$mode}});

        # Concatenate bcc/cc set in the arguments.
        if($self -> {"args"} -> {$mode}) {
            $outfields -> {$mode} .= ", " if($outfields -> {$mode});
            $outfields -> {$mode}  .= $self -> {"args"} -> {$mode};
        }
    }

    # Get the replyto sorted
    if($message -> {"replyto_id"} == 0) {
        $outfields -> {"replyto"} = $message -> {"replyto_other"};
    } else {
        my $replytoh = $self -> {"dbh"} -> prepare("SELECT email FROM ".$self -> {"settings"} -> {"database"} -> {"replytos"}."
                                                   WHERE id = ?");
        $replytoh -> execute($message -> {"replyto_id"})
            or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto query: ".$self -> {"dbh"} -> errstr);

        my $replytor = $replytoh -> fetchrow_arrayref();
        $outfields -> {"replyto"} = $replytor ? $replytor -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADREPLYTO");
    }

    # Get the prefix sorted
    if($message -> {"prefix_id"} == 0) {
        $outfields -> {"prefix"} = $message -> {"prefix_other"};
    } else {
        my $prefixh = $self -> {"dbh"} -> prepare("SELECT prefix FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                                   WHERE id = ?");
        $prefixh -> execute($message -> {"prefix_id"})
            or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix query: ".$self -> {"dbh"} -> errstr);

        my $prefixr = $prefixh -> fetchrow_arrayref();
        $outfields -> {"prefix"} = $prefixr ? $prefixr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADPREFIX");
    }

    # Prepend the prefix to the message
    $outfields -> {"subject"} = $outfields -> {"prefix"}." ".$message -> {"subject"};

    my $signature = $user -> {"signature"};
    $signature = $self -> {"template"} -> load_template("email/sigblock.tem", {"***realname***" => $user -> {"realname"},
                                                                               "***rolename***" => $user -> {"rolename"}})
        if(!$signature);

    # Send the message!
    my $error = $self -> {"template"} -> email_template("email/message.tem", {"***from***"      => $user -> {"realname"}." <".$user -> {"email"}.">",
                                                                              "***to***"        => $self -> {"args"} -> {"to"},
                                                                              "***replyto***"   => $outfields -> {"replyto"},
                                                                              "***cc***"        => $outfields -> {"cc"} || "",
                                                                              "***bcc***"       => $outfields -> {"bcc"} || "",
                                                                              # subject and message need html entities stripping
                                                                              "***subject***"   => decode_entities($outfields -> {"subject"}),
                                                                              "***message***"   => decode_entities($message -> {"message"}),
                                                                              "***realname***"  => $user -> {"realname"},
                                                                              "***rolename***"  => $user -> {"rolename"},
                                                                              "***signature***" => decode_entities($signature),
                                                        });
    $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), $error) if($error);
}


# ============================================================================
#  Internal stuff

## @method private $ build_replyto($default)
# Generate the options to show for the replyto dropdown.
#
# @param default The option to have selected by default.
# @return A string containing the replyto option list.
sub build_replyto {
    my $self    = shift;
    my $default = shift;

    # Ask the database for the available replytoes
    my $replytoh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"replytos"}."
                                               ORDER BY id");
    $replytoh -> execute()
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto lookup: ".$self -> {"dbh"} -> errstr);

    # now build the replyto list...
    my $replytolist = "";
    while(my $replyto = $replytoh -> fetchrow_hashref()) {
        # pick the first real replyto, if we have no default set
        $default = $replyto -> {"id"} if(!defined($default));

        $replytolist .= '<option value="'.$replyto -> {"id"}.'"';
        $replytolist .= ' selected="selected"' if($replyto -> {"id"} == $default);
        $replytolist .= '>'.$replyto -> {"email"}." (".$replyto -> {"description"}.")</option>\n";
    }

    # Append the extra 'other' setting...
    $replytolist .= '<option value="0"';
    $replytolist .= ' selected="selected"' if($default == 0);
    $replytolist .= '>'.$self -> {"template"} -> replace_langvar("MESSAGE_CUSTREPLYTO")."</option>\n";

    return $replytolist;
}


1;
