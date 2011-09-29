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

## @class
# A simple email target implementation. Supported arguments are:
#
# to=<address list>  - specify a list of recipient addresses (comma separated)
# reply-to=<address> - specify the address that replies should go to, if not
#                      replies will go to the From: address (the message owner).
# cc=<address list>  - specify a list of cc recipients (comma sepatated)
# bcc=<address list> - specify a list of bcc recipients (comma sepatated)
#
# Repeat arguments are concatenated, so these are equivalent:
#
# to=foo@bar.com;to=wibble@nowhere.com
# to=foo@bar.com,wibble@nowhere.com

use strict;
use base qw(Target::Target); # This class is a Target module
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

    my $self -> {"args"} = $args;

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
    if(!defined($args)) {
        $args = {"replyto_id"    => 0,
                 "replyto_other" => $user -> {"email"}};
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

    # Send the message!
    $self -> {"template"} -> email_template("email/message.tem", {"***from***"     => $user -> {"realname"}." <".$user -> {"email"}.">",
                                                                  "***to***"       => $self -> {"args"} -> {"to"},
                                                                  "***replyto***"  => $outfields -> {"replyto"},
                                                                  "***cc***"       => $outfields -> {"cc"} || "",
                                                                  "***bcc***"      => $outfields -> {"bcc"} || "",
                                                                  # subject and message need html entities stripping
                                                                  "***subject***"  => decode_entities($outfields -> {"subject"}),
                                                                  "***message***"  => decode_entities($message -> {"message"}),
                                                                  "***realname***" => $user -> {"realname"},
                                                                  "***rolename***" => $user -> {"rolename"},
                                                              });
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


1;
