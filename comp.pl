use Data::Dumper;
use Getopt::Long;
use File::Basename;
use Image::Magick::Thumbnail;
use Image::ExifTool qw(:Public);
$cmdline = $0." ".join(" ",@ARGV);

sub usage {
    printf "Usage: $0 [--dir <dir>]";
};
Getopt::Long::Configure(qw(bundling));
GetOptions(\%OPT,qw{
		       verbose|v+
		       dir|d=s
		       thumbdir|t=s
		       copydir=s
		       fast
		       nodup=s
		       out|o=s
                       width|w=i
                       height|h=i
                       xcnt|x=i
                       ycnt|y=i
	       },@g_more) or usage(\*STDERR);
$OPT{'out'}   = "compose.jpg" if (!exists($OPT{'out'}));
$OPT{'dir'}   = "." if (!exists($OPT{'dir'}));
$OPT{'width'}   = 135 if (!exists($OPT{'width'}));
$OPT{'height'}   = 100 if (!exists($OPT{'height'}));
$OPT{'xcnt'}   = 20 if (!exists($OPT{'xcnt'}));
$OPT{'ycnt'}   = 40 if (!exists($OPT{'ycnt'}));
$cnt = $OPT{'xcnt'} * $OPT{'ycnt'};
if ($OPT{'verbose'}) {
    print("$cnt Photos\n");
}

$cmd = "find ".$OPT{'dir'}." -type f";
@fn = split("\n",`$cmd`);
%f = ();
@f = ();
foreach my $f (@fn) {
    my ($fnhbase, $fnhdir, $fnhext) = fileparse($f,(".jpg",".jpg",".JPG",".jpeg") );
    if ($fnhext) {
	push(@f,[$fnhdir,$fnhbase,$fnhext]);
	
    }
}

%date = (); %w = (); %h = ();
@pics = ();
for ($i = 0; $i < ($cnt+int($cnt/3*2)) && scalar(@f); $i++) {
    $pidx = scalar(@pics);
    $fcnt = ($#f)+1;
    my $randidx = int(rand($fcnt-1));
    $p = splice(@f,$randidx,1);
    push(@pics,$p);
    my ($fnhdir,$fnhbase,$fnhext) = @{$p};
    if ($OPT{'verbose'} > 1) {
	print("Process:".$fnhdir.$fnhbase.$fnhext."\n");
    }
    my $fn = $fnhdir.$fnhbase.$fnhext;
    
    #extract date from EXIF
    my @ioTagList = ('ModifyDate','DateTime','DateTimeOriginal','ImageWidth', 'ImageHeight');
    my $exifTool = new Image::ExifTool;
    $exifTool->Options(DateFormat => "%Y/%m/%d-%H:%M:%S");
    my $info = $exifTool->ImageInfo($fn, @ioTagList);
    my $date = sprintf("%s00",$$info{'ModifyDate'}); #DateTime
    $date = sprintf("%s00",$$info{'DateTimeOriginal'}) if ($date eq '00'); #DateTime
    if ($date =~ m/([0-9]+)\/([0-9]+)\/([0-9]+)\-([0-9]+):([0-9]+):([0-9]+)/) {
	my ($y, $m, $d, $h, $min, $sec) = ($1,$2,$3,$4,$5,$6);
	$$f{'data'} = [$y, $m, $d, $h, $min, $sec];
	$$f{'min'} = $date;
	$day = $$f{'day'} = sprintf("%04d-%02d-%02d",$y,$m,$d);
    } else {
	$$f{'min'} = 'unknown';
	$day = $$f{'day'} = 'unknown';
    }
    if ($OPT{'verbose'} > 1) {
	print(" date: $day\n");
    }
    $date{$day} = [@{$date{$day}}, $pidx];
    $w{$pidx} = $$info{'ImageWidth'};
    $h{$pidx} = $$info{'ImageHeight'};
    
    #print ($w{$pidx});
    #print ($h{$pidx});
    
}

@spics = ();
foreach my $d (sort keys %date) {
    @i = @{$date{$d}};
    if ($OPT{'verbose'} > 1) {
	print ($d.":\n");
    }
    foreach my $j (@i) {
	my ($fnhdir,$fnhbase,$fnhext) = @{$pics[$j]};
	if ($OPT{'verbose'} > 1) {
	    print (" ".$fnhdir,$fnhbase,$fnhext."\n");
	}
	push(@spics,[$fnhdir,$fnhbase,$fnhext,$w{$j},$h{$j},$d]);
	print ("$fnhdir,$fnhbase,$fnhext,$w{$j},$h{$j}\n");
    }
}

$ppw = $OPT{'width'} * $OPT{'xcnt'};
$pph = $OPT{'height'} * $OPT{'ycnt'};

$pcmt = "convert -size ".(${ppw}*2)."x".(${pph}*2)." xc:black $OPT{'out'} ";
$pcmto = `$pcmt`; print ($pcmto);

@c = (); $pd = ""; $y = 0;
while (scalar(@spics)) {
    
#for ($y = 0; $y < $OPT{'ycnt'}; $y++) {
    my $cx = 0; $cony = 0;
    while (($ppw+int($ppw/4*1)) > $cx && scalar(@spics)) {
	my $p = shift(@spics);
	($fnhdir,$fnhbase,$fnhext,$rpw,$rph,$d) = @$p;
	if ($OPT{'verbose'}) {
	    print (":".$fnhdir,$fnhbase,$fnhext."\n");
	}

	$yp = $y*($OPT{'height'}+2);
	$xp = $cx; #$x*$OPT{'width'};
	$ch = $OPT{'height'};
	if ($d ne $pd) {
	    $pcmt = " -pointsize 20 -fill white -draw \" translate $xp,$yp rotate 90 text 0,0 '$d'\" "; 
	    push(@c,$pcmt);
	    $cx += 20;
	}
	$pd = $d;
	$xp = $cx; #$x*$OPT{'width'};
	
	$di = $rpw / $rph   ;
	$cw = $OPT{'width'};
	$cw = int($ch * $di);
	$cx += $cw + 2;
	$pcmt = " -draw \"image over $xp,$yp $cw,$ch '$fnhdir$fnhbase$fnhext'\" ";
	push(@c,$pcmt);
	if (scalar(@c) > 50) {
	    $pcmt = "convert ".join(" ",@c)." $OPT{'out'} $OPT{'out'}";
	    if ($OPT{'verbose'}) {
		print $pcmt."\n";
	    }
	    $pcmto = `$pcmt`; print ($pcmto);
	    @c = ();
	}
    }
    $y++;
}

if (scalar(@c) > 0) {
    $pcmt = "convert ".join(" ",@c)." $OPT{'out'} $OPT{'out'}";
    if ($OPT{'verbose'}) {
	print $pcmt."\n";
    }
    $pcmto = `$pcmt`; print ($pcmto);
}
