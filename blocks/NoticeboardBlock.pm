## @file
# This file contains the implementation of the core noticeboard features.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    14 December 2011
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
package NoticeboardBlock;

## @class NoticeboardBlock
# The 'base' class for all Noticeboard blocks. This extends the Megaphone
# block class with additional functions common to all Noticeboard UI and
# backend modules.
use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock

use Date::Pcalc qw(Days_In_Month);
use Time::Local;

# ============================================================================
#  Month and year lookup and verification functions

## @method @ get_minmax_years()
# Obtain the minimum and maximum years present in the message table. This will
# get the first and last years for which there are sent messages in the database.
#
# @return An array containing the first and last years for which there are sent
#         messages.
sub get_minmax_years {
    my $self = shift;

    my $msgh = $self -> {"dbh"} -> prepare("SELECT MIN(sent),MAX(sent) FROM ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                            WHERE send IS NOT NULL");
    $msgh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message lookup query: ".$self -> {"dbh"} -> errstr);

    my $dates = $msgh -> fetchrow_arrayref();
    my $minyear = 1900 + (localtime($dates -> [0]))[5];
    my $maxyear = 1900 + (localtime($dates -> [1]))[5];

    return ($minyear, $maxyear);
}


## @method $ valid_year($year)
# Determine whether the specified year corresponds to a year in which messages have
# been posted.
#
# @param year The year (including century) to check.
# @return true if one or more messages were posted during the specified year, false otherwise.
sub valid_year {
    my $self = shift;
    my $year = shift;

    my ($miny, $maxy) = $self -> get_minmax_years();
    return ($year >= $miny && $year <= $maxy);
}


## @method @ get_date_bymsgid($id)
# Given a message id, attempt to obtain the month and year the message was posted in.
# This looks up the message with the specified id and works out the month and year
# of posting based on its 'sent' date. If the id does not correspond to a stored
# message, or the message has no sent date, this will fall back on the current
# day and month.
#
# @param id The id of the message to obtain the posting date for.
# @return The month (in the range 1 to 12), and the year (including century)
#         in which the message was posted, or the current month and year.
sub get_date_bymsgid {
    my $self = shift;
    my $id   = shift;

    # Start off with the current time, this will be the default if message
    # lookup fails.
    my $timestamp = time();

    # Query to look up the message. Don't bother using $self -> get_message(), as
    # that will do a load of work that isn't needed for this function.
    my $msgh = $self -> {"dbh"} -> prepare("SELECT sent FROM ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                            WHERE id = ?");
    $msgh -> execute($id)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message lookup query: ".$self -> {"dbh"} -> errstr);

    my $message = $msgh -> fetchrow_arrayref();
    $timestamp = $message -> [0] if($message && $message -> [0]);

    # Get the month and year, and fix them so that they are sane
    my @date (localtime($timestamp))[4, 5];
    $date[0] += 1; $date[1] += 1900;

    return @date;
}


## $method @ get_date()
# Obtain the month and year to show in the calendar. This will check to see
# whether a message id has been specified, and if so it uses that to determine
# the month and year. If no message id has been given, any valid month or year
# given in the query will be used to determine the month and year. Invalid
# or missing month or year settings are replaced with the current month or year
# as appropriate.
#
# @return And array containing the month and year to show in the calendar. The
#         month is in the range 1 to 12, and the year includes the century.
sub get_date {
    my $self = shift;

    # The the query includes a message id, try to use that...
    my $msgid = is_defined_numeric($self -> {"cgi"}, "msgid");
    return get_date_bymsgid($msgid) if($msgid);

    # Get the current month and year for use as defaults
    my ($month, $year) = (localtime())[4, 5];
    $month += 1; $year += 1900;

    # Check whether valid month and year values have been given
    my $setmonth = is_defined_numeric($self -> {"cgi"}, "month");
    $month = $setmonth if($setmonth && $setmonth >= 1 && $setmonth <= 12);

    # Same for the year
    my $setyear = is_defined_numeric($self -> {"cgi"}, "year");
    $year = $setyear if($setyear && $self -> valid_year($year));

    return ($setmonth, $setyear);
}


## @method $ get_month_messages($month, $year)
# Obtain the messages posted during the specified month. This will obtain the
# id, subject, poster, and sent date for each message posted during the specified
# month.
#
# @param month The month to obtain messages for.
# @param year  The year in which the month occured.
# @return A reference to an array, one element for each day in the month. Each element
#         is either undef (no messages posted), or a reference to an array of message
#         hashes.
sub get_month_messages {
    my $self  = shift;
    my $month = shift;
    my $year  = shift;

    # Work out the start and end timestamps. Note that this should go from 00:00 on the first
    # of the month, to 23:59:59 on the last of the month.
    my $mintimestamp = timelocal(0, 0, 0, 1, $month - 1, $year);
    my $maxtimestamp = timelocal(59, 59, 23, Days_In_Month($year, $month), $month - 1, $year);

    # query to pull out the messages...
    my $msgh = $self -> {"dbh"} -> prepare("SELECT m.id, m.subject, m.sent, u.realname
                                            FROM ".$self -> {"settings"} -> {"database"} -> {"messages"}." AS m,
                                                 ".$self -> {"settings"} -> {"database"} -> {"users"}." AS u
                                            WHERE u.user_id = m.user_id
                                            AND m.status = 'sent'
                                            AND m.sent IS NOT NULL
                                            AND m.sent >= ?
                                            AND m.sent <= ?
                                            ORDER BY m.sent");
    $msgh -> execute($mintimestamp, $maxtimestamp)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message lookup query: ".$self -> {"dbh"} -> errstr);

    my $messages;
    # Store any messages posted during the month...
    while(my $message = $msgh -> fetchrow_hashref()) {
        # Work out which day of the month the post was made on
        my $day = (localtime($message -> {"sent"}))[3];

        # Store the message data in the day
        push(@{$messages -> [$day]}, $message);
    }

    return $messages;
}

1;
