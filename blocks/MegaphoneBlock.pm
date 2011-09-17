## @file
# This file contains the implementation of the core megaphone features.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    17 Sept 2011
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
package MegaphoneBlock;

use strict;
use base qw(Block); # This class extends Block
use Logging qw(die_log);


# ============================================================================
#  Storage

## @method void update_userdetails($args)
# Update the details for the specified user. The args hash must minimally contain
# the user's realname, rolename, and user_id.
#
# @param args The arguments to set for the user.
sub update_userdetails {
    my $self = shift;
    my $args = shift;

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                               SET realname = ?, rolename = ?
                                               WHERE user_id = ?");
    $updateh -> execute($args -> {"realname"}, $args -> {"rolename"}, $args -> {"user_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute user details update: ".$self -> {"dbh"} -> errstr);
}


# ============================================================================
#  Validation functions

## @method @ validate_userdetails()
# Determine whether the details provided by the user are valid.
#
# @return An array of two values: the first is a reference to a hash containing the
#         data submitted by the user, the second is either undef or an error message.
sub validate_userdetails {
    my $self = shift;
    my ($args, $errors, $error) = ({}, "", "");

    # template for errors...
    my $errtem = $self -> {"template"} -> load_template("blocks/error_entry.tem");

    ($args -> {"realname"}, $error) = $self -> validate_string("name", {"required" => 1,
                                                                        "nicename" => $self -> {"template"} -> replace_langvar("DETAILS_NAME"),
                                                                        "minlen"   => 1,
                                                                        "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    ($args -> {"rolename"}, $error) = $self -> validate_string("role", {"required" => 1,
                                                                        "nicename" => $self -> {"template"} -> replace_langvar("DETAILS_ROLE"),
                                                                        "minlen"   => 1,
                                                                        "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    # Wrap the errors up, if we have any
    $errors = $self -> {"template"} -> load_template("blocks/user_details_error.tem", {"***errors***" => $errors})
        if($errors);

    return ($args, $errors);
}


# ============================================================================
#  Content generation functions

## @method $ generate_userdetails_form($args, $error, $info)
# Generate the form through which the user can set their details.
#
# @param args  A reference to a hash containing the user's details. This must also
#              minimally include a 'block' argument containing the id of the block
#              that should handle the form.
# @param error A string containing any error messages to show. This will be wrapped
#              in an error box for you.
# @param info  A string containing additional information to show before the form.
#              This will not be wrapped for you!
# @return A string containing the userdetails form.
sub generate_userdetails_form {
    my $self  = shift;
    my $args  = shift;
    my $error = shift;
    my $info  = shift;
    my $hiddenargs;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
        if($error);

    my $content = $self -> {"template"} -> load_template("blocks/user_details.tem", {"***info***"  => $info,
                                                                                     "***error***" => $error,
                                                                                     "***name***"  => $args -> {"realname"},
                                                                                     "***role***"  => $args -> {"rolename"}});
    # If we have a messageid in the args, add it as a hidden value
    $hiddenargs = $self -> {"template"} -> load_template("hiddenarg.tem", {"***name***"  => "msgid",
                                                                           "***value***" => $args -> {"msgid"}});
    
    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $content,
                                                               "***block***"   => $args -> {"block"},
                                                               "***args***"    => $hiddenargs});
}


sub send_message {
    my $self = shift;

}

1;
