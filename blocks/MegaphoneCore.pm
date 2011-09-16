## @file
# This file contains the implementation of the core megaphone features.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    15 Sept 2011
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
package MegaphoneCore;

use strict;
use base qw(Block); # This class extends Block
use MIME::Base64;   # Needed for base64 encoding of popup bodies.


# ============================================================================
#  Frgment generators

## @method $ build_target_matrix($activelist)
# Generate the table containing the target/recipient matrix. This will generate
# a table listing the supported targets horizontally, and the supported recipients
# vertically. Each cell in the table may either contain a checkbox (indicating
# that the system can send to the recipient via that system), or a cross (indicating
# that the recipient can not be contacted via that system).
#
# @param activelist A reference to an array of selected target/recipient combinations.
# @return A string containing the target/recipient matrix
sub build_target_matrix {
    my $self       = shift;
    my $activelist = shift;

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
    my $reciptem      = $self -> {"template"} -> load_template("matrix/recipient.tem");
    my $recipentrytem = $self -> {"template"} -> load_template("matrix/reciptarg.tem");
    my $recipacttem   = $self -> {"template"} -> load_template("matrix/reciptarg-active.tem");
    my $recipinacttem = $self -> {"template"} -> load_template("matrix/reciptarg-inactive.tem");

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
                # Yes, output a checkbox...
                $data .= $self -> {"template"} -> process_template($recipentrytem, {"***data***" => $self -> {"template"} -> process_template($recipacttem, {"***id***"      => $matrow -> [0],
                                                                                                                                                             "***checked***" => $activehash -> {$matrow -> [0]} ? 'checked="checked"' : ""})});
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

## @method $ validate_login()
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


# ============================================================================
#  Content generation functions

## @method $ generate_message($args, $error)
# Generate the 'message' block to send to the user. This will wrap any specified
# error in an appropriate block before inserting it into the message block. Any
# arguments set in the provided args hash are filled in on the form.
#
# @param args  A reference to a hash containing the default values to show in the form.
# @param error An error message to show at the start of the form.
# @return A string containing the message block.
sub generate_message {
    my $self  = shift;
    my $args  = shift || { };
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error.tem", {"***message***" => $error})
        if($error);

    # And build the message block itself. Kinda big and messy, this...
    return $self -> {"template"} -> load_template("blocks/message.tem", {"***error***"       => $error,
                                                                         "***cc1***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [0]  : "",
                                                                         "***cc2***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [1]  : "",
                                                                         "***cc3***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [2]  : "",
                                                                         "***cc4***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [3]  : "",
                                                                         "***bcc1***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [0] : "",
                                                                         "***bcc2***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [1] : "",
                                                                         "***bcc3***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [2] : "",
                                                                         "***bcc4***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [3] : "",
                                                                         "***prefixother***" => $args -> {"prefixother"},
                                                                         "***subject***"     => $args -> {"subject"},
                                                                         "***message***"     => $args -> {"message"},
                                                                         "***delaysend***"   => $args -> {"delaysend"} ? 'checked="checked"' : "",
                                                                         "***delay***"       => $self -> {"template"} -> humanise_seconds($self -> {"settings"} -> {"config"} -> {"Core:delaysend"}),
                                                                         "***targmatrix***"  => $self -> build_target_matrix($args -> {"targset"}),
                                                                         "***prefix***"      => $self -> build_prefix($args -> {"prefix"}),
                                                                     });
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
    $error = $self -> {"template"} -> load_template("blocks/error.tem", {"***message***" => $error})
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


## @method $ generate_message_form($args, $login_errors, $form_errors)
# Generate the content of the message form, optionally including the login block
# if the user has not yet logged in.
#
# @param args         A reference to a hash containing the arguments to prepopulate the message form with.
# @param login_errors A string containing errors related to logging in, or undef.
# @param form_errors  A string containing errors related to the message form itself.
# @return A string containing the message form.
sub generate_message_form {
    my $self         = shift;
    my $args         = shift;
    my $login_errors = shift;
    my $form_errors  = shift;
    my $content      = "";

    # If we do not have a session user, we need the login block
    $content .= $self -> generate_login($login_errors)
        if(!$self -> {"session"} -> {"sessuser"} || ($self -> {"session"} -> {"sessuser"} == $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}));

    $content .= $self -> generate_message($args, $form_errors);

    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $content,
                                                               "***args***"    => ""});
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content);

    # If we have no submission, just send the blank form...
    if(!$self -> {"cgi"} -> param()) {
        $title   = $self -> {"template"} -> replace_langvar("MESSAGE_TITLE");
        $content = $self -> generate_message_form();

    # User has submitted the message form, process it.
    } elsif($self -> {"cgi"} -> param("sendmsg") {
        my ($user, $login_errors, $args, $form_errors);

        # If we have no real user in the session, the first thing to do is validate the login
        if(!$self -> {"session"} -> {"sessuser"} || ($self -> {"session"} -> {"sessuser"} == $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"})) {
            ($user, $login_errors) = $self -> validate_login();

            # If we have a user, create the new session
            $self -> {"session"} -> create_session($user -> {"user_id"}, $self -> {"cgi"} -> {"persist"});

        # We already have a user, get their data as we need it later...
        } else {
            $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});
        }

        # Now check the form contents...
        ($args, $form_errors) = $self -> validate_message();

        # Okay, if we have form or login errors, we need to send the form back...
        if($login_errors || $form_errors) {
            $title   = $self -> {"template"} -> replace_langvar("MESSAGE_TITLE");
            $content = $self -> generate_message_form($args, $login_errors, $form_errors);

        # Form contents are good. Now we can store the message...
        } else {
            my $msgid = $self -> store_message($user, $args);


        }
    # user has submitted the name/role form...
    } elsif($self -> {"cgi"} -> param("setname")) {

    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"   => $title,
                                                               "***content***" => $content});

}

1;
