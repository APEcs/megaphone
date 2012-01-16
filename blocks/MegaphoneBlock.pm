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

## @class MegaphoneBlock
# The 'base' class for all Megaphone blocks. This extends the standard
# webperl Block class with additional functions common to all Megaphone
# UI and backend modules.
use strict;
use base qw(Block); # This class extends Block
use MIME::Base64;   # Needed for base64 encoding of popup bodies.
use HTML::Entities;
use Logging qw(die_log);
use Data::Dumper;

# ============================================================================
#  Constructor

## @cmethod $ new(%args)
# An overridden constructor that will, unless "istarget" is set in the args,
# load all available target modules.
#
# @param args A hash of arguments to initialise the object with
# @return A blessed reference to the object
sub new {
    my $invocant = shift;
    my $class    = ref($invocant) || $invocant;
    my $self     = $class -> SUPER::new(@_);

    if($self && !$self -> {"istarget"}) {
        # Go through the list of targets in the system
        my $targh = $self -> {"dbh"} -> prepare("SELECT name, module_id FROM ".$self -> {"settings"} -> {"database"} -> {"targets"}."
                                                 ORDER BY id");
        $targh -> execute()
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute target list query: ".$self -> {"dbh"} -> errstr);

        # Prevent recursive calls to the module handler...
        $self -> {"module"} -> {"istarget"} = 1;

        $self -> {"targetorder"} = [];
        while(my $targ = $targh -> fetchrow_hashref()) {
            $self -> {"targets"} -> {$targ -> {"module_id"}} = {"name"   => $targ -> {"name"},
                                                                "module" => $self -> {"module"} -> new_module_byid($targ -> {"module_id"})};
            die_log($self -> {"cgi"} -> remote_host(), "Unable to load target module ".$targ -> {"module_id"}.":".$Modules::errstr)
                if(!$self -> {"targets"} -> {$targ -> {"module_id"}} -> {"module"});

            # Make calling modules in the correct order during hook calls later easier
            push(@{$self -> {"targetorder"}}, $targ -> {"module_id"});
        }

        # Kill the recursive lock
        $self -> {"module"} -> {"istarget"} = 0;
    }

    return $self;
}


# ============================================================================
#  Storage

## @method $ store_message($args, $user, $prev_id)
# Store the contents of the message in the database, marked as 'incomplete' so that
# the system can not autosend it yet.
#
# @param args    A reference to a hash containing the message data.
# @param user    A reference to a user's data.
# @param prev_id If creating a new message as part of editing an old one, this should
#                be set to the old message's id. For new messages, this can be omitted.
# @return The message id on success, dies on failure.
sub store_message {
    my $self    = shift;
    my $args    = shift;
    my $user    = shift;
    my $prev_id = shift;

    # First we need to create the message itself
    my $messh = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                             (previous_id, user_id, prefix_id, prefix_other, subject, message, delaysend, created, updated)
                                             VALUES(?, ?, ?, ?, ?, ?, ?, UNIX_TIMESTAMP(), UNIX_TIMESTAMP())");
    $messh -> execute($prev_id,
                      $user -> {"user_id"},
                      $args -> {"prefix_id"},
                      $args -> {"prefix_other"},
                      $args -> {"subject"},
                      $args -> {"message"},
                      $args -> {"delaysend"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message insert: ".$self -> {"dbh"} -> errstr);

    # Get the id of the newly created message. This is messy, but DBI's last_insert_id() is flaky as hell
    my $messid = $self -> {"dbh"} -> {"mysql_insertid"};
    die_log($self -> {"cgi"} -> remote_host(), "Unable to get ID of new message. This should not happen.") if(!$messid);

    # Now we can store the cc, bcc, and destinations
    my $desth = $self -> {"dbh"} -> prepare("INSERT INTO ".$self -> {"settings"} -> {"database"} -> {"messages_dests"}."
                                             VALUES(?, ?)");
    foreach my $destid (@{$args -> {"targset"}}) {
        $desth -> execute($messid, $destid)
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute destination insert: ".$self -> {"dbh"} -> errstr);
    }

    # Call Target modules to store their data.
    foreach my $targ (keys(%{$args -> {"targused"}})) {
        $self -> {"targets"} -> {$targ} -> {"module"} -> store_message($args, $user, $messid, $prev_id);
    }

    return $messid;
}


## @method $ get_message($msgid)
# Obtain the data for the specified message.
#
# @param msgid The ID of the message to retrieve.
# @return A hash containing the message data.
sub get_message {
    my $self  = shift;
    my $msgid = shift;

    # First get the message...
    my $msgh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                            WHERE id = ?");
    $msgh -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message lookup query: ".$self -> {"dbh"} -> errstr);

    my $message = $msgh -> fetchrow_hashref();
    return undef if(!$message);

    # Fetch the destinations
    $message -> {"targset"} = [];
    my $targh = $self -> {"dbh"} -> prepare("SELECT d.dest_id,t.module_id
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"messages_dests"}." AS d,
                                                  ".$self -> {"settings"} -> {"database"} -> {"recip_targs"}." AS m,
                                                  ".$self -> {"settings"} -> {"database"} -> {"targets"}." AS t
                                             WHERE message_id = ?
                                             AND m.id = d.dest_id
                                             AND t.id = m.target_id");
    $targh -> execute($msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute destination lookup query: ".$self -> {"dbh"} -> errstr);

    while(my $targ = $targh -> fetchrow_hashref()) {
        # Store the used destination, and the id of the module that implements the target
        push(@{$message -> {"targset"}}, $targ -> {"dest_id"});
        $message -> {"targused"} -> {$targ -> {"module_id"}} = 1;
    }

    # Call Target modules to fill in their data.
    foreach my $targ (keys(%{$message -> {"targused"}})) {
        $self -> {"targets"} -> {$targ} -> {"module"} -> get_message($msgid, $message);
    }

    # Done, return the data...
    return $message;
}


## @method void set_message_status($msgid, $status)
# Update the status for the specified message.
#
# @param msgid  The ID of the message to update.
# @param status The new status to set, should be 'incomplete', 'pending', 'sent',
#               'edited', or 'aborted'
sub set_message_status {
    my $self   = shift;
    my $msgid  = shift;
    my $status = shift;

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                               SET status = ?, updated = UNIX_TIMESTAMP()
                                               WHERE id = ?");
    $updateh -> execute($status, $msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message update query: ".$self -> {"dbh"} -> errstr);
}


## @method void set_message_visible($msgid, $visible)
# Update the specified message to have the provided visibility. Note that this
# will not actually check that visibility change is valid for the message -the
# caller must check this!
#
# @param msgid   The id of the message to update.
# @param visible True if the message should be made visible, false otherwise.
sub set_message_visible {
    my $self    = shift;
    my $msgid   = shift;
    my $visible = shift;

    # Message has been sent, update it.
    my $updateh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                               SET updated = UNIX_TIMESTAMP(), visible = ?
                                               WHERE id = ?");
    $updateh -> execute($visible, $msgid)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message update query: ".$self -> {"dbh"} -> errstr);
}


## @method $ update_message($msgid, $args, $user)
# Update the specified message to contain the values specified in the new args
# hash. This will die outright if the message has state is 'sent' or 'aborted'.
# Note that, for security and auditing purposes, this does not actually update
# the message as such - it marks the old message as "edited" and creates a new one.
#
# @param msgid The ID of the message to update.
# @param args  A reference to a hash containing the new settings for the message.
# @param user  A reference to a hash containing the user's data.
# @return A new message ID
sub update_message {
    my $self  = shift;
    my $msgid = shift;
    my $args  = shift;
    my $user  = shift;

    # Check that the message can be edited.
    my $message = $self -> get_message($msgid);
    die_log($self -> {"cgi"} -> remote_host(), "Attempt to edit message $msgid when it is in an uneditable state. Giving up in disgust.")
        if($message -> {"status"} eq "edited");

    # Switch the old message to 'edited' status if needed (we don't want to change aborted, failed, or sent messages)
    $self -> set_message_status($msgid, "edited") unless($message -> {"status"} eq "aborted" || $message -> {"status"} eq "sent" || $message -> {"status"} eq "failed");

    # Create a new message
    return $self -> store_message($args, $user, $msgid);
}


## @method void update_userdetails($args)
# Update the details for the specified user. The args hash must minimally contain
# the user's realname, rolename, and user_id.
#
# @param args The arguments to set for the user.
sub update_userdetails {
    my $self = shift;
    my $args = shift;

    die_log($self -> {"cgi"} -> remote_host(), "Realname is not set. This should not happen!") unless($args -> {"realname"});
    die_log($self -> {"cgi"} -> remote_host(), "Rolename is not set. This should not happen!") unless($args -> {"rolename"});

    my $updateh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"users"}."
                                               SET email = ?, realname = ?, rolename = ?, signature = ?, updated = UNIX_TIMESTAMP()
                                               WHERE user_id = ?");
    $updateh -> execute($args -> {"email"}, $args -> {"realname"}, $args -> {"rolename"}, $args -> {"signature"}, $args -> {"user_id"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute user details update: ".$self -> {"dbh"} -> errstr);
}


# ============================================================================
#  Fragment generators

## @method $ build_recipient_tree($parent)
# Recrusively build a tree of recipients from the database.
#
# @param parent The ID of the parent element, 0 indicates the root level.
# @return A reference to a hash containing the recipient subtree for the
#         parent element, or undef if there are no children of parent.
sub build_recipient_tree {
    my $self   = shift;
    my $parent = shift;

    my $reciph  = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"recipients"}."
                                               WHERE parent = ?
                                               ORDER BY position");
    $reciph -> execute($parent)
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to obtain list of targets: ".$self -> {"dbh"} -> errstr);

    my $recipients;
    # Store each recipient, and recursively determine whether it has children
    while(my $recip = $reciph -> fetchrow_hashref()) {
        $recipients -> {$recip -> {"position"}} -> {"id"}        = $recip -> {"id"};
        $recipients -> {$recip -> {"position"}} -> {"name"}      = $recip -> {"name"};
        $recipients -> {$recip -> {"position"}} -> {"shortname"} = $recip -> {"shortname"};
        $recipients -> {$recip -> {"position"}} -> {"children"}  = $self -> build_recipient_tree($recip -> {"id"});
    }

    # This'll either be a tree of recipients, or undef for nothing here at all...
    return $recipients;
}


## @method $ build_active_destinations($recipients, $targets, $activehash, $matrixh)
# Recursively traverse the recipients, and for each target mark whether
# the user has opted to contact the recipient through it.
#
# @param recipients A reference to a hash of recipients.
# @param targets    A reference to an array of targets.
# @param activehash A reference to a hash containing active recipient/target pairs.
# @param matrixh    A cached query to check recipient/target selection in the
#                   database.
# @return The number of active destinations in the current subtree.
sub build_active_destinations {
    my $self       = shift;
    my $recipients = shift;
    my $targets    = shift;
    my $activehash = shift;
    my $matrixh    = shift;

    # Go through each recipient at the current level checking whether it is
    # active, and then check its children if needed.
    my $active = 0;
    foreach my $recip (keys(%{$recipients})) {
        # check the current recipient against all targets
        foreach my $target (@{$targets}) {
            $matrixh -> execute($recipients -> {$recip} -> {"id"}, $target -> {"id"})
                or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute target/recipient map query: ".$self -> {"dbh"} -> errstr);

            # is the recipient/target pair supported as a destination?
            my $matrow = $matrixh -> fetchrow_arrayref();
            if($matrow) {
                # Yes, it is.
                $recipients -> {$recip} -> {"supported_dest"} -> {$target -> {"id"}} = $matrow -> [0];

                # Has the user selected it as a destination?
                if($activehash -> {$matrow -> [0]}) {
                    ++$active;
                    $recipients -> {$recip} -> {"active"} -> {$target -> {"id"}} = 1;
                }
            } else {
                # Not a supported destination...
                $recipients -> {$recip} -> {"supported_dest"} -> {$target -> {"id"}} = 0;
            }
        }

        # If the current recipient has children, mark and count them.
        $recipients -> {$recip} -> {"active_children"} = $self -> build_active_destinations($recipients -> {$recip} -> {"children"}, $targets, $activehash, $matrixh)
            if($recipients -> {$recip} -> {"children"});

        # And update the running count for the whole tree
        $active += $recipients -> {$recip} -> {"active_children"} if($recipients -> {$recip} -> {"active_children"});
    }

    return $active;
}


## @method $ build_matrix_rows($recipients, $targets, $readonly, $tem_cache, $showtree, $idlist, $depth)
# Recursively generate the rows that should appear in the destination matrix table.
# This will go through the specified recipients hash, generating rows for each
# entry and recursing into child trees as needed.
#
# @param recipients A reference to a hash of recipients.
# @param targets    A reference to an array of targets.
# @param readonly   If true, the generate table is a read-only and users can not enable/disable destinations.
# @param tem_cache  A reference to a hash of cached templates.
# @param showtree   If set to true, the current recipient tree is visible.
# @param idlist     The id path to the current level of the tree (normally you will not provide this).
# @param depth      The current tree depth (normally you will not provide this).
# @return A string containing rows to place in the destination matrix body.
sub build_matrix_rows {
    my $self       = shift;
    my $recipients = shift;
    my $targets    = shift;
    my $readonly   = shift;
    my $tem_cache  = shift;
    my $showtree   = shift;
    my $idlist     = shift;
    my $depth      = shift || 0;

    my $matrix = "";
    foreach my $recip (sort {$a <=> $b } keys(%{$recipients})) {
        my $data = "";

        # Each row should consist of an entry for each target...
        foreach my $target (@{$targets}) {

            # Is the destination supported?
            if($recipients -> {$recip} -> {"supported_dest"} -> {$target -> {"id"}}) {
                # Yes, output either a checkbox or a marker...
                my $destid = $recipients -> {$recip} -> {"supported_dest"} -> {$target -> {"id"}};
                my $active = $recipients -> {$recip} -> {"active"} -> {$target -> {"id"}};
                if(!$readonly) {
                    $data .= $self -> {"template"} -> process_template($tem_cache -> {"recipentrytem"}, {"***data***" => $self -> {"template"} -> process_template($tem_cache -> {"recipacttem"}, {"***id***"      => $destid,
                                                                                                                                                                                                    "***name***"    => $target -> {"name"},
                                                                                                                                                                                                    "***checked***" => $active ? 'checked="checked"' : ""})});
                } else {
                    $data .= $self -> {"template"} -> process_template($tem_cache -> {"recipentrytem"}, {"***data***" => ($active ? $tem_cache -> {"recipact_ontem"} : $tem_cache -> {"recipact_offtem"})});
                }
            } else {
                # Nope, output a X marker
                $data .= $self -> {"template"} -> process_template($tem_cache -> {"recipentrytem"}, {"***data***" => $tem_cache -> {"recipinacttem"}});
            }
        }

        # Build CSS stuff to make the folding happen...
        # Indent the row if it is a subgroup
        my $extrastyle = "";
        $extrastyle = "margin-left: ".($depth * 20)."px" if($depth);

        # the name span needs different left padding depending on parent/child status
        my $spanclass = "child";
        $spanclass = "parent" if($recipients -> {$recip} -> {"children"});

        # Should the row be open or closed, or completely hidden?
        my $rowclass = ($recipients -> {$recip} -> {"active_children"} ? " open" : " closed");
        my $rowstyle = ($showtree ? "" : "display: none");

        # Can't update the original idlist, or we'll concatenate ids we shouldn't
        my $myidlist = $idlist || "";
        $myidlist .= "/" if($myidlist);
        $myidlist .= $recipients -> {$recip} -> {"id"};

        # Work out whether we need a toggle icon or not
        my $toggletree = $self -> {"template"} -> process_template($tem_cache -> {"toggletree_$spanclass"}, {"***idlist***" => $myidlist,
                                                                                                             "***state***"  => ($recipients -> {$recip} -> {"active_children"} ? "open" : "close")});

        # Now squirt out the row
        $matrix .= $self -> {"template"} -> process_template($tem_cache -> {"reciptem"}, {"***idlist***"     => $myidlist,
                                                                                          "***rowclass***"   => $rowclass,
                                                                                          "***rowstyle***"   => $rowstyle,
                                                                                          "***spanclass***"  => $spanclass,
                                                                                          "***name***"       => $recipients -> {$recip} -> {"name"},
                                                                                          "***shortname***"  => $recipients -> {$recip} -> {"shortname"},
                                                                                          "***id***"         => $recipients -> {$recip} -> {"id"},
                                                                                          "***targets***"    => $data,
                                                                                          "***extrastyle***" => $extrastyle,
                                                                                          "***toggletree***" => $toggletree});

        # Recurse if needed
        $matrix .= $self -> build_matrix_rows($recipients -> {$recip} -> {"children"}, $targets, $readonly, $tem_cache, $recipients -> {$recip} -> {"active_children"}, $myidlist, $depth + 1)
            if($recipients -> {$recip} -> {"children"});
    }

    return $matrix;
}


## @method $ build_target_matrix($activelist, $readonly)
# Generate the table containing the target/recipient matrix. This will generate
# a table listing the supported targets horizontally, and the supported recipients
# vertically. Each cell in the table may either contain a checkbox (indicating
# that the system can send to the recipient via that system), or a cross (indicating
# that the recipient can not be contacted via that system).
#
# @param activelist A reference to an array of selected target/recipient combinations.
# @param readonly   If true, the table will be generated with images rather than checkboxes.
# @return A string containing the target/recipient matrix
sub build_target_matrix {
    my $self       = shift;
    my $activelist = shift;
    my $readonly   = shift;

    # Make sure that activelist is usable as an arrayref
    $activelist = [] if(!$activelist);

    # No, I mean /really/ make sure...
    die_log($self -> {"cgi"} -> remote_host(), "activelist parameter to build_target_matrix is not an array reference. This should not happen.")
        if(ref($activelist) ne "ARRAY");

    # Convert the list to a hash for faster lookup
    my $activehash;
    foreach my $active (@{$activelist}) {
        $activehash -> {$active} = 1;
    }

    # Start the process of matrix generation by obtaining the list of known targets in the system
    my $targeth = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"targets"}." ORDER BY name");

    # We should prefetch the targets as we need to process them repeatedly during the matrix generation
    $targeth -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to obtain list of targets: ".$self -> {"dbh"} -> errstr);

    my $targets = $targeth -> fetchall_arrayref({}); # Fetch all the targets as a reference to an array of hash references.

    # Make the header list and javascript target list...
    my $targetheader = "";
    my $jstarglist   = "";
    my $targheadtem = $self -> {"template"} -> load_template("matrix/target.tem");
    foreach my $target (@{$targets}) {
        $targetheader .= $self -> {"template"} -> process_template($targheadtem, {"***name***" => $target -> {"name"}});
        $jstarglist   .= "," if($jstarglist);
        $jstarglist   .= '"'.$target -> {"name"}.'"';
    }


    # Now build a hash of recipients, potentially structured as a tree
    my $recipients = $self -> build_recipient_tree(0);

    # Precache the recipient/target lookup query for speed
    my $matrixh = $self -> {"dbh"} -> prepare("SELECT id FROM ".$self -> {"settings"} -> {"database"} -> {"recip_targs"}."
                                               WHERE recipient_id = ? AND target_id = ?");

    # Go through the recipient tree, marking active elements
    $self -> build_active_destinations($recipients, $targets, $activehash, $matrixh);

    # Now we can build the matrix itself
    my $tem_cache = {};
    $tem_cache -> {"reciptem"}          = $self -> {"template"} -> load_template("matrix/recipient.tem");
    $tem_cache -> {"recipentrytem"}     = $self -> {"template"} -> load_template("matrix/reciptarg.tem");
    $tem_cache -> {"recipacttem"}       = $self -> {"template"} -> load_template("matrix/reciptarg-active.tem");
    $tem_cache -> {"recipinacttem"}     = $self -> {"template"} -> load_template("matrix/reciptarg-inactive.tem");
    $tem_cache -> {"recipact_ontem"}    = $self -> {"template"} -> load_template("matrix/reciptarg-active_ticked.tem");
    $tem_cache -> {"recipact_offtem"}   = $self -> {"template"} -> load_template("matrix/reciptarg-active_unticked.tem");
    $tem_cache -> {"toggletree_parent"} = $self -> {"template"} -> load_template("matrix/toggletree_parent.tem");
    $tem_cache -> {"toggletree_child"}  = $self -> {"template"} -> load_template("matrix/toggletree_child.tem");

    my $matrix = $self -> build_matrix_rows($recipients, $targets, $readonly, $tem_cache, 1);

    # We have almost all we need - load the help for the matrix
    my $help = $self -> {"template"} -> load_template("popup.tem", {"***title***"   => $self -> {"template"} -> replace_langvar("MATRIX_HELP_TITLE"),
                                                                    "***b64body***" => encode_base64($self -> {"template"} -> load_template("matrix/matrix-help.tem"))});

    # And we can return the filled-in table...
    return $self -> {"template"} -> load_template("matrix/matrix.tem", {"***help***"     => $help,
                                                                        "***targets***"  => $targetheader,
                                                                        "***targlist***" => $jstarglist,
                                                                        "***matrix***"   => $matrix});
}


## @method $ build_prefix($default)
# Generate the options to show for the prefix dropdown.
#
# @param default The option to have selected by default.
# @return A string containing the prefix option list.
sub build_prefix {
    my $self    = shift;
    my $default = shift;

    # Ask the database for the available prefixes
    my $prefixh = $self -> {"dbh"} -> prepare("SELECT * FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                               ORDER BY id");
    $prefixh -> execute()
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix lookup: ".$self -> {"dbh"} -> errstr);

    # now build the prefix list...
    my $prefixlist = "";
    while(my $prefix = $prefixh -> fetchrow_hashref()) {
        # pick the first real prefix, if we have no default set
        $default = $prefix -> {"id"} if(!defined($default));

        $prefixlist .= '<option value="'.$prefix -> {"id"}.'"';
        $prefixlist .= ' selected="selected"' if($prefix -> {"id"} == $default);
        $prefixlist .= '>'.$prefix -> {"prefix"}." (".$prefix -> {"description"}.")</option>\n";
    }

    # Append the extra 'other' setting...
    $prefixlist .= '<option value="0"';
    $prefixlist .= ' selected="selected"' if($default == 0);
    $prefixlist .= '>'.$self -> {"template"} -> replace_langvar("MESSAGE_CUSTPREFIX")."</option>\n";

    return $prefixlist;
}


## @method $ build_user_presets($user)
# Generate the 'user-specific presets' line for inclusion in the message form.
#
# @return A string containing the user's preset options, or an empty string if
#         the user has no presets.
sub build_user_presets {
    my $self = shift;
    my $user = shift;

    # No user preset? No string content...
    return "" if(!$user -> {"presethtml"});

    return $self -> {"template"} -> load_template("blocks/message_presets.tem", {"***presets***" => $user -> {"presethtml"}});
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

    ($args -> {"email"}, $error) = $self -> validate_string("email", {"required" => 1,
                                                                      "nicename" => $self -> {"template"} -> replace_langvar("DETAILS_EMAIL"),
                                                                      "minlen"   => 1,
                                                                      "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    ($args -> {"rolename"}, $error) = $self -> validate_string("role", {"required" => 1,
                                                                        "nicename" => $self -> {"template"} -> replace_langvar("DETAILS_ROLE"),
                                                                        "minlen"   => 1,
                                                                        "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    ($args -> {"signature"}, $error) = $self -> validate_string("signature", {"required" => 0,
                                                                              "nicename" => $self -> {"template"} -> replace_langvar("DETAILS_SIG")});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    # Wrap the errors up, if we have any
    $errors = $self -> {"template"} -> load_template("blocks/user_details_error.tem", {"***errors***" => $errors})
        if($errors);

    return ($args, $errors);
}


## @method @ validate_login()
# Determine whether the username and password provided by the user are valid. If
# they are, return the user's data.
#
# @return An array of two values: the first is either a reference to a hash containing
#         the user's data, or undef. The second is either undef or an error message.
sub validate_login {
    my $self   = shift;
    my $error  = "";
    my $args   = {};

    my $errtem = $self -> {"template"} -> load_template("blocks/login_error.tem");

    # Check that the username is provided and valid
    ($args -> {"username"}, $error) = $self -> validate_string("username", {"required"   => 1,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_USERNAME"),
                                                                            "minlen"     => 2,
                                                                            "maxlen"     => 12,
                                                                            "formattest" => '^\w+',
                                                                            "formatdesc" => $self -> {"template"} -> replace_langvar("LOGIN_ERR_BADUSERCHAR")});
    # Bomb out at this point if the username is not valid.
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $error})) if($error);

    # Do the same with the password...
    ($args -> {"password"}, $error) = $self -> validate_string("password", {"required"   => 1,
                                                                            "nicename"   => $self -> {"template"} -> replace_langvar("LOGIN_PASSWORD"),
                                                                            "minlen"     => 2,
                                                                            "maxlen"     => 255});
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $error})) if($error);

    # Username and password appear to be present and contain sane characters. Try to log the user in...
    my $user = $self -> {"session"} -> {"auth"} -> valid_user($args -> {"username"}, $args -> {"password"});

    # User is valid!
    return ($user, undef) if($user);

    # User is not valid, does the lasterr contain anything?
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $self -> {"session"} -> {"auth"} -> {"lasterr"}}))
        if($self -> {"session"} -> {"auth"} -> {"lasterr"});

    # Nothing useful, just return a fallback
    return (undef, $self -> {"template"} -> process_template($errtem, {"***reason***" => $self -> {"template"} -> replace_langvar("LOGIN_INVALID")}));
}


