#!/usr/bin/perl -w
#
# analyze-cpi-predicted-cpi-wt-spdup - analyze the differences in cache 
#							   		   partitions when optimized for 
#									   weighted speedup, based on accurate 
#									   CPIs and optimal predicted CPIs 
#									   for 2-benchmark workloads.
# Purpose:
#       To show the extent of sub-optimality of cache partitioning 
#		based on *optimal predicted* CPIs, when compared with cache 
#		partitioning based on accurate CPIs.
#
# Cache partitioning decision metrics: 
#       maximum weighted speedup is used for cache partitions based on optimal 
#		predicted CPIs and accurate CPIs.
# 
# Performance metrics:
#       speedup in weighted speedup, MPKI sum and IPC sum 
#		cache partitioning based on accurate CPIs is used as the base line
#
# NOTE: 
#		Results from this series of scripts are not included in our WDDD 2011
#		paper.   
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
# A four-dimentional array: [program][way1-to-pred][way2-to-pred][way]
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
			  'sphinx3' => 23,);

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
%perfect_predictions = ();
%best_pred_a_mpki_diverge = ();
%best_pred_a_ipc_diverge  = ();
%best_pred_a_speedup = ();
%best_pred_r_mpki_diverge = ();
%best_pred_r_ipc_diverge  = ();
%best_pred_r_speedup = ();

# calculate all possible combinations
print "\n\nbegin to calculate all possible combinations...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my ($pg1, $pg2) = (0,0); 
my ($length, $workload) = (0,0);
my $output_str = 0;
my ($i, $j, $k, $l) =(0,0,0,0);
for ($pg1 = 0; $pg1 <= $key_num - 2; $pg1++){
LABEL:	for($pg2 = $pg1+1; $pg2 <= $key_num -1 ; $pg2++){
		
		$length = scalar(@{ $CPIs[$programs{$keys[$pg1]}] });
		$workload = "$keys[$pg1]+$keys[$pg2]";
		my($best_ii, $speedup) = max_speedup($CPIs[$programs{$keys[$pg1]}], 
						$CPIs[$programs{$keys[$pg2]}]);
		my $mpki = $MPKIs[$programs{$keys[$pg1]}][$best_ii] + 
				$MPKIs[$programs{$keys[$pg2]}][$length - $best_ii - 2];
		my $ipc = 1/$CPIs[$programs{$keys[$pg1]}][$best_ii] + 
				1/$CPIs[$programs{$keys[$pg2]}][$length - $best_ii - 2];

		# try all predictions for each program
		my ($pred_ii, $pred_speedup)=(0,0);
		my ($best_i, $best_j, $best_k, $best_l) = (0,0,0,0);
		my ($pred_best_ii, $pred_best_speedup) = (0,0);
		for($i = 0; $i <= $length - 2; $i ++){
		  for($j = $i+1; $j <= $length -1; $j ++){
			for($k = 0;   $k <= $length -2; $k ++){
			  for($l = $k+1; $l <= $length -1; $l ++){

		# the $pred_speedup gotten here is based on predicted ipc. The value
		# is meanless to us. Instead, we want to get the real-world speedup 
		# for this cache partition.
		($pred_ii, $pred_speedup) = 
			max_speedup($predicted_CPIs[$programs{$keys[$pg1]}][$i][$j], 
					$predicted_CPIs[$programs{$keys[$pg2]}][$k][$l]);
		# if same, we find a cache partition that results in the 
		# same way partitioning as that based on accurate CPIs.
		if($pred_ii == $best_ii){
			my $vector = sprintf("(%2d,%2d,%2d,%2d)",$i+1,$j+1,$k+1,$l+1);
		 	$perfect_predictions{$workload} = "$vector";
			safe_delete_key(\%best_pred_a_speedup, $workload);
			safe_delete_key(\%best_pred_a_mpki_diverge, $workload);
			safe_delete_key(\%best_pred_a_ipc_diverge, $workload);
			safe_delete_key(\%best_pred_r_speedup, $workload);
			safe_delete_key(\%best_pred_r_mpki_diverge, $workload);
			safe_delete_key(\%best_pred_r_ipc_diverge, $workload);

			next LABEL;
		}

		# get the real-world speedup based on pred_ii and accurate cpis
		$pred_speedup = 
            ($CPIs[$programs{$keys[$pg1]}][$length-1]/
            $CPIs[$programs{$keys[$pg1]}][$pred_ii])
          + ($CPIs[$programs{$keys[$pg2]}][$length-1]/
            $CPIs[$programs{$keys[$pg2]}][$length-$pred_ii - 2]);

		# if this combination results in higher speedup, record it.
		if($pred_best_speedup < $pred_speedup){
			$pred_best_speedup = $pred_speedup;
			$pred_best_ii = $pred_ii;
			($best_i,$best_j,$best_k,$best_l) = ($i,$j,$k,$l);
		}

			  }#l
			}#k
		  }#j
		}#i	
		# record difference details
        my $pred_speedup_diff = $speedup - $pred_best_speedup;
        $best_pred_a_speedup{$workload} = $pred_speedup_diff;
        $best_pred_r_speedup{$workload} = $pred_speedup_diff*100/$speedup;

		my $mpki_predicted = 
			$MPKIs[$programs{$keys[$pg1]}][$pred_best_ii]
		  + $MPKIs[$programs{$keys[$pg2]}][$length - $pred_best_ii - 2];

		my $ipc_predicted = 
			1/$CPIs[$programs{$keys[$pg1]}][$pred_best_ii]
		  + 1/$CPIs[$programs{$keys[$pg2]}][$length - $pred_best_ii - 2];

		$mpki_diff = $mpki_predicted - $mpki;
		$best_pred_a_mpki_diverge{$workload} = $mpki_diff;
		$best_pred_r_mpki_diverge{$workload} = $mpki_diff*100/$mpki;
	
		$ipc_diff = $ipc_predicted - $ipc;
		$best_pred_a_ipc_diverge{$workload} = $ipc_diff;
		$best_pred_r_ipc_diverge{$workload} = $ipc_diff*100/$ipc;
	}
}

