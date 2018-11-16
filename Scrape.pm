package CFG2JSON::Scrape;
use strict;
use FindBin;
use lib $FindBin::Bin;
use JSON;
use CFG2JSON::Force10;
use CFG2JSON::Arista;
use CFG2JSON::Cisco;
use CFG2JSON::Juniper;
use File::Slurp;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $filepath=$args->{filepath};
  my $hostname=$args->{hostname};
  my $sitename=$args->{sitename};
  my $config=read_file($filepath.'/'.$sitename.'/configs/'.$hostname);
  my $vendor=_getVendor($config);
  my $dev;
  if($vendor eq 'force10'){
    $dev=CFG2JSON::Force10->new(config=>$config);
  }elsif($vendor eq 'arista'){
    $dev=CFG2JSON::Arista->new(config=>$config);
  }elsif($vendor eq 'cisco'){
    $dev=CFG2JSON::Cisco->new(config=>$config)
  }elsif($vendor =~ /joy-juniper/){
    $dev=CFG2JSON::Juniper->new(config=>$config)
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
sub gethash{
  my ($self,$key)=@_;
  return $self->{$key}
}

1;