## @method @ validate_message()
# Check whether the fields selected by the user are valid, and return as much as possible.
#
# @return An array of two values: the first is a reference to a hash of arguments
#         representing the submitted data, the second is an error message or undef.
sub validate_message {
    my $self   = shift;
    my $errors = shift;
    my $args   = {};
    my $error;

    # template for errors...
    my $errtem = $self -> {"template"} -> load_template("blocks/error_entry.tem");

    # Query used to check that destinations are valid
    my $matrixh = $self -> {"dbh"} -> prepare("SELECT m.id, t.module_id
                                               FROM ".$self -> {"settings"} -> {"database"} -> {"recip_targs"}." AS m,
                                                    ".$self -> {"settings"} -> {"database"} -> {"targets"}." AS t
                                               WHERE m.id = ?
                                               AND t.id = m.target_id");

    # check that we have some selected destinations, and they are valid
    my @targset = $self -> {"cgi"} -> param('matrix');
    my @checked_targs;
    $args -> {"targused"} = {};
    foreach my $targ (@targset) {
        $matrixh -> execute($targ)
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute recipient/target validation check: ".$self -> {"dbh"} -> errstr);

        # do we have a match?
        my $dest = $matrixh -> fetchrow_hashref();
        if($dest){
            # Store the destination, and record that the module implementing the
            # target for the destination has been used.
            push(@checked_targs, $targ);
            $args -> {"targused"} -> {$dest -> {"module_id"}} = 1;

        # Not found, produce an error...
        } else {
            $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_BADMATRIX")});
            last;
        }
    }
    # Store the checked settings we have..
    $args -> {"targset"} = \@checked_targs;

    # We need to have some destinations selected!
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $self -> {"template"} -> replace_langvar("MESSAGE_ERR_NOMATRIX")})
        if(!scalar(@checked_targs));

    # Call Target modules to validate their data.
    foreach my $targ (keys(%{$args -> {"targused"}})) {
        $errors .= $self -> {"targets"} -> {$targ} -> {"module"} -> validate_message($args);
    }

    # Check that the selected prefix is valid...
    # Has the user selected the 'other prefix' option? If so, check they entered a prefix
    if($self -> {"cgi"} -> param("prefix_id") == 0) {
        $args -> {"prefix_id"} = 0;
        ($args -> {"prefix_other"}, $error) = $self -> validate_string("prefix_other", {"required" => 1,
                                                                                        "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_PREFIX"),
                                                                                        "minlen"   => 1,
                                                                                        "maxlen"   => 20});
    # User has selected a prefix, check it is valid
    } else {
        $args -> {"prefix_other"} = undef;
        ($args -> {"prefix_id"}, $error) = $self -> validate_options("prefix_id", {"required" => 1,
                                                                                   "source"   => $self -> {"settings"} -> {"database"} -> {"prefixes"},
                                                                                   "where"    => "WHERE id = ?",
                                                                                   "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_PREFIX")});
    }
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    # Make sure that we have a subject...
    ($args -> {"subject"}, $error) = $self -> validate_string("subject", {"required" => 1,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_SUBJECT"),
                                                                          "minlen"   => 1,
                                                                          "maxlen"   => 255});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    #... and a message, too
    ($args -> {"message"}, $error) = $self -> validate_string("message", {"required" => 1,
                                                                          "nicename" => $self -> {"template"} -> replace_langvar("MESSAGE_MESSAGE"),
                                                                          "minlen"   => 1});
    $errors .= $self -> {"template"} -> process_template($errtem, {"***error***" => $error}) if($error);

    $args -> {"delaysend"} = $self -> {"cgi"} -> param("delaysend") ? 1 : 0;

    # Wrap the errors up, if we have any
    $errors = $self -> {"template"} -> load_template("blocks/error.tem", {"***errors***" => $errors})
        if($errors);

    return ($args, $errors);
}


