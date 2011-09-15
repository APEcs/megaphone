## @file
# This file contains the implementation of the core megaphone features.
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
package MegaphoneCore;

use base qw(Block); # This class extends Block

# ============================================================================
#  Select list generators



# ============================================================================
#  Content generation functions

## @method $ generate_message($args, $error)
# Generate the 'message' block to send to the user. This will wrap any specified
# error in an appropriate block before inserting it into the message block. Any
# arguments set in the provided args hash are filled in on the form.
#
# @param args  A reference to a hash containing the default values to show in the form.
# @param error An error message to show at the start of the form.
# @return A string containing the message block.
sub generate_message {
    my $self  = shift;
    my $args  = shift || { };
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error.tem", {"***message***" => $error})
        if($error);

    # And build the message block itself. Kinda big and messy, this...
    return $self -> {"template"} -> load_template("blocks/message.tem", {"***error***"       => $error,
                                                                         "***cc1***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [0]  : "",
                                                                         "***cc2***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [1]  : "",
                                                                         "***cc3***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [2]  : "",
                                                                         "***cc4***"         => $args -> {"cc"}  ? $args -> {"cc"} -> [3]  : "",
                                                                         "***bcc1***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [0] : "",
                                                                         "***bcc2***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [1] : "",
                                                                         "***bcc3***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [2] : "",
                                                                         "***bcc4***"        => $args -> {"bcc"} ? $args -> {"bcc"} -> [3] : "",
                                                                         "***prefixother***" => $args -> {"prefixother"},
                                                                         "***subject***"     => $args -> {"subject"},
                                                                         "***message***"     => $args -> {"message"},
                                                                         "***delaysend***"   => $args -> {"delaysend"} ? 'checked="checked"' : "",
                                                                         "***targmatrix***"  => $self -> build_target_matrix($args -> {"targset"}),
                                                                         "***prefix***"      => $self -> build_prefix($args -> {"prefix"}),
                                                                     });
}


## @method $generate_login($error)
# Generate the 'login' block to send to the user. This will not prepopulate the form fields, even
# after the user has submitted and received an error - the user must fill in the details each time.
#
# @param error An error message to display in the login form.
# @return A string containing the login block.
sub generate_login {
    my $self  = shift;
    my $error = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error.tem", {"***message***" => $error})
        if($error);

    # And build the login block
    return $self -> {"template"} -> load_template("blocks/login.tem", {"***error***" => $error});
}


## @method $ generate_message_form($args, $login_errors, $form_errors)
# Generate the content of the message form, optionally including the login block
# if the user has not yet logged in.
#
# @param args         A reference to a hash containing the arguments to prepopulate the message form with.
# @param login_errors A string containing errors related to logging in, or undef.
# @param form_errors  A string containing errors related to the message form itself.
# @return A string containing the message form.
sub generate_message_form {
    my $self         = shift;
    my $args         = shift;
    my $login_errors = shift;
    my $form_errors  = shift;
    my $content      = "";

    # If we do not have a session user, we need the login block
    $content .= $self -> generate_login($login_errors)
        if(!$self -> {"session"} -> {"sessuser"} || ($self -> {"session"} -> {"sessuser"} == $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}));

    $content .= $self -> generate_message($args, $form_errors);

    # Args are pretty simple...
    my $args = $self -> {"template"} -> load_template("hiddenargs.tem", {"***name***"  => "op",
                                                                         "***value***" => "sendmsg"});

    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $content,
                                                               "***args***"    => $args});
}


# ============================================================================
#  Interface functions

## @method $ page_display()
# Generate the page content for this module.
sub page_display {
    my $self = shift;

    # We need to determine what the page title should be, and the content to shove in it...
    my ($title, $content);


    # Done generating the page content, return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"   => $title,
                                                               "***content***" => $content});

}

1;
