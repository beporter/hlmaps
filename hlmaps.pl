#!/usr/bin/perl -w
###############################################################################
#                                                                             #
# hlmaps.pl - A script to present a nice web-based HL server map listing      #
#           - Copyright Scott McCrory                                         #
#           - Distributed under the GPL terms - see the docs for info         #
#           - http://hlmaps.sourceforge.net                                   #
#                                                                             #
###############################################################################
# CVS $Id$
###############################################################################
#
#    HLmaps
#    Copyright (C) 2000 Scott D. McCrory <smccrory@users.sourceforge.com>
#    All Rights Reserved
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
###############################################################################

use strict;                         # Requires us to declare all vars used
use CGI qw(:all);                   # Lets us grab vars passed from web server
use CGI::Carp qw(fatalsToBrowser);  # Sent fatal errors to browser

######################## GLOBAL CONSTANTS #####################################

my $CONF_FILE           = "/etc/hlmaps.conf";

###################### GLOBAL DEVELOPMENT CONSTANTS ###########################

# Development constants - please don't mess with these
my $VERSION             = "0.92, July 22, 2000";
my $AUTHOR_NAME         = "Scott McCrory";
my $AUTHOR_EMAIL        = "scott\@mccrory.com";
my $HOME_PAGE           = "http://hlmaps.sourceforge.net";
my $SCRIPT_NAME         = script_name();

############################# GLOBAL VARIABLES ################################

my %params;         # Hash for untainted, global CGI parameters
my %prefs;          # Hash for user preferences as obtained from $CONF_FILE

my $count;          # Number of maps counted

my %mapname;        # Hash to hold map's shortname
my %download;       # Hash to hold map's download URL
my %image;          # Hash to hold map's image URL
my %popularity;     # Hash to hold map's popularity (times run on server)
my %mapcycle;       # Hash to hold map's inclusion in mapcycle.txt
my %size;           # Hash to hold map's file size
my %moddate;        # Hash to hold map's modification date

################################## MAIN #######################################

$CGI::POST_MAX=1024*100;   # Maximum 100k posts to prevent CGI DOS attacks
$CGI::DISABLE_UPLOADS=1;   # Disable uploads to prevent CGI DOS attacks

$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';    # Adjust path to prevent sloppy code execution
$ENV{BASH_ENV} = '';                            # Clear out environment to prevent sloppy code execution
$ENV{ENV} = '';                                 # Clear out another env to prevent sloppy code execution

untaint_data();                                 # Perform validation of all input data
$params{"order"} = $params{"order"} || "a";     # If sort order wasn't specified, make it (a)scending
get_preferences();
get_map_details();
get_mapcycle();
get_map_popularity();
print_page_header();
print_table_header();
print_map_table();
print_table_footer();
print_page_footer();

############################### SUBROUTINES ###################################

# ----------------------------------------------------------------------------
sub untaint_data {
    # This subroutine creates a new CGI object and pulls in the user-provided
    #    parameters.  We then validate and untaint every parameter to prevent
    #    them from being able to malform a URL or do other naughty things.

    my $q = new CGI;                       # A new CGI object
    my @param_list;                        # Hash to hold CGI parameter list
    my %tainted_params;                    # Hash to hold raw, tainted CGI parameters

    # Load list of CGI parameters and put them in our "tainted" hash
    @param_list = $q->param;
    foreach(@param_list) {
        $tainted_params{"$_"} = $q->param("$_");
    }

    # Now untaint all of the data by using substring pattern matching
    foreach(keys %tainted_params) {
        if ( $tainted_params{"$_"} ) {
            $tainted_params{"$_"} =~/([\w-.]+)/;
            $params{"$_"} = $1;
        } else {
            $params{"$_"} = '';
        }
    }
}

# ----------------------------------------------------------------------------
sub get_preferences {
    # Load HLmaps preferences from $CONF_FILE
    
    my $var;                        # Variable name in .conf
    my $value;                      # Value of variable in .conf

    open(CONF, "$CONF_FILE") || die "Sorry, I couldn't open the preferences file $CONF_FILE\n";
    while (<CONF>) { 
        chomp;                      # no newline 
        s/#.*//;                    # no comments 
        s/^\s+//;                   # no leading white 
        s/\s+$//;                   # no trailing white 
        next unless length;         # anything left? 
        ($var, $value) = split(/\s*=\s*/, $_, 2);
        $prefs{$var} = $value;      # load the untainted value into our hash of vars
    }
    close(CONF);
}