# ============================================================================
#  Content generation functions

## @method $ generate_message_editform($msgid, $args, $hidden, $error)
# Generate the message edit form to send to the user. This will wrap any specified
# error in an appropriate block before inserting it into the message block. Any
# arguments set in the provided args hash are filled in on the form.
#
# @param msgid The ID of the message being edited.
# @param args  A reference to a hash containing the default values to show in the form.
# @param hidden A reference to a hash of keys and values to store in hidden input fields.
# @param error An error message to show at the start of the form.
# @return A string containing the message form.
sub generate_message_editform {
    my $self   = shift;
    my $msgid  = shift;
    my $args   = shift || { };
    my $hidden = shift;
    my $error  = shift;

    # Get the user
    my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
        if($error);

    # Check each target for blocks
    my $targethook = "";
    foreach my $targ (@{$self -> {"targetorder"}}) {
        $targethook .= $self -> {"targets"} -> {$targ} -> {"module"} -> generate_message_edit($args);
    }

    # And build the message block itself. Kinda big and messy, this...
    my $body = $self -> {"template"} -> load_template("blocks/message_edit.tem", {"***error***"        => $error,
                                                                                  "***presets***"      => $self -> build_user_presets($user),
                                                                                  "***prefix_other***" => $args -> {"prefix_other"},
                                                                                  "***subject***"      => $args -> {"subject"},
                                                                                  "***message***"      => $args -> {"message"},
                                                                                  "***delaysend***"    => $args -> {"delaysend"} ? 'checked="checked"' : "",
                                                                                  "***delay***"        => $self -> {"template"} -> humanise_seconds($self -> {"settings"} -> {"config"} -> {"Core:delay_send"}),
                                                                                  "***targmatrix***"   => $self -> build_target_matrix($args -> {"targset"}),
                                                                                  "***prefix***"       => $self -> build_prefix($args -> {"prefix_id"}),
                                                                                  "***targethook***"   => $targethook,
                                                                              });

    # store any hidden args...
    my $hiddenargs = "";
    my $hidetem = $self -> {"template"} -> load_template("hiddenarg.tem");
    foreach my $key (keys(%{$hidden})) {
        $hiddenargs .= $self -> {"template"} -> process_template($hidetem, {"***name***"  => $key,
                                                                            "***value***" => $hidden -> {$key}});
    }

    # Send back the form.
    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $body,
                                                               "***args***"    => $hiddenargs,
                                                               "***block***"   => $self -> {"block"}});
}


