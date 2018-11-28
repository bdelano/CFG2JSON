package CFG2JSON::Force10;
use strict;
use Data::Dumper;
use NetAddr::IP;
my $gbics;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  $gbics=buildGbicHash($config);
  my $dev=getinfo($config);
  my $interfaces=getinterfaces($config);
  #$dev->{interfaces}=$interfaces;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  my @inventory=[];
  for(@config){
    if($_=~/!Inventory: Software Version\s+:\s([\d\.]+)\((.*)\)/i){
      $obj->{version}=$1;
      $obj->{subversion}=$2;
    }
    $obj->{model}=$2 if $_=~/!Inventory: (System|Chassis) Type\s+:\s(.*?)\s+/i;
    $obj->{nics_num}=$obj->{nics_num}+$1 if $_=~/!Chassis: Num Ports\s+:\s+([\d]+)/i;
    $obj->{macaddress}=$1 if $_=~/!Chassis: Burned In MAC\s+:\s+([\w:]+)/i;
    $obj->{memory}=$obj->{memory}+($1/1000) if $_=~/!Memory.*\s([\d]+)M/;
    push(@inventory,$_) if $_=~m/!(Inventory|Chassis).*/i;
  }
  for(@inventory){
    if($obj->{model} eq 'E300'){
      $obj->{serial}=$1 if $_=~/!Chassis: Serial Number : ([\w]+)/i;
    }else{
      if($_=~/!Inventory: \*\s(.*)/i){
        my @ia=split(/\s+/,$1);
        $obj->{serial}=$ia[7];
        $obj->{serial}=$ia[2] if $obj->{serial} eq 'N/A';
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
      my $i=$1;
      my $rc=$2;
      if($i=~m/vlan/i){
        $ints->{$i}{formfactor}='virtual';
      }elsif($i=~m/port.*/i){
        $ints->{$i}{formfactor}='LAG';
      }else{
        my $sp=lc($i);
        $sp=~s/(tengigabitethernet|fortygige) //i;
        if($gbics->{$sp}){
          if(uc($gbics->{$sp}{formfactor})=~/MEDIANOT/){
            $ints->{$i}{formfactor}='none';
          }elsif(uc($gbics->{$sp}{formfactor})=~/UNKNOWNUNKNOWN/){
            $ints->{$i}{formfactor}='unknown';
          }else{
            $ints->{$i}{formfactor}=$gbics->{$sp}{formfactor};
            $ints->{$i}{serial}=$gbics->{$sp}{serial};
            $ints->{$i}{qualified}=$gbics->{$sp}{qualified};
          }
        }else{
          $ints->{$i}{formfactor}='physical';
        }
      }
      $rc=~s/!<nl>router$//i;
      $ints->{$i}{vlan}=$1 if $i=~/vlan ([\d]+)/i;
      for(split/<nl>/,$rc){
        my $l=$_;
        $ints->{$i}{description}=$1 if $l=~/description (.*)/i;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,bits=>$2,type=>'interface',version=>'4'}) if $l=~/ip address ([\d]+\..*)\/([\d]+)/;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,type=>'vrrp',version=>'4'}) if $l=~/virtual-address\s([\d]+\.[\d\.]+)/;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,bits=>$2,type=>'interface',version=>'6'}) if $l=~/ipv6 address\s([\w]+:.*)\/([\d]+)/;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,type=>'vrrp',version=>'6'}) if $l=~/virtual-address\s([\w]+:[\w:]+)/;
        $ints->{$i}{vrf}=$1 if $l=~/ip vrf forwarding (.*)/i;
        $ints->{$i}{mtu}=$1 if $l=~m/mtu\s([\d]+)/i;
        if($l=~m/\s+(port-channel\s[\d]+) mode active/){
          my $pci=$1;
          $pci=~s/port/Port/;
          $ints->{$i}{parent}=$pci;
          push(@{$ints->{$pci}{children}},$i);
        }
      }
      #update vrrp network bitmask
      $ints->{$i}{ipaddress}=updateBits($ints->{$i}{ipaddress});
    }
  }
  return $ints
}

sub updateBits{
  my $ips = shift;
  my $nets;
  for(@{$ips}){
    if($_->{bits}){
      my $n=new NetAddr::IP $_->{ip}.'/'.$_->{bits};
      push(@{$nets},$n);
    }
  }
  my $c=0;
  for(@{$ips}){
    my $nip=new NetAddr::IP $_->{ip};
    if(!$_->{bits}){
      for(@{$nets}){
        if($_->contains($nip)){
          $ips->[$c]{bits}=$_->masklen();
          last;
        }
      }
      $ips->[$c]{bits}='32' if !$ips->[$c]{bits};
    }
    $c++;
  }
  return $ips;
}

sub buildGbicHash{
  my $c=shift;
  $c =~ s/\n/<nl>/g;
  my $gb;
  for(split(/<nl>/,$c)){
    #if($_=~/!NAME: \"(.*)\"(\s+)?DESCR:\s\"(.*)\"(\s)?PID:\s(.*)VID:\s(.*)SN:\s(.*)/){
    if($_=~/!InventoryMedia:\s+([\d]+.*)/){
      my ($slot,$port,$type,$media,$serial,$qualified)=split(/\s+/,$1);
      my $sp=$slot.'/'.$port;
      $gb->{$sp}{formfactor}=$type.$media;
      $gb->{$sp}{serial}=$serial;
      $gb->{$sp}{qualified}=$qualified;
    }
  }
  return $gb;
}

1
