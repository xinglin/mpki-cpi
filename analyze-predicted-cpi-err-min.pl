#!/usr/bin/perl -w
#
# analyze-predicted-cpi-err-min - get the minimum cpi prediction error for each
#								  benchmark and the value of c1.
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
# Four-dimensional array indexed by [program][way1][way2][way]
# CPIs are predicted based on CPI samples of way1 and way2
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
my @min_errs = ();
my @min_errs_c1 = ();

# calculate all possible combinations
print "\n\nbegin to get min cpi prediction error for each program...\n";
my @keys = (keys %programs);
my $key_num = scalar(@keys);
my $pg = 0;
my $total_ways = 16;
for($pg = 0; $pg <= $key_num -1; $pg ++){
	my ($i, $j) = (0,0);
	my $min_err_pg = 1000, $min_err_i = 0, $min_err_j = 0;
	for($i = 0; $i <= $total_ways-2; $i++){
		for($j = $i+1; $j <= $total_ways -1; $j++){
			my ($way, $cpi_err) = 
					max_cpi_err($CPIs[$programs{$keys[$pg]}],
							$predicted_CPIs[$programs{$keys[$pg]}][$i][$j]);
			if($cpi_err < $min_err_pg){
				($min_err_pg,$min_err_i,$min_err_j) = ($cpi_err,$i,$j);
			}
		}
	}

	$min_errs[$pg] = $min_err_pg;	
	my $c1 = ($CPIs[$programs{$keys[$pg]}][$min_err_i] 
				- $CPIs[$programs{$keys[$pg]}][$min_err_j])
			/($MPKIs[$programs{$keys[$pg]}][$min_err_i] 
				- $MPKIs[$programs{$keys[$pg]}][$min_err_j]);
	$min_errs_c1[$pg] = $c1;
}

my $count1 = 0, $count5 = 0, $max_err = 0, $minimal_err = 100, $max_err_pg = 0; 
for($pg = 0; $pg <= $key_num -1; $pg ++){
	if($min_errs[$pg] > 1){
		$count1 ++;
	}
	if($min_errs[$pg] > 0.5){
		$count5 ++;
	}
	if($min_errs[$pg] > $max_err){
		$max_err = $min_errs[$pg];
		$max_err_pg = $pg;
	}
	if($min_errs[$pg] < $minimal_err){
		$minimal_err = $min_errs[$pg];
	}
	
	print "$keys[$pg]: $min_errs[$pg]\n";
}
print "Max err: $keys[$max_err_pg]\n";
printf "Max: %0.06f%%, Min: %0.06f%%\n", $max_err, $minimal_err;
printf ">= 1 %%: %d, %0.04f%%\n", $count1, $count1*100/@min_errs;
printf ">= 0.5%%: %d, %0.04f%%\n", $count5, $count5*100/@min_errs;

print_avg("min predicted cpi err",\@min_errs);

for($pg = 0; $pg <= $key_num -1; $pg ++){
	print "$keys[$pg]&";
	printf "%0.04f\\\\\\line\n", $min_errs_c1[$pg];
}
