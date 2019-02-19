package CFG2JSON::BuildList;
use strict;
use FindBin;
use lib $FindBin::Bin;
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
  my ($devlist,$sitelist);
  for(split("\n",`ls -1 $path`)){
    my $site=$_;
    my $cust='default';
    $cust=$custhash->{$site} if $custhash->{$site};
    push(@{$sitelist->{$cust}},{sitename=>$site,rancidpath=>$path});
    for(split("\n",`cat $path/$_/router.db`)){
      my $hn=lc($1) if $_=~/(.*?);.*/i;
      push(@{$devlist->{$cust}},{sitename=>$site,rancidpath=>$path,hostname=>$hn})
    }
  }
  return ($devlist,$sitelist);
}

1;