## @method $ generate_message_confirmform($msgid, $args, $hidden)
# Generate a form from which the user may opt to send the message, or go back and edit it.
#
# @param msgid  The ID of the message being viewed.
# @param args   A reference to a hash containing the message data.
# @param hidden A reference to a hash of keys and values to store in hidden input fields.
# @return A form the user may used to confirm the message or go to edit it.
sub generate_message_confirmform {
    my $self   = shift;
    my $msgid  = shift;
    my $args   = shift || { };
    my $hidden = shift;
    my $outfields = {};

    # Check each target for blocks
    my $targethook = "";
    foreach my $targ (@{$self -> {"targetorder"}}) {
        $targethook .= $self -> {"targets"} -> {$targ} -> {"module"} -> generate_message_confirm($args, $outfields)
            if($args -> {"targused"} -> {$targ});
    }

    # Get the prefix sorted
    if($args -> {"prefix_id"} == 0) {
        $outfields -> {"prefix"} = $args -> {"prefix_other"};
    } else {
        my $prefixh = $self -> {"dbh"} -> prepare("SELECT prefix FROM ".$self -> {"settings"} -> {"database"} -> {"prefixes"}."
                                                   WHERE id = ?");
        $prefixh -> execute($args -> {"prefix_id"})
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute prefix query: ".$self -> {"dbh"} -> errstr);

        my $prefixr = $prefixh -> fetchrow_arrayref();
        $outfields -> {"prefix"} = $prefixr ? $prefixr -> [0] : $self -> {"template"} -> replace_langvar("MESSAGE_BADPREFIX");
    }

    $outfields -> {"delaysend"} = $self -> {"template"} -> load_template($args -> {"delaysend"} ? "blocks/message_edit_delay.tem" : "blocks/message_edit_nodelay.tem",
                                                                         {"***delay***" => $self -> {"template"} -> humanise_seconds($self -> {"settings"} -> {"config"} -> {"Core:delay_send"})});

    # And build the message block itself. Kinda big and messy, this...
    my $body = $self -> {"template"} -> load_template("blocks/message_confirm.tem", {"***targmatrix***"  => $self -> build_target_matrix($args -> {"targset"}, 1),
                                                                                     "***prefix***"      => $outfields -> {"prefix"},
                                                                                     "***subject***"     => $args -> {"subject"},
                                                                                     "***message***"     => $args -> {"message"},
                                                                                     "***delaysend***"   => $outfields -> {"delaysend"},
                                                                                     "***targethook***"  => $targethook,
                                                                                 });
    # store any hidden args...
    my $hiddenargs = "";
    my $hidetem = $self -> {"template"} -> load_template("hiddenarg.tem");
    foreach my $key (keys(%{$hidden})) {
        $hiddenargs .= $self -> {"template"} -> process_template($hidetem, {"***name***"  => $key,
                                                                            "***value***" => $hidden -> {$key}});
    }

    # Send back the form.
    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $body,
                                                               "***args***"    => $hiddenargs,
                                                               "***block***"   => $self -> {"block"}});
}


