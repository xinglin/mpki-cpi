#!/usr/bin/perl -w
#
# analyze-cpi-predicted-cpi-wt-spdup4 - analyze the differences in cache 
#                                       partitioning when optimized for 
#										weighted speedup, based on accurate 
#										CPIs and optimal predicted CPIs for 
#										4-benchmark workloads.
# Purpose:
#       To show the best speedup we can get based on *optimal predicted* CPIs,
#       when compared with accurate CPIs based cache partitioning.
#
# Cache partitioning decision metrics: 
#       maximum weighted speedup for cache partitioning based on optimal 
#       predicted CPIs and accurate CPIs.
# 
# Performance metrics:
#       speedup in weighted speedup, MPKI sum and IPC sum                  
#
use List::Util qw(sum max);
use Common;

#
# MPKIs - MPKIs for each program
# 
# FIXME: remember to add an array here whenever a new program is added. 
#        Make sure this equation holds: $MPKIs = $programs + 1.
#
my @MPKIs = (
	[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],#20
	[],[],[],[],
);

#
# CPIs - CPIs for each program
# 
# FIXME: remember to add an array here whenever a new program are added. 
#        Make sure this equation holds: $CPIs = $programs + 1.
#
my @CPIs = (
	[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],#20
	[],[],[],[],
);

#
# CPIs - predicted CPIs for each program
#
my @predicted_CPIs = ();

#
# program index 
#
%programs = ( 'bwaves' => 1, 'bzip2' => 2, 'cactusADM' => 3, 'calculix' => 4,
			  'gamess' => 5, 'gcc' => 6, 'hmmer' => 7, 'gromacs' => 8, 
			  'leslie3d' => 9, 'mcf' => 10, 'milc' => 11, 'namd' => 12,
			  'povray' => 13, 'soplex' => 14, 'zeusmp' => 15,
			  'sjeng'  => 16, 'libquantum' => 17, 'h264ref' => 18,
			  'tonto'  => 19, 'omnetpp' => 20, 'lbm' => 21, 'astar' => 22,
			  'sphinx3' => 23, );

sub fatal {
	my @message = @_;
	print "@message\n";
	exit(1);
}

my $debug = 1;
sub debug_info {
	my @message = @_;
	if($debug){
		print "@message";
	}
}

sub read_all_mpki_cpi {
	# read mpki and cpi information for programs
	print "read accurate mpki and cpi information for programs\t\t[started]\n";
	foreach $key (keys %programs){
		read_mpki_cpi($key, $MPKIs[$programs{$key}], $CPIs[$programs{$key}]);
	}
	print "read accurate mpkis and cpis\t\t\t\t\t[done]\n";
}

sub read_all_predicted_cpis {
	# read predicted cpis
	print "read predicted cpis for programs\t\t\t\t[started]\n";
	my $filename = 0;

	foreach $key (keys %programs){
		my $length = scalar( @{$CPIs[$programs{$key}]} );
		print "$key\n";
		my @array1 = 0, $i=0,$j=0;
		for($i = 0; $i <= $length - 2; $i ++){
			my @array2 = 0;
			for($j = $i+1; $j <= $length -1; $j ++){
				$filename = sprintf("$key.%02d.%02d.cpis", $i+1,$j+1);
				my @predicted_cpis = 0;
				read_predicted_cpis($filename, \@predicted_cpis);
					$array2[$j] = \@predicted_cpis;
				}
			$array1[$i] = \@array2;
		}
		$predicted_CPIs[$programs{$key}] = \@array1;
	}
	print "read predicted cpis\t\t\t\t\t\t[done]\n";
}

# main() starts here
read_all_mpki_cpi();
read_all_predicted_cpis();

# statistics we are interested to get
%best_pred_a_ipc_diverge = ();
%best_pred_a_speedup = ();
%best_pred_r_ipc_diverge = ();
%best_pred_r_speedup = ();


