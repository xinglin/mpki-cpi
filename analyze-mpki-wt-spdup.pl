#!/usr/bin/perl -w
#
# analyze-mpki-wt-spdup - analyze the differences in cache partitionings 
#						  when optimized for MPKI sum or weighted speedup,
#						  based on MPKIs or accurate CPIs 
#						  for 2-benchmark workloads. 
# Purpose:
#		To show how divergent MPKI based cache partitioning can be from
#		*accurate* CPIs based cache partitioning.
#
# Cache partitioning decision metrics: 
#		minimum MPKI sum for MPKI based cache partitioning
#		maximum weighted speedup for CPIs based cache partitioning
# 
# Performance metrics:
#		weighted speedup, MPKI sum and IPC sum					
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

sub read_all_mpki_cpi {
    # read mpki and cpi information for programs
    print "read accurate mpki and cpi information for programs\t\t[started]\n";
    foreach $key (keys %programs){
        read_mpki_cpi($key, $MPKIs[$programs{$key}], $CPIs[$programs{$key}]);
    }
    print "read accurate mpkis and cpis\t\t\t\t\t[done]\n";
}

read_all_mpki_cpi();

# statistics we are interested to get
%absolute_mpki_diverge = ();
%absolute_ipc_diverge  = ();
%absolute_speedup = ();		#weighted speedup

# cache partitioning optimized for weighted speedup is used as baseline.
%relative_mpki_diverge = ();
%relative_ipc_diverge  = ();
%relative_speedup = ();

# calculate all possible combinations
print "\n\nbegin to calculate all possible combinations...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my $program1 = 0, $program2 = 0;
my $same_result = 0, $diff_result = 0;
my $length = 0, $speedup_diff = 0, $mpki_diff = 0, $ipc_diff = 0;
my $output_str = 0;
for ($program1 = 0; $program1 < $key_num-1; $program1++){
	for($program2 = $program1+1; $program2 <= $key_num -1 ; $program2++){
		my $mpki_min = mpki_min($MPKIs[$programs{$keys[$program1]}], 
						$MPKIs[$programs{$keys[$program2]}]);
		my($ipc_i,$speedup) = 
				max_speedup($CPIs[$programs{$keys[$program1]}], 
						$CPIs[$programs{$keys[$program2]}]);
		if($mpki_min == $ipc_i){
			$same_result ++;
			next;
		}else{
			$diff_result ++;
		}
	
		# divergence details
		$length = scalar(@{ $MPKIs[$programs{$keys[$program1]}] });
		$output_str = sprintf("$keys[$program1]+$keys[$program2]:\n".
				"MPKI_MIN: $mpki_min, IPC_i: $ipc_i\n");
		debug_info($output_str);

		my $mpki_total1 = $MPKIs[$programs{$keys[$program1]}][$mpki_min] + 
				$MPKIs[$programs{$keys[$program2]}][$length - $mpki_min - 2];
		my $mpki_total2 = $MPKIs[$programs{$keys[$program1]}][$ipc_i] + 
				$MPKIs[$programs{$keys[$program2]}][$length - $ipc_i - 2];

		my $ipc_total1 = 1/$CPIs[$programs{$keys[$program1]}][$mpki_min] + 
				1/$CPIs[$programs{$keys[$program2]}][$length - $mpki_min - 2];
		my $ipc_total2 = 1/$CPIs[$programs{$keys[$program1]}][$ipc_i] + 
				1/$CPIs[$programs{$keys[$program2]}][$length - $ipc_i - 2];

		my $speedup1 = ($CPIs[$programs{$keys[$program1]}][$length-1]/ 
						$CPIs[$programs{$keys[$program1]}][$mpki_min])+
				($CPIs[$programs{$keys[$program2]}][$length - 1]/
				$CPIs[$programs{$keys[$program2]}][$length - $mpki_min - 2]);

		my $workload = "$keys[$program1]+$keys[$program2]";
		# mpki diverge
		$mpki_diff = $mpki_total2-$mpki_total1;	#mpki_total2 > total1
		$absolute_mpki_diverge{$workload} = $mpki_diff;
		$relative_mpki_diverge{$workload} = $mpki_diff*100/$mpki_total2; 
		# ipc diverge
		$ipc_diff = $ipc_total2-$ipc_total1;
		$absolute_ipc_diverge{$workload} = $ipc_diff;
		$relative_ipc_diverge{$workload} = $ipc_diff*100/$ipc_total2;
		# speedup
		$speedup_diff = $speedup - $speedup1;
		$absolute_speedup{$workload} = $speedup_diff;
		$relative_speedup{$workload} = $speedup_diff*100/$speedup;

		$output_str = sprintf("absolute diff in mpki: %f, ipc: %f\n", 
								$mpki_diff, $ipc_diff);
		debug_info($output_str);	
		$output_str = sprintf("relative diff in mpki: %.06f%%, ipc: %.06f%%\n", 
				$mpki_diff*100/$mpki_total2, $ipc_diff*100/$ipc_total2);
		debug_info($output_str);

	}
}

print "\n-------------------------------------------------------------\n\n";
my $total = $same_result + $diff_result;
printf "Total results: %d, diff result: $diff_result\n".
		"percentage: %.02f%%\n\n", $total,
			($diff_result)*100/$total;

print "Divergent detail:\n";
my @weighted_speedup = (values %absolute_speedup);
print_avg("absolute speedup", \@weighted_speedup, $total);

@weighted_speedup = (values %relative_speedup);
print_avg("drop in relative speedup", \@weighted_speedup, $total);

my @absolute_mpki = (values %absolute_mpki_diverge);
print_avg("absolute mpki", \@absolute_mpki, $total);

my @relative_mpki = (values %relative_mpki_diverge);
print_avg("drop in relative mpki", \@relative_mpki, $total);

my @absolute_ipc = (values %absolute_ipc_diverge);
print_avg("absolute ipc sum", \@absolute_ipc, $total);

my @relative_ipc = (values %relative_ipc_diverge);
print_avg("drop in relative ipc sum", \@relative_ipc, $total);

print_top(\%absolute_speedup, "absolute speedup", 10);

print_top(\%relative_speedup, "relative speedup",10,10,8,6,4,2);

print_top(\%relative_mpki_diverge, "relative mpki", 10,50,40,30,20,10,5);

print_top(\%absolute_ipc_diverge, "absolute ipc sum",10);

print_top(\%relative_ipc_diverge, "relative ipc sum", 10, 20,15,10,5);