## @method $generate_login($error, $full)
# Generate the 'login' block to send to the user. This will not pre-populate the form fields, even
# after the user has submitted and received an error - the user must fill in the details each time.
#
# @param error An error message to display in the login form.
# @param full  If set, generate the full login form body including submit button (defaults to false,
#              so the login form can be embedded in the message form)
# @return A string containing the login block.
sub generate_login {
    my $self  = shift;
    my $error = shift;
    my $full  = shift;

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
        if($error);

    my $persist_length = $self -> {"session"} -> {"auth"} -> get_config("max_autologin_time");

    # Fix up possible modifiers
    $persist_length =~ s/s$/ seconds/;
    $persist_length =~ s/m$/ minutes/;
    $persist_length =~ s/h$/ hours/;
    $persist_length =~ s/d$/ days/;
    $persist_length =~ s/M$/ months/;
    $persist_length =~ s/y$/ years/;

    # And build the login block
    return $self -> {"template"} -> load_template("blocks/login".($full ? "_full" : "").".tem", {"***error***"      => $error,
                                                                                                 "***persistlen***" => $persist_length});
}


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
    my $hiddenargs = "";

    # Wrap the error message in a message box if we have one.
    $error = $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $error})
        if($error);

    my $content = $self -> {"template"} -> load_template("blocks/user_details.tem", {"***info***"  => $info,
                                                                                     "***error***" => $error,
                                                                                     "***name***"  => $args -> {"realname"},
                                                                                     "***email***" => $args -> {"email"},
                                                                                     "***role***"  => $args -> {"rolename"},
                                                                                     "***sig***"   => $args -> {"signature"}});
    # If we have args, add them as a hidden values
    my $hidetem = $self -> {"template"} -> load_template("hiddenarg.tem");
    foreach my $arg (keys(%{$args})) {
        # skip 'known' args...
        next if($arg eq "block" || $arg eq "realname" || $arg eq "rolename");

        $hiddenargs .= $self -> {"template"} -> process_template($hidetem, {"***name***"  => $arg,
                                                                            "***value***" => $args -> {$arg}});
    }

    return $self -> {"template"} -> load_template("form.tem", {"***content***" => $content,
                                                               "***block***"   => $args -> {"block"},
                                                               "***args***"    => $hiddenargs});
}


