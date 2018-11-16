package CFG2JSON::Juniper;
use strict;

sub new{
  my ($class,$args)=@_;
  my $config=$args->{config};
  my $dev=getinfo($config);
  my $interfaces=getinterfaces($config);
  my $nats=getnats($config);
  $dev->{interfaces}=$interfaces;
  $dev->{nats}=$nats;
  my $self = bless {device=>$dev}, $class;
}

sub getinfo{
  my @config=split("\n",$_[0]);
  my $obj={};
  for(@config){
    if($_=~m/# Chassis\s+([\w]+)\s+([\w]+)/i){
      $obj->{serial}=$1;
      $obj->{model}=$2;
    }
    $obj->{version}=$1 if $_=~/.*O\/S\s+Version\s(.*)\sby builder.*/i;
  }
  return $obj;
}

sub getinterfaces {
  my $c = shift;
  $c=~s/\n/<nl>/g;
  my @cfglines;
	my @cfglines=split(/<nl>/,$c);
	my @infolines = grep(/set interfaces/,@cfglines);
  #print @infolines;
	my %int_hold;
	my %intcount_hash=();
  my $ints;
	#populate hashes and count different interfaces;
  shift @infolines;
	for(@infolines){
		my $l=$_;
    #print $l."\n";
		if($l=~/.*interfaces\s([\w\-\/]+)\s(unit\s([\d]+)\s)?.*/i){
			my $bi=$1;
			my $si=$2;
			#print "$bi : $si \n";
			if(!$si){$si='unit 0';}
				my $wc="$bi $si";
				$wc=~s/\s$//ig;
				$wc=~s/\sunit\s/\./i;
				my $ic=$intcount_hash{$bi};
			if($int_hold{$wc}){
				$int_hold{$wc}=$int_hold{$wc} . '<nl>' . $l;
			}else{
				$int_hold{$wc}=$l;
      	if($ic){
      	$ic++;
      	$intcount_hash{$bi}=$ic;
      	}else{
      	$intcount_hash{$bi}=1;
      	}
			}
		}elsif($l=~/.*interfaces\s(.*)/){
			print "NOMATCH:$1\n"
		}
	}

	for(keys %int_hold){
		my $subi=$_;
		my $bi=$subi;
		$bi=~s/\.[\d]+//i;
		my $count=$intcount_hash{$bi};
		if($count==2){
			if($subi=~m/ae[\d]+\./){
			$int_hold{$bi}=$int_hold{$bi} . '<nl>' . $int_hold{$subi};
			delete($int_hold{$subi});
			}elsif($subi=~m/ae/i){
			}elsif($subi=~/\./){
			$int_hold{$subi}=$int_hold{$bi} . '<nl>' . $int_hold{$subi};
			}else{
			delete($int_hold{$subi});
			}
		}
	}

	for(keys %int_hold){
		my $interface=$_;
		my $rawcfg=$int_hold{$interface};
    if($interface=~/\./i){
			my $ti=$interface;
			$ti=~s/\.0$//ig;
      my %al_hash=();
      for(grep(/$ti /,@cfglines)){
	      if($_=~/set interfaces $ti .*/i){
	      }elsif($al_hash{$_}){
	      }else{
	      	$al_hash{$_}='1';
	      	$rawcfg.='<nl>' . $_;
	      }
      }
      for(grep(/$ti$/,@cfglines)){
        if($_=~/set interfaces $ti .*/i){
        }elsif($al_hash{$_}){
        }else{
        	$al_hash{$_}='1';
        	$rawcfg.='<nl>' . $_;
        }
      }
			my ($bi,$unit)=split(/\./,$ti);
			if($unit){
				for(grep(/$bi unit $unit/,@cfglines)){
					if($_=~/set interfaces $bi unit $unit.*/i){
					}elsif($al_hash{$_}){
					}else{
						$al_hash{$_}='1';
						$rawcfg.='<nl>' . $_;
					}
				}
			}
			if($interface ne $ti){
				for(grep(/$interface/,@cfglines)){
					if($_=~/set interfaces $ti.*/i){
					}elsif($al_hash{$_}){
					}else{
						$al_hash{$_}='1';
						$rawcfg.='<nl>' . $_;
					}
				}
			}
		}

		$rawcfg=~s/^<nl>//i;
		$rawcfg=~s/<nl><nl>/<nl>/ig;
		$rawcfg=~s/[^a-zA-Z0-9\s:_\-()<>{}\/\.]*//g;
		my $vlanlist = '';
		my $vlc=0;
		my $intsec=1;
    my $v6intsec=1;
		my %ipc_hash;
		for(split(/<nl>/,$rawcfg)){
			my $intdet=$_;
      $ints->{$interface}{description}=$1 if $intdet=~/.*description\s(.*)$/ig;
      $ints->{$interface}{ipaddress}=$1 if $intdet=~/^address\s([\d\.\/]+)$/ig;
			if($intdet=~/127\.0\.0\.1/){
			}elsif($intdet =~ m/.*inet address\s([\d\.\/]+).*/ig){
				my $ipc=$1;
				if($ints->{$interface}{ipaddress}){
					if(!$ipc_hash{$ipc}){
            $ints->{$interface}{'ipaddress'.$intsec}=$ipc;
						$intsec++;
						$ipc_hash{$ipc}=1;
					}
				}else{
          $ints->{$interface}{ipaddress}=$ipc;
					$ipc_hash{$ipc}=1;
				}
			}elsif($intdet =~m/inet6 address\s([\w:\/]+).*/ig){
				my $ipc=$1;
				if($ints->{$interface}{v6ipaddress}){
					if(!$ipc_hash{$ipc}){
						$ints->{$interface}{'v6ipaddress'.$v6intsec}=$ipc;
            $v6intsec++;
						$ipc_hash{$ipc}=1;
					}
				}else{
					$ints->{$interface}{v6ipaddress}=$ipc;
          $ipc_hash{$ipc}=1;
        }
      }elsif($intdet =~ m/set interfaces (.*) ether-options 802.3ad.*([\d]+)/ig){
				my $pcinterface = $1 . '.0';
				my $pcid=$2;
				if($interface=~/ae[\d]+/i){
	        $ints->{$pcinterface}{description} = $ints->{$pcinterface}{description} . "<br>channel-group $pcid";
					$ints->{$interface}{description}="INT: $pcinterface<br>" . $ints->{$interface}{description}
				}
			}
		}
	}
	return $ints;
}

