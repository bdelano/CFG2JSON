package CFG2JSON::Arista;
use strict;
use Data::Dumper;
my $gbics;

sub new{
  my $class = shift;
  my $args = { @_ };
  my $config=$args->{config};
  $gbics=buildGBICHash($config);
  my $dev=getinfo($config);
  my $interfaces=getinterfaces($config);
  #my $interfaces={};
  $dev->{interfaces}=$interfaces;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  for(@config){
    $obj->{serial}=$1 if $_=~/!Serial number:\s+(.*)/i;
    $obj->{model}=$1 if $_=~/!Model: Arista\s+(.*)/i;
    $obj->{version}=$1 if $_=~/!Software image version:\s+(.*)/i;
    push(@{$obj->{syslog}},$2) if $_=~/logging( vrf MGMT)? host ([\d\.]+)/i;
    push(@{$obj->{snmp}},$1) if $_=~/snmp-server host ([\d\.]+) version/i;
    push(@{$obj->{tacacs}},$1) if $_=~/!tacacs-server host ([\d\.]+)/i;
    if($_=~/!(.*)\.swix\s+([\d\.\/]+)\\\s+([\w]+),\s([\w]+)\s+.*/i){
      my $patch;
      $patch->{file}=$1;
      $patch->{version}=$2;
      $patch->{status}=$3.'-'.$4;
      push(@{$obj->{patch}},$patch);
    }
  }
  return $obj;
}

sub buildGBICHash{
  my $c = shift;
  $c =~ s/\n/<nl>/g;
  my $ret;
  for(split(/!System has/,$c)){
    if($_=~/.*transceiver slots/){
      for(split(/<nl>/,$_)){
        if($_=~/!\s+([\d\/]+.*)/){
          my @list=split(/\s+/,$1);
          if($list[1] eq 'Not'){
            $ret->{$list[0]}{vendor}='none';
            $ret->{$list[0]}{model}='none';
            $ret->{$list[0]}{serial}='none';
          }else{
            $ret->{$list[0]}{vendor}=$list[1];
            $ret->{$list[0]}{model}=$list[-3];
            $ret->{$list[0]}{serial}=$list[-2];
          }
        }
      }
    }
  }
  return $ret;
}

sub getinterfaces{
  my $c = shift;
  my $ints;
  $c =~ s/\n/<nl>/g;
  $c =~ s/\s+!//ig;
  $c =~ s/([\w])!/$1/ig;
  my @ints_arr=split("!",$c);
  shift @ints_arr;
  for(@ints_arr){
    my $int=$_;
    if($int=~/<nl>interface\s+([fskpmvlgibrtortchanel\d\-\/\.]+[\d])\s?<nl>\s?(.*)/ig){
      my $i=$1;
      my $rc=$2;
      $ints->{$i}{rawconfig}=$rc;
      push(@{$ints->{$i}{vlans}},$1) if $i=~/Vlan([\d]+)/;
      if($i=~/(Vlan|Loop)/i){
        $ints->{$i}{formfactor}='virtual';
      }elsif($i=~/port-/i){
        $ints->{$i}{formfactor}='lag';
      }elsif($i=~/.*\.[\d]+$/){
        #print "match:$i\n";
        $ints->{$i}{formfactor}='virtual';
      }else{
        my $bi=$i;
        $bi=~s/Ethernet//;
        $bi=~s/\/1$//;
        #print "i:$i bi:$bi\n";
        if($gbics->{$bi}{model}){
          $ints->{$i}{formfactor}=$gbics->{$bi}{model};
          $ints->{$i}{serial}=$gbics->{$bi}{serial};
        }elsif($i=~/management/){
          $ints->{$i}{formfactor}='1000BaseTX';
        }else{
          $ints->{$i}{formfactor}='physical';
        }
      }
      $ints->{$i}{mtu}='1500';
      $rc=~s/!<nl>router$//i;
      for(split/<nl>/,$rc){
        my $l=$_;
        $ints->{$i}{description}=$1 if $l=~/\s+description\s([!\"\'():,\@.&\w\s\/\-]+).*$/i;
        push(@{$ints->{$i}{ipaddress}},{ip=>$1,bits=>$2,type=>'interface',version=>'4'}) if $l=~/\s+ip\saddress\s([\d]+\..*)\/([\d]+)$/;
        $ints->{$i}{vrf}=$1 if $l=~/\s+vrf forwarding (.*)/i;
        $ints->{$i}{mtu}=$1 if $l=~/\s+mtu\s([\d]+)/i;
        if($l=~/encapsulation dot1q vlan ([\d]+)/i){
          push(@{$ints->{$i}{vlans}},$1);
          $ints->{$i}{mode}='sub';
        }
        if($l =~ m/\s+switchport\saccess\svlan\s([\d]+.*)$/){
          push(@{$ints->{$i}{vlans}},$1);
          $ints->{$i}{mode}='access';
        }
        if($l =~ /\sswitchport\strunk\sallowed\svlan\s(add\s)?([-,\d.*]+)$/){
          $ints->{$i}=addGroups($ints->{$i},$2);
          $ints->{$i}{mode}='tagged';
        }
        if($l=~/\s+channel-group\s([\d]+)\smode active/){
          $ints->{$i}{parent}='Port-Channel'.$1;
          push(@{$ints->{'Port-Channel'.$1}{children}},$i);
        }
      }
    }
  }
  $ints->{console}{formfactor}='NONE';
  return $ints;
}

sub addGroups{
  my ($int,$info)=@_;
  my @p_arr;
  for(split(/,/,$info)){
    my $pn=$_;
    if($pn=~/([\d]+\/)?([\d]+)-([\d]+\/)?([\d]+)/){
      my $i1s=$1;
      my $i1p=$2;
      my $i2s=$3;
      my $i2p=$4;
      for($i1p...$i2p){
        my $p=$i1s.'/'.$_;
        $p=$_ if !$i1s;
        push(@{$int->{vlans}},$_)
      }
    }else{
      push(@{$int->{vlans}},$pn)
    }
  }
  return $int;
}

1