## @method $ generate_fatal($error)
# Generate a page containing a fatal error. This will produce a complete page,
# excluding HTTP response header, and should be used to bypass normal page generation.
#
# @param error The error to show in the page.
# @return a complete error page.
sub generate_fatal {
    my $self = shift;
    my $error = shift;

    my $content = $self -> {"template"} -> load_template("fatal_error.tem", {"***error***" => $error});

    # return the filled in page template
    return $self -> {"template"} -> load_template("page.tem", {"***title***"     => $self -> {"template"} -> replace_langvar("FATAL_TITLE"),
                                                               "***topright***"  => $self -> generate_topright(),
                                                               "***extrahead***" => "",
                                                               "***content***"   => $content});
}


## @method $ generate_topright()
# Generate the username/login/logout links at the top right of the page, based on
# whether the user has logged in yet or not.
#
# @return A string containing the content to show in the page top-right menu block.
sub generate_topright {
    my $self = shift;

    # Has the user logged in?
    if($self -> {"session"} -> {"sessuser"} && $self -> {"session"} -> {"sessuser"} != $self -> {"session"} -> {"auth"} -> {"ANONYMOUS"}) {
        # We need the user's details
        my $user = $self -> {"session"} -> {"auth"} -> get_user_byid($self -> {"session"} -> {"sessuser"});

        return $self -> {"template"} -> load_template("topright_loggedin.tem", {"***user***" => $user -> {"realname"} || $user -> {"username"}});
    }

    # User hasn't logged in, return the basic login stuff
    return $self -> {"template"} -> load_template("topright_loggedout.tem");
}


