#!/usr/bin/perl
use FindBin;
use lib $FindBin::Bin;
use strict;
use CFG2JSON::Scrape;
my $s=CFG2JSON::Scrape->new({
filepath=>'/home/rancid/var/rancid', # root to your rancid directory
sitename=>'sites', #usually rancid configs are grouped into sites
hostname=>'mydevice' #rancid hostname of the device
});

#print $s;
#print $s->{device};
print $s->json('device');
