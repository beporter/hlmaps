###############################################################################
#                                                                             #
# upload_hlmaps.sh - Uploads an HLmaps distribution package to SourceForge    #
#       - Copyright Scott McCrory as part of the HLmaps distribution          #
#       - Distributed under the GNU Public License - see docs for more info   #
#       - http://hlmaps.sourceforge.net                                       #
#                                                                             #
###############################################################################
# CVS $Id$
###############################################################################

#scp1 hlmaps_release.tar.gz smccrory@hlmaps.sourceforge.net:

# Copy the updated web site docs to SourceForge
scp1 hlmaps_htdocs.tar.gz smccrory@hlmaps.sourceforge.net:/home/groups/hlmaps/
