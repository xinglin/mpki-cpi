#!/usr/bin/perl

package Common;
use strict;
use Exporter;
use List::Util qw(sum);
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = qw(read_mpki_cpi read_predicted_cpis 
						print_avg print_top safe_delete_key combination
						mpki_min max_speedup max_ipc_sum max_cpi_err
						mpki_min3 max_speedup3 max_ipc_sum3
						mpki_min4 max_speedup4 max_ipc_sum4 );

my $debug = 0;
sub debug_info {
    my @message = @_;
    if($debug){
        print "@message";
    }
}

# 
# read accurate mpki and cpis arrays from a file
#
sub read_mpki_cpi {
    my ($filename, $mpkis, $cpis) = @_;
    my @mpkis = @{ $mpkis };
    my @cpis  = @{ $cpis  };

    open(FH, "<./data/$filename") or die("fail to open $filename\n");

    print "read data for $filename\n";
    my $line = <FH>;
    my $i = 0;
    while ($line = <FH> ){
        chomp $line;
        #print "$line\n";
        my $mpki = qx(echo $line | cut -d, -f2);
        chomp $mpki;
        my $cpi = qx(echo  $line | cut -d, -f3);
        chomp $cpi;

        #print "$mpki, $cpi\n";
        if( $mpki != 0 && $cpi != 0){
            $mpkis->[$i] = $mpki;
            $cpis->[$i]  = $cpi;
            $i ++;
        }
    }
    close FH;
}

#
# read predicted CPIs based on two specific ways from a file 
#
sub read_predicted_cpis {
    my ($filename, $predicted_cpis) = @_;

    open(FH, "<./predicted_cpi/$filename") or die("fail to open $filename\n");
    #debug_info("$filename\n");
    my $line = <FH>;
    my $i = 0;
    while ($line = <FH> ){
        chomp $line;
        #print "$line\n";
        my $cpi = qx(echo  $line | cut -d, -f3);
        chomp $cpi;

        #print "$mpki, $cpi\n";
        if( $cpi != 0){
            $predicted_cpis->[$i]  = $cpi;
            $i ++;
        }
    }
    close FH;
}

#
# return the way index i which results in the minimum MPKI sum
# for combinations of 2 programs. 
# The corresponding cache partition will be (i+1, 16-i-1).
#
use constant MAX_MPKI => 1000;

sub mpki_min {
    my ($array1, $array2) = @_;
    my @array1 = @{ $array1 };
    my @array2 = @{ $array2 };

    if (scalar(@array1) != scalar(@array2) ){
        fatal("[mpki_min]: the length of these two arrays are not equal!");
    }

    my $length = @array1;
    debug_info("array length: $length\n");

    my ($i, $element1, $element2, $min_i, $sum) = (0, 0, 0, 0, 0);
    my $min_sum = MAX_MPKI;
    for ( $i = 0; $i < $length-1; $i++ ){
        $element1 = $array1[$i];
        $element2 = $array2[$length - $i - 2];
        $sum = $element1 + $element2;
        #print "$i: $element1 + $element2 = $sum\n";
        if( $min_sum > ($sum) ){
            $min_sum = $sum;
            $min_i   = $i;
        }
    }
    debug_info("min_i: $min_i, min_sum: $min_sum\n");
    return $min_i;
}

