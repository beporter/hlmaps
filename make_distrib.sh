###############################################################################
#                                                                             #
# make_distrib.sh - Makes an HLmaps distribution package                      #
#       - Copyright Scott McCrory as part of the HLmaps distribution          #
#       - Distributed under the GNU Public License - see docs for more info   #
#       - http://hlmaps.sourceforge.net                                       #
#                                                                             #
###############################################################################
# CVS $Id$
###############################################################################

# First refresh the docs in the HTML tree
cd /home/sources/hlmaps
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.cron hlmaps.pl ../hlmaps-htdocs/

# Now prepare the distribution directory
rm -rf /home/sources/hlmaps/hlmaps-releases/*
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.cron hlmaps.pl ../hlmaps-release/

# Tar and gzip the release and html packages
cd /home/sources/
tar cvf hlmaps-release.tar hlmaps-release
gzip -9 hlmaps-release.tar
tar cvf hlmaps-htdocs.tar hlmaps-htdocs
gzip -9 hlmaps-htdocs.tar
