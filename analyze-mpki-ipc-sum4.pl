#!/usr/bin/perl -w
#
# analyze-mpki-ipc-sum4 - analyze the differences in cache partitions 
#                         when optimized for MPKI sum or IPC sum,
#                         based on MPKIs and accurate CPIs 
#                         for 4-benchmark workloads. 
# Purpose:
#       To show how divergent MPKI based cache partitioning can be from
#       *accurate* CPIs based cache partitioning.
#
# Cache partitioning decision metrics: 
#       minimum MPKI sum for MPKI based cache partitioning
#       maximum IPC sum for CPIs based cache partitioning
# 
# Performance metrics:
#       weighted speedup, MPKI sum and IPC sum      
#		cache partitioning based on MPKI is used as the baseline            
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

# read mpki and cpi information for programs
print "read mpki and cpi information for programs...\n";
foreach $key (keys %programs){
	read_mpki_cpi($key, $MPKIs[$programs{$key}], $CPIs[$programs{$key}]);
}

# statistics we are interested to get
%absolute_mpki_diverge = ();
%absolute_ipc_diverge  = ();
%absolute_speedup_diverge  = ();	#weighted speedup
%relative_mpki_diverge = ();
%relative_ipc_diverge  = ();
%relative_speedup_diverge  = ();

# calculate all possible combinations
print "\n\nbegin to calculate combinations of 4-benchmark workloads...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my ($prog1, $prog2, $prog3, $prog4) = (0,0,0,0); 
my ($mpki_min_i, $mpki_min_j, $mpki_min_k) = (0,0,0);
my ($same_result, $diff_result) = (0,0);
my ($length, $mpki_diff, $ipc_diff) = (0,0,0);
my $output_str = 0;
for ($prog1 = 0; $prog1 <= $key_num - 4; $prog1++){
	for($prog2 = $prog1+1; $prog2 <= $key_num - 3 ; $prog2++){
		for($prog3 = $prog2+1; $prog3 <= $key_num - 2 ; $prog3++){
		for($prog4 = $prog3+1; $prog4 <= $key_num - 1 ; $prog4++){
		($mpki_min_i, $mpki_min_j, $mpki_min_k) 
							= mpki_min4($MPKIs[$programs{$keys[$prog1]}], 
								$MPKIs[$programs{$keys[$prog2]}],
								$MPKIs[$programs{$keys[$prog3]}],
								$MPKIs[$programs{$keys[$prog4]}]);
		my ($ipc_i, $ipc_j, $ipc_k, $ipc_sum) 
							= max_ipc_sum4($CPIs[$programs{$keys[$prog1]}], 
								$CPIs[$programs{$keys[$prog2]}],
								$CPIs[$programs{$keys[$prog3]}],
								$CPIs[$programs{$keys[$prog4]}]);
		if($mpki_min_i == $ipc_i && $mpki_min_j == $ipc_j 
								&& $mpki_min_k == $ipc_k){
			$same_result ++;
			next;
		}else{
			$diff_result ++;
		}
	
		# difference details
		$length = scalar(@{ $MPKIs[$programs{$keys[$prog1]}] });
		
		my $mpki_total1 = $MPKIs[$programs{$keys[$prog1]}][$mpki_min_i] + 
				$MPKIs[$programs{$keys[$prog2]}][$mpki_min_j] +
				$MPKIs[$programs{$keys[$prog3]}][$mpki_min_k] +
				$MPKIs[$programs{$keys[$prog4]}][$length - $mpki_min_i 
											- $mpki_min_j - $mpki_min_k - 4];
		my $mpki_total2 = $MPKIs[$programs{$keys[$prog1]}][$ipc_i] + 
				$MPKIs[$programs{$keys[$prog2]}][$ipc_j] + 
				$MPKIs[$programs{$keys[$prog3]}][$ipc_k] + 
				$MPKIs[$programs{$keys[$prog4]}][$length - $ipc_i 
											- $ipc_j -$ipc_k - 4];

		my $ipc_total1 = 1/$CPIs[$programs{$keys[$prog1]}][$mpki_min_i] + 
				1/$CPIs[$programs{$keys[$prog2]}][$mpki_min_j] +
				1/$CPIs[$programs{$keys[$prog3]}][$mpki_min_k] +
				1/$CPIs[$programs{$keys[$prog4]}][$length - $mpki_min_i 
											- $mpki_min_j- $mpki_min_k - 4];
		my $speedup1 = 	$CPIs[$programs{$keys[$prog1]}][$length-1]
					/$CPIs[$programs{$keys[$prog1]}][$mpki_min_i] + 
						$CPIs[$programs{$keys[$prog2]}][$length-1]
					/$CPIs[$programs{$keys[$prog2]}][$mpki_min_j] +
						$CPIs[$programs{$keys[$prog3]}][$length-1]
					/$CPIs[$programs{$keys[$prog3]}][$mpki_min_k] +
						$CPIs[$programs{$keys[$prog4]}][$length-1]
					/$CPIs[$programs{$keys[$prog4]}][$length - $mpki_min_i 
											- $mpki_min_j- $mpki_min_k - 4];
		my $speedup2 = 	$CPIs[$programs{$keys[$prog1]}][$length-1]
					/$CPIs[$programs{$keys[$prog1]}][$ipc_i] + 
						$CPIs[$programs{$keys[$prog2]}][$length-1]
					/$CPIs[$programs{$keys[$prog2]}][$ipc_j] +
						$CPIs[$programs{$keys[$prog3]}][$length-1]
					/$CPIs[$programs{$keys[$prog3]}][$ipc_k] +
						$CPIs[$programs{$keys[$prog4]}][$length-1]
					/$CPIs[$programs{$keys[$prog4]}][$length - $ipc_i 
											- $ipc_j- $ipc_k - 4];
		my $workload = "$keys[$prog1]+$keys[$prog2]+"
						."$keys[$prog3]+$keys[$prog4]";
		# mpki diverge
		$mpki_diff = $mpki_total2 - $mpki_total1;
		$absolute_mpki_diverge{$workload} = $mpki_diff;
		$relative_mpki_diverge{$workload} = $mpki_diff*100/$mpki_total1; 
		# ipc diverge
		$ipc_diff = $ipc_sum - $ipc_total1;
		$absolute_ipc_diverge{$workload} = $ipc_diff;
		$relative_ipc_diverge{$workload} = $ipc_diff*100/$ipc_total1;
		# speedup diverge
		my $speedup_diff = $speedup2 - $speedup1;
		$absolute_speedup_diverge{$workload} = $speedup_diff;
		$relative_speedup_diverge{$workload} = $speedup_diff*100/$speedup1;
			}#pg4
		}#pg3
	}#pg2
}#pg1

