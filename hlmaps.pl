#!/usr/bin/perl -w -T
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
# Make sure you modify this if you're running multiple instances of HLmaps
#    on the same server (one pointing to a CS server, another for TFC, etc.)
#    Make all other preference changes in that file (not here!).

my $CONF_FILE           = "/etc/hlmaps.conf";

###################### GLOBAL DEVELOPMENT CONSTANTS ###########################

# Development constants - please don't mess with these
my $VERSION             = "0.95, September 1, 2000";
my $AUTHOR_NAME         = "Scott McCrory";
my $AUTHOR_EMAIL        = "smccrory\@users.sourceforge.net";
my $HOME_PAGE           = "http://hlmaps.sourceforge.net";
my $SCRIPT_NAME         = script_name();

############################# GLOBAL VARIABLES ################################

my %params;         # Hash for untainted, global CGI parameters
my %prefs;          # Hash for user preferences as obtained from $CONF_FILE

my %mapname;        # Hash to hold map's shortname
my %textfile;       # Hash to hold map's textfile if present
my %download;       # Hash to hold map's download URL
my %image;          # Hash to hold map's image URL
my %popularity;     # Hash to hold map's popularity (times run on server)
my %mapcycle;       # Hash to hold map's inclusion in mapcycle.txt
my %size;           # Hash to hold map's file size
my %moddate;        # Hash to hold map's modification date

my $count;          # Number of maps counted

################################## MAIN #######################################

$CGI::POST_MAX=1024*10;     # Maximum 10k posts to prevent CGI DOS attacks
$CGI::DISABLE_UPLOADS=1;    # Disable uploads to prevent CGI DOS attacks
$ENV{PATH} = '';            # Adjust path to prevent sloppy code execution
$ENV{BASH_ENV} = '';        # Clear out environment to prevent sloppy code execution
$ENV{ENV} = '';             # Clear out another env to prevent sloppy code execution

set_default_values();       # Fill in unspecified variables
get_preferences();          # Load preferences from .conf file
untaint_data();             # Perform validation of all input data
if ( $prefs{DATA_LOCATION} ne "mysql" ) {
    get_text_map_details(); # Read HLmaps data from file
} else {
    get_mysql_map_details();# Read HLmaps data from MySQL database    
}

if ($params{"map"}) {
    print_single_map();     # Print the single-map screen
} else {
    print_page_header();    # Print page header, title, etc.
    print_map_per_page_widget(); # Print drop-down for number of maps/page
    print_nav_bar();        # Print multi-page navigation bar
    print_table_header();   # Print table contruct and header row
    print_map_table();      # Print actual table with info
    print_table_footer();   # Cap off the table
    print_nav_bar();        # Print multi-page navigation bar
    print_page_footer();    # End the HTML page
}

############################### SUBROUTINES ###################################

