#!/usr/bin/perl	-w -T
###############################################################################
#																			  #
# hlmaps.pl	- A	script to present a	nice web-based HL server map listing	  #
#			- Copyright	Scott McCrory										  #
#			- Distributed under	the	GPL	terms -	see	the	docs for info		  #
#			- http://hlmaps.sourceforge.net									  #
#																			  #
###############################################################################
# CVS $Id$
###############################################################################
#
#	 HLmaps
#	 Copyright (C) 2000	Scott D. McCrory <smccrory@users.sourceforge.com>
#	 All Rights	Reserved
#
#	 This program is free software;	you	can	redistribute it	and/or modify
#	 it	under the terms	of the GNU General Public License as published by
#	 the Free Software Foundation; either version 2	of the License,	or
#	 (at your option) any later	version.
#
#	 This program is distributed in	the	hope that it will be useful,
#	 but WITHOUT ANY WARRANTY; without even	the	implied	warranty of
#	 MERCHANTABILITY or	FITNESS	FOR	A PARTICULAR PURPOSE.  See the
#	 GNU General Public	License	for	more details.
#
#	 You should	have received a	copy of	the	GNU	General	Public License
#	 along with	this program; if not, write	to the Free	Software
#	 Foundation, Inc., 59 Temple Place,	Suite 330, Boston, MA  02111-1307  USA
#
###############################################################################

use	strict;							# Requires us to declare all vars used
use	CGI	qw(:all);					# Lets us grab vars	passed from	web	server
use	CGI::Carp qw(fatalsToBrowser);	# Sent fatal errors	to browser
use	File::stat;						# Lets us get stats	of map files

######################## GLOBAL	CONSTANTS #####################################
# Make sure	you	modify this	if you're running multiple instances of	HLmaps
#	 on	the	same server	(pointing to a CS server, a	TFC	server,	etc.)

my $CONF_FILE			= "/etc/hlmaps.conf";

###################### GLOBAL DEVELOPMENT CONSTANTS	###########################

# Development constants	- please don't mess	with these
my $VERSION				= "0.93, July 25, 2000";
my $AUTHOR_NAME			= "Scott McCrory";
my $AUTHOR_EMAIL		= "scott\@mccrory.com";
my $HOME_PAGE			= "http://hlmaps.sourceforge.net";
my $SCRIPT_NAME			= script_name();

############################# GLOBAL VARIABLES ################################

my %params;			# Hash for untainted, global CGI parameters
my %prefs;			# Hash for user	preferences	as obtained	from $CONF_FILE

my %mapname;		# Hash to hold map's shortname
my %download;		# Hash to hold map's download URL
my %image;			# Hash to hold map's image URL
my %popularity;		# Hash to hold map's popularity	(times run on server)
my %mapcycle;		# Hash to hold map's inclusion in mapcycle.txt
my %mapcyclepos;	# Hash to hold map's position in mapcycle.txt
my %size;			# Hash to hold map's file size
my %moddate;		# Hash to hold map's modification date

my $count;			# Number of	maps counted

################################## MAIN	#######################################

$CGI::POST_MAX=1024*100;   # Maximum 100k posts	to prevent CGI DOS attacks
$CGI::DISABLE_UPLOADS=1;   # Disable uploads to	prevent	CGI	DOS	attacks

$ENV{PATH} = '/bin:/usr/bin:/usr/local/bin';	# Adjust path to prevent sloppy	code execution
$ENV{BASH_ENV} = '';							# Clear	out	environment	to prevent sloppy code execution
$ENV{ENV} =	'';									# Clear	out	another	env	to prevent sloppy code execution

get_preferences();								# Load preferences from	.conf file
untaint_data();									# Perform validation of	all	input data
get_map_details();								# Scan map dir and get details
get_mapcycle();									# See if map is	in mapcycle.txt
get_map_popularity();							# See how many times map's been	played
print_page_header();							# Print	page header, title,	etc.
print_nav_bar();                                # Print multi-page navigation bar
print_table_header();							# Print	table contruct and header row
print_map_table();								# Print	actual table with info
print_table_footer();							# Cap off the table
print_page_footer();							# End the HTML page

###############################	SUBROUTINES	###################################