print "\n-------------------------------------------------------------\n\n";
my $total = $same_result + $diff_result;
printf "Total results: $total, diff results: $diff_result\n".
		"percentage: %.04f%%\n\n", ($diff_result)*100/$total;

print "Divergent details\n";
# speedup
my @absolute_speedup = (values %absolute_speedup_diverge);
print_avg("absolute speedup", \@absolute_speedup, $total);
my @relative_speedup = (values %relative_speedup_diverge);
print_avg("[all]Increase in relative speedup", \@relative_speedup, $total);
print_avg("[divergent cases]Increase in relative speedup", \@relative_speedup);

# mpki
my @absolute_mpki = (values %absolute_mpki_diverge);
print_avg("\nabsolute mpki", \@absolute_mpki, $total);
my @relative_mpki = (values %relative_mpki_diverge);
print_avg("[all]Increase in relative mpki", \@relative_mpki, $total);
print_avg("[divergent cases]Increase in relative mpki", \@relative_mpki);

# ipc
my @absolute_ipc = (values %absolute_ipc_diverge);
print_avg("\nabsolute ipc", \@absolute_ipc, $total);
my @relative_ipc = (values %relative_ipc_diverge);
print_avg("[all]Increase in relative ipc", \@relative_ipc, $total);
print_avg("[divergent cases]Increase in relative ipc", \@relative_ipc);

print_top(\%relative_speedup_diverge, "relative speedup", 5, 10,8,6,4,2);
print_top(\%relative_mpki_diverge, "relative mpki", 5, 50,40,30,20,10,5);
print_top(\%relative_ipc_diverge, "relative ipc", 5,20,15,10,5);