#------------------------------------------------------------------------------
sub set_default_values {
    # Set the default CGI parameters and variables if they were not specified
    #   for us in the URL or the .conf
    
    $prefs{SERVER_LOG_SPAWN_MSG}        = "Spawning server";
    $prefs{MAP_EXTENSION}               = "bsp";
    $prefs{DOWNLOAD_EXT}                = "zip";
    
    $prefs{PAGE_BG_URL}                 = "";
    $prefs{PAGE_BG_COLOR}               = "Black";
    $prefs{PAGE_TEXT_COLOR}             = "Yellow";
    $prefs{PAGE_LINK_COLOR}             = "Lime";
    $prefs{PAGE_V_LINK_COLOR}           = "Aqua";
    $prefs{PAGE_A_LINK_COLOR}           = "Green";
    
    $prefs{TABLE_BORDER_LIGHT_COLOR}    = "Aqua";
    $prefs{TABLE_BORDER_DARK_COLOR}     = "Green";
    $prefs{TABLE_NORM_HEAD_COLOR}       = "Navy";
    $prefs{TABLE_SORT_HEAD_COLOR}       = "Blue";
    
    $prefs{DEFAULT_MAPS_PER_PAGE}       = "20";
    
    $prefs{PAGE_HEADING}                = "HLmaps Server Map Listing";
    $prefs{PAGE_SUBHEADING}             = "Click the column headings to sort by them";
    $prefs{PAGE_MAPCOUNT_PRE}           = "Total of";
    $prefs{PAGE_MAPCOUNT_SUF}           = "maps found";
    $prefs{PAGE_DOWNLOAD}               = "Download this map";
    $prefs{PAGE_MAPS_PER_PAGE}          = "Maps Per Page";
    $prefs{PAGE_REFRESH}                = "Refresh";
    
    $prefs{TABLE_MAPNAME_COLUMN}        = "Map Name";
    $prefs{TABLE_IMAGE_COLUMN}          = "Image";
    $prefs{TABLE_POPULARITY_COLUMN}     = "Popularity";
    $prefs{TABLE_MAPCYCLE_COLUMN}       = "In Map Cycle";
    $prefs{TABLE_SIZE_COLUMN}           = "Size";
    $prefs{TABLE_MODDATE_COLUMN}        = "Mod Date";
    $prefs{TABLE_POPULARITY_COUNT_PRE}  = "Played";
    $prefs{TABLE_POPULARITY_COUNT_SUF}  = "time(s)";
    $prefs{TABLE_POPULARITY_NEVER}      = "Never Played";
    $prefs{TABLE_MAPCYCLE_YES}          = "In Map Cycle";
    $prefs{TABLE_MAPCYCLE_NO}           = "No";
    $prefs{TABLE_IMAGE_NO}              = "Image Not Available";
    
    $prefs{DATA_LOCATION}               = "/var/hlmaps.data";
    
    $prefs{MYSQL_SERVER}                = "localhost";
    $prefs{MYSQL_DATABASE}              = "HLmaps";
    $prefs{MYSQL_USER}                  = "HLmaps";
    $prefs{MYSQL_PASSWORD}              = "HLmaps";
    $prefs{MYSQL_TABLE}                 = "maps";
    $prefs{MYSQL_MAPNAME_FIELD}         = "mapname";
    $prefs{MYSQL_IMAGEURL_FIELD}        = "imageurl";
    $prefs{MYSQL_DOWNLOAD_FIELD}        = "downloadurl";
    $prefs{MYSQL_TEXTFILE_FIELD}        = "textfile";
    $prefs{MYSQL_POPULARITY_FIELD}      = "popularity";
    $prefs{MYSQL_MAPCYCLE_FIELD}        = "mapcycle";
    $prefs{MYSQL_SIZE_FIELD}            = "size";
    $prefs{MYSQL_MODDATE_FIELD}         = "moddate";

    $params{"order"}                    = "a";
    $params{"page"}                     = "1";
    $count                              = "0";
}

# ----------------------------------------------------------------------------
sub get_preferences {
    # Load HLmaps preferences from $CONF_FILE

    my $var;                        # Variable name in .conf
    my $value;                      # Value of variable in .conf

    open(CONF, "$CONF_FILE") || die "Sorry, I couldn't open the preferences file $CONF_FILE: $!\n";
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
            $tainted_params{"$_"} =~/([\w\-.]+)/;
            $params{"$_"} = $1;
        } else {
            $params{"$_"} = '';
        }
    }
}

