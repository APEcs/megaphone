## @file
# This file contains the implementation of the core megaphone features.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    17 Sept 2011
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
package MegaphoneBlock;

use strict;
use base qw(Block); # This class extends Block
use MIME::Base64;   # Needed for base64 encoding of popup bodies.
use Logging qw(die_log);


# ============================================================================
#  Storage

## @method $ store_message($args, $user)
# Store the contents of the message in the database, marked as 'incomplete' so that
# the system can not autosend it yet.
#
# @params args A reference to a hash containing the message data.
# @params user A reference to a user's data.
# @return The message id on success, dies on failure.
sub store_message {
    my $self = shift;
    my $args = shift;
    my $user = shift;

    # First we need to create the message itself
    my $messh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                             (user_id, prefix_id, prefix_other, subject, message, delaysend, created, updated)
                                             VALUES(?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())");
    $messh -> execute($user -> {"user_id"},
                      $args -> {"prefix"},
                      $args -> {"prefixother"},
                      $args -> {"subject"},
                      $args -> {"message"},
                      $args -> {"delaysend"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message insert: ".$self -> {"dbh"} -> errstr);

    # Get the id of the newly created message. This is messy, but DBI's last_insert_id() is flakey as hell
    my $messid = $self -> {"dbh"} -> {"mysql_insertid"};
    die_log($self -> {"cgi"} -> remote_host(), "Unable to get ID of new message. This should not happen.") if(!$messid);

    # Now we can store the cc, bcc, and destinations
    my $desth = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages_dests"}."
                                             VALUES(?, ?)");
    foreach my $destid (@{$args -> {"targset"}}) {
        $desth -> execute($messid, $destid)
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute destination insert: ".$self -> {"dbh"} -> errstr);
    }

    foreach my $mode ("cc", "bcc") {
        my $insh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages_$mode"}."
                                                VALUES(?, ?)");
        foreach my $address (@{$args -> {$mode}}) {
            next if(!$address); # skip ""

            $insh -> execute($messid, $address)
                or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute $mode insert: ".$self -> {"dbh"} -> errstr);
        }
    }

    return $messid;
}


## @method $ get_message($msgid)
# Obtain the data for the specified message.
#
# @param msgid The ID of the message to retrieve.
# @return A hash containing the message data.
sub get_message {
    my $self  = shift;
    my $msgid = shift;

    # First get the message...
    my $msgh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                            WHERE id = ?");
    $msgh -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message lookup query: ".$self -> {"dbh"} -> errstr);

    my $message = $msgh -> fetchrow_hashref();
    return undef if(!$message);

    # Fetch the destinations
    $message -> {"targset"} = [];
    my $targh = $self -> {"dbh"} -> prepare("SELECT dest_id FROM ".$self -> {"settings"} -> {"database"} ->  {"messages_dests"}."
                                             WHERE message_id = ?");
    $targh -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute destination lookup query: ".$self -> {"dbh"} -> errstr);

    while(my $targ = $targh -> fetchrow_arrayref()) {
        push(@{$message -> {"targset"}}, $targ -> [0]);
    }

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

    # Done, return the data...
    return $message;
}


## @method void update_userdetails($args)
# Update the details for the specified user. The args hash must minimally contain
# the user's realname, rolename, and user_id.
#
# @param args The arguments to set for the user.
sub update_userdetails {
    my $self = shift;
    my $args = shift;

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                               SET realname = ?, rolename = ?
                                               WHERE user_id = ?");
    $updateh -> execute($args -> {"realname"}, $args -> {"rolename"}, $args -> {"user_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute user details update: ".$self -> {"dbh"} -> errstr);
}


# ============================================================================
#  Frgment generators

## @method $ build_target_matrix($activelist, $readonly)
# Generate the table containing the target/recipient matrix. This will generate
# a table listing the supported targets horizontally, and the supported recipients
# vertically. Each cell in the table may either contain a checkbox (indicating
# that the system can send to the recipient via that system), or a cross (indicating
# that the recipient can not be contacted via that system).
#
# @param activelist A reference to an array of selected target/recipient combinations.
# @param readonly   If true, the table will be generated with images rather than checkboxes.
# @return A string containing the target/recipient matrix
sub build_target_matrix {
    my $self       = shift;
    my $activelist = shift;
    my $readonly   = shift;

    # Make sure that activelist is usable as an arrayref
    $activelist = [] if(!$activelist);

    # No, I mean /really/ make sure...
    die_log($self -> {"cgi"} -> remote_host(), "activelist parameter to build_target_matrix is not an array reference. This should not happen.")
        if(ref($activelist) ne "ARRAY");

    # Convert the list to a hash for faster lookup
    my $activehash;
    foreach my $active (@{$activelist}) {
        $activehash -> {$active} = 1;
    }

    # Okay, now we can start to build the matrix. We need queries for the targets, recipients, and the map table
    my $targeth = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"targets"}." ORDER BY name");
    my $reciph  = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"recipients"}." ORDER BY id");
    my $matrixh = $self -> {"dbh"} -> prepare("SELECT id FROM ".$self -> {"settings"} -> {"database"} -> {"recip_targs"}."
                                               WHERE recipient_id = ? AND target_id = ?");

    # We should prefetch the targets as we need to process them repeatedly during the matrix generation
    $targeth -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to obtain list of targets: ".$self -> {"dbh"} -> errstr);

    my $targets = $targeth -> fetchall_arrayref({}); # Fetch all the targets as a reference to an array of hash references.

    # Make the header list...
    my $targetheader = "";
    my $targheadtem = $self -> {"template"} -> load_template("matrix/target.tem");
    foreach my $target (@{$targets}) {
        $targetheader .= $self -> {"template"} -> process_template($targheadtem, {"***name***" => $target -> {"name"}});
    }

    # Now we can build the matrix itself
    my $matrix = "";
    my $reciptem        = $self -> {"template"} -> load_template("matrix/recipient.tem");
    my $recipentrytem   = $self -> {"template"} -> load_template("matrix/reciptarg.tem");
    my $recipacttem     = $self -> {"template"} -> load_template("matrix/reciptarg-active.tem");
    my $recipinacttem   = $self -> {"template"} -> load_template("matrix/reciptarg-inactive.tem");
    my $recipact_ontem  = $self -> {"template"} -> load_template("matrix/reciptarg-active_ticked.tem");
    my $recipact_offtem = $self -> {"template"} -> load_template("matrix/reciptarg-active_unticked.tem");

    $reciph -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to obtain list of recipients: ".$self -> {"dbh"} -> errstr);

    while(my $recipient = $reciph -> fetchrow_hashref()) {
        my $data = "";
        # Each row should consist of an entry for each target...
        foreach my $target (@{$targets}) {
            $matrixh -> execute($recipient -> {"id"}, $target -> {"id"})
                or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute target/recipient map query: ".$self -> {"dbh"} -> errstr);

            # Do we have the ability to send to this recipient at this target?
            my $matrow = $matrixh -> fetchrow_arrayref();
            if($matrow) {
                # Yes, output either a checkbox or a marker...
                if(!$readonly) {
                    $data .= $self -> {"template"} -> process_template($recipentrytem, {"***data***" => $self -> {"template"} -> process_template($recipacttem, {"***id***"      => $matrow -> [0],
                                                                                                                                                                 "***checked***" => $activehash -> {$matrow -> [0]} ? 'checked="checked"' : ""})});
                } else {
                    $data .= $self -> {"template"} -> process_template($recipentrytem, {"***data***" => ($activehash -> {$matrow -> [0]} ? $recipact_ontem : $recipact_offtem)});
                }
            } else {
                # Nope, output a X marker
                $data .= $self -> {"template"} -> process_template($recipentrytem, {"***data***" => $recipinacttem});
            }
        }

        # Now squirt out the row
        $matrix .= $self -> {"template"} -> process_template($reciptem, {"***name***"    => $recipient -> {"name"},
                                                                         "***id***"      => $recipient -> {"id"},
                                                                         "***targets***" => $data});
    }

    # We have almost all we need - load the help for the matrix
    my $help = $self -> {"template"} -> load_template("popup.tem", {"***title***"   => $self -> {"template"} -> replace_langvar("MATRIX_HELP_TITLE"),
                                                                    "***b64body***" => encode_base64($self -> {"template"} -> load_template("matrix/matrix-help.tem"))});

    # And we can return the filled-in table...
    return $self -> {"template"} -> load_template("matrix/matrix.tem", {"***help***"    => $help,
                                                                        "***targets***" => $targetheader,
                                                                        "***matrix***"  => $matrix});
}


## @method $ build_prefix($default)
# Generate the options to show for the prefix dropdown.
#
# @param default The option to have selected by default.
# @return A string containing the prefix option list.
sub build_prefix {
    my $self    = shift;
    my $default = shift;

    # Ask the database for the available prefixes
    my $prefixh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                               ORDER BY id");
    $prefixh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix lookup: ".$self -> {"dbh"} -> errstr);

    # now build the prefix list...
    my $prefixlist = "";
    while(my $prefix = $prefixh -> fetchrow_hashref()) {
        # pick the first real prefix, if we have no default set
        $default = $prefix -> {"id"} if(!defined($default));

        $prefixlist .= '<option value="'.$prefix -> {"id"}.'"';
        $prefixlist .= ' selected="selected"' if($prefix -> {"id"} == $default);
        $prefixlist .= '>'.$prefix -> {"prefix"}."</option>\n";
    }

    # Append the extra 'other' setting...
    $prefixlist .= '<option value="0"';
    $prefixlist .= ' selected="selected"' if($default == 0);
    $prefixlist .= '>'.$self -> {"template"} -> replace_langvar("MESSAGE_CUSTPREFIX")."</option>\n";

    return $prefixlist;
}


# ============================================================================
#  Validation functions

## @method @ validate_userdetails()
# Determine whether the details provided by the user are valid.
#
# @return An array of two values: the first is a reference to a hash containing the
#         data submitted by the user, the second is either undef or an error message.
sub validate_userdetails {
    my $self = shift;
    my ($args, $errors, $error) = ({}, "", "");

    # template for errors...
    my $errtem = $self -> {"template"} -> load_template("blocks/error_entry.tem");

    ($args -> {"realname"}, $error) = $self -> validate_string("name", {"required" => 1,
                                                                        "nicename" => $self -> {"template"} -> replace_langvar("DETAILS_NAME"),
                                                                        "minlen"   => 1,
                                                                        "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    ($args -> {"rolename"}, $error) = $self -> validate_string("role", {"required" => 1,
                                                                        "nicename" => $self -> {"template"} -> replace_langvar("DETAILS_ROLE"),
                                                                        "minlen"   => 1,
                                                                        "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    # Wrap the errors up, if we have any
    $errors = $self -> {"template"} -> load_template("blocks/user_details_error.tem", {"***errors***" => $errors})
        if($errors);

    return ($args, $errors);
}


## @method @ validate_login()
# Determine whether the username and password provided by the user are valid. If
# they are, return the user's data.
#
# @return An array of two values: the first is either a reference to a hash containing
#         the user's data, or undef. The second is either undef or an error message.
sub validate_login {
    my $self   = shift;
    my $error  = "";
    my $args   = {};

    my $errtem = $self -> {"template"} -> load_template("blocks/login_error.tem");

    # Check that the username is provided and valid
    ($args -> {"username"}, $error) = $self -> validate_string("username", {"required"   => 1,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_USERNAME"),
                                                                            "minlen"     => 2,
                                                                            "maxlen"     => 12,
                                                                            "formattest" => '^\w+',
                                                                            "formatdesc" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADUSERCHAR")});
    # Bomb out at this point if the username is not valid.
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $error})) if($error);

    # Do the same with the password...
    ($args -> {"password"}, $error) = $self -> validate_string("password", {"required"   => 1,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_PASSWORD"),
                                                                            "minlen"     => 2,
                                                                            "maxlen"     => 255});
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $error})) if($error);

    # Username and password appear to be present and contain sane characters. Try to log the user in...
    my $user = $self -> {"session"} -> {"auth"} -> valid_user($args -> {"username"}, $args -> {"password"});

    # User is valid!
    return ($user, undef) if($user);

    # User is not valid, does the lasterr contain anything?
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $self -> {"session"} -> {"auth"} -> {"lasterr"}}))
        if($self -> {"session"} -> {"auth"} -> {"lasterr"});

    # Nothing useful, just return a fallback
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_INVALID")}));
}