#------------------------------------------------------------------------------
sub get_map_details {
    # Open up server map directory and get list of all *.bsp files there
    #    then cycle through each file and see if a corresponding image and download exists
    #    and then print a table row with the pertainent information
    my @filelist;        # List of files
    my $line;            # Counter for cycling through maps
    my $perms;           # Map file permissions (unused)
    my $nop;             # (unused)
    my $owner;           # Map file owner (unused)
    my $group;           # Map file group (unused)
    my $size;            # Map file size
    my $month;           # Map file month
    my $day;             # Map file day
    my $yeartime;        # Map file year and time
    my $filename;        # Map filename
    my $shortname;       # Map short filename
    
    $filename = "$prefs{SERVER_MAP_DIR}" . "*.bsp";
    @filelist = `ls -l $filename`;
    foreach $line (@filelist)
    {
        
        ++$count;
        chomp($line);
    
        # Get the map details
        ($perms, $nop, $owner, $group, $size, $month, $day, $yeartime, $filename) = split(' ', $line);
        $filename =~ /$prefs{SERVER_MAP_DIR}(\w+)/;
        $shortname = $1;
        chomp($shortname);
        $mapname{"$shortname"} = "$shortname";
        $size{"$shortname"} = int($size / 1024);
        $moddate{"$shortname"} = "$month $day $yeartime";

        $download{"$shortname"} = $download{"$shortname"} || "#na#";
        $image{"$shortname"} = $image{"$shortname"} || "#na#";
        $popularity{"$shortname"} = 0;
        $mapcycle{"$shortname"} = "#na#";
        
        # Get the map's corresponding download link if it exists
        $filename = "$prefs{DOWNLOAD_DIR}" . "$shortname" . ".zip";
        if ($filename && -e $filename) {
            $download{"$shortname"} = $filename;
        }
           
        # Get the map's corresponding image file if it exists
        $filename = "$prefs{IMAGES_DIR}" . "$shortname" . ".jpg";
        if ($filename && -e $filename) {
            $image{"$shortname"} = "$prefs{IMAGES_URL}" . "$shortname" . ".jpg";
        }
    }
}

#------------------------------------------------------------------------------
sub get_mapcycle {
    # To know if a map is in the current mapcycle, we'll read the list first
    open(MAPCYC,"$prefs{MAPCYCLE}") || die "Sorry, I couldn't open the mapcycle\n";
    while (<MAPCYC>) {
        chomp;
        if ( $mapname{"$_"} ) { $mapcycle{"$_"} = "Yes"; }
    }
    close(MAPCYC);
}

#------------------------------------------------------------------------------
sub get_map_popularity {
    # To know how popular a map is, we'll parse the logs
    my @filelist;           # List of files
    my($filename, $line);    
        
    opendir(DIR, "$prefs{SERVER_LOG_DIR}");
    @filelist = readdir(DIR);
    closedir(DIR);
    foreach $filename (@filelist) {
        if ($filename !~ /log$/) { next; }
        open(LOGFILE, $prefs{SERVER_LOG_DIR}.$filename) or die "Could not open $filename: $!";
        while ($line = <LOGFILE>) {
            if ($line =~ /Spawning server \"(\w+)\"/) {
                if ($mapname{$1}) { ++$popularity{$1}; }
                last;
            }
        }   
        close(LOGFILE);
    }     
}      

#------------------------------------------------------------------------------
sub print_page_header {
    # Print the page header
    print header(), start_html("$prefs{PAGE_HEADING}");
    print "<body background=\"$prefs{PAGE_BG_IMG}\" bgcolor=\"$prefs{PAGE_BG_COLOR}\" text=\"$prefs{PAGE_TEXT_COLOR}\" link=\"$prefs{PAGE_LINK_COLOR}\" vlink=\"$prefs{PAGE_V_LINK_COLOR}\" alink=\"$prefs{PAGE_A_LINK_COLOR}\">";
    print h1("<CENTER> $prefs{PAGE_HEADING} </CENTER>");
    print h3("<CENTER><I> Click the column headings to sort by them </I></CENTER><BR>");
}

#------------------------------------------------------------------------------
sub print_table_header {   
    my $inverse;
    
    # Get the inverse sort order so that the user can reverse
    #    the way the maps are displayed if they choose
    if ($params{"order"} eq "a") {
        $inverse = "d";
    } else {
        $inverse = "a";
    }        

    # Print the table header
    print "<table border=\"1\" bordercolordark=\"$prefs{TABLE_BORDER_LIGHT_COLOR}\" bordercolorlight=\"$prefs{TABLE_BORDER_DARK_COLOR}\" cellspacing=\"0\" cellpadding=\"3\" align=\"center\">";
    print "<tr>";     
    print "<td align=\"center\"><a href=\"$SCRIPT_NAME?sort=mapname&order=$inverse\"><b>Map Name</b></a></td>";
    print "<td align=\"center\"><a href=\"$SCRIPT_NAME?sort=image&order=$inverse\"><b>Image</b></a></td>";
    print "<td align=\"center\"><a href=\"$SCRIPT_NAME?sort=popularity&order=$inverse\"><b>Times Played</b></a></td>";
    print "<td align=\"center\"><a href=\"$SCRIPT_NAME?sort=mapcycle&order=$inverse\"><b>In Map Cycle</b></a></td>";
    print "<td align=\"center\"><a href=\"$SCRIPT_NAME?sort=size&order=$inverse\"><b>Size</b></a></td>";
    print "<td align=\"center\"><b>Mod Date</b></td>";
    print "</tr>\n";
}

