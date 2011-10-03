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

# @mainpage
# @section index_intro Introduction
# Megaphone is a highly modular, extensible perl-based message composition,
# dispatch, and tracking web application written for the School of CS at
# the University of Manchester. It provides facilities to allow a user to
# compose a message through a simple web interface, and then send that
# message via a variety of transports and systems to selected recipients.
#
# @section index_internal Internal architecture
# @subsection index_webperl Webperl
# The base of the Megaphone system is 'webperl', a suite of Perl classes
# and modules originally developed by Chris Page to support his own websites,
# and since reused in a number of large web systems (including the UK
# Schools National Animation Competition, and various projects supporting
# APEcs' course development systems.) webperl provides support for:
#
# * dynamic loading of classes on demand (allowing the creation of plugin
#   mechanisms.)
# * template processing, with multiple language support
# * cookie or query string sessions, with optional persistent sessions.
# * utility modules for loading and saving configuration files
# * a 'Block' class that serves as the base class for plugin modules loaded
#   through the dynamic module loader. The Block class also includes a
#   range of standard form validation support functions.
#
# See <a href="../webperl/">the WebPerl docs</a> for more details.
#
# @section MegaphoneBlock
# MegaphoneBlock extends the Block class to provide functions common to all
# Megaphone implementation modules. All Megaphone classes extend this class
# (and, through it, Block) to provide their features. MegaphoneBlock is never
# use directly, rather its functions are called by its subclasses.
#
# The Megaphoneblock class is divided up into several distinct chunks of code:
#
# * functions in the 'Storage' section are concerned with interaction with
#   the backend database. The store_message() and get_message() functions
#   are Target-aware (that is, they will invoke the appropriate store and get
#   functions in the available Target modules, to allow each of them to store
#   or retrieve target-specific data for the message.)
# * functions in the 'Fragment generators'