#------------------------------------------------------------------------------
sub get_text_map_details {
    # Open up hlmaps.data file and pull out the map details

    my $l_mapname;
    my $l_textfile;
    my $l_download;
    my $l_image;
    my $l_popularity;
    my $l_mapcycle;
    my $l_size;
    my $l_moddate;

    # Scan the hlmaps.data file and load details into our arrays
    open(DATA,"<$prefs{DATA_LOCATION}") || die "Sorry, I couldn't open the data file $prefs{DATA_LOCATION}: $!\n";
    while (<DATA>) {
        chomp;                  # Take off the newline at the end
        ($l_mapname,$l_textfile,$l_download,$l_image,$l_popularity,$l_mapcycle,$l_size,$l_moddate) = split(/,/ , $_);
        $mapname{$l_mapname}    = $l_mapname;
        $textfile{$l_mapname}   = $l_textfile;
        $download{$l_mapname}   = $l_download;
        $image{$l_mapname}      = $l_image;
        $popularity{$l_mapname} = $l_popularity;
        $mapcycle{$l_mapname}   = $l_mapcycle;
        $size{$l_mapname}       = $l_size;
        $moddate{$l_mapname}    = $l_moddate;
        ++$count;                               # Increment the map counter
    }
    close(DATA);
}
#------------------------------------------------------------------------------
sub get_mysql_map_details {
    # Open up HLmaps database and pull out the map details

    use DBI;

    my $l_mapname;
    my $l_textfile;
    my $l_download;
    my $l_image;
    my $l_popularity;
    my $l_mapcycle;
    my $l_size;
    my $l_moddate;
    
    # Set up database variables and handles
    my ($dsn) = "DBI:mysql:$prefs{MYSQL_DATABASE}:$prefs{MYSQL_SERVER}";
    my ($user_name) = $prefs{MYSQL_USER};
    my ($password) = $prefs{MYSQL_PASSWORD};
    my ($dbh, $sth);
    my (@ary);
    my (%attr) =
    (
        PrintError => 0,
        RaiseError => 0
    );
    
    # Connect to the database
    $dbh = DBI->connect ($dsn, $user_name, $password, \%attr) or mysql_bail_out ("Cannot connect to server '$prefs{MYSQL_SERVER}' into database '$prefs{MYSQL_DATABASE}' with user '$prefs{MYSQL_USER}' and password '$prefs{MYSQL_PASSWORD}'");
    
    # Set active table
    $sth = $dbh->prepare ("USE $prefs{MYSQL_DATABASE}") or mysql_bail_out ("Cannot use maps table '$prefs{MYSQL_TABLE}'");
    $sth->execute () or mysql_bail_out ("Cannot execute command to use maps table '$prefs{MYSQL_TABLE}'");
    
    # Issue query to read all of the details from the database
    $sth = $dbh->prepare ("SELECT $prefs{MYSQL_MAPNAME_FIELD},$prefs{MYSQL_IMAGEURL_FIELD},$prefs{MYSQL_DOWNLOAD_FIELD},$prefs{MYSQL_TEXTFILE_FIELD},$prefs{MYSQL_POPULARITY_FIELD},$prefs{MYSQL_MAPCYCLE_FIELD},$prefs{MYSQL_SIZE_FIELD},$prefs{MYSQL_MODDATE_FIELD} FROM $prefs{MYSQL_TABLE} ORDER BY $prefs{MYSQL_MAPNAME_FIELD}") or mysql_bail_out ("Cannot prepare query from table '$prefs{MYSQL_TABLE}'");
    $sth->execute () or mysql_bail_out ("Cannot execute query from table '$prefs{MYSQL_TABLE}'");
 
    # Read results of query
    while (($l_mapname,$l_textfile,$l_download,$l_image,$l_popularity,$l_mapcycle,$l_size,$l_moddate) = $sth->fetchrow_array ()) {
       $mapname{$l_mapname}    = $l_mapname;
       $textfile{$l_mapname}   = $l_textfile;
       $download{$l_mapname}   = $l_download;
       $image{$l_mapname}      = $l_image;
       $popularity{$l_mapname} = $l_popularity;
       $mapcycle{$l_mapname}   = $l_mapcycle;
       $size{$l_mapname}       = $l_size;
       $moddate{$l_mapname}    = $l_moddate;
       ++$count;                               # Increment the map counter
    }
    # Close the database and clean up
    $sth->finish () or mysql_bail_out ("Cannot finish cleanup from database '$prefs{MYSQL_DATABASE}'");
    $dbh->disconnect () or mysql_bail_out ("Cannot disconnect from database '$prefs{MYSQL_DATABASE}'");
}

#------------------------------------------------------------------------------
sub mysql_bail_out {
    # Print the full text error messages for any database problems  
    my ($message) = shift;
    die "$message\nError $DBI::err ($DBI::errstr)\n";
}

#------------------------------------------------------------------------------
sub print_page_header {
    # Print the page header
    print header(), start_html("$prefs{PAGE_HEADING}");
    print "<body background=\"$prefs{PAGE_BG_URL}\" bgcolor=\"$prefs{PAGE_BG_COLOR}\" text=\"$prefs{PAGE_TEXT_COLOR}\" link=\"$prefs{PAGE_LINK_COLOR}\" vlink=\"$prefs{PAGE_V_LINK_COLOR}\" alink=\"$prefs{PAGE_A_LINK_COLOR}\">\n";
    print h1("<CENTER> $prefs{PAGE_HEADING} </CENTER>\n");
    print h3("<CENTER><I> $prefs{PAGE_SUBHEADING} </I></CENTER>\n");
}

