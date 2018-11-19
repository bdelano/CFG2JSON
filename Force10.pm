package CFG2JSON::Force10;
use strict;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  my $dev=getinfo($config);
  my $interfaces=getinterfaces($config);
  $dev->{interfaces}=$interfaces;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  my @inventory=[];
  for(@config){
    $obj->{version}=$1 if $_=~/!Inventory: Software Version\s+:\s(.*)/i;
    $obj->{model}=$2 if $_=~/!Inventory: (System|Chassis) Type\s+:\s(.*?)\s+/i;
    push(@inventory,$_) if $_=~m/!(Inventory|Chassis).*/i;
  }
  for(@inventory){
    if($obj->{model} eq 'E300'){
      $obj->{serial}=$1 if $_=~/!Chassis: Serial Number : (.*?)\s+/i;
    }else{
      if($_=~/!Inventory: \*\s(.*)/i){
        my @ia=split(/\s+/,$1);
        $obj->{serial}=$ia[7]
      }
    }
  }
  return $obj;
}

sub getinterfaces{
  my $c = shift;
  my $ints;
  $c=~s/\n/<nl>/g;
  my @ints_arr=split(/<nl>i/,$c);
  shift @ints_arr;
  for(@ints_arr){
    my $int=$_;
    if($int=~/nterface (.*?)<nl>(.*?(shutdown|!<nl>router)).*/i){
      my $i=lc($1);
      my $vl=$i;
      my $rc=$2;
      $rc=~s/!<nl>router$//i;
      $vl=~s/Vlan //;
      for(split/<nl>/,$rc){
        my $l=$_;
        $ints->{$i}{description}=$1 if $l=~/description (.*)/i;
        $ints->{$i}{ipaddress}=$1 if $l=~/ip address (.*)/i;
        $ints->{$i}{vrf}=$1 if $l=~/ip vrf forwarding (.*)/i;
        $ints->{$i}{mtu}=$1 if $l=~m/mtu\s([\d]+)/i;
        if($l=~m/\s+(port-channel\s[\d]+) mode active/){
          $ints->{$i}{parent}=$1;
          push(@{$ints->{$1}{children}},$i);
        }
        if($i=~m/vlan/){
          $ints->{$i}{formfactor}='virtual';
        }elsif($i=~m/port.*/){
          $ints->{$i}{formfactor}='LAG';
        }else{
          $ints->{$i}{formfactor}='physical';
        }
      }
    }
  }
  return $ints
}

1