my $same_result = (keys %perfect_predictions);
my $diff_result = (keys %best_pred_a_speedup);
my $total = $same_result + $diff_result;
printf "Total results: $total, diff result: $diff_result".
		"\n\tpercentage: %0.08f%%\n", $diff_result*100/$total;

print "Divergent details:\n";
my @weighted_speedup = (values %best_pred_a_speedup);
print_avg("[Prediction] absolute speedup", \@weighted_speedup, $total);

@weighted_speedup = (values %best_pred_r_speedup);
print_avg("[all]drop in relative speedup", \@weighted_speedup, $total);
print_avg("[divergent cases]drop in relative speedup", \@weighted_speedup);

my @absolute_mpki = (values %best_pred_a_mpki_diverge);
print_avg("absolute mpki", \@absolute_mpki, $total);

my @relative_mpki = (values %best_pred_r_mpki_diverge);
print_avg("[all]Increase in relative mpki", \@relative_mpki, $total);
print_avg("[divergent cases]Increase in relative mpki", \@relative_mpki);

my @absolute_ipc = (values %best_pred_a_ipc_diverge);
print_avg("absolute ipc", \@absolute_ipc, $total);

my @relative_ipc = (values %best_pred_r_ipc_diverge);
print_avg("[all]Increase in relative ipc", \@relative_ipc, $total);
print_avg("[divergent cases]Increase in relative ipc", \@relative_ipc);

print_top(\%best_pred_r_speedup, "relative speedup",10);
print_top(\%best_pred_r_mpki_diverge, "relative mpki", 10);
print_top(\%best_pred_r_ipc_diverge, "relative ipc", 10);
