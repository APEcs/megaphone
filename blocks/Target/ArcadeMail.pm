## @file
# This file contains the implementation of the ARCADE-aware email message target.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.3
# @date    7 Nov 2011
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
package Target::ArcadeMail;

## @class Target::ArcadeMail
# A email target implementation that supports direct mailing or obtaining
# recipient lists from ARCADE. Supported per-destination arguments are:
#
# - to=&lt;address list&gt;  - specify a list of recipient addresses (comma separated)
# - reply-to=&lt;address&gt; - specify the address that replies should go to, if not
#                              specified, replies will go to the From: address (the message owner).
# - cc=&lt;address list&gt;  - specify a list of cc recipients (comma separated)
# - bcc=&lt;address list&gt; - specify a list of bcc recipients (comma separated)
# - course=&lt;[cmd:]cid&gt; - the course code to query for additional bcc recipients. Leading
#                              'COMP' will be ignored if provided. Multiple courseids may be
#                              provided (either as comma separated values, or multiple courseid= )
#                              to compound several courses together. Course ids may optionally be
#                              preceeded by an ARCADE command to execute to fetch the student data.
#                              If a command is specified, the result <b>must</b> have the student
#                              degree in the second field, and the username in the last field.
#
# Repeat arguments are concatenated, so these are equivalent:
#
# - to=addressA;to=addressB
# - to=addressA,addressB
#
# The following arguments may only be specified once per destination:
#
# - degreefilter=&lt;regexp&gt; - an optional filter to apply to degree results from ARCADE. This should
#                                 be the body of a regexp to match against the degree field for each
#                                 student fetched from ARCADE. If the regexp matches, the student is
#                                 added to the recipient list, otherwise they are skipped. If the first
#                                 character is !, the student is only added if the regexp does not match.
#                                 Note that the match is case sensitive!
# - namefilter=&lt;regexp$gt;   - an optional filter to apply to usernames from ARCADE. This should be
#                                 the body of a rexexp to match against the username field for each
#                                 student fetched from ARCADE. If If the regexp matches, the student is
#                                 added to the recipient list, otherwise they are skipped. If the first
#                                 character is !, the student is only added if the regexp does not match.
#                                 Note that the match is case sensitive!
# - debugmode=1|0               - if provided, and set to 1, emails are not sent normally. Instead,
#                                 a single email is sent to the user(s) specified in the reply-to for
#                                 the email listing the recipients the message would have gone to.
#
# In addition, the following settings are supported system-wide via mp_settings. The ARCADE_*
# settings MUST BE SET if any destinations include courseid settings.
#
# - Target::ArcadeMail::recipient_limit  - The maximum number of Cc:, Bcc:, or To: recipients per email.
#                                          If necessary, multiple emails will be sent to keep the number
#                                          of recipients below this limit. Defaults to 10 if not specified.
# - Target::ArcadeMail::ARCADE_field     - The email field to add ARCADE recipients to. Should be "to", "cc" or "bcc".
# - Target::ArcadeMail::ARCADE_host      - hostname of the ARCADE server to query.
# - Target::ArcadeMail::ARCADE_port      - port ARCADE is listening on.
# - Target::ArcadeMail::ARCADE_auth      - Auth data to send to ARCADE. Should be specialProtocol:serverUser:serverPassword
# - Target::ArcadeMail::ARCADE_commmand  - ARCADE command to use when looking up students. Generally
#                                          should be: course regnumbers, degrees, tutgroups, tutors, names and usernames
# - Target::ArcadeMail::ARCADE_domain    - domain that users obtained from ARCADE should be in. eg: cs.man.ac.uk