sub getnats{
	my $c = shift;
  $c=~s/\n/<nl>/g;
  my @nat_arr;
	my %gaddr_hash;
	for(split('<nl>',$c)){
		if($_=~/set security address-book global address (.*)\s([\d\.\/]+)/i){
			$gaddr_hash{$1}=$2;
		}
	}
	my %loc_hash;
	my %rem_hash;
	my %raw_hash;
	for(split('<nl>',$c)){
		if($_=~/set security nat static rule-set (.*) rule (.*) match destination-address (.*)/){
			my $rs=$1;
			my $r=$2;
			my $key=$rs.'-!'.$r;
			$loc_hash{$key}=$3;
			$raw_hash{$key}=$raw_hash{$key}.$_.'<nl>';
		}elsif($_=~/set security nat static rule-set (.*) rule (.*) then static-nat prefix(-name)? (.*)/){
			my $rs=$1;
			my $r=$2;
			my $remip=$4;
			my $key=$rs.'-!'.$r;
			if(!$rem_hash{$key}=~/[\d\.\/]+/){
				$rem_hash{$key}=$remip;
			}
			$raw_hash{$key}=$raw_hash{$key}.$_.'<nl>';
		}
	}
	my $i=1;
	for(keys %loc_hash){
    my $natobj;
		my $loc=$loc_hash{$_};
		my $rem=$rem_hash{$_};
		my $raw=$raw_hash{$_};
		my ($ruleset,$rule)=split('-!',$_);
		if($gaddr_hash{$rem}){
			$rem=$gaddr_hash{$rem};
		}
		my $description="$ruleset $rule $loc to $rem";
		my $int='nat'.$i;
		$i++;
    $natobj->{local}=$loc;
    $natobj->{remote}=$rem;
    $natobj->{description}=$raw;
    push(@nat_arr,$natobj)
	}
  return \@nat_arr;
}

1
