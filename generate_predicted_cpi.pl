#!/usr/bin/perl -w
#
# generate_predicted_cpi - generate all possible predicted cpi for each 
#						   benchmark.
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
#        Make sure this equation holds: $CPIs = $programs + 1.
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

my $debug = 1;
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

#
# given $program, ($way1, $way2), mpkis, and cpis, output the 
# predicted cpis based on these two ways into a file, named as 
# $program.$way1.$way2.cpis
# 			cpi = c1 * mpki + c2 
#
sub output_predict_cpi {
	my($program, $way1, $way2, $mpkis, $cpis) = @_;
	my @mpkis = @{$mpkis}, @cpis = @{$cpis}, @cpis2 = 0;
	my $mpki1 = $mpkis[$way1], $cpi1 = $cpis[$way1];
	my $mpki2 = $mpkis[$way2], $cpi2 = $cpis[$way2]; 

	if($mpki2 == $mpki1){
		return;
	}

	my $c1 = ($cpi2 - $cpi1)/($mpki2 - $mpki1);
	my $c2 = $cpi1 - $c1 * $mpki1;

	my $i = 0, $length = scalar( @mpkis );
	my $delta = 0, $max_delta = 0,$way_of_max_delta = -1;
	for($i = 0; $i < $length; $i++){
		$cpis2[$i] = $c1 * $mpkis[$i] + $c2;
		$delta = abs( $cpis2[$i] - $cpis[$i]);
		if( $max_delta < $delta ){
			$max_delta = $delta;
			$way_of_max_delta = $i; 
		}
	}
	
	my $output_str = sprintf("way%d + way%d:: %d: %0.08f, %0.04f%%\n", 
						$way1+1,$way2+1, $way_of_max_delta, 
						$max_delta, $max_delta*100/$cpis[$way_of_max_delta]);
	debug_info($output_str);

	my $filename = sprintf("%s.%02d.%02d.cpis", $program, $way1+1 , $way2+1);	
	open(FH, ">", "./predicted_cpi/$filename") or 
									die("fail to open $filename\n");

	print FH "way\tmpki\tpredicted cpi\n";
	for($i = 0; $i <= $length - 1; $i++){
		printf FH "%d,\t%0.010f,\t%0.010f\n", $i+1,$mpkis[$i],$cpis2[$i];
	}
	close FH;
}

foreach $key (keys %programs) {
	print "\n------------------$key---------------------------\n\n";
	my $i = 0, $j = 0, $length = scalar( @MPKIs[$programs{$key}] );
	for( $i = 0; $i <= $length -2; $i++){
		for( $j = $i+1; $j <= $length -1; $j++){
			output_predict_cpi($key, $i, $j, $MPKIs[$programs{$key}], 
												$CPIs[$programs{$key}]);
		}	
	}

}

exit 0;