## @method $ generate_sitewarn()
# Generate the site warning box, if a warning is currently set.
#
# @return A string containing the site warning, if one is set, or "".
sub generate_sitewarn {
    my $self = shift;

    return "" if(!$self -> {"settings"} -> {"config"} -> {"site_warning"});

    return $self -> {"template"} -> load_template("blocks/error_box.tem", {"***message***" => $self -> {"settings"} -> {"config"} -> {"site_warning"}});
}


# ============================================================================
#  Message send functions

## @method $ delay_remain($message)
# Determine how long a message has left before it should be sent.
#
# @param message A reference to the message data
# @return The number of seconds left before the message should be sent,
#         -1 if the message should be sent immediately, or undef it should
#         not be sent at all.
sub delay_remain {
    my $self = shift;
    my $message = shift;

    # Only messages in the pending state can ever be sent
    return undef unless($message -> {"status"} eq "pending");

    # Message is pending, if it has no delay send it now
    return -1 unless($message -> {"delaysend"});

    # Message is pending with a delay, how long does it have left?
    my $now      = time();
    my $sendtime = $message -> {"updated"} + $self -> {"settings"} -> {"config"} -> {"Core:delay_send"};

    # If the current time is after the send time, send immediately
    return -1 if($now > $sendtime);

    # otherwise, how long do we have left?
    return $sendtime - $now;
}