# calculate all possible combinations
print "\n\nbegin to calculate all possible combinations...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my ($pg1, $pg2, $pg3,$pg4) = (0,0,0);
my $length = 0;
my $output_str = 0;
my ($i, $j, $k, $l, $m, $n,$o,$p) = (0,0,0,0,0,0,0,0);
for ($pg1 = 0; $pg1 <= $key_num-4; $pg1++){
	for($pg2 = $pg1+1; $pg2 <= $key_num - 3; $pg2++){
	for($pg3 = $pg2+1; $pg3 <= $key_num -2 ; $pg3++){
LABEL:	for($pg4 = $pg3+1; $pg4 <= $key_num -1 ; $pg4++){
		
		$length = scalar(@{ $CPIs[$programs{$keys[$pg1]}] });
		my $workload = "$keys[$pg1]+$keys[$pg2]+$keys[$pg3]+$keys[$pg4]";
		my($best_ii, $best_jj, $best_kk, $speedup) = 
						max_speedup4($CPIs[$programs{$keys[$pg1]}], 
						$CPIs[$programs{$keys[$pg2]}], 
						$CPIs[$programs{$keys[$pg3]}], 
						$CPIs[$programs{$keys[$pg4]}]);

		# try all predictions for each program
		my ($pred_ii, $pred_jj, $pred_kk, $pred_speedup)=(0,0,0,0);
		my ($pred_best_ii, $pred_best_jj, $pred_best_kk, $pred_best_speedup) 						= (0,0,0,0);
		for($i = 0; $i <= $length - 2; $i ++){
		  for($j = $i+1; $j <= $length -1; $j ++){
			for($k = 0;   $k <= $length -2; $k ++){
			  for($l = $k+1; $l <= $length -1; $l ++){
			    for($m = 0;    $m <= $length -2; $m ++){
			      for($n = $m+1; $n <= $length -1; $n ++){
			    for($o = 0;    $o <= $length -2; $o ++){
			      for($p = $o+1; $p <= $length -1; $p ++){

		# the $pred_speedup gotten here is based on predicted ipc. The value
		# is meanless to me.
		($pred_ii, $pred_jj, $pred_kk, $pred_speedup) = 
			max_speedup4($predicted_CPIs[$programs{$keys[$pg1]}][$i][$j], 
						$predicted_CPIs[$programs{$keys[$pg2]}][$k][$l],
						$predicted_CPIs[$programs{$keys[$pg3]}][$m][$n],
						$predicted_CPIs[$programs{$keys[$pg4]}][$o][$p]);

		if($pred_ii == $best_ii && $pred_jj == $best_jj && 
													$pred_kk == $best_kk){
			my $vector = sprintf("(%2d,%2d,%2d,%2d,%2d,%2d)",$i+1,$j+1,
									$k+1,$l+1,$o+1,$p+1);
			$perfect_predictions{$workload} = $vector;
            safe_delete_key(\%best_pred_a_speedup, $workload);
            safe_delete_key(\%best_pred_a_ipc_diverge, $workload);
            safe_delete_key(\%best_pred_r_speedup, $workload);
            safe_delete_key(\%best_pred_r_ipc_diverge, $workload);
			next LABEL;
		}

		# get the real-world speedup based on pred_i and accurate cpis
		$pred_speedup = 
            ($CPIs[$programs{$keys[$pg1]}][$length-1]/
            $CPIs[$programs{$keys[$pg1]}][$pred_ii])
          + ($CPIs[$programs{$keys[$pg2]}][$length-1]/
            $CPIs[$programs{$keys[$pg2]}][$pred_jj])
          + ($CPIs[$programs{$keys[$pg3]}][$length-1]/
            $CPIs[$programs{$keys[$pg3]}][$pred_kk])
          + ($CPIs[$programs{$keys[$pg4]}][$length-1]/
            $CPIs[$programs{$keys[$pg4]}][$length-$pred_ii 
								-$pred_jj -$pred_kk - 4]);

		# if this combination results in higher speedup, record it.
		if($pred_best_speedup < $pred_speedup){
			$pred_best_speedup = $pred_speedup;
			$pred_best_ii = $pred_ii;
			$pred_best_jj = $pred_jj;
			$pred_best_kk = $pred_kk;
		}
					  }#p
					}#o
				  }#n
			    }#m
			  }#l
			}#k
		  }#j
		}#i	
		# record difference details
        my $ipc_predicted =
            1/$CPIs[$programs{$keys[$pg1]}][$pred_best_ii]
          + 1/$CPIs[$programs{$keys[$pg2]}][$pred_best_jj]
          + 1/$CPIs[$programs{$keys[$pg3]}][$pred_best_kk]
          + 1/$CPIs[$programs{$keys[$pg4]}][$length-$pred_best_ii
							-$pred_best_jj-$pred_best_kk - 4];
        my $ipc =
            1/$CPIs[$programs{$keys[$pg1]}][$best_ii]
          + 1/$CPIs[$programs{$keys[$pg2]}][$best_jj]
          + 1/$CPIs[$programs{$keys[$pg3]}][$best_kk]
          + 1/$CPIs[$programs{$keys[$pg4]}][$length-$best_ii
							-$best_jj-$best_kk - 4];
		my $pred_ipc_diff = $ipc - $ipc_predicted;
		$best_pred_a_ipc_diverge{$workload} = $pred_ipc_diff;
		$best_pred_r_ipc_diverge{$workload} = $pred_ipc_diff*100/$ipc;

        my $pred_speedup_diff = $speedup - $pred_best_speedup;
        $best_pred_a_speedup{$workload} = $pred_speedup_diff;
        $best_pred_r_speedup{$workload} = $pred_speedup_diff*100/$speedup;
			}#pg4
		}#pg3
	}#pg2
}#pg1

my $same_result = (keys %perfect_predictions);
my $diff_result = (keys %best_pred_r_speedup);
my $total = $same_result + $diff_result;
printf "Total: %3d, diff: %3d, %0.06f%%\n", 
			$total, $diff_result, $diff_result*100/$total;

print "Divergent detail:\n";
my @weighted_speedup = (values %best_pred_a_speedup);
print_avg("absolute speedup", \@weighted_speedup, $total);

@weighted_speedup = (values %best_pred_r_speedup);
print_avg("drop in relative speedup", \@weighted_speedup, $total);

my @absolute_ipc = (values %best_pred_a_ipc_diverge);
print_avg("absolute ipc", \@absolute_ipc, $total);

my @relative_ipc = (values %best_pred_r_ipc_diverge);
print_avg("drop in relative ipc", \@relative_ipc, $total);

print_top(\%best_pred_a_speedup, "absolute divergent speedup", 10);
print_top(\%best_pred_r_speedup, "relative divergent speedup",10);
print_top(\%best_pred_a_ipc_diverge, "absolute ipc", 10);
print_top(\%best_pred_r_ipc_diverge, "relative ipc",10);
