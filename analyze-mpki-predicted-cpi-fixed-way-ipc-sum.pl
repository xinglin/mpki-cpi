#!/usr/bin/perl -w
#
# analyze-mpki-predicted-cpi-fixed-way-ipc-sum:
# 	analyze the divergence in cache partitions when optimized for MPKI or
#	IPC sum, based on fixed-way CPI predictions and MPKIs for 2-benchmark 
#	workloads.
#
# Purpose:
#       To show how well fixed-way based CPI prediction does when compared with
#       MPKI based cache partitioning.
#
# Cache partitioning decision metrics: 
#		minimum MPKI sum for MPKI based cache partitioning
#       maximum IPC sum for CPIs based cache partitioning
# 
# Performance metrics:
#       weighted speedup, MPKI sum and IPC sum    
#		cache partitioning based on MPKI is used as the baseline              
#
use List::Util qw(sum);
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
# FIXME: remember to add an array here whenever a new program is added. 
#		 Make sure this equation holds: $CPIs = $programs + 1.
#
my @CPIs = (
	[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],#20
	[],[],[],[],
);

#
# predicted_CPIs - predicted CPIs for each program
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
		my @array1 = 0;
		my ($i, $j) = (0,0);
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
%best_pred_a_mpki_diverge = ();
%best_pred_a_ipc_diverge  = ();
%best_pred_a_speedup = ();
%best_pred_r_mpki_diverge = ();
%best_pred_r_ipc_diverge  = ();
%best_pred_r_speedup = ();

# calculate all possible combinations
print "\n\nbegin to calculate all possible 2-benchmark combinations...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my ($pg1, $pg2) = (0,0);
my $length = 0;
my $output_str = 0;
my ($i, $j, $k, $l) = (3,14,3,14);
my ($same_result, $diff_result) = (0,0);
for ($pg1 = 0; $pg1 <= $key_num - 2; $pg1++){
	for($pg2 = $pg1+1; $pg2 <= $key_num - 1 ; $pg2++){
		$length = scalar(@{ $CPIs[$programs{$keys[$pg1]}] });
		my($best_ii) = mpki_min($MPKIs[$programs{$keys[$pg1]}], 
						$MPKIs[$programs{$keys[$pg2]}]);
		my $mpki = $MPKIs[$programs{$keys[$pg1]}][$best_ii] + 
				$MPKIs[$programs{$keys[$pg2]}][$length - $best_ii - 2];
		my $ipc = 1/$CPIs[$programs{$keys[$pg1]}][$best_ii] + 
				1/$CPIs[$programs{$keys[$pg2]}][$length - $best_ii - 2];
		my $speedup = $CPIs[$programs{$keys[$pg1]}][$length -1]
				/$CPIs[$programs{$keys[$pg1]}][$best_ii] + 
				  $CPIs[$programs{$keys[$pg2]}][$length -1]
				/$CPIs[$programs{$keys[$pg2]}][$length - $best_ii - 2];

		my ($pred_ii, $pred_speedup) = 
			max_ipc_sum($predicted_CPIs[$programs{$keys[$pg1]}][$i][$j], 
					$predicted_CPIs[$programs{$keys[$pg2]}][$k][$l]);

		if($pred_ii == $best_ii){
			$same_result++;
			next;
		}else{
			$diff_result++;
		}

		# get the real-world speedup based on pred_i and accurate cpis
		$pred_speedup = 
            ($CPIs[$programs{$keys[$pg1]}][$length-1]/
            $CPIs[$programs{$keys[$pg1]}][$pred_ii])
          + ($CPIs[$programs{$keys[$pg2]}][$length-1]/
            $CPIs[$programs{$keys[$pg2]}][$length-$pred_ii-2]);

		my $workload = "$keys[$pg1]+$keys[$pg2]";
		# record difference details
        my $pred_speedup_diff = $pred_speedup - $speedup;
        $best_pred_a_speedup{$workload} = $pred_speedup_diff;
        $best_pred_r_speedup{$workload} = $pred_speedup_diff*100/$speedup;

		my $mpki_predicted = 
			$MPKIs[$programs{$keys[$pg1]}][$pred_ii]
		  + $MPKIs[$programs{$keys[$pg2]}][$length-$pred_ii-2];

		my $ipc_predicted = 
			1/$CPIs[$programs{$keys[$pg1]}][$pred_ii]
		  + 1/$CPIs[$programs{$keys[$pg2]}][$length-$pred_ii-2];
		
		$mpki_diff = $mpki_predicted - $mpki;
		$best_pred_a_mpki_diverge{$workload} = $mpki_diff;
		$best_pred_r_mpki_diverge{$workload} = $mpki_diff*100/$mpki;
	
		$ipc_diff = $ipc_predicted - $ipc;
		$best_pred_a_ipc_diverge{$workload} = $ipc_diff;
		$best_pred_r_ipc_diverge{$workload} = $ipc_diff*100/$ipc;
	}
}

my $total = $same_result + $diff_result;
printf "[Prediction]: Total: %3d, diff: %3d, %0.04f%%\n", 
			$total, $diff_result, $diff_result*100/$total;

print "Divergent Detail:\n";
my @weighted_speedup = (values %best_pred_a_speedup);
print_avg("absolute speedup", \@weighted_speedup, $total);

@weighted_speedup = (values %best_pred_r_speedup);
print_avg("[all]Increase in relative speedup", \@weighted_speedup, $total);
print_avg("[divergent cases]Increase in relative speedup", \@weighted_speedup);

my @absolute_mpki = (values %best_pred_a_mpki_diverge);
print_avg("absolute mpki", \@absolute_mpki, $total);

my @relative_mpki = (values %best_pred_r_mpki_diverge);
print_avg("[all]Increased in relative mpki", \@relative_mpki, $total);
print_avg("[divergent cases]Increased in relative mpki", \@relative_mpki);

my @absolute_ipc = (values %best_pred_a_ipc_diverge);
print_avg("absolute ipc", \@absolute_ipc, $total);

my @relative_ipc = (values %best_pred_r_ipc_diverge);
print_avg("[all]Increase in relative ipc", \@relative_ipc, $total);
print_avg("[divergent cases]Increase in relative ipc", \@relative_ipc);

print_top(\%best_pred_r_speedup, "relative speedup",10,10,8,6,4,2);
print_top(\%best_pred_r_mpki_diverge, "relative mpki", 10,50,40,30,20,10,5);
print_top(\%best_pred_r_ipc_diverge, "relative ipc", 10,20,15,10,5);
