## @file
# This file contains the implementation of the Noticeboard message list view.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    16 December 2011
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
package Noticeboard::ListView;

## @class Noticeboard::ListView
# A class to generate a HTML fragment containing a list of the
# month's messages.
use strict;
use base qw(NoticeboardBlock); # This class extends NoticeboardBlock

use Time::Local;

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

    # And now go through generating days...
    my $msgtem  = $self -> {"template"} -> load_template("noticeboard/listmsg.tem");
    my $daytem  = $self -> {"template"} -> load_template("noticeboard/listday.tem");
    my $days = "";

    foreach my $day (@{$messages}) {
        next if(!$day || ref($day) ne "ARRAY"); # We might get undefs here, so skip them, and skip anything that isn't an arrayref

        my $msglist = "";
        foreach my $msg (@{$day}) {
            # Truncate the message subject if needed
            $msg -> {"subject"} = substr($msg -> {"subject"}, 0, $self -> {"settings"} -> {"config"} -> {"ListView::subject_truncate"})."..."
                if($self -> {"settings"} -> {"config"} -> {"ListView::subject_truncate"} && length($msg -> {"subject"}) > $self -> {"settings"} -> {"config"} -> {"ListView::subject_truncate"});

            $msglist .= $self -> {"template"} -> process_template($msgtem, {"***id***"   => $msg -> {"id"},
                                                                            "***uid***"  => $msg -> {"user_id"},
                                                                            "***subj***" => $msg -> {"subject"},
                                                                            "***name***" => $msg -> {"realname"}});
        }

        $days .= $self -> {"template"} -> process_template($daytem, {"***day***" => $self -> {"template"} -> format_time(timegm(0, 0, 0, $day, $month - 1, $year), $self -> {"settings"} -> {"config"} -> {"ListView::day_format"}),




    return $self -> {"template"} -> load_template("noticeboard/listmonth.tem", {"***days***" => $days});
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
