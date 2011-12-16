## @file
# This file contains the implementation of the Noticeboard calendar view.
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
package Noticeboard::CalendarView;

## @class Noticeboard::CalendarView
# A class to generate a HTML fragment containing a calendar view of the
# month's messages.
use strict;
use base qw(NoticeboardBlock); # This class extends NoticeboardBlock

use Calendar::Simple; # This makes generating the calendar block much less fiddly...

my @day_names = ( "CALVIEW_SUN",
                  "CALVIEW_MON",
                  "CALVIEW_TUE",
                  "CALVIEW_WED",
                  "CALVIEW_THU",
                  "CALVIEW_FRI",
                  "CALVIEW_SAT" );

# ============================================================================
#  Calendar functions

## @method $ generate($month, $year)
# Generate the content to show in the calendar view area of the Noticeboard UI.
#
# @param month The month of the calendar to generate.
# @param year  The year of the calendar to generate.
# @return A string containing the generated calendar.
sub generate {
    my $self  = shift;
    my $month = shift;
    my $year  = shift;

    # Obtain the list of messages wthin the specified month and year
    my $messages = $self -> get_month_messages($month, $year);

    # Ask Calendar::Simple for the structure of the month. This saves a lot of
    # faffing around...
    my $calendar = calendar($month, $year, $self -> {"settings"} -> {"config"} -> {"Noticeboard::week_start"});

    # Get today's date bits, as they are needed later...
    my ($nowday, $nowmon, $nowyear) = (localtime())[3,4,5];
    $nowmon += 1; $nowyear += 1900;

    # Build the day header
    my $headtem = $self -> {"template"} -> load_template("noticeboard/calendarhead.tem");
    my $first   = $self -> {"settings"} -> {"config"} -> {"Noticeboard::week_start"} || 0;
    my $dayhead = "";
    for(my ($day, $dnum) = (0, $first); $day < 7; ++$day, ++$dnum) {
        $dayhead .= $self -> {"template"} -> process_template($headtem, {"***day***" => $self -> {"template"} -> replace_langvar($day_names[$dnum % 7])});
    }

    # Now the days and weeks
    my $msgtem  = $self -> {"template"} -> load_template("noticeboard/calendarmsg.tem");
    my $daytem  = $self -> {"template"} -> load_template("noticeboard/calendarday.tem");
    my $weektem = $self -> {"template"} -> load_template("noticeboard/calendarweek.tem");
    my $weeks = "";
    foreach my $week (@{$calendar}) {
        my $weekdays = "";
        foreach my $day (@{$week}) {
            my $mode = "noday";
            my $msglist = "";

            # day mau be undef (before the start of the month/after the end)
            if($day) {
                $mode = "day";

                # Any messages posted on this day?
                if($messages -> [$day]) {
                    foreach my $msg (@{$messages -> [$day]}) {
                        # Truncate the message subject if needed
                        $msg -> {"subject"} = substr($msg -> {"subject"}, 0, $self -> {"settings"} -> {"config"} -> {"Noticeboard::subject_truncate"})."..."
                            if($self -> {"settings"} -> {"config"} -> {"Noticeboard::subject_truncate"} && length($msg -> {"subject"}) > $self -> {"settings"} -> {"config"} -> {"Noticeboard::subject_truncate"});

                        $msglist .= $self -> {"template"} -> process_template($msgtem, {"***id***"   => $msg -> {"id"},
                                                                                       "***uid***"  => $msg -> {"user_id"},
                                                                                       "***subj***" => $msg -> {"subject"},
                                                                                       "***name***" => $msg -> {"realname"}});
                    }
                }
            }
            $weekdays .= $self -> {"template"} -> process_template($daytem, {"***daynum***"  => $day,
                                                                             "***active***"  => ($day == $nowday && $month == $nowmon && $year == $nowyear) ? "active" : "",
                                                                             "***daymode***" => $mode,
                                                                             "***msglist***" => $msglist});
        }
        $weeks .= $self -> {"template"} -> process_template($weektem, {"***days***" => $weekdays});
    }

    return $self -> {"template"} -> load_template("noticeboard/calendarmonth.tem", {"***weeks***"   => $weeks,
                                                                                    "***dayhead***" => $dayhead});
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    my ($month, $year) = $self -> get_date();

    print $self -> {"cgi"} -> header(-charset => 'utf-8');
    print $self -> generate($month, $year);
    exit;
}


1;
