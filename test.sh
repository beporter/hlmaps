clear

chown -R smccrory.users /home/sources/hlmaps

cp -f /home/sources/hlmaps/hlmaps.pl /home/httpd/cgi-bin/hlmaps_devel.pl
chown http.http /home/httpd/cgi-bin/hlmaps_devel.pl
chmod 755 /home/httpd/cgi-bin/hlmaps_devel.pl

cp -f /home/sources/hlmaps/hlmaps.conf.distrib /etc/hlmaps.conf
chown http.http /etc/hlmaps.conf
chmod 644 /etc/hlmaps.conf

cp -f /home/sources/hlmaps/hlmaps.cron /etc/cron.daily/hlmaps.cron
chown root.root /etc/cron.daily/hlmaps.cron
chmod 755 /etc/cron.daily/hlmaps.cron

#/etc/cron.daily/hlmaps.cron
/home/httpd/cgi-bin/hlmaps_devel.pl