## @method @ validate_message()
# Check whether the fields selected by the user are valid, and return as much as possible.
#
# @return An array of two values: the first is a reference to a hash of arguments
#         representing the submitted data, the second is an error message or undef.
sub validate_message {
    my $self   = shift;
    my $errors = shift;
    my $args   = {};
    my $error;

    # template for errors...
    my $errtem = $self -> {"template"} -> load_template("blocks/error_entry.tem");

    # Query used to check that destinations are valid
    my $matrixh = $self -> {"dbh"} -> prepare("SELECT id FROM ".$self -> {"settings"} -> {"database"} -> {"recip_targs"}."
                                               WHERE id = ?");

    # check that we have some seleted destinations, and they are valid
    my @targset = $self -> {"cgi"} -> param('matrix');
    my @checked_targs;
    foreach my $targ (@targset) {
        $matrixh -> execute($targ)
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute recipient/target validation check: ".$self -> {"dbh"} -> errstr);

        # do we have a match?
        if($matrixh -> fetchrow_hashref()){
            push(@checked_targs, $targ);

        # Not found, produce an error...
        } else {
            $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADMATRIX")});
            last;
        }
    }
    # Store the checked settings we have..
    $args -> {"targset"} = \@checked_targs;

    # We need to have some destinations selected!
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_NOMATRIX")})
        if(!scalar(@checked_targs));

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
            $args -> {$mode} -> [$i - 1] =~ s/&lt;/</g;
            $args -> {$mode} -> [$i - 1] =~ s/&gt;/>/g;
            $args -> {$mode} -> [$i - 1] =~ s/&quot;/\"/g;
            $args -> {$mode} -> [$i - 1] =~ s/&amp;/&/g;

            # If we have an error, store it, otherwise check the address is valid
            if($error) {
                $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error});
            } else {
                # Emails can have 'real name' junk as well as straight addresses
                if($args -> {$mode} -> [$i - 1] && $args -> {$mode} -> [$i - 1] !~ /^.*<$addressre>$/ && $args -> {$mode} -> [$i - 1] !~ /^$addressre$/) {
                    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADEMAIL", {"***name***" => $self -> {"template"} -> replace_langvar("MESSAGE_".uc($mode))." $i (".$self -> {"template"} -> html_clean($args ->{$mode} -> [$i -1]).")" })});
                }
            }
        }
    }

    # Check that the selected prefix is valid...
    # Has the user selected the 'other prefix' option? If so, check they enetered a prefixe
    if($self -> {"cgi"} -> param("prefix") == 0) {
        $args -> {"prefix"} = 0;
        ($args -> {"prefixother"}, $error) = $self -> validate_string("prefixother", {"required" => 1,
                                                                                      "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_PREFIX"),
                                                                                      "minlen"   => 1,
                                                                                      "maxlen"   => 20});
    # User has selected a prefix, check it is valid
    } else {
        $args -> {"prefixother"} = undef;
        ($args -> {"prefix"}, $error) = $self -> validate_options("prefix", {"required" => 1,
                                                                             "source"   => $self -> {"settings"} -> {"database"} -> {"prefixes"},
                                                                             "where"    => "WHERE id = ?",
                                                                             "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_PREFIX")});
    }
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    # Make sure that we have a subject...
    ($args -> {"subject"}, $error) = $self -> validate_string("subject", {"required" => 1,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_SUBJECT"),
                                                                          "minlen"   => 1,
                                                                          "maxlen"   => 20});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    #... and a message, too
    ($args -> {"message"}, $error) = $self -> validate_string("message", {"required" => 1,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_MESSAGE"),
                                                                          "minlen"   => 1});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    $args -> {"delaysend"} = $self -> {"cgi"} -> param("delaysend") ? 1 : 0;

    # Wrap the errors up, if we have any
    $errors = $self -> {"template"} -> load_template("blocks/error.tem", {"***errors***" => $errors})
        if($errors);

    return ($args, $errors);
}


