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
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock
use Logging qw(die_log);
use Utils qw(is_defined_numeric);


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
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
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
                                                               "***args***"    => "",
                                                               "***block***"   => $self -> {"block"}});
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
    } elsif($self -> {"cgi"} -> param("sendmsg")) {
        my ($user, $login_errors, $args, $form_errors);

        # If we have no real user in the session, the first thing to do is validate the login
        if(!$self -> {"session"} -> {"sessuser"} || ($self -> {"session"} -> {"sessuser"} == $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"})) {
            ($user, $login_errors) = $self -> validate_login();

            # If we have a user, create the new session
            $self -> {"session"} -> create_session($user -> {"user_id"}, $self -> {"cgi"} -> {"persist"}) if($user);

        # We already have a user, get their data as we need it later...
        } else {
            $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});
        }

        # Now check the form contents...
        ($args, $form_errors) = $self -> validate_message();

        # Okay, if we have form or login errors, or we're still anonymous, we need to send the form back...
        if($login_errors || $form_errors || !$user || ($self -> {"session"} -> {"sessuser"} == $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"})) {
            $title   = $self -> {"template"} -> replace_langvar("MESSAGE_TITLE");
            $content = $self -> generate_message_form($args, $login_errors, $form_errors);

        # Form contents are good. Now we can store the message...
        } else {
            my $msgid = $self -> store_message($args, $user);

            # If we have user name and role set, we're done
            if($user -> {"realname"} && $user -> {"rolename"}) {
                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_CONFIRM");
                $content = $self -> generate_message_confirmform($msgid, $args);

            # No user details - we need to poke the user to get the details set
            } else {
                $title   = $self -> {"template"} -> replace_langvar("DETAILS_TITLES");
                $content = $self -> generate_userdetails_form({"msgid" => $msgid,
                                                               "block" => $self -> {"block"}}, undef, $self -> {"template"} -> load_template("blocks/new_user.tem"));
            }
        }

    # Everything else requires a non-anonymous session
    } elsif($self -> {"session"} -> {"sessuser"} && ($self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"})) {

        # Get the message id...
        my $msgid = is_defined_numeric($self -> {"cgi"}, "msgid");
        return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_NOMSGID")) if(!$msgid);

        # We need the user's details too
        my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

        # Get the message data
        my $message = $self -> get_message($msgid);
        return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_BADMSGID")) if(!$message);

        # Check that the user isn't trying to be a smartarse and mess with an old message here...
        return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_MSGSENT")) 
            unless($message -> {"status"} eq "incomplete" || $message -> {"status"} eq "pending");

        # Check that the user actually has permission to edit the message (message owner, or admin)...
        return $self -> generate_fatal($self -> {"template"} -> replace_langvar("FATAL_MSGEDIT_PERMERROR")) 
            unless($message -> {"user_id"} == $user -> {"user_id"} || $user -> {"user_type"} == 3);

        # user has submitted the name/role form...
        if($self -> {"cgi"} -> param("setname")) {
            # Check the details the user submitted, send back the form if they messed up...
            my ($args, $errors) = $self -> validate_userdetails();

            # We need to make sure we have a few values in $args, even if validation failed, so add them now
            $args -> {"msgid"}   = $msgid;
            $args -> {"block"}   = $self -> {"block"};
            $args -> {"user_id"} = $self -> {"session"} -> {"sessuser"};

            # Did the user mess up their details?
            if($errors) {
                $title   = $self -> {"template"} -> replace_langvar("DETAILS_TITLES");
                $content = $self -> generate_userdetails_form($args, $errors);
            } else {
                # Details were valid, update them and then give the user the confirm form.
                $self -> update_userdetails($args);

                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_CONFIRM");
                $content = $self -> generate_message_confirmform($msgid, $message);
            }
        # Has the user asked to update the message?
        } elsif($self -> {"cgi"} -> param("editmsg")) {
            $title   = $self -> {"template"} -> replace_langvar("MESSAGE_EDIT");
            $content = $self -> generate_message_editform($msgid, $message);

        # Has the user submitted the update form?
        } elsif($self -> {"cgi"} -> param("updatemsg")) {
            # check the form contents...
            my ($args, $form_errors) = $self -> validate_message();

            # If we have errors, send back the edit form...
            if($form_errors) {
                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_EDIT");
                $content = $self -> generate_message_editform($msgid, $args, $form_errors);

            # Otherwise, update the message and send back the confirm
            } else {
                # Update the message, note the change to the msgid here!!
                $msgid = $self -> update_message($msgid, $args, $user);

                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_CONFIRM");
                $content = $self -> generate_message_confirmform($msgid, $args);
            }
        # Has the user confirmed message send?
        } elsif($self -> {"cgi"} -> param("dosend")) {
            $self -> send_message($msgid);

            $title   = $self -> {"template"} -> replace_langvar("MESSAGE_COMPLETE");
            $content = $self -> {"template"} -> load_template("blocks/message_done.tem");
        }

    # Has the user's session borken?
    } else {
        $title   = $self -> {"template"} -> replace_langvar("MESSAGE_TITLE");
        $content = $self -> generate_message_form();
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $title,
                                                               "***extrahead***" => "",
                                                               "***content***"   => $content});

}

1;