#------------------------------------------------------------------------------
sub print_map_per_page_widget {
    # Display the drop-down widget to let user determine how many maps to display

    # If the number of maps/page wasn't passed in from CGI then use default
    if ( !$params{mapsperpage} ) {
        $params{mapsperpage} = $prefs{DEFAULT_MAPS_PER_PAGE};
    }

    # Now print the actual widget
    print start_form();
    print "<CENTER><B><I>$prefs{PAGE_MAPS_PER_PAGE}:</B></I> ";
    print popup_menu("mapsperpage",[$params{mapsperpage},"10","20","50","100"]);
    print submit("$prefs{PAGE_REFRESH}");
    print "</CENTER>";
    print end_form();
    
}

#------------------------------------------------------------------------------
sub print_nav_bar {
    # This is where we print the page navigation bar (really a table) so that
    #    users can limit the number of maps displayed per page and can walk
    #    through the result set.

    my $pages;      # Number of pages as calculated
    my $i;          # Loop counter

    if ( $count % $params{mapsperpage} != 0 ) {
      $pages = int( $count / $params{mapsperpage} ) + 1;      #Calculate total pages (last page not full)
    } else {
      $pages = int( $count / $params{mapsperpage} );          #Calculate total pages (last page full)
    }
    
    if ( $pages > 1 ) {
        print "<TABLE border=\"1\" bordercolordark=\"$prefs{TABLE_BORDER_LIGHT_COLOR}\" bordercolorlight=\"$prefs{TABLE_BORDER_DARK_COLOR}\" cellspacing=\"0\" cellpadding=\"3\" ALIGN=\"CENTER\">\n";
        print "<TR>";

        # If we're not on page one, then print the "Prev" cell
        if ($params{page} > 1 ) {
            print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR}>";
            print "<A HREF=\"$SCRIPT_NAME?sort=$params{sort}&order=$params{order}&mapsperpage=$params{mapsperpage}&page=" . ($params{page} - 1) . "\"><B>Prev</B></A></TD>\n";
        }

        # Now cycle through all of the pages and print the corresponding cell
        for ($i = 1; $i <= $pages; $i++) {
            print "<TD ALIGN=\"CENTER\" ";
            if ($i == $params{page}) {
                print "BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR}>";
            } else {
                print "BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR}>";
            }
            print "<A HREF=\"$SCRIPT_NAME?sort=$params{sort}&order=$params{order}&mapsperpage=$params{mapsperpage}&page=$i\"><B>$i</B></A></TD>\n";
        }

        # If we're not on the last page, then print the "Next" cell
        if ($params{page} < $pages ) {
            print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR}>";
            print "<A HREF=\"$SCRIPT_NAME?sort=$params{sort}&order=$params{order}&mapsperpage=$params{mapsperpage}&page=" . ($params{page} + 1) . "\"><B>Next</B></A></TD>\n";
        }

        print "</TR><BR>\n";
        print "</TABLE>\n";
    }
    print "<BR>\n";
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
    print "<TABLE border=\"1\" bordercolordark=\"$prefs{TABLE_BORDER_LIGHT_COLOR}\" bordercolorlight=\"$prefs{TABLE_BORDER_DARK_COLOR}\" cellspacing=\"0\" cellpadding=\"3\" ALIGN=\"CENTER\">\n";
    print "<TR>\n";

    # Print column header for mapname
    if ($params{"sort"} eq "mapname" ) {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
        if ($params{order} eq "a") {
            print "<B>{A}<B> ";
        } else {
            print "<B>{D}<B> ";
        }
    } else {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
    }
    print "<A HREF=\"$SCRIPT_NAME?sort=mapname&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_MAPNAME_COLUMN}</B></A></TD>\n";

    # Print column header for image
    if ($params{"sort"} eq "image" ) {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
        if ($params{order} eq "a") {
            print "<B>{A}<B> ";
        } else {
            print "<B>{D}<B> ";
        }
    } else {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
    }
    print "<A HREF=\"$SCRIPT_NAME?sort=image&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_IMAGE_COLUMN}</B></A></TD>\n";

    # Print column header for popularity
    if ($params{"sort"} eq "popularity" ) {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
        if ($params{order} eq "a") {
            print "<B>{A}<B> ";
        } else {
            print "<B>{D}<B> ";
        }
    } else {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
    }
    print "<A HREF=\"$SCRIPT_NAME?sort=popularity&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_POPULARITY_COLUMN}</B></A></TD>\n";

    # Print column header for mapcycle
    if ($params{"sort"} eq "mapcycle" ) {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
        if ($params{order} eq "a") {
            print "<B>{A}<B> ";
        } else {
            print "<B>{D}<B> ";
        }
    } else {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
    }
    print "<A HREF=\"$SCRIPT_NAME?sort=mapcycle&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_MAPCYCLE_COLUMN}</B></A></TD>\n";

    # Print column header for size
    if ($params{"sort"} eq "size" ) {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
        if ($params{order} eq "a") {
            print "<B>{A}<B> ";
        } else {
            print "<B>{D}<B> ";
        }
    } else {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
    }
    print "<A HREF=\"$SCRIPT_NAME?sort=size&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_SIZE_COLUMN}</B></A></TD>\n";

    # Print column header for moddate
    if ($params{"sort"} eq "moddate" ) {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
        if ($params{order} eq "a") {
            print "<B>{A}<B> ";
        } else {
            print "<B>{D}<B> ";
        }
    } else {
        print "<TD ALIGN=\"CENTER\" BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
    }
    print "<A HREF=\"$SCRIPT_NAME?sort=moddate&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_MODDATE_COLUMN}</B></A></TD>\n";

    print "</TR>\n";
}

