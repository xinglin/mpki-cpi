#!/usr/bin/perl -w
#
# analyze-preficted-cpi-err-fix-way - get the global way pair (way1, way2), 
#									  which results in the least average 
#									  predicted cpi error. 
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
my @avg_errs = ([],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]);

# calculate all possible combinations
print "\n\nbegin to get avg cpi prediction error with fix way pair ".
			"for each program...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my $pg = 0;
my $total_ways = 16;
for($i = 0; $i <= $total_ways-2; $i++){
	for($j = $i+1; $j <= $total_ways -1; $j++){
		my $cpi_err = 0;
		for($pg = 0; $pg <= $key_num - 1; $pg++){
			my($max_i, $max_cpi_err) = max_cpi_err($CPIs[$programs{$keys[$pg]}],
						$predicted_CPIs[$programs{$keys[$pg]}][$i][$j]);
			$cpi_err += $max_cpi_err;
		}
		$avg_errs[$i][$j] = $cpi_err/$key_num;	
	}
}

my $min_avg_err = 1000, $min_i = 0, $min_j = 0;
for($i = 0; $i <= $total_ways-2; $i++){
	for($j = $i+1; $j <= $total_ways -1; $j++){
		if($min_avg_err > $avg_errs[$i][$j]){
			$min_avg_err = $avg_errs[$i][$j];
			$min_i = $i;
			$min_j = $j;
		}
		printf "(%d,%d): %0.06f%%\n",$i, $j, $avg_errs[$i][$j];
	}
}
printf "Min: (%d,%d): %0.06f%%\n", $min_i, $min_j, $min_avg_err;

# CPI prediction error for every benchmark
my @every_errs = ();

# calculate all possible combinations
print "\n\nbegin to get CPI prediction error for each benchmark".
		" with the fix way pair...\n";
for($pg = 0; $pg <= $key_num - 1; $pg++){
	my($max_i, $max_cpi_err) = max_cpi_err($CPIs[$programs{$keys[$pg]}],
					$predicted_CPIs[$programs{$keys[$pg]}][$min_i][$min_j]);
    $every_errs[$pg] = $max_cpi_err;
}

for($pg = 0; $pg <= $key_num - 1; $pg++){
    printf "$keys[$pg]: %0.04f%%\n", $every_errs[$pg];
}
