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
chown -R smccrory.smccrory *
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.cron hlmaps.pl INSTALL.MySQL htdocs/

# Now prepare the distribution directory
rm -rf ../hlmaps-release/*
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.cron hlmaps.pl INSTALL.MySQL ../hlmaps-release/

# Tar and gzip the release and html packages
cd .. 
tar cvf hlmaps-release.tar hlmaps-release
gzip -9 hlmaps-release.tar
tar cvf hlmaps-htdocs.tar hlmaps/htdocs
gzip -9 hlmaps-htdocs.tar