# ----------------------------------------------------------------------------
sub	get_preferences	{
	# Load HLmaps preferences from $CONF_FILE

	my $var;						# Variable name	in .conf
	my $value;						# Value	of variable	in .conf

	open(CONF, "$CONF_FILE") ||	die	"Sorry,	I couldn't open	the	preferences	file $CONF_FILE\n";
	while (<CONF>) {
		chomp;						# no newline
		s/#.*//;					# no comments
		s/^\s+//;					# no leading white
		s/\s+$//;					# no trailing white
		next unless	length;			# anything left?
		($var, $value) = split(/\s*=\s*/, $_, 2);
		$prefs{$var} = $value;		# load the untainted value into	our	hash of	vars
	}
	close(CONF);
}

# ----------------------------------------------------------------------------
sub	untaint_data {
	# This subroutine creates a	new	CGI	object and pulls in	the	user-provided
	#	 parameters.  We then validate and untaint every parameter to prevent
	#	 them from being able to malform a URL or do other naughty things.

	my $q =	new	CGI;					   # A new CGI object
	my @param_list;						   # Hash to hold CGI parameter	list
	my %tainted_params;					   # Hash to hold raw, tainted CGI parameters

	# Load list	of CGI parameters and put them in our "tainted"	hash
	@param_list	= $q->param;
	foreach(@param_list) {
		$tainted_params{"$_"} =	$q->param("$_");
	}

	# Now untaint all of the data by using substring pattern matching
	foreach(keys %tainted_params) {
		if ( $tainted_params{"$_"} ) {
			$tainted_params{"$_"} =~/([\w\-.]+)/;
			$params{"$_"} =	$1;
		} else {
			$params{"$_"} =	'';
		}
	}

    # Set the default CGI parameters if they were not specified for us
    if (!$params{"sort"}) { $params{"sort"} = "mapname"; }
    if (!$params{"order"}) { $params{"order"} = "a"; }
    if (!$params{"mapsperpage"}) { $params{"mapsperpage"} = $prefs{DEFAULT_MAPS_PER_PAGE}; }
    if (!$params{"page"}) { $params{"page"} = 1; }
}

#------------------------------------------------------------------------------
sub	get_map_details	{
	# Open up server map directory and get list	of all *.bsp files there
	#	 then cycle	through	each file and see if a corresponding image and download	exists
	#	 and then print	a table	row	with the pertainent	information
	my @filelist;		# List of files
	my $size;			# Map file size
	my $filename;		# Map filename for loop
	my $shortname;		# Map short	filename
	my $inode;			# inode	for	file stat gathering
	my $dlfilename;		# Download filename, if	it exists
	my $imgfilename;	# Image	filename, if it	exists


	opendir(DIR, "$prefs{SERVER_MAP_DIR}") || die "Couldn't	read map dir: $prefs{SERVER_MAP_DIR}";
	@filelist =	grep { /\.$prefs{MAP_EXTENSION}$/ }	readdir(DIR);
	closedir(DIR);

	foreach	$filename (@filelist)
	{

		++$count;						# Increment	the	map	counter
		$shortname = $filename;			# Strip	off	the	extension
		$shortname =~/(\w+)./;			# and untaint it
		$shortname = $1;				#

		# Get the map details
		$inode = stat("$prefs{SERVER_MAP_DIR}" . "$filename");
		$moddate{"$shortname"} = $inode->mtime;	# In epoch seconds
		$size{"$shortname"}	= int($inode->size / 1024);
		$mapname{"$shortname"} = "$shortname";
		$download{"$shortname"}	= $download{"$shortname"} || "#na#";
		$image{"$shortname"} = $image{"$shortname"}	|| "#na#";
		$popularity{"$shortname"} =	0;
		$mapcycle{"$shortname"}	= "#na#";
		$mapcyclepos{"$shortname"}=	9999;

		# Get the map's	corresponding download link	if it exists
		$dlfilename	= "$prefs{DOWNLOAD_DIR}" . "$shortname.$prefs{DOWNLOAD_EXT}";
		if ($dlfilename	&& -e $dlfilename) {
			$download{"$shortname"}	= $dlfilename;
		}

		# Get the map's	corresponding image	file if	it exists
		$imgfilename = "$prefs{IMAGES_DIR}"	. "$shortname" . ".jpg";
		if ($imgfilename &&	-e $imgfilename) {
			$image{"$shortname"} = "$prefs{IMAGES_URL}"	. "$shortname" . ".jpg";
		}
	}
}

