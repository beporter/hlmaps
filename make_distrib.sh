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
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.pl ../hlmaps-htdocs/

# Now prepare the distribution directory
rm -rf ../hlmaps-release
mkdir ../hlmaps-release
cp -f CHANGELOG CONTRIBUTING CONTRIBUTORS INSTALL LICENSE README TODO hlmaps.conf.distrib hlmaps.pl ../hlmaps-release/

# Tar and gzip the release and html packages
tar cvf ../hlmaps-release.tar ../hlmaps-release
gzip -9 ../hlmaps-release.tar
tar cvf ../hlmaps-htdocs.tar ../htdocs
gzip -9 ../hlmaps-htdocs.tar

