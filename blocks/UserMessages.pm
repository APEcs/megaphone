## @file
# This file contains the implementation of the user message manipulation code.
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
package UserMessages;

use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock
use Logging qw(die_log);



# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content) = ("", "");

    # User must be logged in before we can do anything else
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        # Get the user's data, as it'll be needed...
        my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

        $title = $self -> {"template"} -> replace_langvar("MSGLIST_TITLE");
        $content .= $self -> generate_userdetails_form({"realname" => $user -> {"realname"},
                                                        "rolename" => $user -> {"rolename"},
                                                        "block"    => $self -> {"block"}});
        $content .= $self -> generate_messagelist(); 

    # User has not logged in, force them to
    } else {
        my $url = "index.cgi?block=".$self -> {"module"} -> get_block_id('login')."&amp;back=".$self -> {"session"} -> encode_querystring($self -> {"cgi"} -> query_string());

        print $self -> {"cgi"} -> redirect($url);
        exit;
    }

    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $title,
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***extrahead***" => "",
                                                               "***content***"   => $content});

}


1;