#------------------------------------------------------------------------------
sub	get_mapcycle {

	my $position = 1;		# Used to track	map's position in the mapcycle

	# To know if a map is in the current mapcycle, we'll read the list first
	open(MAPCYC,"$prefs{MAPCYCLE}")	|| die "Sorry, I couldn't open the mapcycle\n";
	while (<MAPCYC>) {
		chomp;					# Take of the newline at the end
		$_ =~ tr/\r//;			# as well as any DOS line returns
		if ( $mapname{"$_"}	) {
			$mapcycle{"$_"}	= "$prefs{TABLE_MAPCYCLE_YES} (\#$position)";
			$mapcyclepos{"$_"} = $position;
		}
		++$position;
	}
	close(MAPCYC);
}

#------------------------------------------------------------------------------
sub	get_map_popularity {
	# To know how popular a	map	is,	we'll parse	the	logs
	my @filelist;			# List of files
	my($filename, $line);

	opendir(DIR, "$prefs{SERVER_LOG_DIR}");
	@filelist =	readdir(DIR);
	closedir(DIR);
	foreach	$filename (@filelist) {
		if ($filename !~ /log$/) { next; }
		open(LOGFILE, $prefs{SERVER_LOG_DIR}.$filename)	or die "Could not open $filename: $!";
		while ($line = <LOGFILE>) {
			if ($line =~ /Spawning server \"(\w+)\"/) {
				if ($mapname{$1}) {	++$popularity{$1}; }
				last;
			}
		}
		close(LOGFILE);
	}
}

#------------------------------------------------------------------------------
sub	print_page_header {
	# Print	the	page header
	print header(),	start_html("$prefs{PAGE_HEADING}");
	print "<body background=\"$prefs{PAGE_BG_URL}\"	bgcolor=\"$prefs{PAGE_BG_COLOR}\" text=\"$prefs{PAGE_TEXT_COLOR}\" link=\"$prefs{PAGE_LINK_COLOR}\"	vlink=\"$prefs{PAGE_V_LINK_COLOR}\"	alink=\"$prefs{PAGE_A_LINK_COLOR}\">\n";
	print h1("<CENTER> $prefs{PAGE_HEADING}	</CENTER>\n");
	print h3("<CENTER><I> $prefs{PAGE_SUBHEADING} </I></CENTER>\n");
}

#------------------------------------------------------------------------------
sub	print_nav_bar {
    # This is where we print the page navigation bar (really a table) so that
    #    users can limit the number of maps displayed per page and can walk
    #    through the result set.
    
    my $pages;      # Number of pages as calculated
    my $i;          # Loop counter
    
    $pages = int($count / $params{mapsperpage}) + 1;    # Calculate total pages
    
    if ( $pages > 1 ) {
    	print "<TABLE border=\"1\" bordercolordark=\"$prefs{TABLE_BORDER_LIGHT_COLOR}\"	bordercolorlight=\"$prefs{TABLE_BORDER_DARK_COLOR}\" cellspacing=\"0\" cellpadding=\"3\" ALIGN=\"CENTER\">\n";
    	print "<TR>";

        # If we're not on page one, then print the "Prev" cell
        if ($params{page} > 1 ) {
            print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR}>";
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
            print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR}>";
        	print "<A HREF=\"$SCRIPT_NAME?sort=$params{sort}&order=$params{order}&mapsperpage=$params{mapsperpage}&page=" . ($params{page} + 1) . "\"><B>Next</B></A></TD>\n";
        }

      	print "</TR><BR>\n";
    	print "</TABLE>\n";
    }
    print "<BR>\n";
}

