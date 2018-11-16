package Scrape;
use FindBin;
use lib $FindBin::Bin;
use JSON;
use strict;
use NetAddr::IP;
use Force10;
use Arista;
use Cisco;
use Juniper;
use File::Slurp;

sub new{
  my ($class,$args)=@_;
  my $filepath=$args->{filepath};
  my $hostname=$args->{hostname};
  my $sitename=$args->{sitename};
  my $config=read_file($filepath.'/'.$sitename.'/configs/'.$hostname);
  my $vendor=_getVendor($config);
  my $dev;
  if($vendor eq 'force10'){
    $dev=Force10->new({config=>$config});
  }elsif($vendor eq 'arista'){
    $dev=Arista->new({config=>$config});
  }elsif($vendor eq 'cisco'){
    $dev=Cisco->new({config=>$config})
  }elsif($vendor =~ /joy-juniper/){
    $dev=Juniper->new({config=>$config})
  }
  $dev->{device}{sitename}=$sitename;
  $dev->{device}{hostname}=$hostname;
  my $self = bless {
    config => $config,
    device => $dev->{device}
  }, $class;
}

sub _getVendor{
  my @cl=split("\n",$_[0]);
  my $vl=shift @cl;
  $vl=~s/!RANCID-CONTENT-TYPE: //i;
  return $vl
}

sub json{
  my ($self,$key)=@_;
  return encode_json $self->{$key};
}

1;