#
# return the way index (i,j) which results in the minimum MPKI sum 
# for combinations of 3 programs
# The corresponding cache partition will be (i+1, j+1, 16-i-j-2).
#
sub mpki_min3 {
    my ($array1, $array2, $array3) = @_;
    my @array1 = @{ $array1 };
    my @array2 = @{ $array2 };
    my @array3 = @{ $array3 };

    if (scalar(@array1) != scalar(@array2)
            || scalar(@array1) != scalar(@array3) ){
        fatal("[mpki_min3]: the length of these three arrays are not equal!");
    }

    my $length = @array1;
    debug_info("array length: $length\n");

    my ($i, $j) = (0, 0);
    my ($element1, $element2, $element3) = (0, 0, 0);
    my $min_sum = MAX_MPKI;
	my ($min_i, $min_j, $sum) = (0, 0, 0);
    for ( $i = 0; $i < $length - 2; $i++ ){
        for($j = 0; $j <= $length - $i - 3; $j++ ){
            $element1 = $array1[$i];
            $element2 = $array2[$j];
            $element3 = $array3[$length -($i+$j) - 3];
            $sum = $element1 + $element2 + $element3;
            #print "$i: $element1 + $element2 = $sum\n";
            if( $min_sum > ($sum) ){
                $min_sum = $sum;
                $min_i   = $i;
                $min_j   = $j;
            }
        }
    }
    debug_info("min_i: $min_i, min_j: $min_j, min_sum: $min_sum\n");
    return ($min_i, $min_j);
}

#
# return the way index (i,j,k) which results in the minimum MPKI sum
# for combination of 4 benchmarks.
# The corresponding cache partition will be (i+1, j+1, k+1, 16-i-j-k-3).
#
sub mpki_min4 {
    my ($array1, $array2, $array3, $array4) = @_;
    my @array1 = @{ $array1 };
    my @array2 = @{ $array2 };
    my @array3 = @{ $array3 };
    my @array4 = @{ $array4 };

    if (scalar(@array1) != scalar(@array2) 
            || scalar(@array1) != scalar(@array3)
                || scalar(@array1 != scalar(@array4))){
        fatal("[mpki_min4]: the length of these three arrays are not equal!");
    }

    my $length = @array1;
    #debug_info("array length: $length\n");
    my ($i,$j,$k) = (0,0,0);
    my ($element1, $element2, $element3, $element4) = (0,0,0,0);
    my $min_sum = MAX_MPKI;
	my ($min_i, $min_j, $min_k, $sum) = (0,0,0,0);
    for ( $i = 0; $i <= $length - 4; $i++ ){
        for($j = 0; $j <= $length - $i - 4; $j++ ){
            for($k = 0; $k <= $length - $i -$j - 4; $k++ ){
            $element1 = $array1[$i];
            $element2 = $array2[$j];
            $element3 = $array3[$k];
            $element4 = $array4[$length -($i+$j+$k) - 4];
            $sum = $element1 + $element2 + $element3 + $element4;
            #print "$i: $element1 + $element2 = $sum\n";
            if( $min_sum > ($sum) ){
                $min_sum = $sum;
                $min_i   = $i;
                $min_j   = $j;
                $min_k   = $k;
            }
            }
        }
    }
    debug_info("min_i: $min_i, min_j: $min_j, min_k: $min_k, ".
                        "min_sum: $min_sum\n");
    return ($min_i, $min_j, $min_k);
}

#
# return the index way i which results in max weighted speedup
# for combinations of 2 programs.
# The corresponding cache partition will be (i+1, 16-i-1).
#
sub max_speedup {
    my ($array1, $array2) = @_;
    my @cpis1 = @{ $array1 };
    my @cpis2 = @{ $array2 };

    if (scalar(@cpis1) != scalar(@cpis2) ){
        fatal("[max_speedup]: the length of these two arrays are not equal!");
    }

    my $length = @cpis1;

    my ($i, $speedup1, $speedup2, $best_i, $speedup) = (0,0,0,0,0);
	my $best_speedup = 0;
    for ( $i = 0; $i < $length-1; $i++ ){
        $speedup1 = $cpis1[$length-1]/$cpis1[$i];
        $speedup2 = $cpis2[$length-1]/$cpis2[$length - $i - 2];
        $speedup = $speedup1 + $speedup2;
        #print "$i: $element1 + $element2 = $sum\n";
        if( $speedup > ($best_speedup) ){
            $best_speedup = $speedup;
            $best_i   = $i;
        }
    }
    debug_info("best_i: $best_i, best_speedup: $best_speedup\n");
    return ($best_i, $best_speedup);
}