#------------------------------------------------------------------------------
sub print_map_table {
    
    my $hlmap;          # The map we're working with in the loop
    my @sortkeys;       # Which field we're going to sort by

    # If we're asked to sort, then we'll rearrange the hash key order on
    #    the requested sort element ...
    if ( $params{'sort'} eq "download") {
        if ( $params{"order"} eq "a") {
            @sortkeys = sort { $download{$a} cmp $download{$b} } keys %download;
        } else {
            @sortkeys = sort { $download{$b} cmp $download{$a} } keys %download;
        }
    } elsif ( $params{'sort'} eq "image") {
        if ( $params{"order"} eq "a") {
            @sortkeys = sort { $image{$a} cmp $image{$b} } keys %image;
        } else {
            @sortkeys = sort { $image{$b} cmp $image{$a} } keys %image;
        }
    } elsif ( $params{'sort'} eq "popularity") {
        if ( $params{"order"} eq "a") {
            @sortkeys = sort { $popularity{$a} <=> $popularity{$b} } keys %popularity;
        } else {
            @sortkeys = sort { $popularity{$b} <=> $popularity{$a} } keys %popularity;
        }
    } elsif ( $params{'sort'} eq "mapcycle") {
        if ( $params{"order"} eq "a") {
            @sortkeys = sort { $mapcycle{$a} cmp $mapcycle{$b} } keys %mapcycle;
        } else {
            @sortkeys = sort { $mapcycle{$b} cmp $mapcycle{$a} } keys %mapcycle;
        }
    } elsif ( $params{'sort'} eq "size") {
        if ( $params{"order"} eq "a") {
            @sortkeys = sort { $size{$a} <=> $size{$b} } keys %size;
        } else {
            @sortkeys = sort { $size{$b} <=> $size{$a} } keys %size;
        }
    } elsif ( $params{'sort'} eq "moddate") {
        if ( $params{"order"} eq "a") {
            @sortkeys = sort { $moddate{$a} cmp $moddate{$b} } keys %moddate;
        } else {
            @sortkeys = sort { $moddate{$b} cmp $moddate{$a} } keys %moddate;
        }
    } else {
        if ( $params{"order"} eq "a") {
            @sortkeys = sort { $mapname{$a} cmp $mapname{$b} } keys %mapname;
        } else {
            @sortkeys = sort { $mapname{$b} cmp $mapname{$a} } keys %mapname;
        }
    }

    foreach $hlmap (@sortkeys) {
        print "<tr>";
 
        # Print the map's name (and corresponding download link if present)
        if ($download{"$hlmap"} && $download{"$hlmap"} ne "#na#" && -e $download{"$hlmap"}) {
            print "<td align=\"center\"><a href=\"$prefs{DOWNLOAD_URL}$hlmap.zip\"><B>$hlmap</B></a></td>";
        } else {
            print "<td align=\"center\"><B>$hlmap</B></td>";
        }
 
        # If there's a corresponding image file, display it.
        if ($image{"$hlmap"} && $image{"$hlmap"} ne "#na#") {
            print "<td align=\"center\"><img src=\"$image{\"$hlmap\"}\" ALT=\"$hlmap\" WIDTH=212 HEIGHT=160></td>";
        } else {
            print "<td align=\"center\"><i>Image not available</i></td>";
        }
 
        # Now print image's popularity (number of times run on the server)
        if ($popularity{"$hlmap"} > 0) {
            print "<td align=\"center\"><B>Played $popularity{\"$hlmap\"} time";
            if ( $popularity{"$hlmap"} > 1 ) { print "s"; }
            print "</B></td>";
        } else {
            print "<td align=\"center\"><i>never</i></td>";
        }

        # Print whether this map is in the server's mapcycle.txt or not
        if ( $mapcycle{"$hlmap"} && $mapcycle{"$hlmap"} ne "#na#") {
            print "<td align=\"center\"><b>In Mapcycle</b></td>";
        } else {
            print "<td align=\"center\"><i>no</i></td>";
        }
 
        # Print map's file size
        if ( $size{"$hlmap"} && $size{"$hlmap"} ne "#na#") {
            print "<td align=\"right\">$size{\"$hlmap\"} k</td>";
        } else {
            print "<td align=\"center\"><i>-</i></td>";
        }

        # Print map's modification date
        if ( $moddate{"$hlmap"} && $moddate{"$hlmap"} ne "#na#") {
            print "<td align=\"center\">$moddate{\"$hlmap\"}</td>";
        } else {
            print "<td align=\"center\"><i>-</i></td>";
        }

        print "</tr>";
    }
}

#------------------------------------------------------------------------------
sub print_table_footer {
    # We're done with the table, so close it out and print the footer information
    print "</td></table>";
}

#------------------------------------------------------------------------------
sub print_page_footer {
    print "<BR><CENTER><B>Total of $count maps found</B><BR><BR>";
    print "Generated by <a href=\"$HOME_PAGE\"><B>hlmaps.pl</B></a> $VERSION<BR>";
    print "Written by <a href=\"MAILTO:$AUTHOR_EMAIL\">$AUTHOR_NAME</a></CENTER><BR>";
    print end_html;
}

###############################################################################
