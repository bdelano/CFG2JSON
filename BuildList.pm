package CFG2JSON::BuildList;
use strict;
use FindBin;
use lib $FindBin::Bin;
use JSON;
use CFG2JSON::Force10;
use CFG2JSON::Arista;
use CFG2JSON::Cisco;
use CFG2JSON::Juniper;
use Data::Dumper;
use File::Slurp;

sub new{
  my ($class,$args) = @_;
  my ($devlist,$sitelist)=_buildList($args->{rancidpath},$args->{custhash});
  $args->{devlist}=$devlist;
  $args->{sitelist}=$sitelist;
  my $self = bless $args , $class;
}

sub _buildList{
  my ($path,$custhash)=@_;
  print "path:$path\n";
  my ($devlist,$sitelist);
  for(split("\n",`ls -1 $path`)){
    my $site=$_;
    my $cust='default';
    $cust=$custhash->{$_} if $custhash->{$_};
    push(@{$sitelist->{$cust}},{sitename=>$site,rancidpath=>$path});
    for(split("\n",`ls -1 $path/$_/configs/`)){
      push(@{$devlist->{$cust}},{sitename=>$site,rancidpath=>$path,hostname=>$_})
    }
  }
  return ($devlist,$sitelist);
}

1;