use strict;
use base qw(Target); # This class is a Target module
use Logging qw(die_log);
use Encode;
use HTML::Entities;
use List::Util;
use Socket;

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
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto query: ".$self -> {"dbh"} -> errstr);

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
                or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute $mode insert: ".$self -> {"dbh"} -> errstr);
        }
    }

    my $replytoh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages_reply"}."
                                                VALUES(?, ?, ?)");
    $replytoh -> execute($mess_id, $args -> {"replyto_id"}, $args -> {"replyto_other"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto insert: ".$self -> {"dbh"} -> errstr);
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
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute $mode lookup query: ".$self -> {"dbh"} -> errstr);

        $message -> {$mode} = [];
        while(my $cc = $cch -> fetchrow_arrayref()) {
            push(@{$message -> {$mode}}, $cc -> [0]);
        }
    }

    my $replyh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} ->  {"messages_reply"}."
                                              WHERE message_id = ?");
    $replyh -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto lookup query: ".$self -> {"dbh"} -> errstr);

    my $replyr = $replyh -> fetchrow_hashref();
    die_log($self -> {"cgi"} -> remote_host(), "No reply-to set for message: ".$self -> {"dbh"} -> errstr) if(!$replyr);

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
    die_log($self -> {"cgi"} -> remote_host(), "Unable to get user details for message ".$message -> {"id"}) if(!$user);

    # work out the to/bcc/cc fields and the recipient queue
    my @recip_queue = ();
    foreach my $mode ("to", "cc", "bcc") {
        my $addresses = "";

        # merge arguments set by the user to ensure that we have a single string of csv
        $addresses = join(",", @{$message -> {$mode}}) if($message -> {$mode});

        # prepend values set in the database
        $addresses = $self -> {"args"} -> {$mode}.",".$addresses
            if($self -> {"args"} -> {$mode});

        # split them again so we can do recipient limiting
        my @recipients = split(/,/, $addresses);

        # Build the recipients list
        foreach my $recip (@recipients) {
            push(@recip_queue, {"address" => $recip, "mode" => $mode});
        }
    }

    # Get the replyto sorted
    if($message -> {"replyto_id"} == 0) {
        $outfields -> {"replyto"} = $message -> {"replyto_other"};
    } else {
        my $replytoh = $self -> {"dbh"} -> prepare("SELECT email FROM ".$self -> {"settings"} -> {"database"} -> {"replytos"}."
                                                   WHERE id = ?");
        $replytoh -> execute($message -> {"replyto_id"})
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto query: ".$self -> {"dbh"} -> errstr);

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
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix query: ".$self -> {"dbh"} -> errstr);

        my $prefixr = $prefixh -> fetchrow_arrayref();
        $outfields -> {"prefix"} = $prefixr ? $prefixr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADPREFIX");
    }

    # Prepend the prefix to the message
    $outfields -> {"subject"} = $outfields -> {"prefix"}." ".$message -> {"subject"};

    # Work out what the signature should be, falling back on the realname/rolename block if one hasn't be specified
    my $signature = $user -> {"signature"};
    $signature = $self -> {"template"} -> load_template("email/sigblock.tem", {"***realname***" => $user -> {"realname"},
                                                                               "***rolename***" => $user -> {"rolename"}})
        if(!$signature);

    # Get recipients from ARCADE
    my $arcadeusers = $self -> get_arcade_recipients(\@recip_queue, $self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::ARCADE_field"});

    # potentially have duplicate recipients in the recipient queue at this point. Strip them.
    my @unique_queue = ();
	my %seen   = ();
	foreach my $recip (@recip_queue) {
		next if($seen{ $recip -> {"address"} }++);
		push(@unique_queue, $recip);
    }

    # Fix up fields that may contain special chars
    $outfields -> {"message"} = decode_entities($message -> {"message"});
    $outfields -> {"subject"} = decode_entities($outfields -> {"subject"});

    # If we have debugging enabled, the message should just go to the reply-to address
    my $error;
    if($self -> {"args"} -> {"debugmode"}) {
        # Build the recipients block
        my $mailnum = 0;
        for(my $start = 0; $start < scalar(@unique_queue); $start += $self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::recipient_limit"}) {
            my $fields = {};

            for(my $pos = 0; $pos < $self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::recipient_limit"}; ++$pos) {
                if(defined($unique_queue[$start + $pos])) {
                    $fields -> {$unique_queue[$start + $pos] -> {"mode"}} .= "," if($fields -> {$unique_queue[$start + $pos] -> {"mode"}});
                    $fields -> {$unique_queue[$start + $pos] -> {"mode"}} .= $unique_queue[$start + $pos] -> {"address"};
                }
            }

            my $recipients .= $self -> {"template"} -> load_template("email/debugrecipients.tem", {"***num***"   => ++$mailnum,
                                                                                                   "***to***"    => $fields -> {"to"},
                                                                                                   "***cc***"    => $fields -> {"cc"},
                                                                                                   "***bcc***"   => $fields -> {"bcc"}});

            $error = $self -> {"template"} -> email_template("email/debugmessage.tem", {"***from***"       => $user -> {"realname"}." <".$user -> {"email"}.">",
                                                                                        "***replyto***"    => $outfields -> {"replyto"},
                                                                                        "***to***"         => $outfields -> {"replyto"},
                                                                                        "***recipients***" => $recipients,
                                                                                        "***count***"      => $arcadeusers || "No",
                                                                                        "***subject***"    => Encode::encode_utf8($outfields -> {"subject"}),
                                                                                        "***message***"    => Encode::encode_utf8($outfields -> {"message"}),
                                                                                        "***realname***"   => $user -> {"realname"},
                                                                                        "***rolename***"   => $user -> {"rolename"},
                                                                                        "***signature***"  => decode_entities($signature),
                                                             });
        }
    } else {
        # Send the messages!
        for(my $start = 0; $start < scalar(@unique_queue); $start += $self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::recipient_limit"}) {
            my $fields = {};

            for(my $pos = 0; $pos < $self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::recipient_limit"}; ++$pos) {
                if(defined($unique_queue[$start + $pos])) {
                    $fields -> {$unique_queue[$start + $pos] -> {"mode"}} .= "," if($fields -> {$unique_queue[$start + $pos] -> {"mode"}});
                    $fields -> {$unique_queue[$start + $pos] -> {"mode"}} .= $unique_queue[$start + $pos] -> {"address"};
                }
            }

            $error = $self -> {"template"} -> email_template("email/message.tem", {"***from***"      => $user -> {"realname"}." <".$user -> {"email"}.">",
                                                                                   "***replyto***"   => $outfields -> {"replyto"},
                                                                                   "***to***"        => $fields -> {"to"} || "",
                                                                                   "***cc***"        => $fields -> {"cc"} || "",
                                                                                   "***bcc***"       => $fields -> {"bcc"} || "",

                                                                                   # subject and message need html entities stripping
                                                                                   "***subject***"   => Encode::encode_utf8($outfields -> {"subject"}),
                                                                                   "***message***"   => Encode::encode_utf8($outfields -> {"message"}),
                                                                                   "***realname***"  => $user -> {"realname"},
                                                                                   "***rolename***"  => $user -> {"rolename"},
                                                                                   "***signature***" => decode_entities($signature),
                                                             });
        }
    }

    die_log($self -> {"cgi"} -> remote_host(), $error) if($error);
}


# ============================================================================
#  Internal stuff

## @method $ build_replyto($default)
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
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute replyto lookup: ".$self -> {"dbh"} -> errstr);

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


## @method $ arcade_connect()
# Open a connection to the ARCADE system and return a socket to
# perform operations through.
#
# @return A typeglob containing the ARCADE connection.
sub arcade_connect {
    my $self = shift;

    local *SOCK;

    my $iaddr   = inet_aton($self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::ARCADE_host"}) || die "Unable to resolve Arcade host ".$self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::ARCADE_host"};
    my $paddr   = sockaddr_in($self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::ARCADE_port"}, $iaddr);
    my $proto   = getprotobyname('tcp');

    socket(SOCK, PF_INET, SOCK_STREAM, $proto)  || die "Unable to create socket.\nError was: $!";
    connect(SOCK, $paddr) || die "Unable to connect to Arcade.\nError was: $!";

    my $auth = $self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::ARCADE_auth"};
    $auth =~ s/:/\n/g;
    print SOCK "$auth\n";
    return *SOCK;
}


## @method $ arcade_command($command, $course)
# Send a command to the ARCADE server, and return the response.
#
# @param command The command to send to ARCADE.
# @param course  The ID of the course the query. Leading COMP is stripped.
# @return A string containing student data, one student per line. If the
#         command failed for some reason (unknown command, unknown course, etc)
#         this will return an empty string.
sub arcade_command {
    my $self = shift;
    my $command = shift;
    my $course = shift;

    # Strip leading COMP if needed
    $course =~ s/^COMP//;

    # Get a connection to ARCADE
    local *SOCK = $self -> arcade_connect();

    # Send it the command and course,
    print SOCK "$command:$course\n";
    my $OldSelect = select SOCK; $|=1; select $OldSelect;


    my $result = "";
    my $line;
    while(defined($line = <SOCK>)) {
        $result .= $line unless($line eq "++WORKING\n");
    }
    close (SOCK) || die "Error while closing socket connection.\nError was: $!";
    return $result;
}


## @method @ get_arcade_filter($name)
# Obtain the filter regexp and mode for the specified filter.
#
# @param name The name of the filter to obtain the regexp for
# @return An array of two values: the filter regexp, and the filter mode
#         (either "match" or "exclude")
sub get_arcade_filter {
    my $self = shift;
    my $name = shift;

    my $filter = $self -> {"args"} -> {$name};
    my $fmode  = "match";
    if($filter && $filter =~ /^!/) {
        $filter = substr($filter, 1);
        $fmode  = "exclude";
    }

    return ($filter, $fmode);
}


## @method $ arcade_filter_match($filter, $fmode, $data)
# Determine whether the specified data passes the filtering rules provided.
# If no filter rule is set, the data always passes it. Otherwise, this will
# return true if the data matches the filter and the filter mode is "match",
# or if it does not match the filter and the filter mode is "exclude".
# Otherwise this returns false.
#
# @param filter The filter regexp to apply to the data.
# @param fmode  The filter match mode. Should be "match" or "exclude".
# @param data   The data to check against the filter.
# @return true if the data passes the filter check, false otherwise.
sub arcade_filter_match {
    my $self   = shift;
    my $filter = shift;
    my $fmode  = shift;
    my $data   = shift;

    return (!$filter ||
            ($fmode eq "match"   && $data =~ /$filter/) ||
            ($fmode eq "exclude" && $data !~ /$filter/));
}


## @method $ get_arcade_recipients($recip_queue, $mode)
# Get the list of students recored in arcade for the current destination
# (if appropriate). This will add students to the recipient queue with
# the specified destination mode ('to', 'cc', or 'bcc')
#
# @param recip_queue A reference to an array containing the recipient queue.
# @param mode        The destination mode to add ARCADE recipients as (must
#                    be 'to', 'cc', or 'bcc).
# @return The number of recipients added to the queue.
sub get_arcade_recipients {
    my $self        = shift;
    my $recip_queue = shift;
    my $mode        = shift;
    my $count       = 0;

    # Do nothing if we have no courseid values specified
    return if(!$self -> {"args"} -> {"course"});

    # Obtain filtering definitions if needed
    my ($degreefilter, $degreefmode) = $self -> get_arcade_filter("degreefilter");
    my ($namefilter,   $namefmode  ) = $self -> get_arcade_filter("namefilter");

    # Now get a list of courses to check...
    my @courses = split(/,/, $self -> {"args"} -> {"course"});

    # Ask ARCADE for users for each course
    foreach my $course (@courses) {
        # Split the course up into command and course id parts
        my ($cmd, $cid) = $course =~ /^(.*?)(?::(\w+))?$/;

        # If command and course id are set, fix up . to , in the command.
        if($cmd && $cid) {
            $cmd =~ s/\./,/g;

        # No command set, fix up the course if and use the default command
        } else {
            $cid = $cmd;
            $cmd = $self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::ARCADE_command"};
        }

        # Here we go...
        my $result = $self -> arcade_command($cmd, $cid);
        if($result) {

            # ARCADE returned one or more users, so split the string by lines
            my @users = split(/^/, $result);
            foreach my $user (@users) {

                # Grab the fields out of the line. $fields[1] must be the degree,
                # and $fields[scalar(@fields) - 1] must be the username
                chomp($user);
                my @fields = split(/\t/, $user);

                my $username = $fields[scalar(@fields) - 1];

                # If the username was obtained, do filtering checks...
                if($username) {
                    # Skip users who do not pass filtering
                    next unless($self -> arcade_filter_match($degreefilter, $degreefmode, $fields[1]) &&
                                $self -> arcade_filter_match($namefilter  , $namefmode  , $username));

                    push(@{$recip_queue}, {"address" => $username.'@'.$self -> {"settings"} -> {"config"} -> {"Target::ArcadeMail::ARCADE_domain"},
                                           "mode"    => $mode});
                    ++$count;
                }
            }
        }
    }

    return $count;
};

1;