#------------------------------------------------------------------------------
sub	print_table_header {
	my $inverse;

	# Get the inverse sort order so	that the user can reverse
	#	 the way the maps are displayed	if they	choose
	if ($params{"order"} eq	"a") {
		$inverse = "d";
	} else {
		$inverse = "a";
	}

	# Print	the	table header
	print "<TABLE border=\"1\" bordercolordark=\"$prefs{TABLE_BORDER_LIGHT_COLOR}\"	bordercolorlight=\"$prefs{TABLE_BORDER_DARK_COLOR}\" cellspacing=\"0\" cellpadding=\"3\" ALIGN=\"CENTER\">\n";
	print "<TR>\n";

	if ($params{"sort"}	eq "mapname" ) {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
	} else {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
	}
	print "<A HREF=\"$SCRIPT_NAME?sort=mapname&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_MAPNAME_COLUMN}</B></A></TD>\n";

	if ($params{"sort"}	eq "image" ) {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
	} else {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
	}
	print "<A HREF=\"$SCRIPT_NAME?sort=image&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_IMAGE_COLUMN}</B></A></TD>\n";

	if ($params{"sort"}	eq "popularity"	) {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
	} else {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
	}
	print "<A HREF=\"$SCRIPT_NAME?sort=popularity&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_POPULARITY_COLUMN}</B></A></TD>\n";

	if ($params{"sort"}	eq "mapcycle" )	{
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
	} else {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
	}
	print "<A HREF=\"$SCRIPT_NAME?sort=mapcycle&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_MAPCYCLE_COLUMN}</B></A></TD>\n";

	if ($params{"sort"}	eq "size" )	{
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
	} else {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
	}
	print "<A HREF=\"$SCRIPT_NAME?sort=size&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_SIZE_COLUMN}</B></A></TD>\n";

	if ($params{"sort"}	eq "moddate" ) {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_SORT_HEAD_COLOR} >";
	} else {
		print "<TD ALIGN=\"CENTER\"	BGCOLOR=$prefs{TABLE_NORM_HEAD_COLOR} >";
	}
	print "<A HREF=\"$SCRIPT_NAME?sort=moddate&order=$inverse&mapsperpage=$params{mapsperpage}&page=1\"><B>$prefs{TABLE_MODDATE_COLUMN}</B></A></TD>\n";

	print "</TR>\n";
}