## @method $ send_message($msgid, $force)
# Send the message to all the selected destinations. This will do nothing if
# the message is waiting on a delayed send, unless force is set, in which case
# the message will always be sent if possible.
#
# @param msgid The id of the message to send.
# @param force Force the message to be sent, ignoring the message delay.
# @return True if the message was sent, 0 if it was not. Dies with an error
#         if the message should not/can not be sent.
sub send_message {
    my $self  = shift;
    my $msgid = shift;
    my $force = shift;

    # Get the message data, so we know what to do with it
    my $message = $self -> get_message($msgid);
    die_log($self -> {"cgi"} -> remote_host(), "Unable to fetch message data for message $msgid. This should not happen.") if(!$message);

    # We can only work with "pending" messages
    die_log($self -> {"cgi"} -> remote_host(), "Attempt to send a message that is not in a sendable state. This should not happen.")
        unless($message -> {"status"} eq "pending");

    # check that the message is sendable
    my $remain = $self -> delay_remain($message);
    die_log($self -> {"cgi"} -> remote_host(), "Illegal attempt to send message ".$message -> {"id"}.": message is not sendable!") if(!defined($remain));

    # Do nothing if the remain is > 0 and we're not being forced to send
    return 0 unless($force || $remain <= 0);

    # Message is going out! Work out where the user has asked to send it.
    my $desth = $self -> {"dbh"} -> prepare("SELECT d.args, t.module_id
                                             FROM ".$self -> {"settings"} -> {"database"} -> {"recip_targs"}." AS d,
                                                  ".$self -> {"settings"} -> {"database"} -> {"targets"}." AS t
                                             WHERE d.id = ?
                                             AND t.id = d.target_id");

    my $errors = "";
    foreach my $destid (@{$message -> {"targset"}}) {
        $desth -> execute($destid)
            or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute destination lookup: ".$self -> {"dbh"} -> errstr);

        my $dest = $desth -> fetchrow_hashref();
        die_log($self -> {"cgi"} -> remote_host(), "No matching destination for message ".$message -> {"id"}.", dest $destid") if(!$dest);

        # Get the module to handle the destination
        my $targetmod = $self -> {"targets"} -> {$dest -> {"module_id"}} -> {"module"};
        die_log($self -> {"cgi"} -> remote_host(), "No target module for message ".$message -> {"id"}.", dest $destid") if(!$targetmod);

        # Update the config as needed
        $targetmod -> set_config($dest -> {"args"});

        # Got a target module, send the message
        eval { $targetmod -> send($message) };

        # If we have errors, record them
        $errors .= "<li>Target::".$self -> {"targets"} -> {$dest -> {"module_id"}} -> {"name"}.": $@</li>\n"
            if($@);
    }

    # Message has been sent, update it.
    my $updateh = $self -> {"dbh"} -> prepare("UPDATE ".$self -> {"settings"} -> {"database"} -> {"messages"}."
                                               SET status = ?, updated = UNIX_TIMESTAMP(), sent = UNIX_TIMESTAMP(), visible = 1, fail_info = ?
                                               WHERE id = ?");
    $updateh -> execute($errors ? 'failed' : 'sent',
                        $errors ? $errors : undef,
                        $message -> {"id"})
        or die_log($self -> {"cgi"} -> remote_host(), "Unable to execute message update query: ".$self -> {"dbh"} -> errstr);

    return 1;
}


1;
