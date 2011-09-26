## @file
# This file contains the implementation of the moodle message target.
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
package Target::Moodle;

## @class
# A moodle target implementation. Supported arguments are:
#
# forum_id=<fid>,course_id=<cid>,prefix=<1/0>;
#
# If multiple forum_id/course_id arguments are specified, this will
# insert the message into each forum. the prefix is completely optional,
# and defaults to 0, if true then the subject prefix for the message is
# included in the moodle discussion subject.

use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock

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

    if($self) {
        # If there are any arguments to convert, split and store
        if($self -> {"args"}) {
            my @args = split(/;/, $self -> {"args"});

            $self -> {"args"} = [];
            foreach my $arg (@args) {
                my @argbits = split(/,/, $arg);

                my $arghash = {};
                foreach my $argbit (@argbits) {
                    my ($name, $value) = $argbit =~ /^(\w+)=(.*)$/;
                    $arghash -> {$name} = $value;
                }

                push(@{$self -> {"args"}}, $arghash);
            }
        }
    }
    return $self;
}


# ============================================================================
#  Moodle interaction

## @method $ get_moodle_userid($username)
# Obtain the moodle record for the user with the specified username.
#
# @param username The username of the user to find in moodle's database.
# @return The requested user's userid, or undef if the user does not exist.
sub get_moodle_userid {
    my $self     = shift;
    my $username = shift;

    # Pretty simple query, really...
    my $userh = $self -> {"moodle"} -> prepare("SELECT id FROM ".$self -> {"settings"} -> {"config"} -> {"Target::Moodle:users"}."
                                                WHERE username LIKE ?");
    $userh -> execute($username)
        or die_log($self -> {"cgi"} -> remote_host(), "Target::Moodle: Unable to execute user query: ".$self -> {"moodle"} -> errstr);

    my $user = $userh -> fetchrow_arrayref();

    return $user ? $user -> [0] : undef;
}


# ============================================================================
#  Message send functions

## @method $ send($message)
# Attempt to send the specified message as a moodle forum post.
#
# @param message A reference to a hash containing the message to send.
# @return undef on success, an error message on failure.
sub send {
    my $self    = shift;
    my $message = shift;

    # Get the user's data
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($message -> {"user_id"});
    die_log($self -> {"cgi"} -> remote_host(), "Unable to get user details for message ".$message -> {"id"}) if(!$user);

    # Open the moodle database connection.
    $self -> {"moodle"} = DBI->connect($self -> {"settings"} -> {"config"} -> {"Target::Moodle:database"},
                                       $self -> {"settings"} -> {"config"} -> {"Target::Moodle:username"},
                                       $self -> {"settings"} -> {"config"} -> {"Target::Moodle:password"},
                                       { RaiseError => 0, AutoCommit => 1, mysql_enable_utf8 => 1 })
        or die_log($self -> {"cgi"} -> remote_host(), "Target::Moodle: Unable to connect to database: ".$DBI::errstr);

    # Look up the user in moodle's user table
    my $moodleuser = $self -> get_moodle_userid($user -> {"username"});

    # If we have no user, fall back on the, um, fallback...
    my $fallback = 0;
    if(!$moodleuser) {
        $fallback = 1;
        $moodleuser = $self -> get_moodle_user($self -> {"settings"} -> {"config"} -> {"Target::Moodle:fallback_user"})
            or die_log($self -> {"cgi"} -> remote_host(), "Target::Moodle: Unable to obtain a moodle user (username and fallback failed)");
    }

    # Precache queries
    my $discussh = $self -> {"moodle"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"config"} -> {"Target::Moodle:discussions"}."
                                                   (course, forum, name, userid, timemodified, usermodified)
                                                   VALUES(?, ?, ?, ?, ?, ?)");

    my $posth   =  $self -> {"moodle"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"config"} -> {"Target::Moodle:posts"}."
                                                  (discussion, userid, created, modified, subject, message)
                                                  VALUES(?, ?, ?, ?, ?, ?)");

    my $updateh = $self -> {"moodle"} -> prepare("UPDATE ".$self -> {"settings"} -> {"config"} -> {"Target::Moodle:discussions"}."
                                                  SET firstpost = ?
                                                  WHERE id = ?");

    # Go through each moodle forum, posting the message there.
    foreach my $arghash (@{$self -> {"args"}}) {
        # Get the prefix sorted if needed
        my $prefix = "";
        if($arghash -> {"prefix"}) {
            if($message -> {"prefix_id"} == 0) {
                $prefix = $message -> {"prefixother"};
            } else {
                my $prefixh = $self -> {"dbh"} -> prepare("SELECT prefix FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                                   WHERE id = ?");
                $prefixh -> execute($message -> {"prefix_id"})
                    or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix query: ".$self -> {"dbh"} -> errstr);

                my $prefixr = $prefixh -> fetchrow_arrayref();
                $prefix = $prefixr ? $prefixr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADPREFIX");
            }
            $prefix .= " " if($prefix);
        }

        # Timestamp for posting is now
        my $now = time();

        # Make the discussion
        $discussh -> execute($arghash -> {"course_id"},
                             $arghash -> {"forum_id"},
                             $prefix.$message -> {"subject"},
                             $moodleuser,
                             $now,
                             $moodleuser)
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute discussion insert query: ".$self -> {"moodle"} -> errstr);

        # Get the discussion id
        my $discussid = $self -> {"moodle"} -> {"mysql_insertid"};
        die_log($self -> {"cgi"} -> remote_host(), "Unable to get ID of new discussion. This should not happen.") if(!$discussid);

        # Post the message body
        $posth -> execute($discussid, $moodleuser, $now, $now, $prefix.$message -> {"subject"}, $message -> {"message"})
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute post insert query: ".$self -> {"moodle"} -> errstr);

        # Get the post id..
        my $postid = $self -> {"moodle"} -> {"mysql_insertid"};
        die_log($self -> {"cgi"} -> remote_host(), "Unable to get ID of new post. This should not happen.") if(!$postid);

        # Update the discussion with the post id
        $updateh -> execute($postid, $discussid)
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute discussion update query: ".$self -> {"moodle"} -> errstr);
    }

    # Done talking to moodle now.
    $self -> {"moodle"} -> disconnect();
}

1;
