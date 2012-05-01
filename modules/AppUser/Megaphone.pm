## @file
# This file contains the implementation of the Megaphone application user class.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
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

## @class
package AppUser::Megaphone;

use strict;
use base qw(AppUser);

# ============================================================================
#  Pre- and Post-auth functions.

## @method $ pre_authenticate($username, $auth)
# Perform any system-specific pre-authentication tasks on the specified
# user. This function allows systems to tailor pre-auth tasks to the
# requirements of the system. For example, this may be used to check the
# username against a table of authorised users.
#
# @note The implementation provided here does no work, and simply returns
#       true in all cases.
#
# @param username The username of the user to perform pre-auth tasks on.
# @param auth     A reference to the auth object calling this.
# @return true if the authentication process should continue, false if the
#         user should not be authenticated or logged in. If this returns
#         false, an error message will be appended to the specified auth's
#         lasterr field.
sub pre_authenticate {
    my $self     = shift;
    my $username = shift;
    my $auth     = shift;

    my ($type, $html) = $self -> _authorised_user($username);

    # Doesn't really matter if $html is undef, as some users may not have it set anyway.
    # but $type needs to be set for a valid user. Note that this can not return $type as-is,
    # as '0' is a valid type!
    return defined($type);
}


## @method $ post_authenticate($username, $auth)
# Perform any system-specific post-authentication tasks on the specified
# user's data. This function allows each system to tailor post-auth tasks
# to the requirements of the system.
#
# @note The implementation provided here will create an empty user record
#       if one with the specified username does not already exist. The
#       user is initialised as a type 0 ('normal') user, with default
#       values for all the fields. If this behaviour is not required or
#       desirable, subclasses may wish to override this function completely.
#
# @param username The username of the user to perform post-auth tasks on.
# @param auth     A reference to the auth object calling this.
# @return A reference to a hash containing the user's data on success,
#         undef otherwise. If this returns undef, an error message will be
#         appended to the specified auth's lasterr field.
sub post_authenticate {
    my $self     = shift;
    my $username = shift;
    my $auth     = shift;

    # Call the superclass method to handle making sure the user exists
    my $user = $self -> SUPER::post_authenticate($username, $auth);

    # Otherwise make sure the user is set up
    return $self -> _set_user_details($user);
}


# ============================================================================
#  Internal functions

## @method private @ _authorised_user($username)
# Determine whether the user is allowed to use the web application.
# This will check the username against the authorised users table, and if the
# user is present this will return their user type. If the user is not listed
# in the authorised users table, this returns undef and they should not get
# access!
#
# @param username The username to check.
# @return the user's initial type and preset html if found, undef otherwise.
sub _authorised_user {
    my $self     = shift;
    my $username = shift;

    my $userh = $self -> {"dbh"} -> prepare("SELECT user_type, presethtml FROM ".$self -> {"settings"} -> {"database"} -> {"authorised"}."
                                             WHERE username LIKE ?");
    $userh -> execute($username)
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to look up user authorisation: ".$self -> {"dbh"} -> errstr);

    # If we have a user entry, return their type
    my $user = $userh -> fetchrow_arrayref();
    return ($user -> [0], $user -> [1]) if($user);

    return (undef, undef);
}


## @method private @ _set_user_details($user)
# Complete the setup of a user record by inserting their new type and presethtml.
# This will take the user type and presethtml data set in the user auth table and
# copy it into a newly created user's data. If the user has already been set up,
# this does nothing. Note that, if the data in the authorised users table has
# changed, this *will not* update the user's data to match, that must be done
# manually!
#
# @param user A reference to the user's database record hash.
# @return A reference to the user's database record hash on success, undef on
#         failure.
sub _set_user_details {
    my $self  = shift;
    my $user  = shift;

    # is the user's current type NULL (ie: not set up?) If so, set it up...
    if(!defined($user -> {"user_type"})) {
        # Get the user's settings from authorised
        my ($type, $html) = $self -> _authorised_user($user -> {"username"});

        my $userset = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                                   SET user_type = ?, presethtml = ?
                                                   WHERE user_id = ?");
        $userset -> execute($type, $html, $user -> {"user_id"})
            or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to updated new user record: ".$self -> {"dbh"} -> errstr);

        # Record the new settings
        $user -> {"user_type"} = $type;
        $user -> {"presethtml"} = $html;
    }

    return $user;
}

1;
