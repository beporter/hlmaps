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

cd ..

# Copy the updated web site docs to SourceForge
scp hlmaps-htdocs.tar.gz smccrory@hlmaps.sourceforge.net:/home/groups/h/hl/hlmaps/htdocs/

# Open a shell session to allow us to decompress it
ssh -l smccrory hlmaps.sourceforge.net