#
# return the way index i which results in max IPC sum
# for 2-benchmark workloads
# The corresponding cache partition will be (i+1, 16-i-1).
#
sub max_ipc_sum {
    my ($array1, $array2) = @_;
    my @cpis1 = @{ $array1 };
    my @cpis2 = @{ $array2 };

    if (scalar(@cpis1) != scalar(@cpis2) ){
        fatal("[max_ipc_sum]: the length of these two arrays are not equal!");
    }

    my $length = @cpis1;

    my ($i, $ipc_sum1, $ipc_sum2, $best_i, $ipc_sum) = (0,0,0,0,0);
	my $best_ipc_sum = 0;
    for ( $i = 0; $i < $length-1; $i++ ){
        $ipc_sum1 = 1/$cpis1[$i];
        $ipc_sum2 = 1/$cpis2[$length - $i - 2];
        $ipc_sum = $ipc_sum1 + $ipc_sum2;
        #print "$i: $element1 + $element2 = $sum\n";
        if( $ipc_sum > ($best_ipc_sum) ){
            $best_ipc_sum = $ipc_sum;
            $best_i   = $i;
        }
    }
    debug_info("best_i: $best_i, best_speedup: $best_ipc_sum\n");
    return ($best_i, $best_ipc_sum);
}

#
# return the way index i which results in the max error in CPI predictions
#
sub max_cpi_err {
    my ($array1, $array2) = @_;
    my @cpis1 = @{ $array1 };
    my @pred_cpis2 = @{ $array2 };

    if (scalar(@cpis1) != scalar(@pred_cpis2) ){
        fatal("[max_cpi_err]: the length of these two arrays are not equal!");
    }

    my $length = @cpis1;

    my ($i,$cpi_diff) = (0,0);
	my ($max_i, $max_cpi_err) = (0,0);
    for ( $i = 0; $i <= $length-1; $i++ ){
        $cpi_diff = abs($cpis1[$i] - $pred_cpis2[$i])*100/$cpis1[$i];
        if( $cpi_diff > ($max_cpi_err) ){
			$max_cpi_err = $cpi_diff;
            $max_i   = $i;
        }
    }
    debug_info("best_i: $max_i, worst: $max_cpi_err%%\n");
    return ($max_i, $max_cpi_err);
}

#
# return the way index (i,j) which results in max weighted speedup 
# for 3-benchmark workloads. 
# The corresponding cache partition will be (i+1, j+1, 16-i-j-2).
#
sub max_speedup3 {
    my ($array1, $array2,$array3) = @_;
    my @cpis1 = @{ $array1 };
    my @cpis2 = @{ $array2 };
    my @cpis3 = @{ $array3 };

    if (scalar(@cpis1) != scalar(@cpis2) ||
			scalar(@cpis1) != scalar(@cpis3) ){
        fatal("[max_speedup3]: the lengths of the three arrays are not equal!");
    }

    my $length = @cpis1;

    my ($i, $j, $speedup1, $speedup2, $speedup3, $best_i, $best_j, $speedup)
			= (0,0,0,0,0,0,0,0);
	my $best_speedup = 0;
    for ( $i = 0; $i < $length-2; $i++ ){
      for ( $j = 0; $j <= $length - $i -3; $j++ ){
        $speedup1 = $cpis1[$length-1]/$cpis1[$i];
        $speedup2 = $cpis2[$length-1]/$cpis2[$j];
        $speedup3 = $cpis3[$length-1]/$cpis3[$length-$i-$j-3];
        $speedup = $speedup1 + $speedup2 + $speedup3;
        if( $speedup > ($best_speedup) ){
            $best_speedup = $speedup;
            $best_i  = $i;
			$best_j  = $j;
        }
	  }
    }
    debug_info("best_i: $best_i, best_j: $best_j,".
						" best_speedup: $best_speedup\n");
    return ($best_i, $best_j, $best_speedup);
}

