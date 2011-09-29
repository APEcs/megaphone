## @file
# This file contains the implementation of the target base class.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    29 Sept 2011
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
package Target::Target;

use strict;
use base qw(MegaphoneBlock); # This class extends MegaphoneBlock

## @class
# A base class for Target modules that provides minimal implementations
# of the interface functions expected by the core.

# ============================================================================
#  General interface functions

## @method void set_config($args)
# Set the current configuration to the module to the values in the provided
# args string.
#
# @param args A string containing the new configuration.
sub set_config {
    my $self = shift;
    my $args = shift;

}


## @method $ generate_message($args, $user)
# Generate the string to insert into the message.tem target hook region for
# this target.
#
# @param args A reference to a hash of arguments to use in the form
# @param user A reference to a hash containing the user's data
# @return A string containing the message form fragment.
sub generate_message {
    my $self = shift;
    my $args = shift;
    my $user = shift;

    # This target has no special options.
    return "";
}

1;
