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
# @section index_mpblock MegaphoneBlock
# MegaphoneBlock extends the Block class to provide functions common to all
# Megaphone implementation modules. All Megaphone classes extend this class
# (and, through it, Block) to provide their features. MegaphoneBlock is never
# used directly, rather its functions are called by its subclasses.
#
# @section index_level2 MegaphoneCore, UserMessages, Login, and Cron
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
# @section index_target Target
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
#
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
# @section creating_optionless Creating optionless targets.
#
# Creating an optionless Target subclass involves implementing a single function
# in your new module
1;
