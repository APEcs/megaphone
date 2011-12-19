## @file
# This file contains the implementation of the core noticeboard features.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    13 December 2011
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
package NoticeboardCore;

## @class NoticeboardCore
# Implementation of the basic message browser interface. This presents
# the user with a calendar and message list from which they may view
# messages.
use strict;
use base qw(NoticeboardBlock); # This class extends Block
use Logging qw(die_log);
use Utils qw(is_defined_numeric);

# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    my ($month, $year) = $self -> get_date();

    # Load the support modules
    my $calendar = $self -> {"module"} -> new_module("calview");

    # very simple template load, doesn't need anything fancy here...
    return $self -> {"template"} -> load_template("noticeboard.tem", {"***extrahead***" => "",
                                                                      "***calview***"   => $calendar -> generate($month, $year),
                                                                     });
}

1;
