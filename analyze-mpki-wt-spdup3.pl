#!/usr/bin/perl -w
#
# analyze-mpki-wt-spdup3 - analyze the differences in cache partitionings 
#                          when optimized for MPKI sum or weighted speedup
#                          based on MPKIs and accurate CPIs 
#                          for 3-benchmark workloads. 
# Purpose:
#       To show how divergent MPKI based cache partitioning can be from
#       *accurate* CPIs based cache partitioning.
#
# Cache partitioning decision metrics: 
#       minimum MPKI sum for MPKI based cache partitioning
#       maximum weighted speedup for CPIs based cache partitioning
# 
# Performance metrics:
#       weighted speedup, MPKI sum and IPC sum                  
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
#		 Make sure this equation holds: $CPIs = $programs + 1.
#
my @CPIs = (
	[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],#20
	[],[],[],[],
);

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

my $debug = 0;
sub debug_info {
	my @message = @_;
	if($debug){
		print "@message";
	}
}

# read mpki and cpi information for programs
print "read mpki and cpi information for programs...\n";
foreach $key (keys %programs){
	read_mpki_cpi($key, $MPKIs[$programs{$key}], $CPIs[$programs{$key}]);
}

# statistics we are interested to get
%absolute_mpki_diverge = ();
%absolute_ipc_diverge  = ();
%absolute_weighted_speedup = ();
%relative_mpki_diverge = ();
%relative_ipc_diverge  = ();
%relative_weighted_speedup = ();

# calculate all possible combinations
print "\n\nbegin to calculate all possible 3-benchmark workloads...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my $program1 = 0, $program2 = 0, $program3 = 0; 
my $mpki_min_i = 0, $mpki_min_j = 0, $best_i = 0, $best_j = 0,$best_speedup=0;
my $same_result = 0, $diff_result = 0;
my $length = 0, $speedup_diff = 0, $mpki_diff = 0, $ipc_diff = 0;
my $output_str = 0;
for ($program1 = 0; $program1 <= $key_num - 3; $program1++){
	for($program2 = $program1+1; $program2 <= $key_num - 2 ; $program2++){
		for($program3 = $program2+1; $program3 <= $key_num - 1 ; $program3++){
		($mpki_min_i, $mpki_min_j) = 
					mpki_min3($MPKIs[$programs{$keys[$program1]}], 
										$MPKIs[$programs{$keys[$program2]}],
										$MPKIs[$programs{$keys[$program3]}]);
		($best_i, $best_j,$best_speedup) = 
					max_speedup3($CPIs[$programs{$keys[$program1]}], 
									$CPIs[$programs{$keys[$program2]}],
									$CPIs[$programs{$keys[$program3]}]);
		if($mpki_min_i == $best_i && $mpki_min_j == $best_j){
			$same_result ++;
			next;
		}else{
			$diff_result ++;
		}
	
		# difference details
		$length = scalar(@{ $MPKIs[$programs{$keys[$program1]}] });

		my $mpki_total1 = $MPKIs[$programs{$keys[$program1]}][$mpki_min_i] + 
				$MPKIs[$programs{$keys[$program2]}][$mpki_min_j] +
				$MPKIs[$programs{$keys[$program3]}][$length - $mpki_min_i 
														- $mpki_min_j - 3];
		my $mpki_total2 = $MPKIs[$programs{$keys[$program1]}][$best_i] + 
				$MPKIs[$programs{$keys[$program2]}][$best_j] + 
				$MPKIs[$programs{$keys[$program3]}][$length - $best_i 
														- $best_j - 3];

		my $ipc_total1 = 1/$CPIs[$programs{$keys[$program1]}][$mpki_min_i] + 
				1/$CPIs[$programs{$keys[$program2]}][$mpki_min_j] +
				1/$CPIs[$programs{$keys[$program3]}][$length - $mpki_min_i 
														- $mpki_min_j - 3];
		my $ipc_total2 = 1/$CPIs[$programs{$keys[$program1]}][$best_i] + 
				1/$CPIs[$programs{$keys[$program2]}][$best_j] +
				1/$CPIs[$programs{$keys[$program3]}][$length - $best_i 
										- $best_j - 3];
				      
		my $speedup1 = ($CPIs[$programs{$keys[$program1]}][$length-1]/
                        $CPIs[$programs{$keys[$program1]}][$mpki_min_i])+
                ($CPIs[$programs{$keys[$program2]}][$length - 1]/
                $CPIs[$programs{$keys[$program2]}][$mpki_min_j]) +
                ($CPIs[$programs{$keys[$program3]}][$length - 1]/
                $CPIs[$programs{$keys[$program3]}][$length- $mpki_min_i 
							- $mpki_min_j - 3]);

		my $workload = "$keys[$program1]+$keys[$program2]+$keys[$program3]";
        $speedup_diff = $best_speedup - $speedup1;
        $absolute_weighted_speedup{$workload} = $speedup_diff;
        $relative_weighted_speedup{$workload} = $speedup_diff*100/$best_speedup;

		$mpki_diff = $mpki_total2 - $mpki_total1;
		$absolute_mpki_diverge{$workload} = $mpki_diff;
		$relative_mpki_diverge{$workload} = $mpki_diff*100/$mpki_total2; 
	
		$ipc_diff = $ipc_total2-$ipc_total1;
		$absolute_ipc_diverge{$workload} = $ipc_diff;
		$relative_ipc_diverge{$workload} = $ipc_diff*100/$ipc_total2;
		}
	}
}

print "\n-------------------------------------------------------------\n\n";
my $total = $same_result + $diff_result;
printf "Total results: %d, diff results: $diff_result\n".
		"percentage: %.02f%%\n\n", $total,
			($diff_result)*100/$total;

print "Divergent details:\n";
my @absolute_speedup = (values %absolute_weighted_speedup);
print_avg("absolute speedup", \@absolute_speedup, $total);
my @relative_speedup = (values %relative_weighted_speedup);
print_avg("drop in relative speedup", \@relative_speedup, $total);

my @absolute_mpki = (values %absolute_mpki_diverge);
print_avg("absolute mpki", \@absolute_mpki, $total);
my @relative_mpki = (values %relative_mpki_diverge);
print_avg("drop in relative mpki", \@relative_mpki, $total);

my @absolute_ipc = (values %absolute_ipc_diverge);
print_avg("absolute ipc", \@absolute_ipc, $total);
my @relative_ipc = (values %relative_ipc_diverge);
print_avg("drop in relative ipc", \@relative_ipc, $total);

print_top(\%relative_weighted_speedup, "relative speedup",10, 10,8,6,4,2);
print_top(\%relative_mpki_diverge, "relative mpki", 10, 50, 40, 30,20,10,5);
print_top(\%relative_ipc_diverge, "relative ipc", 10, 20, 15, 10, 5);