# ============================================================================
#  Content generation functions

## @method $ generate_message_editform($msgid, $args, $error)
# Generate the message edit form to send to the user. This will wrap any specified
# error in an appropriate block before inserting it into the message block. Any
# arguments set in the provided args hash are filled in on the form.
#
# @param msgid The ID of the message being edited.
# @param args  A reference to a hash containing the default values to show in the form.
# @param error An error message to show at the start of the form.
# @return A string containing the message form.
sub generate_message_editform {
    my $self  = shift;
    my $msgid = shift;
    my $args  = shift || { };
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
        if($error);

    # And build the message block itself. Kinda big and messy, this...
    my $body = $self -> {"template"} -> load_template("blocks/message_edit.tem", {"***error***"       => $error,
                                                                                  "***cc1***"         => $args -> {"cc"}  ?  $args -> {"cc"} -> [0]  : "",
                                                                                  "***cc2***"         => $args -> {"cc"}  ?  $args -> {"cc"} -> [1]  : "",
                                                                                  "***cc3***"         => $args -> {"cc"}  ?  $args -> {"cc"} -> [2]  : "",
                                                                                  "***cc4***"         => $args -> {"cc"}  ?  $args -> {"cc"} -> [3]  : "",
                                                                                  "***bcc1***"        => $args -> {"bcc"} ?  $args -> {"bcc"} -> [0] : "",
                                                                                  "***bcc2***"        => $args -> {"bcc"} ?  $args -> {"bcc"} -> [1] : "",
                                                                                  "***bcc3***"        => $args -> {"bcc"} ?  $args -> {"bcc"} -> [2] : "",
                                                                                  "***bcc4***"        => $args -> {"bcc"} ?  $args -> {"bcc"} -> [3] : "",
                                                                                  "***cc2hide***"     => $args -> {"cc"}  ? ($args -> {"cc"} -> [1]  ? "" : "hide") : "hide",
                                                                                  "***cc3hide***"     => $args -> {"cc"}  ? ($args -> {"cc"} -> [2]  ? "" : "hide") : "hide",
                                                                                  "***cc4hide***"     => $args -> {"cc"}  ? ($args -> {"cc"} -> [3]  ? "" : "hide") : "hide",
                                                                                  "***bcc2hide***"    => $args -> {"bcc"} ? ($args -> {"bcc"} -> [1] ? "" : "hide") : "hide",
                                                                                  "***bcc3hide***"    => $args -> {"bcc"} ? ($args -> {"bcc"} -> [2] ? "" : "hide") : "hide",
                                                                                  "***bcc4hide***"    => $args -> {"bcc"} ? ($args -> {"bcc"} -> [3] ? "" : "hide") : "hide",
                                                                                  "***prefixother***" => $args -> {"prefixother"},
                                                                                  "***subject***"     => $args -> {"subject"},
                                                                                  "***message***"     => $args -> {"message"},
                                                                                  "***delaysend***"   => $args -> {"delaysend"} ? 'checked="checked"' : "",
                                                                                  "***delay***"       => $self -> {"template"} -> humanise_seconds($self -> {"settings"} -> {"config"} -> {"Core:delaysend"}),
                                                                                  "***targmatrix***"  => $self -> build_target_matrix($args -> {"targset"}),
                                                                                  "***prefix***"      => $self -> build_prefix($args -> {"prefix"}),
                                                                              });
    # Need to store the message id, so the code knows which message to update.
    my $hiddenargs = $self -> {"template"} -> load_template("hiddenarg.tem", {"***name***"  => "msgid",
                                                                              "***value***" => $msgid});

    # Send back the form.
    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $body,
                                                               "***args***"    => $hiddenargs,
                                                               "***block***"   => $self -> {"block"}});
}