#
# return the way index (i,j) which results in max IPC sum
# for 3-benchmark workloads. 
# The corresponding cache partition will be (i+1, j+1, 16-i-j-2).
#
sub max_ipc_sum3 {
    my ($array1, $array2,$array3) = @_;
    my @cpis1 = @{ $array1 };
    my @cpis2 = @{ $array2 };
    my @cpis3 = @{ $array3 };

    if (scalar(@cpis1) != scalar(@cpis2) ||
			scalar(@cpis1) != scalar(@cpis3) ){
        fatal("the lengths of these three arrays are not equal!");
    }

    my $length = @cpis1;

    my ($i, $j, $ipc1, $ipc2, $ipc3, $best_i, $best_j, $ipc_sum)
			= (0,0,0,0,0,0,0,0);
	my $best_ipc_sum = 0;
    for ( $i = 0; $i < $length-2; $i++ ){
      for ( $j = 0; $j <= $length - $i -3; $j++ ){
        $ipc1 = 1/$cpis1[$i];
        $ipc2 = 1/$cpis2[$j];
        $ipc3 = 1/$cpis3[$length - $i -$j - 3];
        $ipc_sum = $ipc1 + $ipc2 + $ipc3;
        if( $ipc_sum > ($best_ipc_sum) ){
            $best_ipc_sum = $ipc_sum;
            $best_i  = $i;
			$best_j  = $j;
        }
	  }
    }
    debug_info("best_i: $best_i, best_j: $best_j,".
						" best_speedup: $best_ipc_sum\n");
    return ($best_i, $best_j, $best_ipc_sum);
}

#
# return the way index (i,j,k) which results in max weighted speedup
# for 4-benchmark workloads.
# The corresponding cache partition will be (i+1, j+1, k+1, 16-i-j-k-3).
#
sub max_speedup4 {
    my ($array1, $array2, $array3, $array4) = @_;
    my @cpis1 = @{ $array1 };
    my @cpis2 = @{ $array2 };
    my @cpis3 = @{ $array3 };
    my @cpis4 = @{ $array4 };

    if (scalar(@cpis1) != scalar(@cpis2) ||
    	scalar(@cpis1) != scalar(@cpis3) ||
			scalar(@cpis1) != scalar(@cpis4) ){
        fatal("[max_spdup4]: the lengths of these four arrays are not equal!");
    }

    my $length = @cpis1;

    my ($i, $j, $k, $speedup1, $speedup2, $speedup3, $speedup4)
			= (0,0,0,0,0,0,0);
	my ($best_i, $best_j, $best_k, $speedup) = (0,0,0,0);
	my $best_speedup = 0;
    for ( $i = 0; $i <= $length - 4; $i++ ){
      for ( $j = 0; $j <= $length - $i - 4; $j++ ){
       for ( $k = 0; $k <= $length - $i -$j - 4; $k++ ){
        $speedup1 = $cpis1[$length-1]/$cpis1[$i];
        $speedup2 = $cpis2[$length-1]/$cpis2[$j];
        $speedup3 = $cpis3[$length-1]/$cpis3[$k];
        $speedup4 = $cpis4[$length-1]/$cpis4[$length - $i -$j -$k - 4];
        $speedup = $speedup1 + $speedup2 + $speedup3 + $speedup4;
        if( $speedup > ($best_speedup) ){
            $best_speedup = $speedup;
            $best_i  = $i;
			$best_j  = $j;
			$best_k = $k;
        }
	   }#k	
	  }#j
    }#i
    debug_info("best_i: $best_i, best_j: $best_j,best_k: $best_k".
						" best_speedup: $best_speedup\n");
    return ($best_i, $best_j, $best_k, $best_speedup);
}