#------------------------------------------------------------------------------
sub print_map_table {

    my $hlmap;          # The map we're working with in the loop
    my $i;              # Counter for map loop
    my $min;            # Lowest map # we'll print
    my $max;            # Highest map # we'll print
    my @sortkeys;       # Which field we're going to sort by
    my $seconds;        # Used for file stat printing
    my $minutes;        # Used for file stat printing
    my $hours;          # Used for file stat printing
    my $day_of_month;   # Used for file stat printing
    my $month;          # Used for file stat printing
    my $year;           # Used for file stat printing
    my $wday;           # Used for file stat printing
    my $yday;           # Used for file stat printing
    my $isdst;          # Used for file stat printing

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
            @sortkeys = sort { $mapcycle{$a} <=> $mapcycle{$b} } keys %mapcycle;
        } else {
            @sortkeys = sort { $mapcycle{$b} <=> $mapcycle{$a} } keys %mapcycle;
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

    $i = 0;                             # Initialize the map loop counter
    $min = ($params{page} - 1)  * $params{mapsperpage};
    $max = $params{page}        * $params{mapsperpage};

    foreach $hlmap (@sortkeys) {

        ++$i;                           # Increment the map counter

        if ($i > $min && $i <= $max ) { # Only print map if it's in our range

            print "<TR>\n";             # Begin the table row

            # Print the map's name and corresponding download and link to single map display
            print "<TD ALIGN=\"CENTER\"><A HREF=\"$SCRIPT_NAME?map=$hlmap\"><B>$mapname{$hlmap}</B></A></TD>\n";

            # If there's a corresponding image file, display it.
            if ( $image{"$hlmap"} && $image{"$hlmap"} ne "#na#" ) {
                print "<TD ALIGN=\"CENTER\"><A HREF=\"$SCRIPT_NAME?map=$hlmap\"><IMG SRC=\"$image{\"$hlmap\"}\" ALT=\"$hlmap\" WIDTH=212 HEIGHT=160 BORDER=0></A></TD>\n";
            } else {
                $_ = $prefs{TABLE_IMAGE_NO};
                if ( /[\\\/]/ ) {
                    print "<TD ALIGN=\"CENTER\"><A HREF=\"$SCRIPT_NAME?map=$hlmap\"><IMG SRC=\"$prefs{TABLE_IMAGE_NO}\" ALT=\"$hlmap\" WIDTH=212 HEIGHT=160 BORDER=0></A></TD>\n";
                } else {
                    print "<TD ALIGN=\"CENTER\"><I>$prefs{TABLE_IMAGE_NO}</I></TD>\n";
                }
            }

            # Now print map's popularity (number of times run on the server)
            if ($popularity{"$hlmap"} > 0) {
                print "<TD ALIGN=\"CENTER\"><B>$prefs{TABLE_POPULARITY_COUNT_PRE} $popularity{\"$hlmap\"} $prefs{TABLE_POPULARITY_COUNT_SUF}</B></TD>\n";
            } else {
                print "<TD ALIGN=\"CENTER\"><I>$prefs{TABLE_POPULARITY_NEVER}</I></TD>\n";
            }

            # Print whether this map is in the server's mapcycle.txt or not
            if ( $mapcycle{"$hlmap"} && $mapcycle{"$hlmap"} != 9999) {
                print "<TD ALIGN=\"CENTER\"><B>$mapcycle{$hlmap}</B></TD>\n";
            } else {
                print "<TD ALIGN=\"CENTER\"><I>$prefs{TABLE_MAPCYCLE_NO}</I></TD>\n";
            }

            # Print map's file size
            if ( $size{"$hlmap"} && $size{"$hlmap"} ne "#na#") {
                print "<TD ALIGN=\"right\">" . int($size{"$hlmap"}/1024) . " k</TD>\n";
            } else {
                print "<TD ALIGN=\"CENTER\"><I>-</I></TD>\n";
            }

            # Print map's modification date/time
            ($seconds, $minutes, $hours, $day_of_month, $month, $year, $wday, $yday, $isdst) = localtime($moddate{"$hlmap"});
            printf("<TD ALIGN=\"CENTER\">%04d/%02d/%02d - %02d:%02d:%02d</TD>\n", 1900 + $year, $month, $day_of_month, $hours, $minutes, $seconds);

            # End the table row
            print "</TR>\n";
        }
    }
}

