package CFG2JSON::Scrape;
use strict;
use FindBin;
use lib $FindBin::Bin;
use JSON;
use CFG2JSON::Force10;
use CFG2JSON::Arista;
use CFG2JSON::Opengear;
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
  my $mgmtip=nslookup($hostname);
  my $dev;
  if($vendor eq 'force10'){
    $dev=CFG2JSON::Force10->new(config=>$config);
  }elsif($vendor eq 'arista'){
    $dev=CFG2JSON::Arista->new(config=>$config);
  }elsif($vendor eq 'cisco'){
    $dev=CFG2JSON::Cisco->new(config=>$config);
  }elsif($vendor eq 'opengear'){
    $dev=CFG2JSON::Opengear->new(config=>$config);
  }elsif($vendor =~ /juniper/){
    $dev=CFG2JSON::Juniper->new(config=>$config);
  }else{
    $dev->{error}="No matching vendor found for $hostname!";
  }
  $dev->{device}{mgmtip}=$mgmtip;
  $dev->{device}{sitename}=$sitename;
  $dev->{device}{hostname}=$hostname;
  $dev->{device}{vendor}=$vendor;
  $dev->{device}{devicerole}=getDeviceRole($hostname);
  my $self = bless {
    config => $config,
    device => $dev->{device}
  }, $class;
}

sub _getVendor{
  my @cl=split("\n",$_[0]);
  my $vl=shift @cl;
  $vl=~s/[!#]RANCID-CONTENT-TYPE: //i;
  $vl=~s/joy-//i;
  $vl=~s/-srx//i;
  return $vl
}

sub json{
  my $self=shift;
  return encode_json $self->{device};
}
sub gethash{
  my $self=shift;
  return $self->{device}
}

sub nslookup{
  my $hn=$_[0];
  #print "nslookup $hn\n";
  my $nsl=`nslookup $_[0]`;
  $nsl=~s/\n//g;
  $nsl=~s/\'//g;
  $nsl=~s/.*usAddress: (.*)$/$1/i;
  $nsl=~s/.*server cant find.*/notfound/i;
  return $nsl;
}

sub getDeviceRole{
  my $l = shift;
  my $req;
  if($l=~/agg/){
    $req='Aggregate';
  }elsif($l=~/-lef([\d]+)?-/){
    $req='Leaf'
  }elsif($l=~/-spn([\d]+)?-/){
    $req='Spine'
  }elsif($l=~/.*-dc$/i){
    $req='DirectConnect';
  }elsif($l=~/.*-(dc|mx480|service|ss|edg)/i){
    $req='Edge';
  }elsif($l=~/pdu/i){
    $req='PDU';
  }elsif($l=~/HSM/i){
    $req='HSM';
  }elsif($l=~/SDX/i){
    $req='SDX';
  }elsif($l=~/WAF/i){
    $req='WAF';
  }elsif($l=~/srx/i){
    $req='Firewall';
  }elsif($l=~/ids/i){
    $req='IDS';
  }elsif($l=~/.*(bigswitch|bs4048|bsmf|bmf|\-BS).*/i){
    $req='BigSwitch';
  }elsif($l=~/.*(admin|mgt|mgg).*/i){
    $req='NW Admin';
  }elsif($l=~/.*(dist).*/i){
    $req='Distribution';
  }elsif($l=~/.*(core).*/i){
    $req='Core';
  }elsif($l=~/.*(arbor|tms).*/i){
    $req='Arbor';
  }elsif($l=~/.*(logr|lr[12])/){
    $req='LogRythm';
  }elsif($l=~/.*-(con|oob)/i){
    $req='NW Console';
  }elsif($l=~/.*(kvm|dns|tac|opennms|cacti|netopsinfo|noctool|nftracker|ns[12]\.).*/i){
    $req='Server';
  }elsif($l=~/.*mx204.*/){
    $req='Core';
  }elsif($l=~/.*-e300-[12]/){
    $req='Core';
  }elsif($l=~/.*-tor/i || $l=~/.*[\d]+\-[12]/){
    $req='TOR';
  }
  return $req;
}

1;
