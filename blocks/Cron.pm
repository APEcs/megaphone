## @file
# This file contains the implementation of the cron-triggered mail
# sender facility
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
package Cron;

## @class Cron
# This subclass of MegaphoneBlock implements the message send checks/
# operation required to allow messages to be sent after a delay.
#
use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock

# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # Ask the database for pending messages...
    my $pendh = $self -> {"dbh"} -> prepare("SELECT id FROM ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                             WHERE status = 'pending'
                                             ORDER BY updated ASC");
    $pendh -> execute()
        or $self -> {"logger"} -> die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message lookup: ".$self -> {"dbh"} -> errstr);

    my $body = '<div class="cron">Checking messages.<br/>';
    while(my $msgrow = $pendh -> fetchrow_arrayref()) {
        $body .= "Checking message ".$msgrow -> [0]."... ";
        $body .= $self -> send_message($msgrow -> [0]) ? "sent" : "delay active";
        $body .= "<br/>\n";
    }
    $body .= "Done.</div>";

    # Done sending, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $self -> {"template"} -> replace_langvar("CRON_TITLE"),
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***sitewarn***"  => $self -> generate_sitewarn(),
                                                               "***extrahead***" => "",
                                                               "***content***"   => $body});
}

1;