#
# return the way index (i,j,k) which results in max IPC sum
# for 4-benchmark workloads.
#
sub max_ipc_sum4 {
    my ($array1, $array2,$array3,$array4) = @_;
    my @cpis1 = @{ $array1 };
    my @cpis2 = @{ $array2 };
    my @cpis3 = @{ $array3 };
    my @cpis4 = @{ $array4 };

    if (scalar(@cpis1) != scalar(@cpis2) ||
    	scalar(@cpis1) != scalar(@cpis3) ||
			scalar(@cpis1) != scalar(@cpis4) ){
        fatal("the lengths of these four arrays are not equal!");
    }

    my $length = @cpis1;

    my ($i, $j, $k, $ipc1, $ipc2, $ipc3, $ipc4) = (0,0,0,0,0,0,0);
	my ($best_i, $best_j, $best_k, $ipc_sum) = (0,0,0,0);
	my $best_ipc_sum = 0;
    for ( $i = 0; $i <= $length - 4; $i++ ){
      for ( $j = 0; $j <= $length - $i - 4; $j++ ){
       for ( $k = 0; $k <= $length - $i -$j - 4; $k++ ){
        $ipc1 = 1/$cpis1[$i];
        $ipc2 = 1/$cpis2[$j];
        $ipc3 = 1/$cpis3[$k];
        $ipc4 = 1/$cpis4[$length - $i -$j -$k - 4];
        $ipc_sum = $ipc1 + $ipc2 + $ipc3 + $ipc4;

        if( $ipc_sum > ($best_ipc_sum) ){
            $best_ipc_sum = $ipc_sum;
            $best_i  = $i;
			$best_j  = $j;
			$best_k = $k;
        }
	   }#k	
	  }#j
    }#i
    debug_info("best_i: $best_i, best_j: $best_j,best_k: $best_k".
						" best_speedup: $best_ipc_sum\n");
    return ($best_i, $best_j, $best_k, $best_ipc_sum);
}

#
# print the average value for an array
#
sub print_avg {
	my($name, $array, $total_num) = @_;
	my @array = @{ $array };
	if(!defined($total_num)){
		$total_num = scalar (@array);
	}

	if( scalar(@array) == 0 ){
		print "No element is in the arrray\n";
		return;
	}

	printf "$name average: %0.06f\n",
            sum(@array)/$total_num;
}

#
# print top_num values and number of values above thresholds for a hash.
#
sub print_top {
	my($hash, $name, $top_num, @thresholds) = @_;
	my %hash = %{ $hash };
	my ($i, @counts) = (0,0);
	print "Top $top_num highest $name:\n";

	for($i = 0; $i < scalar(@thresholds); $i++){
		$counts[$i] = 0;
	}

	# sort the values in this hash first
	foreach my $key ((sort { $hash{$b} <=> $hash{$a} }
                    (keys %hash))){
		for($i = 0; $i < scalar(@thresholds); $i++){
    		if( $hash{$key} >= $thresholds[$i] ){
        		$counts[$i]++;
    		}
		}

    	if($top_num >= 0){
        	printf "\t%0.06f\t\t\t $key\n", $hash{$key};
        	$top_num --;
    	}
	}
	my $total = (keys %hash);
	print "--------------$name summary------------------\n";
	print "\ttotal: $total\n";
	for($i = 0; $i < scalar(@thresholds); $i++){
		printf "\t>= %0.2f: %3d, %0.06f%%\n", $thresholds[$i], $counts[$i],
					$counts[$i]*100/$total;
	}
	print "\n";
}

sub safe_delete_key {
	my($hash, $key) = @_;
	my %hash = %{ $hash };
	if(exists ($hash{$key})){
		delete $hash{$key};
	}
}

#
# return possible combinations, e.g. return 253 for combination(23, 2).
#
sub combination {
	my($total, $subset) = @_;
	my $sum = 1;
	for(my $i = 0; $i < $subset; $i++ ){
		$sum *= ($total - $i);
	}
	for(my $i = 0; $i < $subset; $i++ ){
		$sum /= ($i + 1);
	}

	return $sum;
}

1;
