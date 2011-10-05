## @file
# This file contains documentation for the Megaphone system.
#
# @author  Chris Page &lt;chris@starforge.co.uk&gt;
# @version 1.0
# @date    3 Oct 2011
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

## @mainpage
# @section index_intro Introduction
# Megaphone is a highly modular, extensible perl-based message composition,
# dispatch, and tracking web application written for the School of CS at
# the University of Manchester. It provides facilities that allow users to
# compose messages through a simple web interface, and then send the
# messages via a variety of transports and systems to selected recipients.
#
# @section index_internal Internal architecture
# @subsection index_webperl Webperl
# The base of the Megaphone system is 'webperl', a suite of Perl classes
# and modules originally developed by Chris Page to support his own websites,
# and since reused in a number of large web systems (including the UK
# Schools National Animation Competition, and various projects supporting
# APEcs' course development systems.) webperl provides support for:
#
# - dynamic loading of classes on demand (allowing the creation of plugin
#   mechanisms.)
# - template processing, with multiple language support
# - cookie-based sessions, with optional persistent sessions and query-string
#   SID fallback.
# - utility modules for loading and saving configuration files
# - a 'Block' class that serves as the base class for plugin modules loaded
#   through the dynamic module loader. The Block class also includes a
#   range of standard form validation support functions.
#
# See <a href="../webperl/">the WebPerl docs</a> for more details.
#
# @subsection index_mpblock MegaphoneBlock
# MegaphoneBlock extends the Block class to provide functions common to all
# Megaphone implementation modules. All Megaphone classes extend this class
# (and, through it, Block) to provide their features. MegaphoneBlock is never
# used directly, rather its functions are called by its subclasses.
#
# @subsection index_level2 MegaphoneCore, UserMessages, Login, and Cron
# The actual 'user interface' classes build on top of MegaphoneBlock, each
# class concentrating on implementing a different aspect of the system:
#
# - MegaphoneCore implements the basic message composition, editing, and
#   confirmation web interface.
# - UserMessages generates the list of messages a user has composed, and
#   provides options to manipulate them.
# - Login implements a 'stand-alone' login page, used when the user attempts
#   to access an area of the system that requires access control when they
#   are not currently logged in.
# - Cron provides the message check and send facility required to support
#   delayed message sending.
#
# These UI modules are never invoked directly - the index.cgi script looks
# for a 'block' argument in the query string or posted data, and uses that
# to determine which of the UI modules should be loaded to serve the page.
# When loaded by index.cgi, the module's page_display() function is called
# to perform module-specific logic and page generation.
#
# @subsection index_target Target
# Target is used as the base class for message target implementation modules.
# All modules that handle sending messages to other systems must be added
# as subclasses of Target to work correctly, and the Target class extends
# MegaphoneBlock to provide the minimal interface that individual Target
# subclasses may override to provide more useful features.
#
# Currently implemented Target sublasses are:
#
# - Target::Email provides the facility to send messages to users via email,
#   with options to cc/bcc copies as needed.
# - Target::Moodle allows messages to be posted to Moodle forums.
# - Target::Twitter will post messages to twitter, either truncating or splitting
#   long messages depending on user selection.
#
# See \ref creating_targets for more details about how to implement new
# targets for the system.
#
# @section index_schema Database schema
#
# A diagram illustrating the database schema is <a href="../megaphone_schema.png">available here</a>.
# You may wish to refer to that image while reading the remainder of this section.
#
# The Megaphone database schema consists of four 'groups' of tables, with some
# connections between them:
#
# - mp_settings: webperl's settings table is an isolated table containing a list
#   of key-value pairs representing the system configuration.
# - mp_sessions and mp_session_keys: webperl's session tables, each session and
#   session key contains the ID of the user who owns the session.
# - mp_blocks and mp_modules: webperl's module and block handling tables. All
#   dynamically loadable modules appear in the mp_modules table, while web-accessible
#   modules also have entries in the mp_blocks table. Dynamically loadable Target
#   modules are recorded in the mp_modules table, and the IDs given there are
#   used in the mp_targets table.
# - the remaining tables are Megaphone-specific.
#
# The majority of tables in the database are hopefully self-explanatory, but what follows
# is a summary of the important tables:
#
# - mp_users contains the list of users who have successfully logged into the system
#   at least once. The first time a user logs in (and is listed in the mp_authorised_users
#   table), a new row is created for them in the mp_users table - it is not necessary
#   to create entries for users in the mp_users table before they log in. However, the
#   user must appear in the mp_authorised_users table to log in, and if their entry in
#   the mp_authorised_users table is removed, they will be unable to log in even if
#   they provide the correct credentials and even have an entry in mp_users.
# - mp_messages stores the list of all messages composed in the system, and the data
#   about the messages. It is important to note that mp_messages only stores the
#   common information about each message - target specific information should be
#   recorded in a separate tables, <b>never</b> modify the mp_messages table to store
#   target-specific data.
# - mp_recipients, mp_targets, and mp_recipients_targets store the list of recipient names,
#   target names and the IDs of the Target modules that handle the target, and a mapping
#   between recipients and targets. The latter table forms the basis of the Destinations
#   table shown to the user, and it contains any recipient-specific data to pass to the
#   responsible Target module when it is invoked to send a message.
# - mp_message_dests contains the list of selected mp_recipients_targets rows for a given
#   message: the list of recipients the user wants the message to go to, and the systems
#   the message should be sent through.
#
# @page creating_targets Creating Target modules
#
# If you need to send messages to a system that Megaphone does not currently
# support, you will usually need to create a new Target subclass to handle it.
# There are generally two forms of Target subclass:
#
# - Optionless, send only. These are Targets that only require the "Common options"
#   from the user (destination, message prefix, subject, and body). A good example
#   of this form of Target subclass is Target::Moodle
# - Full implementations. These are targets that present the user with additional
#   options when selected as a destination. They must implement the full range
#   of Target interface functions to insert their options into the message forms,
#   and handle the storage and retrieval of message data. Target::Twitter is a
#   simple example of this form of Target subclass.
#
# This page discusses how to create both sorts of targets, and then provides
# information anout how to make Megaphone aware of your new target.
#
# @section creating_optionless Creating optionless targets.
#
# To create an optionless Target subclass you <b>must</b> provide your own send()
# implementation. You will probably also want to implement your own set_config()
# function, to convert any arguments set in the database for your target into
# something your send function can use. A very minimal example Target subclass would be:
# \verbatim
# package Target::YourTarget; # All targets must be in the Target:: namespace
# use strict;
# use base qw(Target);        # All target classes must extend Target
#
# sub send() {
#     my $self    = shift;
#     my $message = shift;
#
#     # Do something with $message here to send it to your system
# }
#
# 1;
# \endverbatim
#
# The message argument is a reference to a hash containing the data to be sent to
# your target. The basic contents are:
# \verbatim
# my $message = {
#     'created'      => '',       # unix timestamp containing message creation time
#     'delaysend'    => '',       # 0 for no delay, 1 for delay
#     'format'       => 'plain',  # message body format - 'plain' or 'html'
#     'fail_info'    => undef,    # Failure reason, undef in send(), do not edit.
#     'id'           => '',       # id of the message being sent
#     'message'      => '',       # The message body text
#     'prefix_id'    => '1',      # Selected prefix id. 0 = use prefix_other
#     'prefix_other' => undef,    # custom prefix text
#     'previous_id'  => undef,    # id of the message that this is an edit of
#     'sent'         => undef,    # sent timeout. undef in send(), do not edit.
#     'status'       => 'pending',# message status. Must be 'pending' to send!
#     'subject'      => '',       # The message subject
#     'targset'      => [ '9' ],  # array of selected recipients_targets rows
#     'targused'     => {         # hash of used Target module ids.
#         '101' => 1
#     },
#     'updated'      => '',       # unix timestamp of last update
#     'visible'      => '0',      # Always 0 in send(), do not edit.
#     'user_id'      => ''        # ID of the message owner
# };
# \endverbatim
#
# Other targets may have added their own data to the message hash, but the above
# values will always be available regardless of the other Target subclasses in the
# system.
#
# The $self argument is a reference to a hash which will contain, among other things,
# references to the cgi, dbh, template, settings, and session objects - you may use
# them as needed when sending your message.
#
# @section creating_options Creating Target modules with options
#
# Sometimes your intended target system will require additional information from the
# user (for example, the Target::Email class allows users to enter cc/bcc and custom
# Reply-To information, and Target::Twitter lets the user decide whether to truncate
# or split long messages when posting to twitter.) Megaphone has been designed to
# support this level of module-specific data collection without the need to modify
# the core code in any way: Target modules that need to collect additional information
# from the user need to implement a number of functions to collect, validate, store,
# retrieve, and display their data, and those functions are called by the core code
# as needed.
#
# Implementing a Target module with options basically involves providing versions of
# all the functions defined in Target. Please see the Target::Twitter module for a
# simple example.
#
# @section creating_register Making Megaphone aware of the new target
#
# Simply creating the new Target subclass is not enough to make it available to users;
# you need to tell Megaphone that it exists, and set up any destination-specific
# arguments to be passed to it during message sending. To do this, you need to add
# entries to three tables in the database:
#
# - create an entry for the new module in the mp_modules table. As a rule of thumb,
#   Target subclasses should use IDs over 100.
# - create an entry in mp_targets giving the human-readable target name, and the ID
#   of the module just added to the mp_modules table.
# - add entries to mp_recipients_targets for each recipient you need to support with
#   your target module, supplying any recipient-specific arguments necessary in the
#   args column.
#
# Once you have completed these steps, your new target will be available to users.
1;
