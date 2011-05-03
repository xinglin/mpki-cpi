#!/usr/bin/perl -w
# 
# For every possible pair of (way1, way2), get how many same configurations
# we can get for all possible combinations of 2 programs.
#
# Another purpose is to see which pair gives us the most same configurations
# and we will use that pair for fixed-way predictions. 
#
use List::Util qw(sum);
use Common;
#
# MPKIs - MPKI for each program
# 
# FIXME: remember to add an array here whenever a new program is added. 
#        $MPKIs = $programs + 1.
my @MPKIs = (
	[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],#20
	[],[],[],[],
);

#
# CPIs - CPI for each program
# 
# FIXME: remember to add an array here whenever a new program are added. 
#
my @CPIs = (
	[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],#20
	[],[],[],[],
);

#
# CPIs - CPI for each program
# 
# FIXME: remember to add an array here whenever a new program are added. 
#
my %predicted_CPIs = ();

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
my @same_partitioning = ([],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]);

# calculate all possible combinations
print "\n\nbegin to calculate all possible combinations...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my $pg1 = 0; 
my $pg2 = 0;
my $length = 0;
my $output_str = 0;
my $i=0, $j=0;

$length = scalar(@{ $CPIs[$programs{$keys[0]}] });
for($i = 0; $i <= $length - 2; $i ++){
	for($j = $i+1; $j <= $length -1; $j ++){
		$same_partitioning[$i][$j] = 0;
	}
}

for($i = 0; $i <= $length - 2; $i ++){
	for($j = $i+1; $j <= $length -1; $j ++){

		for ($pg1 = 0; $pg1 < $key_num-1; $pg1++){
			for($pg2 = $pg1+1; $pg2 <= $key_num -1 ; $pg2++){
		
		my($best_ii, $speedup) = max_speedup($CPIs[$programs{$keys[$pg1]}], 
						$CPIs[$programs{$keys[$pg2]}]);
		my ($pred_ii, $pred_speedup) = 
			max_speedup($predicted_CPIs[$programs{$keys[$pg1]}][$i][$j], 
					$predicted_CPIs[$programs{$keys[$pg2]}][$i][$j]);
		if($pred_ii == $best_ii){
			$same_partitioning[$i][$j] ++;
		}

		  }#pg2
		}#pg1
		
		if($same_partitioning[$i][$j] >= 220){
			print "($i, $j): $same_partitioning[$i][$j]\n";
		}
	}#j
}#i

my @thresholds = (210,200,190,180);
my @counts = (0,0);
my ($count_i,$max, $min) = (0,0,253);
for($i = 0; $i <= $length - 2; $i ++){
	for($j = $i+1; $j <= $length -1; $j ++){
		if($max < $same_partitioning[$i][$j]){
			$max = $same_partitioning[$i][$j];
		}
		if($min > $same_partitioning[$i][$j]){
			$min = $same_partitioning[$i][$j];
		}

		for($count_i = 0; $count_i < scalar(@thresholds); $count_i ++){
			if($same_partitioning[$i][$j] >= $thresholds[$count_i]){
				$counts[$count_i]++;
			}
		}
	}
}
print "\tMax: $max, Min: $min\n";
for($count_i = 0; $count_i < scalar(@thresholds); $count_i ++){
	printf "\t>= %3d: %0.04f%% (%d/120)\n", $thresholds[$count_i],
				$counts[$count_i]*100/120, $counts[$count_i];
}

exit 0;
