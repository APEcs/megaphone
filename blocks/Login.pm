## @file
# This file contains the implementation of the 'stand-alone' login.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    19 Sept 2011
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
package Login;

## @class Login
# A 'stand alone' login implementation. This presents the user with a
# login form, checks the credentials they enter, and then redirects
# them back to the task they were performing that required a login.
use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock


# ============================================================================
#  Query string handling

## @method $ get_back($decode)
# Obtain the contents of the back argument, if it is present. This will determine whether
# the back cgi argument is set, and if it is whether it only contains base64 data. If
# both of these are true, this will return the string (optionally decoding it before
# returning). If the back is not present, or does not appear to be valid, this returns
# an empty string.
#
# @param decode If true, the back string is decoded before being returned. Defaults to false.
# @return The back string, or an empty string if the back is not present/valid.
sub get_back {
    my $self   = shift;
    my $decode = shift;

    # back should contain the return query string if the user was doing anything beforehand
    my $back = $self -> {"cgi"} -> param("back") || "";

    # If there is a back, and it's valid base64, decode it
    if($back && $back =~ m|^[A-Za-z0-9+/=]+$|) {
        $back = $self -> {"session"} -> decode_querystring($back) if($decode);

        return $back;
    }

    # Otherwise, we want to just return "" to be safe
    return "";
}


# ============================================================================
#  Content generation functions

## @method $ generate_login_form($login_errors)
# Generate the content of the login form.
#
# @param login_errors A string containing errors related to logging in, or undef.
# @return A string containing the login form.
sub generate_login_form {
    my $self         = shift;
    my $login_errors = shift;

    # Store the back if we have it
    my $args = "";
    $args =  $self -> {"template"} -> load_template("hiddenarg.tem", {"***name***"  => "back",
                                                                      "***value***" => $self -> get_back()});

    return ($self -> {"template"} -> replace_langvar("LOGIN_TITLE"),
            $self -> {"template"} -> load_template("form.tem", {"***content***" => $self -> generate_login($login_errors, 1),
                                                                "***args***"    => $args,
                                                                "***block***"   => $self -> {"block"}}),
            "");
}


## @method @ generate_loggedin()
# Generate the contents of a page telling the user that they have successfully logged in.
#
# @return An array of three values: the page title string, the 'logged in' message, and
#         a meta element to insert into the head element to redirect the user.
sub generate_loggedin {
    my $self = shift;

    my $url = "index.cgi?".$self -> get_back(1);

    my $content = $self -> {"template"} -> load_template("blocks/login_done.tem", {"***url***"    => $url,
                                                                                   "***return***" => $self -> {"template"} -> replace_langvar("LOGIN_REDIRECT", {"***url***" => $url})});

    # return the title, content, and extraheader
    return ($self -> {"template"} -> replace_langvar("LOGIN_TITLE"),
            $content,
            $self -> {"template"} -> load_template("refreshmeta.tem", {"***url***" => $url}));
}


## @method @ generate_loggedout()
# Generate the contents of a page telling the user that they have successfully logged out.
#
# @return An array of three values: the page title string, the 'logged out' message, and
#         a meta element to insert into the head element to redirect the user.
sub generate_loggedout {
    my $self = shift;

    my $url = "index.cgi?".$self -> get_back(1);

    my $content = $self -> {"template"} -> load_template("blocks/logout_done.tem", {"***url***"    => $url,
                                                                                    "***return***" => $self -> {"template"} -> replace_langvar("LOGOUT_REDIRECT", {"***url***" => $url})});

    # return the title, content, and extraheader
    return ($self -> {"template"} -> replace_langvar("LOGOUT_TITLE"),
            $content,
            $self -> {"template"} -> load_template("refreshmeta.tem", {"***url***" => $url}));
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $body, $extrahead) = ("", "", "");

    # If the user is not anonymous, they have logged in already. Bypass for 'setname' though
    if($self -> {"session"} -> {"sessuser"} && ($self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) && !$self -> {"cgi"} -> param("setname")) {

        # Is the user requesting a logout? If so, doo eet.
        if(defined($self -> {"cgi"} -> param("logout"))) {
            if($self -> {"session"} -> delete_session()) {
                ($title, $body, $extrahead) = $self -> generate_loggedout();
            } else {
                return $self -> generate_fatal($SessionHandler::errstr);
            }

        # Already logged in, huh. Send back the logged-in message to remind them...
        } else {
            ($title, $body, $extrahead) = $self -> generate_loggedin();
        }

    # User is anonymous - do we have a login?
    } elsif(defined($self -> {"cgi"} -> param("login"))) {

        # Validate the other fields...
        my ($user, $login_errors) = $self -> validate_login();

        # Do we have any errors? If so, send back the login form with them
        if($login_errors) {
            ($title, $body, $extrahead) = $self -> generate_login_form($login_errors, 1);

        # No errors, user is valid...
        } else {
            # create the new logged-in session
            $self -> {"session"} -> create_session($user -> {"user_id"}, $self -> {"cgi"} -> param("persist")) if($user);

            # Do we have realname/rolename for the user? If so, send the loggedin message...
            if($user -> {"realname"} && $user -> {"rolename"}) {
                ($title, $body, $extrahead) = $self -> generate_loggedin();

            # missing user details...
            } else {
                $title = $self -> {"template"} -> replace_langvar("DETAILS_TITLES");
                $body  = $self -> generate_userdetails_form({"block" => $self -> {"block"},
                                                             "back" => $self -> get_back()}, undef, $self -> {"template"} -> load_template("blocks/new_user.tem"));
            }
        }

    # Has user submitted the userdetails form?
    } elsif($self -> {"cgi"} -> param("setname")) {

        # Check the details the user submitted, send back the form if they messed up...
        my ($args, $errors) = $self -> validate_userdetails();

        # We need to make sure we have a few values in $args, even if validation failed, so add them now
        $args -> {"block"}   = $self -> {"block"};
        $args -> {"user_id"} = $self -> {"session"} -> {"sessuser"};

        # Did the user mess up their details?
        if($errors) {
            $title = $self -> {"template"} -> replace_langvar("DETAILS_TITLES");
            $body  = $self -> generate_userdetails_form($args, $errors);
        } else {
            # Details were valid, update them and then give the user the loggedin form.
            $self -> update_userdetails($args);

            ($title, $body, $extrahead) = $self -> generate_loggedin();
        }

    # No session, no submission? Send back the login form...
    } else {
        ($title, $body, $extrahead) = $self -> generate_login_form(undef, 1);
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $title,
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***sitewarn***"  => $self -> generate_sitewarn(),
                                                               "***extrahead***" => $extrahead,
                                                               "***content***"   => $body});
}

1;
