## @file
# This file contains the implementation of the SSH authentication class.
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

## @class
# Implementation of a basic ssh authentication module. This will allow
# users to be authenticated against an arbitrary SSH-capable system. It
# is... less than perfect, especially if the response time from the server
# is lousy, but it beats the madness than is LDAP auth.
package SSHAuth;

use strict;
# Standard modules
use Net::SSH::Expect;
use Net::SSH::Perl;

# Custom module imports
use Logging qw(die_log);

# ============================================================================
#  Constructor

## @cmethod SSHAuth new(@args)
# Create a new SSHAuth object.
#
# @param args A hash of key, value pairs to initialise the object with.
# @return     A reference to a new SSHAuth object.
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = {
        cgi       => undef,
        dbh       => undef,
        settings  => undef,
        @_,
    };

    # Ensure that we have objects that we need
    return set_error("cgi object not set") unless($self -> {"cgi"});
    return set_error("dbh object not set") unless($self -> {"dbh"});
    return set_error("settings object not set") unless($self -> {"settings"});

    $self -> {"ANONYMOUS"} = $self -> {"settings"} -> {"config"} -> {"SSHAuth:anonymous"};

    return bless $self, $class;
}


# ============================================================================
#  Interface code

## @method $ get_config($name)
# Obtain the value for the specified configuration variable.
#
# @param name The name of the configuration variable to return.
# @return The value for the name, or undef if the value is not set.
sub get_config {
    my $self = shift;
    my $name = shift;

    # Make sure the configuration name starts with the appropriate module handle
    $name = "SSHAuth:$name" unless($name =~ /^SSHAuth:/);

    return $self -> {"settings"} -> {"config"} -> {$name};
}


## @method $ get_user_byid($userid, $onlyreal)
# Obtain the user record for the specified user, if they exist. This should
# return a reference to a hash of user data corresponding to the specified userid, 
# or undef if the userid does not correspond to a valid user. If the onlyreal
# argument is set, the userid must correspond to 'real' user - bots or inactive 
# users should not be returned.
#
# @param userid   The id of the user to obtain the data for.
# @param onlyreal If true, only users of type 0 or 3 are returned.
# @return A reference to a hash containing the user's data, or undef if the user
#         can not be located (or is not real)
sub get_user_byid {
    my $self     = shift;
    my $userid   = shift;
    my $onlyreal = shift;

    my $userh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                             WHERE user_id = ?".
                                            ($onlyreal ? " AND user_type IN (0,3)" : ""));
    $userh -> execute($userid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute user lookup query. Error was: ".$self -> {"dbh"} -> errstr);

    return $userh -> fetchrow_hashref();
}


## @method $ unique_id($extra)
# Obtain a unique ID number. This id number is guaranteed to be unique across calls, and
# may contain non-alphanumeric characters. The returned scalar may contain binary data.
#
# @param extra An extra string to append to the id before returning it.
# @return A unique ID. May contain binary data, is guaranteed to start with a number.
sub unique_id {
    my $self  = shift;
    my $extra = shift || "";

    # Potentially not atomic, but putting something in place that is really isn't worth it right now...
    my $id = $self -> {"settings"} -> {"config"} -> {"SSHAuth:unique_id"};
    $self -> {"settings"} -> set_db_config($self -> {"dbh"}, $self -> {"settings"} -> {"database"} -> {"settings"}, "SSHAuth:unique_id", ++$id);

    # Ask urandom for some randomness to combat potential problems with the above non-atomicity
    my $buffer;
    open(RND, "/dev/urandom")
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to open urandom: $!");
    read(RND, $buffer, 24);
    close(RND);

    # append the process id and random buffer to the id we got from the database. The
    # PID should be enough to prevent atomicity problems, the random junk just makes sure.
    return $id.$$.$buffer.$extra;
}


## @method $ valid_user($username, $password)
# Determine whether the specified user is valid, and obtain their user record.
# This will authenticate the user, and if the credentials supplied are valid, the
# user's internal record will be returned to the caller.
#
# @param username The username to check.
# @param password The password to check.
# @return A reference to a hash containing the user's data if the user is valid,
#         undef if the user is not valid. If this returns undef, the reason is
#         contained in $self -> {"lasterr"}
sub valid_user {
    my $self     = shift;
    my $username = shift;
    my $password = shift;

    # First, determine whether the user is valid
    return undef unless($self -> _ssh_valid_user($username, $password));

    # User is valid, can we get their data?
    my $user = $self -> _get_user_byusername($username);

    # If we have a user, our work is done
    return $user if($user);

    # No record for this user, need to make one...
    my $newuser = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                               (username, created, updated) 
                                               VALUES(?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())");
    $newuser -> execute($username)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to create new user record: ".$self -> {"dbh"} -> errstr);

    $user =  $self -> _get_user_byusername($username);
    
    # Got a new user okay? If so, return their record...
    return $user if($user);

    # Looks like addition failed...
    $self -> {"lasterr"} = "User addition failed.";
    return undef;
}


# ============================================================================
#  Internal stuff, do not use from elsewhere

## @method $ _get_user_byusername($username)
# Obtain the user with the specified username from the database. This will return the
# user's record in the database if they are found, undef otherwise.
#
# @param username The username of the user to obtain the data for.
# @return A reference to a hash containing the user's data, undef if the user can not be found.
sub _get_user_byusername {
    my $self     = shift;
    my $username = shift;

    my $userh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                             WHERE username LIKE ?");
    $userh -> execute($username)
        or die_log($self -> {"cgi"} -> remote_host(), "FATAL: Unable to query database for user record: ".$self -> {"dbh"} -> errstr);

    return $userh -> fetchrow_hashref();
}


## @method $ _ssh_valid_user($username, $password)
# Attempt to authenticate the user against the ssh server. This will check the user's
# login against the configured ssh server, and return true if the login is valid.
#  
# @param username The username to check against the server.
# @param password The password to check against the server.
# @return true if the login is valid, false otherwise. If the return value is false,
#         $self -> {"lasterr"} contains the response from the ssh server.
sub _ssh_valid_user {
    my $self     = shift;
    my $username = shift;
    my $password = shift;

    $self -> {"lasterr"} = "";
    if($username && $password) {
        my $ssh = Net::SSH::Expect -> new(host     => $self -> {"settings"} -> {"config"} -> {"SSHAuth:server"},
                                          user     => $username,
                                          password => $password,
                                          raw_pty  => 1,
                                          timeout  => $self -> {"settings"} -> {"config"} -> {"SSHAuth:timeout"},
                                          binary   => $self -> {"settings"} -> {"config"} -> {"SSHAuth:binary"});
        my $resp = $ssh -> login();
        $resp =~ s/\s//g;
        $ssh -> close();

        if($resp =~ /Welcome/ || $resp =~ /Last\s*login/s) {
            return 1;
        } else {
            $self -> {"lasterr"} = "ssh login to ".$self -> {"settings"} -> {"config"} -> {"SSHAuth:server"}." failed. Response was: $resp";
        }
    }

    return 0;
}

1;
