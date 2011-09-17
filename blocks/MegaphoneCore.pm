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
            my $msgid = $self -> store_message($args, $user);

            # If we have user name and role set, we're done
            if($user -> {"realname"} && $user -> {"rolename"}) {
                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_CONFIRM");
                $content = $self -> {"template"} -> load_template("blocks/message_confirm.tem");

            # No user details - we need to poke the user to get the details set
            } else {
                $title   = $self -> {"template"} -> replace_langvar("DETAILS_TITLES");
                $content = $self -> generate_userdetails_form({"msgid" => $msgid,
                                                               "block" => $self -> {"block"}}, undef, $self -> {"template"} -> load_template("blocks/new_user.tem"));
            }
        }

    # Everything else requires a non-anonymous session
    } elsif($self -> {"session"} -> {"sessuser"} && ($self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"})) {

        # user has submitted the name/role form...
        if($self -> {"cgi"} -> param("setname")) {
            # Check the details the user submitted, send back the form if they messed up...
            my ($args, $errors) = $self -> validate_userdetails();

            # We need to make sure we have a few values in $args, even if validation failed, so add them now
            $args -> {"msgid"} = is_defined_numeric($self -> {"cgi"}, "msgid");
            die_log($self -> {"cgi"} -> remote_host(), "Message Id vanished during user details form. This should not happen!") if(!$args -> {"msgid"});

            $args -> {"block"}   = $self -> {"block"};
            $args -> {"user_id"} = $self -> {"session"} -> {"sessuser"};

            if($errors) {
                $title   = $self -> {"template"} -> replace_langvar("DETAILS_TITLES");
                $content = $self -> generate_userdetails_form($args, $errors);
            } else {
                $self -> update_userdetails($args);

                $title   = $self -> {"template"} -> replace_langvar("MESSAGE_CONFIRM");
            $content = $self -> {"template"} -> load_template("blocks/message_confirm.tem");
            }

            # Has the user confirmed message send?
        } elsif($self -> {"cgi"} -> param("dosend")) {
            # Get the message id...
            my $msgid = is_defined_numeric($self -> {"cgi"}, "msgid");
            die_log($self -> {"cgi"} -> remote_host(), "Message Id vanished during confirm form. This should not happen!") if(!$msgid);

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
    return $self -> {"template"} -> load_template("page.tem", {"***title***"   => $title,
                                                               "***content***" => $content});

}

1;