## @method $ generate_message_confirmform($msgid, $args)
# Generate a form from which the user may opt to send the message, or go back and edit it.
#
# @param msgid The ID of the message being viewed.
# @param args  A reference to a hash containing the message data.
# @return A form the user may used to confirm the message or go to edit it.
sub generate_message_confirmform {
    my $self  = shift;
    my $msgid = shift;
    my $args  = shift || { };
    my $tem;

    $tem -> {"cc"}  = $self -> {"template"} -> load_template("blocks/message_confirm_cc.tem");
    $tem -> {"bcc"} = $self -> {"template"} -> load_template("blocks/message_confirm_bcc.tem");

    my $outfields;
    # work out the bcc/cc fields....
    foreach my $mode ("cc", "bcc") {
        for(my $i = 0; $i < 4; ++$i) {
            # Append the cc/bcc if it is set...
            $outfields -> {$mode} .= $self -> {"template"} -> process_template($tem -> {$mode}, {"***data***" => $args -> {$mode} -> [$i]})
                if($args -> {$mode} -> [$i]);
        }
    }

    # Get the prefix sorted
    if($args -> {"prefix"} == 0) {
        $outfields -> {"prefix"} = $args -> {"prefixother"};
    } else {
        my $prefixh = $self -> {"dbh"} -> prepare("SELECT prefix FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                                   WHERE id = ?");
        $prefixh -> execute($args -> {"prefix"})
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix query: ".$self -> {"dbh"} -> errstr);

        my $prefixr = $prefixh -> fetchrow_arrayref();
        $outfields -> {"prefix"} = $prefixr ? $prefixr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADPREFIX");
    }

    $outfields -> {"delaysend"} = $self -> {"template"} -> load_template($args -> {"delaysend"} ? "blocks/message_edit_delay.tem" : "blocks/message_edit_nodelay.tem",
                                                                         {"***delay***" => $self -> {"template"} -> humanise_seconds($self -> {"settings"} -> {"config"} -> {"Core:delaysend"})});

    # And build the message block itself. Kinda big and messy, this...
    my $body = $self -> {"template"} -> load_template("blocks/message_confirm.tem", {"***targmatrix***"  => $self -> build_target_matrix($args -> {"targset"}, 1),
                                                                                     "***cc***"          => $outfields -> {"cc"},
                                                                                     "***bcc***"         => $outfields -> {"bcc"},
                                                                                     "***prefix***"      => $outfields -> {"prefix"},
                                                                                     "***subject***"     => $args -> {"subject"},
                                                                                     "***message***"     => $args -> {"message"},
                                                                                     "***delaysend***"   => $outfields -> {"delaysend"},
                                                                                 });

    # Need to store the message id, so the code knows which message to update.
    my $hiddenargs = $self -> {"template"} -> load_template("hiddenarg.tem", {"***name***"  => "msgid",
                                                                              "***value***" => $msgid});

    # Send back the form.
    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $body,
                                                               "***args***"    => $hiddenargs,
                                                               "***block***"   => $self -> {"block"}});
}