#------------------------------------------------------------------------------
sub	print_map_table	{

	my $hlmap;			# The map we're	working	with in	the	loop
	my $i;              # Counter for map loop
	my $min;            # Lowest map # we'll print
	my $max;            # Highest map # we'll print
	my @sortkeys;		# Which	field we're	going to sort by
	my $seconds;		# Used for file	stat printing
	my $minutes;		# Used for file	stat printing
	my $hours;			# Used for file	stat printing
	my $day_of_month;	# Used for file	stat printing
	my $month;			# Used for file	stat printing
	my $year;			# Used for file	stat printing
	my $wday;			# Used for file	stat printing
	my $yday;			# Used for file	stat printing
	my $isdst;			# Used for file	stat printing

	# If we're asked to	sort, then we'll rearrange the hash	key	order on
	#	 the requested sort	element	...
	if ( $params{'sort'} eq	"download")	{
		if ( $params{"order"} eq "a") {
			@sortkeys =	sort { $download{$a} cmp $download{$b} } keys %download;
		} else {
			@sortkeys =	sort { $download{$b} cmp $download{$a} } keys %download;
		}
	} elsif	( $params{'sort'} eq "image") {
		if ( $params{"order"} eq "a") {
			@sortkeys =	sort { $image{$a} cmp $image{$b} } keys	%image;
		} else {
			@sortkeys =	sort { $image{$b} cmp $image{$a} } keys	%image;
		}
	} elsif	( $params{'sort'} eq "popularity") {
		if ( $params{"order"} eq "a") {
			@sortkeys =	sort { $popularity{$a} <=> $popularity{$b} } keys %popularity;
		} else {
			@sortkeys =	sort { $popularity{$b} <=> $popularity{$a} } keys %popularity;
		}
	} elsif	( $params{'sort'} eq "mapcycle") {
		if ( $params{"order"} eq "a") {
			@sortkeys =	sort { $mapcyclepos{$a}	<=>	$mapcyclepos{$b} } keys	%mapcycle;
		} else {
			@sortkeys =	sort { $mapcyclepos{$b}	<=>	$mapcyclepos{$a} } keys	%mapcycle;
		}
	} elsif	( $params{'sort'} eq "size") {
		if ( $params{"order"} eq "a") {
			@sortkeys =	sort { $size{$a} <=> $size{$b} } keys %size;
		} else {
			@sortkeys =	sort { $size{$b} <=> $size{$a} } keys %size;
		}
	} elsif	( $params{'sort'} eq "moddate")	{
		if ( $params{"order"} eq "a") {
			@sortkeys =	sort { $moddate{$a}	cmp	$moddate{$b} } keys	%moddate;
		} else {
			@sortkeys =	sort { $moddate{$b}	cmp	$moddate{$a} } keys	%moddate;
		}
	} else {
		if ( $params{"order"} eq "a") {
			@sortkeys =	sort { $mapname{$a}	cmp	$mapname{$b} } keys	%mapname;
		} else {
			@sortkeys =	sort { $mapname{$b}	cmp	$mapname{$a} } keys	%mapname;
		}
	}

    $i = 0;                             # Initialize the map loop counter
    $min = ($params{page} - 1)  * $params{mapsperpage};
    $max = $params{page}        * $params{mapsperpage};
    
	foreach	$hlmap (@sortkeys) {

        ++$i;                           # Increment the map counter
        
        if ($i > $min && $i < $max ) {  # Only print map if it's in our range
        
    		print "<TR>\n";             # Begin	the	table row
    		
    		# Print	the	map's name (and	corresponding download link	if present)
    		if ($download{"$hlmap"}	&& $download{"$hlmap"} ne "#na#" &&	-e $download{"$hlmap"})	{
    			print "<TD ALIGN=\"CENTER\"><A HREF=\"$prefs{DOWNLOAD_URL}$hlmap.$prefs{DOWNLOAD_EXT}\"><B>$hlmap</B></A></TD>\n";
    		} else {
    			print "<TD ALIGN=\"CENTER\"><B>$hlmap</B></TD>\n";
    		}
    
    		# If there's a corresponding image file, display it.
    		if ($image{"$hlmap"} &&	$image{"$hlmap"} ne	"#na#")	{
    			if ($download{"$hlmap"}	&& $download{"$hlmap"} ne "#na#" &&	-e $download{"$hlmap"})	{
    				print "<TD ALIGN=\"CENTER\"><A HREF=\"$prefs{DOWNLOAD_URL}$hlmap.$prefs{DOWNLOAD_EXT}\"><IMG SRC=\"$image{\"$hlmap\"}\"	ALT=\"$hlmap\" WIDTH=212 HEIGHT=160	BORDER=0></A></TD>\n";
    			} else {
    				print "<TD ALIGN=\"CENTER\"><IMG SRC=\"$image{\"$hlmap\"}\"	ALT=\"$hlmap\" WIDTH=212 HEIGHT=160></TD>\n";
    			}
    		} else {
    			print "<TD ALIGN=\"CENTER\"><I>$prefs{TABLE_IMAGE_NO}</I></TD>\n";
    		}
    
    		# Now print	image's	popularity (number of times	run	on the server)
    		if ($popularity{"$hlmap"} >	0) {
    			print "<TD ALIGN=\"CENTER\"><B>$prefs{TABLE_POPULARITY_COUNT_PRE} $popularity{\"$hlmap\"} $prefs{TABLE_POPULARITY_COUNT_SUF}</B></TD>\n";
    		} else {
    			print "<TD ALIGN=\"CENTER\"><I>$prefs{TABLE_POPULARITY_NEVER}</I></TD>\n";
    		}
    
    		# Print	whether	this map is	in the server's	mapcycle.txt or	not
    		if ( $mapcycle{"$hlmap"} &&	$mapcycle{"$hlmap"}	ne "#na#") {
    			print "<TD ALIGN=\"CENTER\"><B>$mapcycle{$hlmap}</B></TD>\n";
    		} else {
    			print "<TD ALIGN=\"CENTER\"><I>$prefs{TABLE_MAPCYCLE_NO}</I></TD>\n";
    		}
    
    		# Print	map's file size
    		if ( $size{"$hlmap"} &&	$size{"$hlmap"}	ne "#na#") {
    			print "<TD ALIGN=\"right\">$size{\"$hlmap\"} k</TD>\n";
    		} else {
    			print "<TD ALIGN=\"CENTER\"><I>-</I></TD>\n";
    		}
    
    		# Print	map's modification date/time
    		($seconds, $minutes, $hours, $day_of_month,	$month,	$year, $wday, $yday, $isdst) = localtime($moddate{"$hlmap"});
    		printf("<TD	ALIGN=\"CENTER\">%04d/%02d/%02d	- %02d:%02d:%02d</TD>\n", 1900 + $year,	$month,	$day_of_month, $hours, $minutes, $seconds);
    
    		# End the table	row
    		print "</TR>\n";
    	}
	}
}

#------------------------------------------------------------------------------
sub	print_table_footer {
	# We're	done with the table, so	close it out and print the footer information
	print "</TABLE>\n";
}

#------------------------------------------------------------------------------
sub	print_page_footer {
	print "<BR><CENTER><B>$prefs{PAGE_MAPCOUNT_PRE}	$count $prefs{PAGE_MAPCOUNT_SUF}</B><BR><BR>\n";
	print "Generated by	<A HREF=\"$HOME_PAGE\"><B>hlmaps.pl</B></A>	$VERSION<BR>\n";
	print "Written by <A HREF=\"MAILTO:$AUTHOR_EMAIL\">$AUTHOR_NAME</A></CENTER><BR>\n";
	print end_html . "\n";
}

###############################################################################