#------------------------------------------------------------------------------
sub print_table_footer {
    # We're done with the table, so close it out and print the footer information
    print "</TABLE>\n";
    print "<BR><CENTER><B>$prefs{PAGE_MAPCOUNT_PRE} $count $prefs{PAGE_MAPCOUNT_SUF}</B></CENTER>\n";
}

#------------------------------------------------------------------------------
sub print_page_footer {
    print "<BR><CENTER>Generated by <A HREF=\"$HOME_PAGE\"><B>hlmaps.pl</B></A> $VERSION<BR>\n";
    print "Written by <A HREF=\"MAILTO:$AUTHOR_EMAIL\">$AUTHOR_NAME</A></CENTER><BR>\n";
    print end_html . "\n";
}

#------------------------------------------------------------------------------
sub print_single_map {
    # We've been asked to print the single map screen

    my $txtfilename;
    my $seconds;        # Used for file stat printing
    my $minutes;        # Used for file stat printing
    my $hours;          # Used for file stat printing
    my $day_of_month;   # Used for file stat printing
    my $month;          # Used for file stat printing
    my $year;           # Used for file stat printing
    my $wday;           # Used for file stat printing
    my $yday;           # Used for file stat printing
    my $isdst;          # Used for file stat printing


    # Print page header
    print header(), start_html("$params{map}");
    print "<body background=\"$prefs{PAGE_BG_URL}\" bgcolor=\"$prefs{PAGE_BG_COLOR}\" text=\"$prefs{PAGE_TEXT_COLOR}\" link=\"$prefs{PAGE_LINK_COLOR}\" vlink=\"$prefs{PAGE_V_LINK_COLOR}\" alink=\"$prefs{PAGE_A_LINK_COLOR}\">\n";
    print h1("<CENTER>HLmaps: $params{map}</CENTER>\n");

    print "<BR><BR>";

    # Print table header
    print "<TABLE border=\"1\" bordercolordark=\"$prefs{TABLE_BORDER_LIGHT_COLOR}\" bordercolorlight=\"$prefs{TABLE_BORDER_DARK_COLOR}\" cellspacing=\"0\" cellpadding=\"3\" ALIGN=\"CENTER\">\n";

    # Print image if one exists
    if ( $image{$params{"map"}} && $image{$params{"map"}} ne "#na#" ) {
        print "<TR><TD ALIGN=\"CENTER\"><IMG SRC=\"" . $image{$params{"map"}} . "\" ALT=\"$params{map}\" WIDTH=212 HEIGHT=160 BORDER=0></TD></TR>\n";
    } else {
        $_ = $prefs{TABLE_IMAGE_NO};
        if ( /[\\\/]/ ) {
            print "<TR><TD ALIGN=\"CENTER\"><IMG SRC=\"$prefs{TABLE_IMAGE_NO}\" ALT=\"$params{map}\" WIDTH=212 HEIGHT=160 BORDER=0></TD>\n";
        } else {
            print "<TR><TD ALIGN=\"CENTER\"><I>$prefs{TABLE_IMAGE_NO}</I></TD>\n";
        }
    }


    # Print download link if one exists
    if ( $download{$params{"map"}} && $download{$params{"map"}} ne "#na#" ) {
        print "<TR><TD ALIGN=\"CENTER\"><A HREF=\"" . $prefs{DOWNLOAD_URL} . $params{"map"} . "." . $prefs{DOWNLOAD_EXT} . "\"><B>$prefs{PAGE_DOWNLOAD}</B></TD></TR>\n";
    }

    # Print map's popularity (number of times run on the server)
    if ($popularity{$params{"map"}} > 0) {
        print "<TR><TD ALIGN=\"CENTER\"><B>$prefs{TABLE_POPULARITY_COUNT_PRE} $popularity{$params{map}} $prefs{TABLE_POPULARITY_COUNT_SUF}</B></TD></TR>\n";
    } else {
        print "<TR><TD ALIGN=\"CENTER\"><I>$prefs{TABLE_POPULARITY_NEVER}</I></TD></TR>\n";
    }

    # Print whether this map is in the server's mapcycle.txt or not
    if ( $mapcycle{$params{"map"}} && $mapcycle{$params{"map"}} != 9999) {
        print "<TR><TD ALIGN=\"CENTER\"><B>$prefs{TABLE_MAPCYCLE_COLUMN} ($mapcycle{$params{map}})</B></TD></TR>\n";
    } else {
        print "<TR><TD ALIGN=\"CENTER\"><I>$prefs{TABLE_MAPCYCLE_COLUMN}: $prefs{TABLE_MAPCYCLE_NO}</I></TD></TR>\n";
    }

    # Print map's file size
    if ( $size{$params{"map"}} && $size{$params{"map"}} ne "#na#") {
        print "<TR><TD ALIGN=\"CENTER\">$prefs{TABLE_SIZE_COLUMN}: " . int($size{$params{"map"}}/1024) . " k</TD></TR>\n";
    } else {
        print "<TR><TD ALIGN=\"CENTER\"><I>-</I></TD></TR>\n";
    }

    # Print map's modification date/time
    ($seconds, $minutes, $hours, $day_of_month, $month, $year, $wday, $yday, $isdst) = localtime($moddate{$params{map}});
    printf("<TR><TD ALIGN=\"CENTER\">$prefs{TABLE_MODDATE_COLUMN}: %04d/%02d/%02d - %02d:%02d:%02d</TD>\n", 1900 + $year, $month, $day_of_month, $hours, $minutes, $seconds);

    # Print the text file if it exists
    if ( $textfile{$params{"map"}} && $textfile{$params{"map"}} ne "#na#") {
    
        $txtfilename = $prefs{SERVER_MAP_DIR} . $params{"map"} . ".txt";
        if ( -e $txtfilename ) {
            open(TXTFILE,"$txtfilename") || die "Sorry, I couldn't open the text file $txtfilename: $!\n";
            print "<TR><TD ALIGN=\"CENTER\">";
            while (<TXTFILE>) {
                chomp;                  # Take off the newline at the end
                $_ =~ tr/\r//;          # as well as any DOS carriage returns
                print "$_<BR>\n";
            }
            close(TXTFILE);
        }
    }

    # Print table and page footers
    print "</TR></TABLE>\n";
    print_page_footer();
}

###############################################################################