## @method $generate_login($error)
# Generate the 'login' block to send to the user. This will not prepopulate the form fields, even
# after the user has submitted and received an error - the user must fill in the details each time.
#
# @param error An error message to display in the login form.
# @return A string containing the login block.
sub generate_login {
    my $self  = shift;
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
        if($error);

    my $persist_length = $self -> {"session"} -> {"auth"} -> get_config("max_autologin_time");

    # Fix up possible modifiers
    $persist_length =~ s/s$/ seconds/;
    $persist_length =~ s/m$/ minutes/;
    $persist_length =~ s/h$/ hours/;
    $persist_length =~ s/d$/ days/;
    $persist_length =~ s/M$/ months/;
    $persist_length =~ s/y$/ years/;

    # And build the login block
    return $self -> {"template"} -> load_template("blocks/login.tem", {"***error***"      => $error,
                                                                       "***persistlen***" => $persist_length});
}


## @method $ generate_userdetails_form($args, $error, $info)
# Generate the form through which the user can set their details.
#
# @param args  A reference to a hash containing the user's details. This must also
#              minimally include a 'block' argument containing the id of the block
#              that should handle the form.
# @param error A string containing any error messages to show. This will be wrapped
#              in an error box for you.
# @param info  A string containing additional information to show before the form.
#              This will not be wrapped for you!
# @return A string containing the userdetails form.
sub generate_userdetails_form {
    my $self  = shift;
    my $args  = shift;
    my $error = shift;
    my $info  = shift;
    my $hiddenargs;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
        if($error);

    my $content = $self -> {"template"} -> load_template("blocks/user_details.tem", {"***info***"  => $info,
                                                                                     "***error***" => $error,
                                                                                     "***name***"  => $args -> {"realname"},
                                                                                     "***role***"  => $args -> {"rolename"}});
    # If we have a messageid in the args, add it as a hidden value
    $hiddenargs = $self -> {"template"} -> load_template("hiddenarg.tem", {"***name***"  => "msgid",
                                                                           "***value***" => $args -> {"msgid"}});

    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $content,
                                                               "***block***"   => $args -> {"block"},
                                                               "***args***"    => $hiddenargs});
}


# ============================================================================
#  Message send functions

sub send_message {
    my $self = shift;

}

1;
