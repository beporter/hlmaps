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
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.pl htdocs/

# Now prepare the distribution directory
rm -rf hlmaps_release
mkdir hlmaps_release
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.pl hlmaps_release/

# Tar and gzip the release and html packages
tar cvf hlmaps_release.tar hlmaps_release
gzip -9 hlmaps_release.tar
tar cvf hlmaps_htdocs.tar htdocs
gzip -9 hlmaps_htdocs.tar

